import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/pkce_helper.dart';
import 'package:pulse_flutter/core/storage/ephemeral_storage.dart';

void main() {
  group('PkceHelper Unit Tests', () {
    test('base64UrlUnpadded encodes bytes correctly without padding or standard base64 chars', () {
      // Test with bytes that produce +, /, and = in standard base64
      // 0xfb, 0xff, 0xfe -> standard base64 is "+//+" -> URL-safe is "-__-"
      final List<int> testBytes1 = <int>[0xfb, 0xff, 0xfe];
      final String encoded1 = PkceHelper.base64UrlUnpadded(testBytes1);
      expect(encoded1, equals('-__-'));
      expect(encoded1.contains('+'), isFalse);
      expect(encoded1.contains('/'), isFalse);
      expect(encoded1.contains('='), isFalse);

      // Single byte test (produces 2 padding characters in standard base64)
      final List<int> singleByte = <int>[0x41]; // 'A' -> 'QQ=='
      final String encodedSingle = PkceHelper.base64UrlUnpadded(singleByte);
      expect(encodedSingle, equals('QQ'));
      expect(encodedSingle.contains('='), isFalse);
    });

    test('generateCodeChallenge matches RFC 7636 Appendix B test vector', () {
      // Official RFC 7636 Appendix B test vector
      const String rfcVerifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      const String expectedChallenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';

      final String actualChallenge = PkceHelper.generateCodeChallenge(rfcVerifier);
      expect(actualChallenge, equals(expectedChallenge));
    });

    test('generateCodeChallenge matches manual SHA-256 computation for arbitrary strings', () {
      const String customVerifier = 'custom_code_verifier_1234567890_abcdefghijklmnopqrstuvwxyz';
      final List<int> digest = sha256.convert(utf8.encode(customVerifier)).bytes;
      final String expectedChallenge = PkceHelper.base64UrlUnpadded(digest);

      final String challenge = PkceHelper.generateCodeChallenge(customVerifier);
      expect(challenge, equals(expectedChallenge));
    });

    test('generateCodeVerifier produces valid unpadded Base64URL string with required entropy', () {
      final String verifier1 = PkceHelper.generateCodeVerifier();
      final String verifier2 = PkceHelper.generateCodeVerifier();

      // 64 raw bytes base64 encoded: ceil(64 * 4 / 3) = 86 chars (unpadded)
      expect(verifier1.length, equals(86));
      expect(verifier2.length, equals(86));
      expect(verifier1, isNot(equals(verifier2))); // High entropy CSPRNG

      // Verify character set: [A-Za-z0-9_-]
      final RegExp urlSafeRegex = RegExp(r'^[A-Za-z0-9_-]+$');
      expect(urlSafeRegex.hasMatch(verifier1), isTrue);
      expect(urlSafeRegex.hasMatch(verifier2), isTrue);
      expect(verifier1.contains('='), isFalse);
      expect(verifier1.contains('+'), isFalse);
      expect(verifier1.contains('/'), isFalse);
    });

    test('generateState and generateNonce produce 24-byte unpadded Base64URL strings', () {
      final String state = PkceHelper.generateState();
      final String nonce = PkceHelper.generateNonce();

      // 24 raw bytes base64 encoded: 24 * 4 / 3 = 32 chars (exact)
      expect(state.length, equals(32));
      expect(nonce.length, equals(32));
      expect(state, isNot(equals(nonce)));

      final RegExp urlSafeRegex = RegExp(r'^[A-Za-z0-9_-]+$');
      expect(urlSafeRegex.hasMatch(state), isTrue);
      expect(urlSafeRegex.hasMatch(nonce), isTrue);
    });
  });

  group('EphemeralStorage Unit Tests', () {
    late EphemeralStorage storage;

    setUp(() {
      storage = EphemeralStorage.inMemory();
    });

    test('stores and retrieves verifier, state, and nonce', () {
      expect(storage.getVerifier(), isNull);
      expect(storage.getState(), isNull);
      expect(storage.getNonce(), isNull);

      const String verifier = 'test_verifier_123';
      const String state = 'test_state_456';
      const String nonce = 'test_nonce_789';

      storage.savePkceSession(
        verifier: verifier,
        state: state,
        nonce: nonce,
      );

      expect(storage.getVerifier(), equals(verifier));
      expect(storage.getState(), equals(state));
      expect(storage.getNonce(), equals(nonce));
    });

    test('handles optional nonce properly', () {
      storage.savePkceSession(
        verifier: 'v1',
        state: 's1',
      );

      expect(storage.getVerifier(), equals('v1'));
      expect(storage.getState(), equals('s1'));
      expect(storage.getNonce(), isNull);
    });

    test('clear wipes all stored PKCE parameters', () {
      storage.savePkceSession(
        verifier: 'v_to_clear',
        state: 's_to_clear',
        nonce: 'n_to_clear',
      );

      expect(storage.getVerifier(), isNotNull);
      expect(storage.getState(), isNotNull);
      expect(storage.getNonce(), isNotNull);

      storage.clear();

      expect(storage.getVerifier(), isNull);
      expect(storage.getState(), isNull);
      expect(storage.getNonce(), isNull);
    });

    test('storage factory returns functional storage instance', () {
      final EphemeralStorage defaultStorage = EphemeralStorage();
      defaultStorage.savePkceSession(
        verifier: 'factory_v',
        state: 'factory_s',
      );

      expect(defaultStorage.getVerifier(), equals('factory_v'));
      expect(defaultStorage.getState(), equals('factory_s'));

      defaultStorage.clear();
      expect(defaultStorage.getVerifier(), isNull);
    });
  });
}
