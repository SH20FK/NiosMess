import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/storage/ephemeral_storage.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';

void main() {
  group('=== CHALLENGE SUITE 1: EphemeralStorage Empirical Stress Tests ===', () {
    late EphemeralStorage storage;

    setUp(() {
      storage = EphemeralStorage.inMemory();
    });

    test('1.1 Initial state: All PKCE parameters are strictly null upon instantiation', () {
      expect(storage.getVerifier(), isNull);
      expect(storage.getState(), isNull);
      expect(storage.getNonce(), isNull);
    });

    test('1.2 Standard save and retrieval of all parameters', () {
      storage.savePkceSession(
        verifier: 'test_verifier_alpha',
        state: 'test_state_beta',
        nonce: 'test_nonce_gamma',
      );

      expect(storage.getVerifier(), equals('test_verifier_alpha'));
      expect(storage.getState(), equals('test_state_beta'));
      expect(storage.getNonce(), equals('test_nonce_gamma'));
    });

    test('1.3 Overwrites: Full overwrite of existing session updates all keys', () {
      storage.savePkceSession(
        verifier: 'initial_verifier',
        state: 'initial_state',
        nonce: 'initial_nonce',
      );
      expect(storage.getVerifier(), equals('initial_verifier'));
      expect(storage.getState(), equals('initial_state'));
      expect(storage.getNonce(), equals('initial_nonce'));

      // Overwrite with second set
      storage.savePkceSession(
        verifier: 'overwritten_verifier',
        state: 'overwritten_state',
        nonce: 'overwritten_nonce',
      );
      expect(storage.getVerifier(), equals('overwritten_verifier'));
      expect(storage.getState(), equals('overwritten_state'));
      expect(storage.getNonce(), equals('overwritten_nonce'));
    });

    test('1.4 Overwrites: Saving without nonce or with empty nonce purges previous nonce', () {
      storage.savePkceSession(
        verifier: 'v1',
        state: 's1',
        nonce: 'existing_nonce',
      );
      expect(storage.getNonce(), equals('existing_nonce'));

      // Overwrite without nonce (nonce = null)
      storage.savePkceSession(
        verifier: 'v2',
        state: 's2',
      );
      expect(storage.getVerifier(), equals('v2'));
      expect(storage.getState(), equals('s2'));
      expect(storage.getNonce(), isNull, reason: 'Nonce must be removed when omitted on re-save');

      // Re-populate and overwrite with empty string nonce
      storage.savePkceSession(
        verifier: 'v3',
        state: 's3',
        nonce: 'nonce_to_empty',
      );
      expect(storage.getNonce(), equals('nonce_to_empty'));

      storage.savePkceSession(
        verifier: 'v4',
        state: 's4',
        nonce: '',
      );
      expect(storage.getNonce(), isNull, reason: 'Empty string nonce must purge the nonce key');
    });

    test('1.5 Sequential clear(): Calling clear() repeatedly is safe and idempotent', () {
      // Clear on empty storage
      expect(() => storage.clear(), returnsNormally);
      expect(storage.getVerifier(), isNull);
      expect(storage.getState(), isNull);
      expect(storage.getNonce(), isNull);

      // Populate and clear
      storage.savePkceSession(
        verifier: 'v_clear',
        state: 's_clear',
        nonce: 'n_clear',
      );
      storage.clear();
      expect(storage.getVerifier(), isNull);
      expect(storage.getState(), isNull);
      expect(storage.getNonce(), isNull);

      // Multiple successive clear calls
      for (int i = 0; i < 10; i++) {
        expect(() => storage.clear(), returnsNormally);
        expect(storage.getVerifier(), isNull);
      }

      // Re-save after clear works normally
      storage.savePkceSession(
        verifier: 'v_after_clear',
        state: 's_after_clear',
      );
      expect(storage.getVerifier(), equals('v_after_clear'));
      expect(storage.getState(), equals('s_after_clear'));
    });

    test('1.6 Read idempotency: Getters do not mutate or purge state prior to clear()', () {
      storage.savePkceSession(
        verifier: 'persistent_verifier',
        state: 'persistent_state',
        nonce: 'persistent_nonce',
      );

      for (int i = 0; i < 5; i++) {
        expect(storage.getVerifier(), equals('persistent_verifier'));
        expect(storage.getState(), equals('persistent_state'));
        expect(storage.getNonce(), equals('persistent_nonce'));
      }
    });

    test('1.7 Isolation: Distinct MemoryEphemeralStorage instances do not leak state', () {
      final EphemeralStorage storeA = EphemeralStorage.inMemory();
      final EphemeralStorage storeB = EphemeralStorage.inMemory();

      storeA.savePkceSession(
        verifier: 'verifier_A',
        state: 'state_A',
        nonce: 'nonce_A',
      );

      expect(storeA.getVerifier(), equals('verifier_A'));
      expect(storeB.getVerifier(), isNull);
      expect(storeB.getState(), isNull);
      expect(storeB.getNonce(), isNull);

      storeB.savePkceSession(
        verifier: 'verifier_B',
        state: 'state_B',
      );
      storeA.clear();

      expect(storeA.getVerifier(), isNull);
      expect(storeB.getVerifier(), equals('verifier_B'));
    });

    test('1.8 High-volume stress loop: 1,000 rapid sequential write-read-clear cycles', () {
      for (int i = 0; i < 1000; i++) {
        final String v = 'verifier_$i';
        final String s = 'state_$i';
        final String n = 'nonce_$i';

        storage.savePkceSession(verifier: v, state: s, nonce: n);
        expect(storage.getVerifier(), equals(v));
        expect(storage.getState(), equals(s));
        expect(storage.getNonce(), equals(n));

        storage.clear();
        expect(storage.getVerifier(), isNull);
        expect(storage.getState(), isNull);
        expect(storage.getNonce(), isNull);
      }
    });

    test('1.9 Concurrency & Race condition resilience: 100 concurrent async writes', () async {
      final List<Future<void>> futures = <Future<void>>[];

      for (int i = 0; i < 100; i++) {
        final int id = i;
        futures.add(Future<void>(() {
          storage.savePkceSession(
            verifier: 'async_v_$id',
            state: 'async_s_$id',
            nonce: 'async_n_$id',
          );
          final String? readV = storage.getVerifier();
          final String? readS = storage.getState();
          // Verify no null corruption during active writes
          expect(readV, isNotNull);
          expect(readS, isNotNull);
        }));
      }

      await Future.wait(futures);

      // Final state must hold the exact triplet from whichever write completed last
      final String? finalV = storage.getVerifier();
      final String? finalS = storage.getState();
      final String? finalN = storage.getNonce();

      expect(finalV, isNotNull);
      expect(finalS, isNotNull);
      expect(finalN, isNotNull);
      expect(finalV!.startsWith('async_v_'), isTrue);
      expect(finalS!.startsWith('async_s_'), isTrue);
      expect(finalN!.startsWith('async_n_'), isTrue);

      storage.clear();
      expect(storage.getVerifier(), isNull);
    });

    test('1.10 Edge case payload handling: Large payloads and Unicode/special characters', () {
      final String largePayload = 'A' * 65536; // 64KB string
      const String unicodePayload = '🔑🔒✓_Ниос_Тест_123!@#\$%^&*()+=~`<>?:";{}[]|\\';

      storage.savePkceSession(
        verifier: largePayload,
        state: unicodePayload,
        nonce: 'special_+/=-_chars',
      );

      expect(storage.getVerifier(), equals(largePayload));
      expect(storage.getState(), equals(unicodePayload));
      expect(storage.getNonce(), equals('special_+/=-_chars'));

      storage.clear();
      expect(storage.getVerifier(), isNull);
    });

    test('1.11 Default factory constructor produces functional MemoryEphemeralStorage in tests', () {
      final EphemeralStorage defaultInstance = EphemeralStorage();
      expect(defaultInstance, isA<MemoryEphemeralStorage>());

      defaultInstance.savePkceSession(verifier: 'fac_v', state: 'fac_s');
      expect(defaultInstance.getVerifier(), equals('fac_v'));
      expect(defaultInstance.getState(), equals('fac_s'));
      defaultInstance.clear();
      expect(defaultInstance.getVerifier(), isNull);
    });
  });

  group('=== CHALLENGE SUITE 2: AuthSession Model Empirical Stress Tests ===', () {
    test('2.1 Serialization symmetry: round-trip preserves all fields with niosId', () {
      const AuthSession original = AuthSession(
        accessToken: 'eyJh...mock_access_token_12345',
        userId: 1042,
        username: 'cryptodriver',
        displayName: 'Satoshi Nakamoto',
        niosId: 'nios_uuid_9988-7766-5544',
      );

      final Map<String, dynamic> json = original.toJson();
      final AuthSession restored = AuthSession.fromJson(json);

      expect(restored.accessToken, equals(original.accessToken));
      expect(restored.userId, equals(original.userId));
      expect(restored.username, equals(original.username));
      expect(restored.displayName, equals(original.displayName));
      expect(restored.niosId, equals(original.niosId));
    });

    test('2.2 Serialization symmetry: round-trip without niosId omits key from JSON', () {
      const AuthSession original = AuthSession(
        accessToken: 'token_without_nios_id',
        userId: 55,
        username: 'legacy_user',
        displayName: 'Legacy User',
      );

      final Map<String, dynamic> json = original.toJson();
      expect(json.containsKey('nios_id'), isFalse, reason: 'toJson must omit nios_id key when null');

      final AuthSession restored = AuthSession.fromJson(json);
      expect(restored.accessToken, equals(original.accessToken));
      expect(restored.userId, equals(original.userId));
      expect(restored.username, equals(original.username));
      expect(restored.displayName, equals(original.displayName));
      expect(restored.niosId, isNull);
    });

    test('2.3 Full JSON encode/decode string symmetry', () {
      const AuthSession original = AuthSession(
        accessToken: 'jwt_payload.with.signature',
        userId: 777,
        username: 'star_lord',
        displayName: 'Peter Quill (🚀)',
        niosId: 'nios_guardian_01',
      );

      final String encodedJsonString = jsonEncode(original.toJson());
      final dynamic decodedMap = jsonDecode(encodedJsonString);
      expect(decodedMap, isA<Map<String, dynamic>>());

      final AuthSession restored = AuthSession.fromJson(decodedMap as Map<String, dynamic>);
      expect(restored.accessToken, equals(original.accessToken));
      expect(restored.userId, equals(original.userId));
      expect(restored.username, equals(original.username));
      expect(restored.displayName, equals(original.displayName));
      expect(restored.niosId, equals(original.niosId));
    });

    test('2.4 Backwards compatibility: legacy payloads with missing optional fields', () {
      // Minimal payload (only access_token present)
      final Map<String, dynamic> legacyMinimal = <String, dynamic>{
        'access_token': 'legacy_min_token_abc',
      };
      final AuthSession session1 = AuthSession.fromJson(legacyMinimal);
      expect(session1.accessToken, equals('legacy_min_token_abc'));
      expect(session1.userId, equals(0), reason: 'Missing userId should default to 0');
      expect(session1.username, equals(''), reason: 'Missing username should default to empty string');
      expect(session1.displayName, equals(''), reason: 'Missing displayName should default to empty string');
      expect(session1.niosId, isNull);

      // Legacy payload with null fields
      final Map<String, dynamic> legacyWithNulls = <String, dynamic>{
        'access_token': 'token_with_nulls',
        'user_id': null,
        'username': null,
        'display_name': null,
        'nios_id': null,
      };
      final AuthSession session2 = AuthSession.fromJson(legacyWithNulls);
      expect(session2.accessToken, equals('token_with_nulls'));
      expect(session2.userId, equals(0));
      expect(session2.username, equals(''));
      expect(session2.displayName, equals(''));
      expect(session2.niosId, isNull);

      // Legacy payload with extra unexpected fields
      final Map<String, dynamic> legacyWithExtras = <String, dynamic>{
        'access_token': 'token_with_extras',
        'user_id': 123,
        'username': 'bob',
        'display_name': 'Bob',
        'legacy_token_field': 'ignore_me',
        'roles': <String>['admin', 'user'],
        'metadata': <String, dynamic>{'version': 1},
      };
      final AuthSession session3 = AuthSession.fromJson(legacyWithExtras);
      expect(session3.accessToken, equals('token_with_extras'));
      expect(session3.userId, equals(123));
      expect(session3.username, equals('bob'));
      expect(session3.displayName, equals('Bob'));
      expect(session3.niosId, isNull);
    });

    test('2.5 Error cases: Throws FormatException on missing or empty access_token', () {
      // Missing access_token key
      expect(
        () => AuthSession.fromJson(<String, dynamic>{'user_id': 1}),
        throwsFormatException,
      );

      // Null access_token
      expect(
        () => AuthSession.fromJson(<String, dynamic>{'access_token': null, 'user_id': 1}),
        throwsFormatException,
      );

      // Empty string access_token
      expect(
        () => AuthSession.fromJson(<String, dynamic>{'access_token': '', 'user_id': 1}),
        throwsFormatException,
      );
    });

    test('2.6 copyWith comprehensive testing', () {
      const AuthSession original = AuthSession(
        accessToken: 'tok_1',
        userId: 100,
        username: 'alice',
        displayName: 'Alice Original',
        niosId: 'nios_alice_1',
      );

      // No arguments -> identical copy
      final AuthSession copyNoArgs = original.copyWith();
      expect(copyNoArgs.accessToken, equals('tok_1'));
      expect(copyNoArgs.userId, equals(100));
      expect(copyNoArgs.username, equals('alice'));
      expect(copyNoArgs.displayName, equals('Alice Original'));
      expect(copyNoArgs.niosId, equals('nios_alice_1'));

      // Update only niosId
      final AuthSession updatedNiosId = original.copyWith(niosId: 'nios_alice_new_id');
      expect(updatedNiosId.accessToken, equals('tok_1'));
      expect(updatedNiosId.userId, equals(100));
      expect(updatedNiosId.username, equals('alice'));
      expect(updatedNiosId.displayName, equals('Alice Original'));
      expect(updatedNiosId.niosId, equals('nios_alice_new_id'));

      // Transition niosId from null to value
      const AuthSession noNiosSession = AuthSession(
        accessToken: 'tok_2',
        userId: 200,
        username: 'bob',
        displayName: 'Bob Original',
      );
      final AuthSession withAddedNiosId = noNiosSession.copyWith(niosId: 'nios_bob_id');
      expect(withAddedNiosId.niosId, equals('nios_bob_id'));
      expect(withAddedNiosId.username, equals('bob'));

      // Update all fields simultaneously
      final AuthSession updatedAll = original.copyWith(
        accessToken: 'tok_all_new',
        userId: 999,
        username: 'charlie',
        displayName: 'Charlie Brown',
        niosId: 'nios_charlie_id',
      );
      expect(updatedAll.accessToken, equals('tok_all_new'));
      expect(updatedAll.userId, equals(999));
      expect(updatedAll.username, equals('charlie'));
      expect(updatedAll.displayName, equals('Charlie Brown'));
      expect(updatedAll.niosId, equals('nios_charlie_id'));

      // Original remains unmodified (immutability check)
      expect(original.accessToken, equals('tok_1'));
      expect(original.userId, equals(100));
    });
  });

  group('=== CHALLENGE SUITE 3: NiosOAuthTokenResponse Empirical Stress Tests ===', () {
    test('3.1 expires_in parsing with various formats (int, string, zero, negative, invalid)', () {
      // 1. Positive Integer
      final NiosOAuthTokenResponse resInt = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'tok_int',
        'expires_in': 3600,
      });
      expect(resInt.expiresIn, equals(3600));
      expect(resInt.isSuccess, isTrue);

      // 2. Positive String
      final NiosOAuthTokenResponse resStr = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'tok_str',
        'expires_in': '86400',
      });
      expect(resStr.expiresIn, equals(86400));
      expect(resStr.isSuccess, isTrue);

      // 3. Zero Integer
      final NiosOAuthTokenResponse resZeroInt = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'tok_zero_int',
        'expires_in': 0,
      });
      expect(resZeroInt.expiresIn, equals(0));

      // 4. Zero String
      final NiosOAuthTokenResponse resZeroStr = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'tok_zero_str',
        'expires_in': '0',
      });
      expect(resZeroStr.expiresIn, equals(0));

      // 5. Negative Integer
      final NiosOAuthTokenResponse resNegInt = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'tok_neg_int',
        'expires_in': -1,
      });
      expect(resNegInt.expiresIn, equals(-1));

      // 6. Negative String
      final NiosOAuthTokenResponse resNegStr = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'tok_neg_str',
        'expires_in': '-3600',
      });
      expect(resNegStr.expiresIn, equals(-3600));

      // 7. Non-numeric invalid string -> falls back safely to null
      final NiosOAuthTokenResponse resInvalid = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'tok_invalid_expires',
        'expires_in': 'not_a_valid_number',
      });
      expect(resInvalid.expiresIn, isNull);
      expect(resInvalid.isSuccess, isTrue);

      // 8. Missing expires_in key -> null
      final NiosOAuthTokenResponse resMissing = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'tok_missing_expires',
      });
      expect(resMissing.expiresIn, isNull);

      // 9. Null expires_in -> null
      final NiosOAuthTokenResponse resNull = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'tok_null_expires',
        'expires_in': null,
      });
      expect(resNull.expiresIn, isNull);
    });

    test('3.2 Error response parsing and fallback precedence', () {
      // RFC 6749 standard error_description
      final NiosOAuthTokenResponse rfcError = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'error': 'invalid_grant',
        'error_description': 'The authorization code is invalid or expired',
      });
      expect(rfcError.isSuccess, isFalse);
      expect(rfcError.error, equals('invalid_grant'));
      expect(rfcError.errorDescription, equals('The authorization code is invalid or expired'));

      // Alternative error_message key
      final NiosOAuthTokenResponse altErrorMsg = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'error': 'unauthorized_client',
        'error_message': 'Client not authorized for scope',
      });
      expect(altErrorMsg.isSuccess, isFalse);
      expect(altErrorMsg.error, equals('unauthorized_client'));
      expect(altErrorMsg.errorDescription, equals('Client not authorized for scope'));

      // Alternative message key
      final NiosOAuthTokenResponse altMsg = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'error': 'server_error',
        'message': 'Internal database error',
      });
      expect(altMsg.isSuccess, isFalse);
      expect(altMsg.error, equals('server_error'));
      expect(altMsg.errorDescription, equals('Internal database error'));

      // Precedence: error_description > error_message > message
      final NiosOAuthTokenResponse precedenceTest = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'error': 'custom_error',
        'error_description': 'Highest priority description',
        'error_message': 'Medium priority message',
        'message': 'Lowest priority message',
      });
      expect(precedenceTest.errorDescription, equals('Highest priority description'));
    });

    test('3.3 isSuccess predicate validation under all edge cases', () {
      // Case A: Valid token, no error -> TRUE
      final NiosOAuthTokenResponse valid = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'valid_token_123',
      });
      expect(valid.isSuccess, isTrue);

      // Case B: Valid token, but error is present -> FALSE
      final NiosOAuthTokenResponse tokenWithError = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': 'some_token',
        'error': 'invalid_scope',
      });
      expect(tokenWithError.isSuccess, isFalse);

      // Case C: Empty token, no error -> FALSE
      final NiosOAuthTokenResponse emptyToken = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': '',
      });
      expect(emptyToken.isSuccess, isFalse);

      // Case D: Null token, no error -> FALSE
      final NiosOAuthTokenResponse nullToken = NiosOAuthTokenResponse.fromJson(<String, dynamic>{
        'access_token': null,
      });
      expect(nullToken.isSuccess, isFalse);

      // Case E: Completely empty json -> FALSE
      final NiosOAuthTokenResponse emptyJson = NiosOAuthTokenResponse.fromJson(<String, dynamic>{});
      expect(emptyJson.isSuccess, isFalse);
    });

    test('3.4 NiosOAuthTokenResponse serialization symmetry (toJson and fromJson)', () {
      final NiosOAuthTokenResponse fullResponse = NiosOAuthTokenResponse(
        accessToken: 'at_full_test_123',
        tokenType: 'Bearer',
        expiresIn: 7200,
        scope: 'openid profile email',
        idToken: 'id_token_jwt_987',
        error: null,
        errorDescription: null,
      );

      final Map<String, dynamic> jsonMap = fullResponse.toJson();
      expect(jsonMap['access_token'], equals('at_full_test_123'));
      expect(jsonMap['token_type'], equals('Bearer'));
      expect(jsonMap['expires_in'], equals(7200));
      expect(jsonMap['scope'], equals('openid profile email'));
      expect(jsonMap['id_token'], equals('id_token_jwt_987'));
      expect(jsonMap.containsKey('error'), isFalse);
      expect(jsonMap.containsKey('error_description'), isFalse);

      final NiosOAuthTokenResponse restored = NiosOAuthTokenResponse.fromJson(jsonMap);
      expect(restored.accessToken, equals(fullResponse.accessToken));
      expect(restored.tokenType, equals(fullResponse.tokenType));
      expect(restored.expiresIn, equals(fullResponse.expiresIn));
      expect(restored.scope, equals(fullResponse.scope));
      expect(restored.idToken, equals(fullResponse.idToken));
      expect(restored.isSuccess, isTrue);

      // Error response symmetry
      final NiosOAuthTokenResponse errorResponse = NiosOAuthTokenResponse(
        error: 'access_denied',
        errorDescription: 'User cancelled auth',
      );
      final Map<String, dynamic> errJson = errorResponse.toJson();
      expect(errJson['error'], equals('access_denied'));
      expect(errJson['error_description'], equals('User cancelled auth'));

      final NiosOAuthTokenResponse restoredError = NiosOAuthTokenResponse.fromJson(errJson);
      expect(restoredError.error, equals('access_denied'));
      expect(restoredError.errorDescription, equals('User cancelled auth'));
      expect(restoredError.isSuccess, isFalse);
    });
  });
}
