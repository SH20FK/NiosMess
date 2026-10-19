import 'dart:convert';
import 'dart:isolate';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as hashes;
import '../ordinary_e2ee/ordinary_e2ee_codec.dart';

/// Relays see routing metadata, never message text or account private keys.
/// The signed lifetime is authoritative. Hop counts are a best-effort bound;
/// an untrusted relay can reset them, but cannot extend expiry or change content.
class MeshPacket {
  const MeshPacket._(
    this.body,
    this.signature,
    this.work,
    this.hops,
    this.id,
    this.envelope,
    this.expiresAt,
    this.author,
    this.purpose,
  );
  static const maxBytes = 24576;
  static const maxHops = 8;
  static const lifetime = Duration(days: 3);
  final String body, signature, id, envelope, author, purpose;
  final int work, hops;
  final DateTime expiresAt;
  String get wire => jsonEncode({
    'v': 1,
    'body': body,
    'signature': signature,
    'work': work,
    'hops': hops,
  });
  int get byteLength => utf8.encode(wire).length;
  MeshPacket forwarded() => MeshPacket._(
    body,
    signature,
    work,
    hops + 1,
    id,
    envelope,
    expiresAt,
    author,
    purpose,
  );

  static String _id(String body) => base64UrlEncode(
    hashes.sha256.convert(utf8.encode(body)).bytes,
  ).replaceAll('=', '');
  static bool _work(String id, int nonce) {
    final digest = hashes.sha256
        .convert(utf8.encode('niosmess-ble-work-v1:$id:$nonce'))
        .bytes;
    return digest[0] == 0 && digest[1] == 0;
  }

  static int _mine(String id) {
    for (var i = 0; i < 0x7fffffff; i++) {
      if (_work(id, i)) return i;
    }
    throw StateError('Не удалось подготовить Bluetooth-пакет');
  }

  static Future<MeshPacket> create(
    OrdinaryKeys keys,
    String envelope, {
    required List<int> deviceSeed,
    required String permit,
    DateTime? now,
    String purpose = 'message',
  }) async {
    final time = (now ?? DateTime.now()).toUtc();
    final pub = await keys.public();
    final deviceKey = await Ed25519().newKeyPairFromSeed(deviceSeed);
    final device = base64Encode((await deviceKey.extractPublicKey()).bytes);
    final claim = permitClaims(permit);
    if (claim['device'] != device ||
        claim['author'] != pub['ed'] ||
        claim['user'] != keys.userId ||
        claim['epoch'] != keys.epoch) {
      throw const FormatException('Wrong offline device permit');
    }
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      (claim['exp'] as int) * 1000,
      isUtc: true,
    );
    final limit = time.add(lifetime);
    final body = jsonEncode({
      'v': 1,
      'created': time.millisecondsSinceEpoch,
      'expires':
          (expiry.isBefore(limit) ? expiry : limit).millisecondsSinceEpoch,
      'author': pub['ed'],
      'device': device,
      'permit': permit,
      'packet': envelope,
      'purpose': purpose,
    });
    // Reserve space for signature, proof of work and JSON framing before mining.
    if (utf8.encode(body).length > maxBytes - 1024) {
      throw StateError('Сообщение слишком большое для Bluetooth');
    }
    final id = _id(body);
    final signature = base64Encode(
      (await Ed25519().sign(
        utf8.encode('niosmess-ble-v1:$body'),
        keyPair: deviceKey,
      )).bytes,
    );
    final nonce = await Isolate.run(() => _mine(id));
    return parse(
      jsonEncode({
        'v': 1,
        'body': body,
        'signature': signature,
        'work': nonce,
        'hops': 0,
      }),
      now: time,
    );
  }

  /// Offline peers authenticate the normal pinned E2E signature. Only the
  /// server can verify this permit's MAC and check session revocation on backfill.
  static Map<String, dynamic> permitClaims(String permit) {
    if (permit.length > 4096) throw const FormatException('Invalid permit');
    final parts = permit.split('.');
    if (parts.length != 2 ||
        base64Url.decode(base64Url.normalize(parts[1])).length != 32) {
      throw const FormatException('Invalid permit');
    }
    final data = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
    );
    if (data is! Map<String, dynamic> ||
        data.length != 9 ||
        data['v'] != 1 ||
        data['user'] is! int ||
        data['session'] is! int ||
        data['iat'] is! int ||
        data['exp'] is! int ||
        data['epoch'] is! String ||
        data['author'] is! String ||
        data['device'] is! String ||
        data['nonce'] is! String ||
        (data['exp'] as int) <= (data['iat'] as int) ||
        (data['exp'] as int) - (data['iat'] as int) > lifetime.inSeconds) {
      throw const FormatException('Invalid permit claims');
    }
    return data;
  }

  static Future<MeshPacket> parse(
    String wire, {
    DateTime? now,
    bool forBackfill = false,
  }) async {
    if (utf8.encode(wire).length > maxBytes) {
      throw const FormatException('Mesh packet too large');
    }
    final decoded = jsonDecode(wire);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 5 ||
        decoded['v'] != 1 ||
        decoded['body'] is! String ||
        decoded['signature'] is! String ||
        decoded['work'] is! int ||
        decoded['hops'] is! int) {
      throw const FormatException('Invalid mesh frame');
    }
    final body = decoded['body'] as String, id = _id(body);
    final work = decoded['work'] as int, hops = decoded['hops'] as int;
    if (work < 0 ||
        work > 0x7fffffff ||
        hops < 0 ||
        hops > maxHops ||
        !_work(id, work)) {
      throw const FormatException('Invalid mesh budget');
    }
    final value = jsonDecode(body);
    if (value is! Map<String, dynamic> ||
        value.length != 8 ||
        value['v'] != 1 ||
        value['created'] is! int ||
        value['expires'] is! int ||
        value['author'] is! String ||
        value['device'] is! String ||
        value['permit'] is! String ||
        value['packet'] is! String ||
        !const ['message', 'receipt'].contains(value['purpose'])) {
      throw const FormatException('Invalid signed mesh body');
    }
    final created = DateTime.fromMillisecondsSinceEpoch(
      value['created'] as int,
      isUtc: true,
    );
    final expires = DateTime.fromMillisecondsSinceEpoch(
      value['expires'] as int,
      isUtc: true,
    );
    final time = (now ?? DateTime.now()).toUtc();
    if (created.isAfter(time.add(const Duration(minutes: 5))) ||
        (!forBackfill && !expires.isAfter(time)) ||
        !expires.isAfter(created) ||
        expires.difference(created) > lifetime) {
      throw const FormatException('Expired mesh message');
    }
    final author = value['author'] as String,
        signature = decoded['signature'] as String;
    decodeE2e(author, 32);
    final device = value['device'] as String;
    decodeE2e(device, 32);
    final claim = permitClaims(value['permit'] as String);
    if (claim['device'] != device ||
        claim['author'] != author ||
        created.millisecondsSinceEpoch <
            (claim['iat'] as int) * 1000 - 300000 ||
        expires.millisecondsSinceEpoch > (claim['exp'] as int) * 1000) {
      throw const FormatException('Invalid offline credential');
    }
    if (!await OrdinaryCodec.verify(
      'niosmess-ble-v1:$body',
      signature,
      device,
    )) {
      throw const FormatException('Invalid mesh signature');
    }
    final envelope = value['packet'] as String;
    if (!OrdinaryCodec.recognises(envelope)) {
      throw const FormatException('E2E required');
    }
    final inner = OrdinaryCodec.packet(envelope);
    final header = OrdinaryCodec.header(envelope);
    if (header['sender'] != claim['user'] ||
        header['epoch'] != claim['epoch']) {
      throw const FormatException('Mismatched offline credential');
    }
    if (!await OrdinaryCodec.verify(
      inner['body'] as String,
      inner['signature'] as String,
      author,
    )) {
      throw const FormatException('Mismatched message author');
    }
    return MeshPacket._(
      body,
      signature,
      work,
      hops,
      id,
      envelope,
      expires,
      author,
      value['purpose'] as String,
    );
  }
}
