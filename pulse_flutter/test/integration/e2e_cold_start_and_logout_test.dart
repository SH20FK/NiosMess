import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';

// ── TEST HARNESS & IN-MEMORY TEST DOUBLES ──────────────────────────────────────

class InMemorySecureStorage {
  final Map<String, String> _data = {};
  bool throwOnRead = false;
  bool throwOnWrite = false;
  bool throwOnDelete = false;

  Future<String?> read({required String key}) async {
    if (throwOnRead) {
      throw Exception('Simulated SecureStorage PlatformException on read');
    }
    return _data[key];
  }

  Future<void> write({required String key, required String value}) async {
    if (throwOnWrite) {
      throw Exception('Simulated SecureStorage PlatformException on write');
    }
    _data[key] = value;
  }

  Future<void> delete({required String key}) async {
    if (throwOnDelete) {
      throw Exception('Simulated SecureStorage PlatformException on delete');
    }
    _data.remove(key);
  }

  Future<void> deleteAll() async {
    _data.clear();
  }

  bool containsKey(String key) => _data.containsKey(key);
  Map<String, String> get dump => Map.unmodifiable(_data);
}

class MockCentralAuthHttpClient extends http.BaseClient {
  MockCentralAuthHttpClient({
    this.accountStatusCode = 200,
    this.accountBody,
    this.logoutStatusCode = 200,
    this.logoutBody,
    this.simulateNetworkOffline = false,
  });

  int accountStatusCode;
  Map<String, dynamic>? accountBody;
  int logoutStatusCode;
  Map<String, dynamic>? logoutBody;
  bool simulateNetworkOffline;

  int accountProbeCount = 0;
  int logoutCallCount = 0;
  http.Request? lastAccountRequest;
  http.Request? lastLogoutRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (simulateNetworkOffline) {
      throw http.ClientException('Network is unreachable (Airplane mode / DNS failure)');
    }

    final path = request.url.path;

    if (path.contains('/id/api/v1/account')) {
      accountProbeCount++;
      if (request is http.Request) {
        lastAccountRequest = request;
      }
      final body = accountBody ??
          {
            'id': 'nios_user_999',
            'username': 'alex_rivera',
            'email': 'alex@ni-os.ru',
            'display_name': 'Alex Rivera',
          };
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        accountStatusCode,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    if (path.contains('/id/api/v1/logout')) {
      logoutCallCount++;
      if (request is http.Request) {
        lastLogoutRequest = request;
      }
      final body = logoutBody ?? {'success': true};
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        logoutStatusCode,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'error': 'Not found'}))),
      404,
      headers: {'content-type': 'application/json'},
    );
  }
}

class MockWebSocketClientDouble {
  bool isConnected = false;
  int unregisterFcmCount = 0;
  int wsLogoutCount = 0;
  int getMeCount = 0;
  String? lastFcmTokenUnregistered;
  bool throwOnFcmUnregister = false;
  bool throwOnWsLogout = false;

  Future<void> connect() async {
    isConnected = true;
  }

  Future<dynamic> request(String action, {Map<String, dynamic>? payload}) async {
    if (action == 'unregister_fcm_token') {
      unregisterFcmCount++;
      lastFcmTokenUnregistered = payload?['fcm_token'] as String?;
      if (throwOnFcmUnregister) {
        throw Exception('Simulated FCM unregister failure');
      }
      return {'success': true};
    }

    if (action == 'logout') {
      wsLogoutCount++;
      if (throwOnWsLogout) {
        throw Exception('Simulated WS logout timeout/error');
      }
      isConnected = false;
      return {'success': true};
    }

    if (action == 'me_info') {
      getMeCount++;
      return {
        'id': 1001,
        'username': 'alex_rivera',
        'display_name': 'Alex Rivera',
        'bio': 'NiosMess User',
      };
    }

    return {'success': true};
  }

  void close() {
    isConnected = false;
  }
}

class MockCacheServiceDouble {
  bool isCleared = false;
  int clearCallCount = 0;
  bool throwOnClear = false;

  Future<void> clearAll() async {
    clearCallCount++;
    if (throwOnClear) {
      throw Exception('Simulated Cache clear failure');
    }
    isCleared = true;
  }
}

// ── COLD START & LOGOUT ORCHESTRATOR SIMULATOR ─────────────────────────────────

class ColdStartAndLogoutManager {
  ColdStartAndLogoutManager({
    required this.storage,
    required this.httpClient,
    required this.wsClient,
    required this.cacheService,
  });

  final InMemorySecureStorage storage;
  final MockCentralAuthHttpClient httpClient;
  final MockWebSocketClientDouble wsClient;
  final MockCacheServiceDouble cacheService;

  AuthSession? currentSession;
  ApiProfile? currentProfile;
  bool isAuthenticated = false;
  String? inMemoryToken;
  String? statusMessage;

  static const String sessionKey = 'auth.session';

  /// Probe central Nios ID session according to NIOSMESS_FRONTEND_LOGIN.md §3 & §6:
  /// Only 401 returns false (session is dead).
  /// 200, 500, network offline all return true (don't kick user out).
  Future<bool> hasNiosIdSession() async {
    try {
      final response = await httpClient.get(Uri.parse('https://ni-os.ru/id/api/v1/account'));
      return response.statusCode != 401;
    } catch (_) {
      // Offline network failure -> keep session active
      return true;
    }
  }

  /// Cold start initialization logic:
  Future<void> initializeColdStart() async {
    String? raw;
    try {
      raw = await storage.read(key: sessionKey);
    } catch (_) {
      raw = null;
    }

    if (raw == null || raw.isEmpty) {
      currentSession = null;
      isAuthenticated = false;
      inMemoryToken = null;
      return;
    }

    AuthSession? parsedSession;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        parsedSession = AuthSession.fromJson(decoded);
      }
    } catch (_) {
      parsedSession = null;
    }

    if (parsedSession == null || parsedSession.accessToken.isEmpty) {
      await storage.delete(key: sessionKey);
      currentSession = null;
      isAuthenticated = false;
      inMemoryToken = null;
      return;
    }

    // Check central Nios ID session
    final bool centralActive = await hasNiosIdSession();
    if (!centralActive) {
      // 401 detected: central session is expired or revoked -> auto-logout
      await performCleanLogout();
      statusMessage = 'Сессия Nios ID завершена. Войдите снова.';
      return;
    }

    // Active session confirmed (or offline)
    currentSession = parsedSession;
    inMemoryToken = parsedSession.accessToken;
    isAuthenticated = true;

    // Connect WebSocket & refresh profile
    await wsClient.connect();
    final me = await wsClient.request('me_info');
    currentProfile = ApiProfile.fromJson(Map<String, dynamic>.from(me as Map));
  }

  /// Clean logout pipeline according to NIOSMESS_FRONTEND_LOGIN.md §7:
  /// 1. Unregister push notification token (FCM)
  /// 2. POST /id/api/v1/logout (central session termination)
  /// 3. WS logout & close
  /// 4. Purge storage & memory tokens
  /// 5. Clear local message cache
  Future<void> performCleanLogout({String? fcmToken}) async {
    // 1. FCM unregister
    if (fcmToken != null && fcmToken.isNotEmpty) {
      try {
        await wsClient.request('unregister_fcm_token', payload: {'fcm_token': fcmToken});
      } catch (_) {}
    }

    // 2. Central HTTP logout
    try {
      await httpClient.post(Uri.parse('https://ni-os.ru/id/api/v1/logout'));
    } catch (_) {}

    // 3. WS logout
    try {
      await wsClient.request('logout');
    } catch (_) {}
    wsClient.close();

    // 4. Storage & token purge
    try {
      await storage.delete(key: sessionKey);
    } catch (_) {}
    inMemoryToken = null;
    currentSession = null;
    currentProfile = null;
    isAuthenticated = false;

    // 5. Local cache clear
    try {
      await cacheService.clearAll();
    } catch (_) {}
  }
}

// ── MAIN TEST SUITE ────────────────────────────────────────────────────────────

void main() {
  group('Feature 23: Cold Start Session Verification (401 vs Offline)', () {
    test('23.1 Cold start with valid stored session + 200 OK restores session & connects WS', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(accountStatusCode: 200);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'token_valid_123',
        userId: 1001,
        username: 'alex_rivera',
        displayName: 'Alex Rivera',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isTrue);
      expect(manager.currentSession?.accessToken, equals('token_valid_123'));
      expect(manager.inMemoryToken, equals('token_valid_123'));
      expect(manager.currentProfile?.username, equals('alex_rivera'));
      expect(wsClient.isConnected, isTrue);
      expect(httpClient.accountProbeCount, equals(1));
    });

    test('23.2 Cold start with valid stored session + 401 Unauthorized triggers clean auto-logout', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(accountStatusCode: 401);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'token_revoked_456',
        userId: 1001,
        username: 'alex_rivera',
        displayName: 'Alex Rivera',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isFalse);
      expect(manager.currentSession, isNull);
      expect(manager.inMemoryToken, isNull);
      expect(storage.containsKey(ColdStartAndLogoutManager.sessionKey), isFalse);
      expect(cacheService.isCleared, isTrue);
      expect(manager.statusMessage, equals('Сессия Nios ID завершена. Войдите снова.'));
    });

    test('23.3 Cold start with valid stored session + network offline preserves offline session', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(simulateNetworkOffline: true);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'token_offline_789',
        userId: 1001,
        username: 'alex_rivera',
        displayName: 'Alex Rivera',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isTrue);
      expect(manager.currentSession?.accessToken, equals('token_offline_789'));
      expect(storage.containsKey(ColdStartAndLogoutManager.sessionKey), isTrue);
    });

    test('23.4 Cold start with 500 server error preserves session (no false logout)', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(accountStatusCode: 500);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'token_server_glitch',
        userId: 1001,
        username: 'alex_rivera',
        displayName: 'Alex Rivera',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isTrue);
    });

    test('23.5 Cold start with no stored session remains unauthenticated', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isFalse);
      expect(manager.currentSession, isNull);
      expect(httpClient.accountProbeCount, equals(0)); // no probe needed when no session
    });

    test('23.6 Cold start with corrupted JSON purges storage safely', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: '{invalid_json_corrupted:');

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isFalse);
      expect(storage.containsKey(ColdStartAndLogoutManager.sessionKey), isFalse);
    });

    test('23.7 Cold start with empty access_token in stored JSON purges storage', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      await storage.write(
        key: ColdStartAndLogoutManager.sessionKey,
        value: jsonEncode({'access_token': '', 'user_id': 1001, 'username': 'test'}),
      );

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isFalse);
      expect(storage.containsKey(ColdStartAndLogoutManager.sessionKey), isFalse);
    });
  });

  group('Feature 24: Clean Logout Pipeline (Central HTTP + Local WS + Storage)', () {
    test('24.1 Logout unregisters push notification FCM token', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.performCleanLogout(fcmToken: 'fcm_token_device_abc');

      expect(wsClient.unregisterFcmCount, equals(1));
      expect(wsClient.lastFcmTokenUnregistered, equals('fcm_token_device_abc'));
    });

    test('24.2 Logout executes POST /id/api/v1/logout', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.performCleanLogout();

      expect(httpClient.logoutCallCount, equals(1));
      expect(httpClient.lastLogoutRequest?.url.path, equals('/id/api/v1/logout'));
    });

    test('24.3 Logout dispatches WS action logout and closes connection', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();
      await wsClient.connect();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.performCleanLogout();

      expect(wsClient.wsLogoutCount, equals(1));
      expect(wsClient.isConnected, isFalse);
    });

    test('24.4 Logout purges AuthSession from FlutterSecureStorage', () async {
      final storage = InMemorySecureStorage();
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: 'test_session');
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.performCleanLogout();

      expect(storage.containsKey(ColdStartAndLogoutManager.sessionKey), isFalse);
    });

    test('24.5 Logout clears in-memory token provider', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      )..inMemoryToken = 'bearer_token_xyz';

      await manager.performCleanLogout();

      expect(manager.inMemoryToken, isNull);
      expect(manager.isAuthenticated, isFalse);
    });

    test('24.6 Logout clears local cache service', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.performCleanLogout();

      expect(cacheService.isCleared, isTrue);
      expect(cacheService.clearCallCount, equals(1));
    });

    test('24.7 Logout survives network failures during central logout call', () async {
      final storage = InMemorySecureStorage();
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: 'test_session');
      final httpClient = MockCentralAuthHttpClient(simulateNetworkOffline: true);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.performCleanLogout();

      expect(storage.containsKey(ColdStartAndLogoutManager.sessionKey), isFalse);
      expect(manager.isAuthenticated, isFalse);
    });

    test('24.8 Logout survives FCM unregister failures and proceeds to completion', () async {
      final storage = InMemorySecureStorage();
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: 'test_session');
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble()..throwOnFcmUnregister = true;
      final cacheService = MockCacheServiceDouble();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.performCleanLogout(fcmToken: 'broken_fcm');

      expect(storage.containsKey(ColdStartAndLogoutManager.sessionKey), isFalse);
      expect(cacheService.isCleared, isTrue);
    });
  });

  group('TIER 2: Boundary & Corner Cases (Features 23 & 24)', () {
    test('T2.1 Storage read throwing PlatformException handled gracefully', () async {
      final storage = InMemorySecureStorage()..throwOnRead = true;
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isFalse);
    });

    test('T2.2 Rapid consecutive logout calls execute idempotently without exception', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.performCleanLogout();
      await manager.performCleanLogout();
      await manager.performCleanLogout();

      expect(manager.isAuthenticated, isFalse);
      expect(httpClient.logoutCallCount, equals(3));
    });

    test('T2.3 Central probe returning HTTP 204 No Content treated as valid session', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(accountStatusCode: 204);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'token_204',
        userId: 1001,
        username: 'alex',
        displayName: 'Alex',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isTrue);
    });

    test('T2.4 Central probe returning HTTP 504 Gateway Timeout preserves session', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(accountStatusCode: 504);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'token_504',
        userId: 1001,
        username: 'alex',
        displayName: 'Alex',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isTrue);
    });

    test('T2.5 Cache clear throwing exception does not prevent AuthState reset', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble()..throwOnClear = true;

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.performCleanLogout();

      expect(manager.isAuthenticated, isFalse);
    });
  });

  group('TIER 3: Cross-Feature Interactions (Features 23 & 24)', () {
    test('T3.1 Hydration -> Probe 200 OK -> WS Connect -> Profile Fetch -> Active State', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(accountStatusCode: 200);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'full_lifecycle_token',
        userId: 1001,
        username: 'alex_rivera',
        displayName: 'Alex Rivera',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isTrue);
      expect(manager.currentProfile?.bio, equals('NiosMess User'));
      expect(wsClient.isConnected, isTrue);
      expect(httpClient.accountProbeCount, equals(1));
    });

    test('T3.2 Hydration -> Probe 401 -> Auto-Logout -> Clean Slate', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(accountStatusCode: 401);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'expired_token',
        userId: 1001,
        username: 'alex',
        displayName: 'Alex',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isFalse);
      expect(storage.dump, isEmpty);
      expect(cacheService.isCleared, isTrue);
    });

    test('T3.3 User Logout -> FCM Unregister -> HTTP Logout -> WS Logout -> Storage Purge', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'active_session_token',
        userId: 1001,
        username: 'alex',
        displayName: 'Alex',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();
      expect(manager.isAuthenticated, isTrue);

      await manager.performCleanLogout(fcmToken: 'fcm_user_token_888');

      expect(manager.isAuthenticated, isFalse);
      expect(wsClient.unregisterFcmCount, equals(1));
      expect(httpClient.logoutCallCount, equals(1));
      expect(wsClient.wsLogoutCount, equals(1));
      expect(storage.dump, isEmpty);
      expect(cacheService.isCleared, isTrue);
    });
  });

  group('TIER 4: Real-World Workload Scenarios', () {
    test('Scenario 2: Returning user launches app with valid session, opens chats immediately', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(accountStatusCode: 200);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'token_returning_user',
        userId: 1001,
        username: 'alex_rivera',
        displayName: 'Alex Rivera',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isTrue);
      expect(manager.currentProfile?.username, equals('alex_rivera'));
    });

    test('Scenario 3: User revoked session from Nios ID web portal; app auto-logs out with notice', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(accountStatusCode: 401);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'token_revoked_externally',
        userId: 1001,
        username: 'alex_rivera',
        displayName: 'Alex Rivera',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isFalse);
      expect(manager.statusMessage, contains('Сессия Nios ID завершена'));
    });

    test('Scenario 4: User launches app in airplane mode; app preserves session for offline viewing', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient(simulateNetworkOffline: true);
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'token_airplane_mode',
        userId: 1001,
        username: 'alex_rivera',
        displayName: 'Alex Rivera',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();

      expect(manager.isAuthenticated, isTrue);
      expect(manager.currentSession?.accessToken, equals('token_airplane_mode'));
    });

    test('Scenario 6: User clicks «Выйти» in Settings; complete 5-stage logout pipeline executes without leaks', () async {
      final storage = InMemorySecureStorage();
      final httpClient = MockCentralAuthHttpClient();
      final wsClient = MockWebSocketClientDouble();
      final cacheService = MockCacheServiceDouble();

      const session = AuthSession(
        accessToken: 'token_to_logout',
        userId: 1001,
        username: 'alex_rivera',
        displayName: 'Alex Rivera',
      );
      await storage.write(key: ColdStartAndLogoutManager.sessionKey, value: jsonEncode(session.toJson()));

      final manager = ColdStartAndLogoutManager(
        storage: storage,
        httpClient: httpClient,
        wsClient: wsClient,
        cacheService: cacheService,
      );

      await manager.initializeColdStart();
      expect(manager.isAuthenticated, isTrue);

      await manager.performCleanLogout(fcmToken: 'fcm_user_settings_click');

      expect(manager.isAuthenticated, isFalse);
      expect(storage.containsKey(ColdStartAndLogoutManager.sessionKey), isFalse);
      expect(manager.inMemoryToken, isNull);
      expect(wsClient.isConnected, isFalse);
      expect(cacheService.isCleared, isTrue);
    });
  });
}
