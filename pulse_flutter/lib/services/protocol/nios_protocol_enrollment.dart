import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as hashing;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/services/protocol/nios_protocol_accounts.dart';

final niosProtocolEnrollmentProvider = Provider<NiosProtocolEnrollment>((ref) {
  return NiosProtocolEnrollment(
    accounts: ref.read(niosProtocolAccountsProvider),
  );
});

/// Binds a persisted device to the existing authenticated messenger session.
/// Private signing material stays with the account owner and its logout fence.
/// Only implemented client capabilities are advertised, independently of SDKs
/// which happen to be bundled with the application.
final class NiosProtocolEnrollment {
  NiosProtocolEnrollment({
    required NiosProtocolAccounts accounts,
    Uri? origin,
    http.Client Function()? clientFactory,
  }) : _accounts = accounts,
       _origin = origin ?? Uri.parse(ApiConstants.origin),
       _clientFactory = clientFactory ?? http.Client.new;

  final NiosProtocolAccounts _accounts;
  final Uri _origin;
  final http.Client Function() _clientFactory;
  final Map<int, Future<void>> _tails = {};
  final Map<int, String> _registered = {};

  static const streamCapabilities = <String, Object>{
    'link': <int>[],
    'stream': <int>[1],
    'mls': <String, Object>{'versions': <int>[], 'suites': <String>[]},
    'irohAlpn': <String>[],
    'ktStatements': <int>[],
  };

  Future<void> ensureRegistered({
    required int accountId,
    required String legacyPublicKey,
    required String bearerToken,
  }) {
    if (accountId <= 0 ||
        legacyPublicKey.isEmpty ||
        bearerToken.isEmpty ||
        bearerToken.length > 4096) {
      return Future.error(const ProtocolEnrollmentException('invalid_session'));
    }
    final result = (_tails[accountId] ?? Future<void>.value()).then(
      (_) => _enroll(accountId, legacyPublicKey, bearerToken),
    );
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[accountId] = settled;
    unawaited(
      settled.then((_) {
        if (identical(_tails[accountId], settled)) _tails.remove(accountId);
      }),
    );
    return result;
  }

  Future<void> _enroll(int id, String legacy, String token) async {
    final account = await _accounts.openAccount('$id');
    final cacheKey = hashing.sha256
        .convert(utf8.encode(jsonEncode([account.deviceId, legacy, token])))
        .toString();
    if (_registered[id] == cacheKey) return;
    final client = _clientFactory();
    try {
      final devicePath = '/v1/devices/${account.deviceId}';
      final challenge = await _request(
        client,
        'POST',
        '$devicePath/challenge',
        token,
        {},
      );
      final challengeId = challenge['challenge'];
      final session = challenge['session'];
      if (challenge['account'] != '$id' ||
          challenge['device'] != account.deviceId ||
          challengeId is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(challengeId) ||
          session is! int ||
          session <= 0) {
        throw const ProtocolEnrollmentException('invalid_challenge');
      }
      final identity = base64Encode(
        await account.protocolPublicKey(purpose: 'account-identity'),
      );
      final link = base64Encode(
        await account.protocolPublicKey(purpose: 'link-signing'),
      );
      final protocolsHash = hashing.sha256
          .convert(utf8.encode(jsonEncode(streamCapabilities)))
          .toString();
      final statement = utf8.encode(
        jsonEncode([
          'nios-device-registration',
          1,
          '$id',
          account.deviceId,
          identity,
          link,
          null,
          null,
          legacy,
          protocolsHash,
        ]),
      );
      final identitySignature = await account.signProtocol(
        statement,
        purpose: 'account-identity',
      );
      final proof = utf8.encode(
        jsonEncode([
          'nios-device-enrollment',
          1,
          '$id',
          account.deviceId,
          session,
          challengeId,
          hashing.sha256.convert(statement).toString(),
        ]),
      );
      final deviceSignature = await account.signProtocol(
        proof,
        purpose: 'link-signing',
      );
      await _request(client, 'PUT', devicePath, token, {
        'challenge': challengeId,
        'identity_key': identity,
        'link_key': link,
        'mls_key': null,
        'endpoint_key': null,
        'protocols': streamCapabilities,
        'legacy_key': legacy,
        'identity_signature': base64Encode(identitySignature),
        'device_proof': base64Encode(deviceSignature),
      });
      // Sign through the owner once more so logout during the HTTP request
      // cannot leave a successful enrollment cached for a stopped account.
      await account.signProtocol(const [], purpose: 'link-signing');
      _registered[id] = cacheKey;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _request(
    http.Client client,
    String method,
    String path,
    String token,
    Map<String, Object?> body,
  ) async {
    final request = http.Request(method, _origin.resolve(path))
      ..followRedirects = false
      ..headers['authorization'] = 'Bearer $token'
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body);
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      if (bytes.length + chunk.length > 65536) {
        throw const ProtocolEnrollmentException('invalid_response');
      }
      bytes.addAll(chunk);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProtocolEnrollmentException('http_${response.statusCode}');
    }
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) throw const FormatException();
      return value;
    } on FormatException {
      throw const ProtocolEnrollmentException('invalid_response');
    }
  }
}

final class ProtocolEnrollmentException implements Exception {
  const ProtocolEnrollmentException(this.code);
  final String code;
  @override
  String toString() => 'ProtocolEnrollmentException($code)';
}
