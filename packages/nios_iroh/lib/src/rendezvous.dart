import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:iroh_quic/iroh_quic.dart' as iroh;
import 'package:nios_sdk/link.dart';

import 'transport.dart';

/// A verified native address with its monotonic server publication revision.
/// Persist [revision] alongside the device pin to reject replayed older answers.
final class IrohAddressPublication {
  const IrohAddressPublication({
    required this.peer,
    required this.revision,
    required this.expiresAt,
  });

  final IrohPeer peer;
  final int revision;
  final DateTime expiresAt;
}

/// Authenticated address exchange only. This client neither creates a relay nor
/// weakens the independently pinned Iroh/Link identities from enrollment.
/// Native Iroh must be initialized before calling publish/lookup.
final class IrohRendezvousClient {
  IrohRendezvousClient({
    required this.baseUri,
    required this.accountId,
    required this.deviceId,
    required this.bearerToken,
    this.timeout = const Duration(seconds: 15),
    List<String> allowedRelayUrls = const [],
    http.Client? client,
    bool allowInsecureLoopback = false,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _clock = clock ?? DateTime.now,
       _allowedRelayUrls = List.unmodifiable(allowedRelayUrls) {
    final loopback = const {
      '127.0.0.1',
      'localhost',
      '::1',
    }.contains(baseUri.host);
    if ((baseUri.scheme != 'https' &&
            !(allowInsecureLoopback && loopback && baseUri.scheme == 'http')) ||
        baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        bearerToken.isEmpty ||
        bearerToken.length > 4096 ||
        timeout <= Duration.zero ||
        !RegExp(r'^[A-Za-z0-9._:@/-]{1,160}$').hasMatch(accountId) ||
        !RegExp(r'^[A-Za-z0-9._:@-]{1,160}$').hasMatch(deviceId) ||
        allowedRelayUrls.length > 8) {
      throw ArgumentError(
        'Invalid authenticated Iroh rendezvous configuration',
      );
    }
    for (final value in allowedRelayUrls) {
      final uri = Uri.parse(value);
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw ArgumentError('Iroh relays require explicit HTTPS URLs');
      }
    }
  }

  final Uri baseUri;
  final String accountId;
  final String deviceId;
  final String bearerToken;
  final Duration timeout;
  final List<String> _allowedRelayUrls;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _clock;
  final Set<Completer<void>> _aborters = {};
  bool _closed = false;

  static Uint8List _signingBytes(
    String account,
    String device,
    Map<String, dynamic> value,
  ) => Uint8List.fromList(
    utf8.encode(
      jsonEncode([
        'nios-iroh-address',
        1,
        account,
        device,
        value['endpoint_key'],
        value['revision'],
        value['expires'],
        value['address'],
      ]),
    ),
  );

  void _checkRelays(iroh.EndpointAddr address) {
    final allowed = _allowedRelayUrls
        .map((value) => iroh.RelayUrl.parse(value).value)
        .toSet();
    if (address.relayUrls.any((value) => !allowed.contains(value.value))) {
      throw const LinkTransportException(
        'iroh_unapproved_relay',
        permanent: true,
      );
    }
  }

  Future<void> publish({
    required iroh.EndpointAddr address,
    required iroh.SecretKey endpointIdentity,
    required crypto.SimpleKeyPair linkSigningKey,
    required int revision,
    Duration expiresIn = const Duration(minutes: 3),
  }) async {
    if (revision < 1 ||
        revision > 9007199254740991 ||
        expiresIn <= Duration.zero ||
        expiresIn > const Duration(minutes: 5) ||
        address.id != endpointIdentity.publicKey) {
      throw ArgumentError('Invalid Iroh publication identity or lifetime');
    }
    _checkRelays(address);
    final encoded = address.canonical().encode();
    if (encoded.isEmpty || encoded.length > 4096) {
      throw ArgumentError('Iroh address exceeds the publication budget');
    }
    final value = <String, dynamic>{
      'v': 1,
      'endpoint_key': base64Encode(endpointIdentity.publicKey.asBytes()),
      'address': base64Encode(encoded),
      'revision': revision,
      'expires': _clock().add(expiresIn).millisecondsSinceEpoch,
    };
    final signing = _signingBytes(accountId, deviceId, value);
    value['signature'] = base64Encode(endpointIdentity.sign(signing).toBytes());
    value['device_signature'] = base64Encode(
      (await crypto.Ed25519().sign(signing, keyPair: linkSigningKey)).bytes,
    );
    final response = await _request('PUT', '/v1/iroh/address', value);
    if (response['stored'] != true || response['revision'] != revision) {
      throw const LinkTransportException(
        'invalid_iroh_publication_receipt',
        permanent: true,
      );
    }
  }

  Future<IrohAddressPublication> lookup({
    required String peerAccountId,
    required String peerDeviceId,
    required iroh.EndpointId pinnedEndpointId,
    required crypto.SimplePublicKey pinnedLinkSigningKey,
    required int chatId,
    int minimumRevision = 0,
  }) async {
    if (chatId < 1 ||
        chatId > 9007199254740991 ||
        minimumRevision < 0 ||
        minimumRevision > 9007199254740991 ||
        !RegExp(r'^[A-Za-z0-9._:@-]{1,160}$').hasMatch(peerDeviceId) ||
        !RegExp(r'^[A-Za-z0-9._:@/-]{1,160}$').hasMatch(peerAccountId) ||
        pinnedLinkSigningKey.type != crypto.KeyPairType.ed25519 ||
        pinnedLinkSigningKey.bytes.length != 32) {
      throw ArgumentError('Invalid Iroh peer pin or chat');
    }
    final value = await _request(
      'GET',
      '/v1/iroh/devices/${Uri.encodeComponent(peerDeviceId)}/address?chat_id=$chatId',
    );
    const fields = {
      'account',
      'device',
      'v',
      'endpoint_key',
      'address',
      'revision',
      'expires',
      'signature',
      'device_signature',
    };
    final revision = value['revision'];
    final expires = value['expires'];
    final now = _clock().millisecondsSinceEpoch;
    if (value.length != fields.length ||
        !value.keys.toSet().containsAll(fields) ||
        value['account'] != peerAccountId ||
        value['device'] != peerDeviceId ||
        value['v'] is! int ||
        value['v'] != 1 ||
        value['endpoint_key'] != base64Encode(pinnedEndpointId.asBytes()) ||
        revision is! int ||
        revision < 1 ||
        revision < minimumRevision ||
        revision > 9007199254740991 ||
        expires is! int ||
        expires <= now ||
        expires >
            now + const Duration(minutes: 5, seconds: 30).inMilliseconds) {
      throw const LinkTransportException('stale_iroh_address', permanent: true);
    }
    final signing = _signingBytes(peerAccountId, peerDeviceId, value);
    final endpointSignature = _decode64(value['signature'], 64);
    final linkSignature = _decode64(value['device_signature'], 64);
    if (!pinnedEndpointId.verify(
          signing,
          iroh.Signature.fromBytes(endpointSignature),
        ) ||
        !await crypto.Ed25519().verify(
          signing,
          signature: crypto.Signature(
            linkSignature,
            publicKey: pinnedLinkSigningKey,
          ),
        )) {
      throw const LinkTransportException(
        'forged_iroh_address',
        permanent: true,
      );
    }
    final bytes = _decode64(value['address'], null, maximum: 4096);
    final address = iroh.EndpointAddr.decode(bytes).canonical();
    if (address.id != pinnedEndpointId) {
      throw const LinkTransportException(
        'iroh_address_identity_mismatch',
        permanent: true,
      );
    }
    _checkRelays(address);
    return IrohAddressPublication(
      peer: IrohPeer(
        deviceId: peerDeviceId,
        endpointId: pinnedEndpointId,
        address: address,
      ),
      revision: revision,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expires, isUtc: true),
    );
  }

  static Uint8List _decode64(Object? value, int? length, {int maximum = 4096}) {
    if (value is! String || value.length > maximum * 4 ~/ 3 + 8) {
      throw const FormatException('Invalid signed Iroh address field');
    }
    final decoded = base64Decode(value);
    if ((length != null && decoded.length != length) ||
        decoded.length > maximum ||
        base64Encode(decoded) != value) {
      throw const FormatException('Invalid signed Iroh address size');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (_closed) throw const LinkTransportException('transport_closed');
    final abort = Completer<void>();
    _aborters.add(abort);
    final timer = Timer(timeout, () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final request =
          http.AbortableRequest(
              method,
              baseUri.resolve(path),
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers.addAll({
              'authorization': 'Bearer $bearerToken',
              'content-type': 'application/json',
            });
      if (body != null) request.body = jsonEncode(body);
      final response = await _client.send(request).timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(timeout)) {
        if (bytes.length + chunk.length > 16384) {
          throw const FormatException('Oversized Iroh rendezvous response');
        }
        bytes.addAll(chunk);
      }
      if (response.statusCode != 200) {
        throw LinkTransportException(
          'iroh_rendezvous_http_${response.statusCode}',
          permanent: const {
            400,
            401,
            403,
            404,
            409,
            413,
            422,
          }.contains(response.statusCode),
        );
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid Iroh rendezvous response');
      }
      return decoded;
    } finally {
      timer.cancel();
      _aborters.remove(abort);
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<void> close() async {
    _closed = true;
    for (final abort in _aborters) {
      if (!abort.isCompleted) abort.complete();
    }
    if (_ownsClient) _client.close();
  }
}
