import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart' as rsa;
import 'ordinary_e2ee_codec.dart';

const enrollmentIssuer = 'https://ni-os.ru';

class EnrollmentProof {
  const EnrollmentProof(
    this.token,
    this.subject,
    this.requestId,
    this.target,
    this.salt,
    this.expiresAt,
  );
  final String token, subject, requestId, target, salt;
  final DateTime expiresAt;

  Future<String> approvalText(int userId, String packet) async {
    final digest = await Sha256().hash(utf8.encode(token));
    final hex = digest.bytes
        .map((n) => n.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'niosmess-auto-approve-v1:$userId:$requestId:$target:$hex:$packet';
  }

  Future<List<int>> wrappingSalt() async =>
      (await Sha256().hash(utf8.encode('niosmess-auto-pair-v1:$token'))).bytes;
}

class EnrollmentVerifier {
  EnrollmentVerifier({this.fetchKeys, DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Future<E2eJson> Function()? fetchKeys;
  final DateTime Function() now;
  E2eJson? _keys;
  DateTime? _loaded;

  Future<E2eJson> _load({bool refresh = false}) async {
    if (!refresh &&
        _keys != null &&
        _loaded != null &&
        now().difference(_loaded!).inSeconds < 300) {
      return _keys!;
    }
    if (fetchKeys != null) {
      _keys = await fetchKeys!();
    } else {
      // The issuer URL is fixed by the app, never supplied by the message relay.
      final response = await http
          .get(Uri.parse('$enrollmentIssuer/oauth/jwks'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200 || response.bodyBytes.length > 32768) {
        throw StateError('NiosID verification unavailable');
      }
      _keys = jsonDecode(utf8.decode(response.bodyBytes)) as E2eJson;
    }
    if (_keys!['keys'] is! List ||
        (_keys!['keys'] as List).isEmpty ||
        (_keys!['keys'] as List).length > 8) {
      throw const FormatException('Invalid NiosID verification keys');
    }
    _loaded = now();
    return _keys!;
  }

  Future<EnrollmentProof> verify(String token, String subject) async {
    try {
      return await _verify(token, subject);
    } on TypeError {
      throw const FormatException('Invalid login proof');
    } on ArgumentError {
      throw const FormatException('Invalid login proof');
    }
  }

  Future<EnrollmentProof> _verify(String token, String subject) async {
    if (token.length > 16384) {
      throw const FormatException('Invalid login proof');
    }
    final pieces = token.split('.');
    if (pieces.length != 3) throw const FormatException('Invalid login proof');
    final header =
        jsonDecode(
              utf8.decode(base64Url.decode(base64Url.normalize(pieces[0]))),
            )
            as E2eJson;
    final claims =
        jsonDecode(
              utf8.decode(base64Url.decode(base64Url.normalize(pieces[1]))),
            )
            as E2eJson;
    if (header['alg'] != 'RS256' || header['kid'] is! String) {
      throw const FormatException('Invalid login signature');
    }
    var keys = await _load();
    List<E2eJson> matching(E2eJson value) => (value['keys'] as List)
        .whereType<Map>()
        .map((key) => Map<String, dynamic>.from(key))
        .where(
          (key) =>
              key['kid'] == header['kid'] &&
              key['kty'] == 'RSA' &&
              (key['alg'] == null || key['alg'] == 'RS256'),
        )
        .toList();
    var candidates = matching(keys);
    if (candidates.isEmpty) {
      keys = await _load(refresh: true);
      candidates = matching(keys);
    }
    if (candidates.length != 1) {
      throw const FormatException('Unknown NiosID key');
    }
    BigInt integer(String value) {
      final bytes = base64Url.decode(base64Url.normalize(value));
      if (bytes.length > 1024) throw const FormatException('Invalid RSA key');
      return BigInt.parse(
        bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      );
    }

    final key = candidates.single;
    final modulus = integer(key['n'] as String),
        exponent = integer(key['e'] as String);
    if (modulus.bitLength < 2048 || exponent != BigInt.from(65537)) {
      throw const FormatException('Invalid NiosID key');
    }
    final signer = rsa.RSASigner(rsa.SHA256Digest(), '0609608648016503040201')
      ..init(
        false,
        rsa.PublicKeyParameter<rsa.RSAPublicKey>(
          rsa.RSAPublicKey(modulus, exponent),
        ),
      );
    if (!signer.verifySignature(
      Uint8List.fromList(utf8.encode('${pieces[0]}.${pieces[1]}')),
      rsa.RSASignature(base64Url.decode(base64Url.normalize(pieces[2]))),
    )) {
      throw const FormatException('Invalid NiosID signature');
    }
    final current = now().millisecondsSinceEpoch ~/ 1000;
    if (claims['iss'] != enrollmentIssuer ||
        claims['sub'] != subject ||
        !const ['niosmess_native', 'niosmess_web'].contains(claims['aud']) ||
        claims['iat'] is! int ||
        claims['exp'] is! int ||
        current - (claims['iat'] as int) < -30 ||
        current - (claims['iat'] as int) > 600 ||
        (claims['exp'] as int) <= current ||
        claims['nonce'] is! String) {
      throw const FormatException('Expired or mismatched NiosID login');
    }
    final binding = (claims['nonce'] as String).split(':');
    if (binding.length != 4 ||
        binding[0] != 'nios-e2e1' ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(binding[1])) {
      throw const FormatException('Login is not bound to this device');
    }
    String standard(String value) {
      final bytes = base64Url.decode(base64Url.normalize(value));
      if (bytes.length != 32 ||
          base64UrlEncode(bytes).replaceAll('=', '') != value) {
        throw const FormatException('Invalid device binding');
      }
      return base64Encode(bytes);
    }

    final expires = (claims['exp'] as int) < (claims['iat'] as int) + 600
        ? claims['exp'] as int
        : (claims['iat'] as int) + 600;
    return EnrollmentProof(
      token,
      subject,
      binding[1],
      standard(binding[2]),
      standard(binding[3]),
      DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true),
    );
  }
}
