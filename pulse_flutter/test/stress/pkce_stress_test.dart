import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/pkce_helper.dart';

void main() {
  group('PkceHelper Empirical Stress & Challenge Tests', () {
    const int stressIterations = 10000;
    final RegExp urlSafeRegex = RegExp(r'^[A-Za-z0-9_-]+$');

    test('10,000 iterations: generateCodeVerifier invariant stress testing', () {
      final Set<String> verifiers = <String>{};
      final Map<String, int> charDistribution = <String, int>{};

      for (int i = 0; i < stressIterations; i++) {
        final String verifier = PkceHelper.generateCodeVerifier(64);

        // 1. Invariant: Length of 64 raw bytes Base64URL-encoded unpadded is 86 characters
        expect(
          verifier.length,
          equals(86),
          reason: 'Verifier #$i length must be exactly 86 characters for 64 bytes',
        );

        // 2. Invariant: Zero forbidden Base64 characters (+, /, =)
        expect(
          verifier.contains('+'),
          isFalse,
          reason: 'Verifier #$i must not contain "+"',
        );
        expect(
          verifier.contains('/'),
          isFalse,
          reason: 'Verifier #$i must not contain "/"',
        );
        expect(
          verifier.contains('='),
          isFalse,
          reason: 'Verifier #$i must not contain "=" padding',
        );

        // 3. Invariant: Only RFC 7636 unreserved URL-safe characters [A-Za-z0-9_-]
        expect(
          urlSafeRegex.hasMatch(verifier),
          isTrue,
          reason: 'Verifier #$i contains non-URL-safe characters',
        );

        // Collect character distribution
        for (int c = 0; c < verifier.length; c++) {
          final String ch = verifier[c];
          charDistribution[ch] = (charDistribution[ch] ?? 0) + 1;
        }

        // Add to set for entropy check
        verifiers.add(verifier);
      }

      // 4. Invariant: High entropy - 100% uniqueness across 10,000 iterations (zero collisions)
      expect(
        verifiers.length,
        equals(stressIterations),
        reason: 'Collision detected in 10,000 verifiers! CSPRNG entropy failure.',
      );

      // 5. Invariant: All 64 Base64URL characters must appear in 860,000 generated chars
      expect(
        charDistribution.length,
        equals(64),
        reason: 'All 64 Base64URL characters should appear across 860,000 characters',
      );
      for (final String ch in 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'.split('')) {
        expect(
          charDistribution.containsKey(ch),
          isTrue,
          reason: 'Character "$ch" never appeared in 10,000 iterations',
        );
        expect(
          charDistribution[ch]!,
          greaterThan(5000), // Expected mean is ~13,437; >5000 verifies reasonable uniformity
          reason: 'Character "$ch" frequency (${charDistribution[ch]}) is suspiciously low',
        );
      }
    });

    test('10,000 iterations: generateState & generateNonce length and entropy invariants', () {
      final Set<String> states = <String>{};
      final Set<String> nonces = <String>{};

      for (int i = 0; i < stressIterations; i++) {
        final String state = PkceHelper.generateState(24);
        final String nonce = PkceHelper.generateNonce(24);

        // 1. Invariant: Length of 24 raw bytes Base64URL-encoded unpadded is 32 characters
        expect(
          state.length,
          equals(32),
          reason: 'State #$i length must be exactly 32 characters for 24 bytes',
        );
        expect(
          nonce.length,
          equals(32),
          reason: 'Nonce #$i length must be exactly 32 characters for 24 bytes',
        );

        // 2. Invariant: Zero forbidden characters (+, /, =)
        expect(state.contains('+') || state.contains('/') || state.contains('='), isFalse);
        expect(nonce.contains('+') || nonce.contains('/') || nonce.contains('='), isFalse);

        // 3. Invariant: URL safe charset
        expect(urlSafeRegex.hasMatch(state), isTrue);
        expect(urlSafeRegex.hasMatch(nonce), isTrue);

        // 4. Invariant: State != Nonce in the same invocation
        expect(state, isNot(equals(nonce)));

        states.add(state);
        nonces.add(nonce);
      }

      // 5. Invariant: Zero collisions across 10,000 iterations
      expect(states.length, equals(stressIterations));
      expect(nonces.length, equals(stressIterations));
      // Cross-collision check between states and nonces sets
      expect(states.intersection(nonces).length, equals(0));
    });

    test('10,000 iterations: generateCodeChallenge correctness, determinism, and SHA-256 oracle', () {
      for (int i = 0; i < stressIterations; i++) {
        final String verifier = PkceHelper.generateCodeVerifier(64);

        final String challenge1 = PkceHelper.generateCodeChallenge(verifier);
        final String challenge2 = PkceHelper.generateCodeChallenge(verifier);

        // 1. Invariant: Deterministic output for same verifier
        expect(
          challenge1,
          equals(challenge2),
          reason: 'generateCodeChallenge must be deterministic for iteration #$i',
        );

        // 2. Invariant: Challenge length for SHA-256 (32 bytes) is 43 characters unpadded
        expect(
          challenge1.length,
          equals(43),
          reason: 'S256 challenge length must be 43 characters',
        );

        // 3. Invariant: Zero forbidden characters
        expect(challenge1.contains('+'), isFalse);
        expect(challenge1.contains('/'), isFalse);
        expect(challenge1.contains('='), isFalse);
        expect(urlSafeRegex.hasMatch(challenge1), isTrue);

        // 4. Oracle check against independent standard crypto pipeline
        final List<int> utf8Bytes = utf8.encode(verifier);
        final Digest expectedDigest = sha256.convert(utf8Bytes);
        final String expectedBase64Url = base64Url.encode(expectedDigest.bytes).replaceAll('=', '');
        expect(
          challenge1,
          equals(expectedBase64Url),
          reason: 'Challenge does not match independent SHA-256 Base64URL calculation',
        );
      }
    });

    test('Deterministic SHA-256 S256 test vectors & edge-case byte lengths', () {
      // Vector 1: Official RFC 7636 Appendix B
      const String rfcVerifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      const String rfcExpectedChallenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';
      expect(PkceHelper.generateCodeChallenge(rfcVerifier), equals(rfcExpectedChallenge));

      // Vector 2: Single ASCII char 'a'
      // SHA-256('a') = ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb
      // Base64URL unpadded: ypeBEsobvcr6wjGzmiPcTaeG7_gUfE5yuYB3ha_uSLs
      const String charVerifier = 'a';
      const String charExpectedChallenge = 'ypeBEsobvcr6wjGzmiPcTaeG7_gUfE5yuYB3ha_uSLs';
      expect(PkceHelper.generateCodeChallenge(charVerifier), equals(charExpectedChallenge));

      // Vector 3: 43 characters (RFC minimum verifier length)
      const String minVerifier = '0123456789012345678901234567890123456789012';
      final String minExpected = base64Url.encode(sha256.convert(utf8.encode(minVerifier)).bytes).replaceAll('=', '');
      expect(PkceHelper.generateCodeChallenge(minVerifier), equals(minExpected));

      // Vector 4: 128 characters (RFC maximum verifier length)
      final String maxVerifier = 'A' * 128;
      final String maxExpected = base64Url.encode(sha256.convert(utf8.encode(maxVerifier)).bytes).replaceAll('=', '');
      expect(PkceHelper.generateCodeChallenge(maxVerifier), equals(maxExpected));

      // Vector 5: Various byte length verifiers
      final Map<int, int> byteLengthToChars = <int, int>{
        16: 22,  // ceil(16 * 4 / 3) = 22
        24: 32,  // 24 * 4 / 3 = 32
        32: 43,  // ceil(32 * 4 / 3) = 43
        48: 64,  // 48 * 4 / 3 = 64
        64: 86,  // ceil(64 * 4 / 3) = 86
        96: 128, // 96 * 4 / 3 = 128
        128: 171,// ceil(128 * 4 / 3) = 171
      };

      for (final MapEntry<int, int> entry in byteLengthToChars.entries) {
        final String v = PkceHelper.generateCodeVerifier(entry.key);
        expect(v.length, equals(entry.value), reason: 'Byte length ${entry.key} should produce ${entry.value} chars');
        expect(urlSafeRegex.hasMatch(v), isTrue);
        expect(v.contains('='), isFalse);
      }
    });

    test('base64UrlUnpadded handles boundary byte sequences', () {
      // Empty input
      expect(PkceHelper.base64UrlUnpadded(<int>[]), equals(''));

      // Single byte (produces 2 padding '=' in standard base64)
      expect(PkceHelper.base64UrlUnpadded(<int>[0x00]), equals('AA'));
      expect(PkceHelper.base64UrlUnpadded(<int>[0xFF]), equals('_w'));

      // Two bytes (produces 1 padding '=' in standard base64)
      expect(PkceHelper.base64UrlUnpadded(<int>[0x00, 0x00]), equals('AAA'));
      expect(PkceHelper.base64UrlUnpadded(<int>[0xFF, 0xFF]), equals('__8'));

      // Three bytes (0 padding in standard base64)
      expect(PkceHelper.base64UrlUnpadded(<int>[0x00, 0x00, 0x00]), equals('AAAA'));
      expect(PkceHelper.base64UrlUnpadded(<int>[0xFF, 0xFF, 0xFF]), equals('____'));

      // URL-safe replacement verification: 0xFB, 0xFF, 0xFE produces +//+ in std -> -__- in URL-safe
      expect(PkceHelper.base64UrlUnpadded(<int>[0xFB, 0xFF, 0xFE]), equals('-__-'));
    });
  });
}
