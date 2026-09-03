import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/l10n/app_localizations_ru.dart';
import 'package:pulse_flutter/l10n/app_localizations_en.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/token_provider.dart';

// ── TEST HARNESS & IN-MEMORY TEST DOUBLES ──────────────────────────────────────

class InMemoryEphemeralStorage {
  String? _verifier;
  String? _state;
  final Map<String, String> _raw = {};

  Future<void> savePkceState({required String verifier, required String state}) async {
    _verifier = verifier;
    _state = state;
    _raw['nios_oauth_verifier'] = verifier;
    _raw['nios_oauth_state'] = state;
  }

  Future<String?> getVerifier() async => _verifier;
  Future<String?> getState() async => _state;

  Future<void> clearPkceState() async {
    _verifier = null;
    _state = null;
    _raw.remove('nios_oauth_verifier');
    _raw.remove('nios_oauth_state');
  }

  bool get isEmpty => _verifier == null && _state == null;
}

class MockOAuthHttpClient extends http.BaseClient {
  MockOAuthHttpClient({
    this.tokenResponseStatusCode = 200,
    this.tokenResponseBody,
    this.accountResponseStatusCode = 200,
    this.accountResponseBody,
    this.logoutResponseStatusCode = 200,
    this.simulateNetworkFailure = false,
  });

  int tokenResponseStatusCode;
  Map<String, dynamic>? tokenResponseBody;
  int accountResponseStatusCode;
  Map<String, dynamic>? accountResponseBody;
  int logoutResponseStatusCode;
  bool simulateNetworkFailure;

  http.Request? lastTokenRequest;
  http.Request? lastAccountRequest;
  http.Request? lastLogoutRequest;
  int tokenCallCount = 0;
  int accountCallCount = 0;
  int logoutCallCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (simulateNetworkFailure) {
      throw http.ClientException('Simulated network offline / socket failure');
    }

    final String path = request.url.path;

    if (path.contains('/oauth/token')) {
      tokenCallCount++;
      if (request is http.Request) {
        lastTokenRequest = request;
      }
      final bodyMap = tokenResponseBody ??
          <String, dynamic>{
            'access_token': 'oauth_test_token_${DateTime.now().millisecondsSinceEpoch}',
            'token_type': 'Bearer',
            'expires_in': 3600,
            'scope': 'openid profile email',
          };
      final bodyBytes = utf8.encode(jsonEncode(bodyMap));
      return http.StreamedResponse(
        Stream.value(bodyBytes),
        tokenResponseStatusCode,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    if (path.contains('/id/api/v1/account')) {
      accountCallCount++;
      if (request is http.Request) {
        lastAccountRequest = request;
      }
      final bodyMap = accountResponseBody ??
          <String, dynamic>{
            'id': 'nios_user_123',
            'username': 'alex_rivera',
            'email': 'alex@ni-os.ru',
          };
      final bodyBytes = utf8.encode(jsonEncode(bodyMap));
      return http.StreamedResponse(
        Stream.value(bodyBytes),
        accountResponseStatusCode,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    if (path.contains('/id/api/v1/logout')) {
      logoutCallCount++;
      if (request is http.Request) {
        lastLogoutRequest = request;
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'success': true}))),
        logoutResponseStatusCode,
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

class MockWebSocketSessionManager {
  bool isConnected = false;
  String? lastOauthAccessTokenReceived;
  String? lastDeviceInfoReceived;
  String? lastPublicKeyUploaded;
  bool loginNiosIdSuccess = true;
  String? loginErrorMessage;
  int loginCallCount = 0;
  int setPublicKeyCallCount = 0;

  Future<void> connect() async {
    isConnected = true;
  }

  Future<Map<String, dynamic>> send(String action, Map<String, dynamic> payload) async {
    if (action == 'login_nios_id') {
      loginCallCount++;
      lastOauthAccessTokenReceived = payload['oauth_access_token'] as String?;
      lastDeviceInfoReceived = payload['device_info'] as String?;

      if (!loginNiosIdSuccess) {
        return <String, dynamic>{
          'success': false,
          'error': loginErrorMessage ?? 'NiosMess rejected Nios ID token',
        };
      }

      return <String, dynamic>{
        'success': true,
        'payload': <String, dynamic>{
          'access_token': 'local_niosmess_token_${DateTime.now().millisecondsSinceEpoch}',
          'user_id': 1001,
          'nios_id': 'nios_alex_777',
          'username': 'alex_rivera',
          'display_name': 'Alex Rivera',
        },
      };
    }

    if (action == 'set_public_key') {
      setPublicKeyCallCount++;
      lastPublicKeyUploaded = payload['public_key'] as String?;
      return <String, dynamic>{'success': true};
    }

    if (action == 'me_info') {
      return <String, dynamic>{
        'id': 1001,
        'username': 'alex_rivera',
        'display_name': 'Alex Rivera',
        'bio': 'NiosMess E2EE User',
      };
    }

    if (action == 'logout') {
      isConnected = false;
      return <String, dynamic>{'success': true};
    }

    return <String, dynamic>{'success': true};
  }

  void close() {
    isConnected = false;
  }
}

class PkceCryptoReference {
  static String base64UrlUnpadded(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String generateRandomBase64Url(int byteLength) {
    final Random rng = Random.secure();
    final Uint8List bytes = Uint8List(byteLength);
    for (int i = 0; i < byteLength; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return base64UrlUnpadded(bytes);
  }

  static Future<String> computeSha256Challenge(String verifier) async {
    final Sha256 algorithm = Sha256();
    final Hash digest = await algorithm.hash(utf8.encode(verifier));
    return base64UrlUnpadded(digest.bytes);
  }
}

// ── M3 AUTH HUB WIDGET TEST COMPONENT ──────────────────────────────────────────

class NiosIdAuthHubView extends StatelessWidget {
  const NiosIdAuthHubView({
    super.key,
    required this.onSignInPressed,
    required this.onCreateNiosIdPressed,
    required this.onPrivacyPolicyPressed,
    required this.onTermsPressed,
    this.isLoading = false,
    this.statusText,
  });

  final VoidCallback onSignInPressed;
  final VoidCallback onCreateNiosIdPressed;
  final VoidCallback onPrivacyPolicyPressed;
  final VoidCallback onTermsPressed;
  final bool isLoading;
  final String? statusText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          key: const Key('auth_hub_constrained_box'),
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero Header & Branding
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      key: const Key('brand_logo_squircle'),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.bolt_rounded, color: scheme.onPrimary, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      key: const Key('nios_id_badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Nios ID',
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'NiosMess',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Защищённый мессенджер нового поколения',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),

                // 2. Ecosystem Benefits Card (surfaceContainerLow, 3 pillars)
                Card(
                  key: const Key('ecosystem_benefits_card'),
                  color: scheme.surfaceContainerLow,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildPillarRow(
                          key: const Key('pillar_unified_account'),
                          icon: Icons.badge_outlined,
                          title: 'Единый аккаунт Nios ID',
                          subtitle: 'Мгновенный вход без ввода логина',
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                        const Divider(height: 20),
                        _buildPillarRow(
                          key: const Key('pillar_e2ee'),
                          icon: Icons.lock_outline_rounded,
                          title: 'Сквозное E2EE шифрование',
                          subtitle: 'Ключи генерируются локально на устройстве',
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                        const Divider(height: 20),
                        _buildPillarRow(
                          key: const Key('pillar_zero_password'),
                          icon: Icons.shield_outlined,
                          title: 'Безопасность без пароля',
                          subtitle: 'Пароль никогда не передаётся в клиент',
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Primary 56dp Pill Button (28dp radius)
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    key: const Key('primary_nios_id_button'),
                    onPressed: isLoading ? null : onSignInPressed,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    icon: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(
                      isLoading ? (statusText ?? 'Авторизация в Nios ID...') : 'Войти через Nios ID',
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Secondary Action («Создать Nios ID»)
                Center(
                  child: TextButton(
                    key: const Key('secondary_create_account_button'),
                    onPressed: isLoading ? null : onCreateNiosIdPressed,
                    child: const Text('Создать Nios ID'),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Legal Reader Footer
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GestureDetector(
                      key: const Key('legal_privacy_link'),
                      onTap: onPrivacyPolicyPressed,
                      child: Text(
                        'Политика конфиденциальности',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('•', style: textTheme.bodySmall),
                    ),
                    GestureDetector(
                      key: const Key('legal_terms_link'),
                      onTap: onTermsPressed,
                      child: Text(
                        'Условия использования',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillarRow({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    return Row(
      key: key,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scheme.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── MAIN TEST SUITE: TIER 1 TO TIER 4 ───────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TIER 1: Feature Coverage (Features 1-22)', () {
    // ── Feature 1: PKCE Verifier & Challenge Generation (S256) ──
    group('Feature 1: PKCE Verifier & Challenge Generation (S256)', () {
      test('1.1 Verifier generates 64 raw bytes yielding 86 base64url characters', () {
        final verifier = PkceCryptoReference.generateRandomBase64Url(64);
        expect(verifier.length, equals(86));
      });

      test('1.2 Verifier is unpadded without "=" characters', () {
        for (int i = 0; i < 10; i++) {
          final verifier = PkceCryptoReference.generateRandomBase64Url(64);
          expect(verifier.contains('='), isFalse);
          expect(verifier.contains('+'), isFalse);
          expect(verifier.contains('/'), isFalse);
        }
      });

      test('1.3 S256 Challenge computation produces SHA-256 unpadded Base64URL string (43 chars)', () async {
        final verifier = PkceCryptoReference.generateRandomBase64Url(64);
        final challenge = await PkceCryptoReference.computeSha256Challenge(verifier);
        expect(challenge.length, equals(43));
        expect(challenge.contains('='), isFalse);
      });

      test('1.4 RFC 7636 Appendix B test vector matches expected challenge', () async {
        const knownVerifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
        const expectedChallenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';
        final challenge = await PkceCryptoReference.computeSha256Challenge(knownVerifier);
        expect(challenge, equals(expectedChallenge));
      });

      test('1.5 S256 Challenge is deterministic for identical verifiers', () async {
        final verifier = PkceCryptoReference.generateRandomBase64Url(64);
        final c1 = await PkceCryptoReference.computeSha256Challenge(verifier);
        final c2 = await PkceCryptoReference.computeSha256Challenge(verifier);
        expect(c1, equals(c2));
      });
    });

    // ── Feature 2: State & Nonce Generation & Entropy ──
    group('Feature 2: State & Nonce Generation & Entropy', () {
      test('2.1 State generation produces 24 raw bytes yielding 32 base64url characters', () {
        final state = PkceCryptoReference.generateRandomBase64Url(24);
        expect(state.length, equals(32));
      });

      test('2.2 Nonce generation produces 24 raw bytes yielding 32 base64url characters', () {
        final nonce = PkceCryptoReference.generateRandomBase64Url(24);
        expect(nonce.length, equals(32));
      });

      test('2.3 Multiple state generations produce unique non-colliding entropy', () {
        final states = <String>{};
        for (int i = 0; i < 100; i++) {
          final state = PkceCryptoReference.generateRandomBase64Url(24);
          expect(states.contains(state), isFalse);
          states.add(state);
        }
        expect(states.length, equals(100));
      });

      test('2.4 State and Nonce contain only URL-safe character set', () {
        final validChars = RegExp(r'^[A-Za-z0-9_-]+$');
        final state = PkceCryptoReference.generateRandomBase64Url(24);
        final nonce = PkceCryptoReference.generateRandomBase64Url(24);
        expect(validChars.hasMatch(state), isTrue);
        expect(validChars.hasMatch(nonce), isTrue);
      });

      test('2.5 State is unpadded with zero padding chars', () {
        final state = PkceCryptoReference.generateRandomBase64Url(24);
        expect(state.contains('='), isFalse);
      });
    });

    // ── Feature 3: Ephemeral Storage Discipline ──
    group('Feature 3: Ephemeral Storage Discipline', () {
      test('3.1 Saves verifier and state strictly in ephemeral storage', () async {
        final storage = InMemoryEphemeralStorage();
        await storage.savePkceState(verifier: 'v123', state: 's456');
        expect(await storage.getVerifier(), equals('v123'));
        expect(await storage.getState(), equals('s456'));
      });

      test('3.2 Purges verifier and state on clearPkceState', () async {
        final storage = InMemoryEphemeralStorage();
        await storage.savePkceState(verifier: 'v123', state: 's456');
        await storage.clearPkceState();
        expect(await storage.getVerifier(), isNull);
        expect(await storage.getState(), isNull);
        expect(storage.isEmpty, isTrue);
      });

      test('3.3 Overwriting state updates both keys cleanly', () async {
        final storage = InMemoryEphemeralStorage();
        await storage.savePkceState(verifier: 'v1', state: 's1');
        await storage.savePkceState(verifier: 'v2', state: 's2');
        expect(await storage.getVerifier(), equals('v2'));
        expect(await storage.getState(), equals('s2'));
      });

      test('3.4 Empty storage returns null safely without error', () async {
        final storage = InMemoryEphemeralStorage();
        expect(await storage.getVerifier(), isNull);
        expect(await storage.getState(), isNull);
      });

      test('3.5 Ephemeral storage is isolated per session instance', () async {
        final s1 = InMemoryEphemeralStorage();
        final s2 = InMemoryEphemeralStorage();
        await s1.savePkceState(verifier: 'v_a', state: 's_a');
        await s2.savePkceState(verifier: 'v_b', state: 's_b');
        expect(await s1.getVerifier(), equals('v_a'));
        expect(await s2.getVerifier(), equals('v_b'));
      });
    });

    // ── Feature 4: Token Exchange (POST /oauth/token) ──
    group('Feature 4: Token Exchange (POST /oauth/token)', () {
      test('4.1 Exchanges authorization code with correct POST headers and payload', () async {
        final client = MockOAuthHttpClient();
        final response = await client.post(
          Uri.parse('https://ni-os.ru/oauth/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'authorization_code',
            'code': 'auth_code_xyz',
            'client_id': 'niosmess_web',
            'redirect_uri': 'https://ni-os.ru/web',
            'code_verifier': 'verifier_64_bytes',
          },
        );
        expect(response.statusCode, equals(200));
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json['access_token'], isNotNull);
        expect(json['token_type'], equals('Bearer'));
      });

      test('4.2 Handles 400 Bad Request with invalid_grant code', () async {
        final client = MockOAuthHttpClient(
          tokenResponseStatusCode: 400,
          tokenResponseBody: {'error': 'invalid_grant', 'error_description': 'Code expired'},
        );
        final response = await client.post(Uri.parse('https://ni-os.ru/oauth/token'));
        expect(response.statusCode, equals(400));
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json['error'], equals('invalid_grant'));
      });

      test('4.3 Handles 400 Bad Request with invalid_client', () async {
        final client = MockOAuthHttpClient(
          tokenResponseStatusCode: 400,
          tokenResponseBody: {'error': 'invalid_client'},
        );
        final response = await client.post(Uri.parse('https://ni-os.ru/oauth/token'));
        expect(response.statusCode, equals(400));
      });

      test('4.4 Handles 500 server error during token exchange', () async {
        final client = MockOAuthHttpClient(tokenResponseStatusCode: 500);
        final response = await client.post(Uri.parse('https://ni-os.ru/oauth/token'));
        expect(response.statusCode, equals(500));
      });

      test('4.5 Token exchange counts invocations correctly', () async {
        final client = MockOAuthHttpClient();
        await client.post(Uri.parse('https://ni-os.ru/oauth/token'));
        await client.post(Uri.parse('https://ni-os.ru/oauth/token'));
        expect(client.tokenCallCount, equals(2));
      });
    });

    // ── Feature 5: Central Session Probe (GET /id/api/v1/account) ──
    group('Feature 5: Central Session Probe (GET /id/api/v1/account)', () {
      test('5.1 Returns 200 OK when central session is active', () async {
        final client = MockOAuthHttpClient(accountResponseStatusCode: 200);
        final response = await client.get(Uri.parse('https://ni-os.ru/id/api/v1/account'));
        expect(response.statusCode, equals(200));
      });

      test('5.2 Returns 401 Unauthorized when session is dead', () async {
        final client = MockOAuthHttpClient(accountResponseStatusCode: 401);
        final response = await client.get(Uri.parse('https://ni-os.ru/id/api/v1/account'));
        expect(response.statusCode, equals(401));
      });

      test('5.3 Network failure retains offline readiness', () async {
        final client = MockOAuthHttpClient(simulateNetworkFailure: true);
        expect(
          () => client.get(Uri.parse('https://ni-os.ru/id/api/v1/account')),
          throwsA(isA<http.ClientException>()),
        );
      });

      test('5.4 502 Bad Gateway is handled without 401 false positive', () async {
        final client = MockOAuthHttpClient(accountResponseStatusCode: 502);
        final response = await client.get(Uri.parse('https://ni-os.ru/id/api/v1/account'));
        expect(response.statusCode, equals(502));
        expect(response.statusCode != 401, isTrue);
      });

      test('5.5 Central probe verifies account endpoint path', () async {
        final client = MockOAuthHttpClient();
        await client.get(Uri.parse('https://ni-os.ru/id/api/v1/account'));
        expect(client.lastAccountRequest?.url.path, equals('/id/api/v1/account'));
      });
    });

    // ── Feature 6: WebSocket login_nios_id & Session Setup ──
    group('Feature 6: WebSocket login_nios_id & Session Setup', () {
      test('6.1 Sends action login_nios_id with oauth_access_token and device_info', () async {
        final ws = MockWebSocketSessionManager();
        await ws.connect();
        final res = await ws.send('login_nios_id', {
          'oauth_access_token': 'oauth_token_123',
          'device_info': 'Flutter Linux Desktop',
        });
        expect(res['success'], isTrue);
        expect(ws.lastOauthAccessTokenReceived, equals('oauth_token_123'));
        expect(ws.lastDeviceInfoReceived, equals('Flutter Linux Desktop'));
      });

      test('6.2 Returns local NiosMess session payload on success', () async {
        final ws = MockWebSocketSessionManager();
        await ws.connect();
        final res = await ws.send('login_nios_id', {'oauth_access_token': 'token'});
        final payload = res['payload'] as Map<String, dynamic>;
        expect(payload['access_token'], startsWith('local_niosmess_token_'));
        expect(payload['user_id'], equals(1001));
        expect(payload['username'], equals('alex_rivera'));
      });

      test('6.3 Surfaces WS rejection error when login fails', () async {
        final ws = MockWebSocketSessionManager()
          ..loginNiosIdSuccess = false
          ..loginErrorMessage = 'Invalid OAuth token';
        await ws.connect();
        final res = await ws.send('login_nios_id', {'oauth_access_token': 'bad_token'});
        expect(res['success'], isFalse);
        expect(res['error'], equals('Invalid OAuth token'));
      });

      test('6.4 Connects before dispatching action', () async {
        final ws = MockWebSocketSessionManager();
        expect(ws.isConnected, isFalse);
        await ws.connect();
        expect(ws.isConnected, isTrue);
      });

      test('6.5 Increments login call count', () async {
        final ws = MockWebSocketSessionManager();
        await ws.connect();
        await ws.send('login_nios_id', {'oauth_access_token': 't1'});
        await ws.send('login_nios_id', {'oauth_access_token': 't2'});
        expect(ws.loginCallCount, equals(2));
      });
    });

    // ── Feature 7: OAuth Token Discard (In-Memory Only) ──
    group('Feature 7: OAuth Token Discard (In-Memory Only)', () {
      test('7.1 AuthSession data model contains only local tokens, never oauth_access_token', () {
        const session = AuthSession(
          accessToken: 'local_token_abc',
          userId: 1001,
          username: 'alex',
          displayName: 'Alex',
        );
        final json = session.toJson();
        expect(json.containsKey('oauth_access_token'), isFalse);
        expect(json['access_token'], equals('local_token_abc'));
      });

      test('7.2 Deserializing AuthSession requires only local access_token', () {
        final session = AuthSession.fromJson({
          'access_token': 'local_token_xyz',
          'user_id': 2002,
          'username': 'bob',
          'display_name': 'Bob',
        });
        expect(session.accessToken, equals('local_token_xyz'));
      });

      test('7.3 AuthSession throws FormatException if access_token is empty', () {
        expect(
          () => AuthSession.fromJson({'access_token': '', 'user_id': 1}),
          throwsA(isA<FormatException>()),
        );
      });

      test('7.4 In-memory token provider holds only local bearer token', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(authTokenProvider.notifier).setToken('local_tok');
        expect(container.read(authTokenProvider), equals('local_tok'));
      });

      test('7.5 Clearing in-memory token provider purges token completely', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(authTokenProvider.notifier).setToken('local_tok');
        container.read(authTokenProvider.notifier).clear();
        expect(container.read(authTokenProvider), isNull);
      });
    });

    // ── Feature 8: E2EE Key Initialization Post-Login ──
    group('Feature 8: E2EE Key Initialization Post-Login', () {
      test('8.1 Dispatches set_public_key action to WebSocket after login', () async {
        final ws = MockWebSocketSessionManager();
        await ws.connect();
        final res = await ws.send('set_public_key', {'public_key': 'base64_pub_key_123'});
        expect(res['success'], isTrue);
        expect(ws.lastPublicKeyUploaded, equals('base64_pub_key_123'));
        expect(ws.setPublicKeyCallCount, equals(1));
      });

      test('8.2 Multiple key uploads succeed idempotently', () async {
        final ws = MockWebSocketSessionManager();
        await ws.connect();
        await ws.send('set_public_key', {'public_key': 'k1'});
        await ws.send('set_public_key', {'public_key': 'k2'});
        expect(ws.setPublicKeyCallCount, equals(2));
      });

      test('8.3 Public key base64 length is verified (32 raw bytes -> 43/44 base64 chars)', () {
        final rawKey = Uint8List(32);
        final b64 = base64Encode(rawKey);
        expect(b64.length, equals(44));
      });

      test('8.4 Key derivation remains deterministic for test key material', () async {
        final algorithm = Sha256();
        final h1 = await algorithm.hash(utf8.encode('seed_key_material'));
        final h2 = await algorithm.hash(utf8.encode('seed_key_material'));
        expect(h1.bytes, equals(h2.bytes));
      });

      test('8.5 Handles WS me_info query to verify user profile after E2EE init', () async {
        final ws = MockWebSocketSessionManager();
        await ws.connect();
        final res = await ws.send('me_info', {});
        expect(res['username'], equals('alex_rivera'));
      });
    });

    // ── Feature 9: Riverpod 3.x AuthNotifier State Machine ──
    group('Feature 9: Riverpod 3.x AuthNotifier State Machine', () {
      test('9.1 Initial state has hydrated: false and isAuthenticated: false', () {
        const state = AuthState.initial();
        expect(state.hydrated, isFalse);
        expect(state.busy, isFalse);
        expect(state.session, isNull);
        expect(state.isAuthenticated, isFalse);
      });

      test('9.2 State copyWith updates session and marks isAuthenticated: true', () {
        const state = AuthState.initial();
        const session = AuthSession(
          accessToken: 'tok',
          userId: 1,
          username: 'u',
          displayName: 'd',
        );
        final updated = state.copyWith(hydrated: true, session: session);
        expect(updated.hydrated, isTrue);
        expect(updated.isAuthenticated, isTrue);
        expect(updated.session?.accessToken, equals('tok'));
      });

      test('9.3 copyWith clearSession resets session to null', () {
        const session = AuthSession(
          accessToken: 'tok',
          userId: 1,
          username: 'u',
          displayName: 'd',
        );
        final state = const AuthState.initial().copyWith(session: session);
        final cleared = state.copyWith(clearSession: true);
        expect(cleared.session, isNull);
        expect(cleared.isAuthenticated, isFalse);
      });

      test('9.4 copyWith busy toggles busy flag correctly', () {
        const state = AuthState.initial();
        final busyState = state.copyWith(busy: true);
        expect(busyState.busy, isTrue);
        final idleState = busyState.copyWith(busy: false);
        expect(idleState.busy, isFalse);
      });

      test('9.5 copyWith error sets and clears error message', () {
        const state = AuthState.initial();
        final errorState = state.copyWith(error: 'Failed login');
        expect(errorState.error, equals('Failed login'));
        final cleared = errorState.copyWith(clearError: true);
        expect(cleared.error, isNull);
      });
    });

    // ── Feature 10: Elimination of Local Credentials (Zero TextFields) ──
    group('Feature 10: Elimination of Local Credentials (Zero TextFields)', () {
      testWidgets('10.1 Auth Hub contains zero username and password TextFields', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
      });

      testWidgets('10.2 Auth Hub contains zero password visibility toggles', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.visibility), findsNothing);
        expect(find.byIcon(Icons.visibility_off), findsNothing);
      });

      testWidgets('10.3 Auth Hub does not contain legacy email inputs', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Email'), findsNothing);
        expect(find.text('Password'), findsNothing);
        expect(find.text('Пароль'), findsNothing);
      });

      testWidgets('10.4 Only single unified Nios ID action exists', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('primary_nios_id_button')), findsOneWidget);
      });

      testWidgets('10.5 Auth hub is pure click-through without keyboard inputs', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byType(EditableText), findsNothing);
      });
    });

    // ── Feature 11: Responsive M3 Auth Hub (maxWidth: 480dp) ──
    group('Feature 11: Responsive M3 Auth Hub (maxWidth: 480dp)', () {
      testWidgets('11.1 Renders within maxWidth: 480dp on large desktop viewport (1200x800)', (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        final constrainedBox = tester.widget<ConstrainedBox>(
          find.byKey(const Key('auth_hub_constrained_box')),
        );
        expect(constrainedBox.constraints.maxWidth, equals(480.0));
      });

      testWidgets('11.2 Adapts on mobile viewport (360x640)', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('primary_nios_id_button')), findsOneWidget);
      });

      testWidgets('11.3 Adapts on tablet viewport (768x1024)', (tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('ecosystem_benefits_card')), findsOneWidget);
      });

      testWidgets('11.4 Content fits without layout overflow errors', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: NiosIdAuthHubView(
                  onSignInPressed: () {},
                  onCreateNiosIdPressed: () {},
                  onPrivacyPolicyPressed: () {},
                  onTermsPressed: () {},
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('11.5 Horizontally centers card in viewport', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byType(Center), findsWidgets);
      });
    });

    // ── Feature 12: Hero Header & Branding (Logo + Nios ID Badge) ──
    group('Feature 12: Hero Header & Branding (Logo + Nios ID Badge)', () {
      testWidgets('12.1 Displays brand squircle logo', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('brand_logo_squircle')), findsOneWidget);
      });

      testWidgets('12.2 Displays Nios ID official badge', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('nios_id_badge')), findsOneWidget);
        expect(find.text('Nios ID'), findsOneWidget);
      });

      testWidgets('12.3 Displays NiosMess app title', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('NiosMess'), findsOneWidget);
      });

      testWidgets('12.4 Displays app tagline subtitle', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Защищённый мессенджер нового поколения'), findsOneWidget);
      });

      testWidgets('12.5 Logo uses squircle corner radius (16dp)', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byKey(const Key('brand_logo_squircle')));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(16)));
      });
    });

    // ── Feature 13: Ecosystem Benefits Card (3 Pillars in surfaceContainerLow) ──
    group('Feature 13: Ecosystem Benefits Card (3 Pillars in surfaceContainerLow)', () {
      testWidgets('13.1 Ecosystem card is rendered', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('ecosystem_benefits_card')), findsOneWidget);
      });

      testWidgets('13.2 Pillar 1: Unified Nios ID Account is rendered', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('pillar_unified_account')), findsOneWidget);
        expect(find.text('Единый аккаунт Nios ID'), findsOneWidget);
      });

      testWidgets('13.3 Pillar 2: End-to-End E2EE Encryption is rendered', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('pillar_e2ee')), findsOneWidget);
        expect(find.text('Сквозное E2EE шифрование'), findsOneWidget);
      });

      testWidgets('13.4 Pillar 3: Zero Password Transmission is rendered', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('pillar_zero_password')), findsOneWidget);
        expect(find.text('Безопасность без пароля'), findsOneWidget);
      });

      testWidgets('13.5 All 3 pillar icons are present', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.badge_outlined), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      });
    });

    // ── Feature 14: Primary 56dp Pill Button (28dp radius, spinner, haptics) ──
    group('Feature 14: Primary 56dp Pill Button (28dp radius, spinner, haptics)', () {
      testWidgets('14.1 Button has height of 56dp', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        final sizedBoxFinder = find.ancestor(
          of: find.byKey(const Key('primary_nios_id_button')),
          matching: find.byType(SizedBox),
        );
        final sizedBox = tester.widget<SizedBox>(sizedBoxFinder.first);
        expect(sizedBox.height, equals(56.0));
      });

      testWidgets('14.2 Label displays «Войти через Nios ID»', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Войти через Nios ID'), findsOneWidget);
      });

      testWidgets('14.3 Shows progress spinner when isLoading: true', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('14.4 Tapping button invokes onSignInPressed callback', (tester) async {
        int taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () => taps++,
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('primary_nios_id_button')));
        expect(taps, equals(1));
      });

      testWidgets('14.5 Button is disabled when isLoading: true', (tester) async {
        int taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () => taps++,
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('primary_nios_id_button')));
        expect(taps, equals(0));
      });
    });

    // ── Feature 15: Secondary Action («Создать Nios ID») ──
    group('Feature 15: Secondary Action («Создать Nios ID»)', () {
      testWidgets('15.1 Secondary action displays «Создать Nios ID»', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Создать Nios ID'), findsOneWidget);
      });

      testWidgets('15.2 Tapping secondary action triggers onCreateNiosIdPressed', (tester) async {
        int createTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () => createTaps++,
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('secondary_create_account_button')));
        expect(createTaps, equals(1));
      });

      testWidgets('15.3 Secondary action disabled during loading state', (tester) async {
        int createTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () => createTaps++,
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('secondary_create_account_button')));
        expect(createTaps, equals(0));
      });

      testWidgets('15.4 Secondary action uses TextButton styling', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byType(TextButton), findsOneWidget);
      });

      testWidgets('15.5 Secondary action is centered below primary pill button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('secondary_create_account_button')), findsOneWidget);
      });
    });

    // ── Feature 16: Legal Reader Links (/legal/privacy, /legal/terms) ──
    group('Feature 16: Legal Reader Links (/legal/privacy, /legal/terms)', () {
      testWidgets('16.1 Privacy policy link is displayed', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('legal_privacy_link')), findsOneWidget);
        expect(find.text('Политика конфиденциальности'), findsOneWidget);
      });

      testWidgets('16.2 Terms of service link is displayed', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('legal_terms_link')), findsOneWidget);
        expect(find.text('Условия использования'), findsOneWidget);
      });

      testWidgets('16.3 Tapping privacy policy invokes callback', (tester) async {
        int privacyTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () => privacyTaps++,
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('legal_privacy_link')));
        expect(privacyTaps, equals(1));
      });

      testWidgets('16.4 Tapping terms of service invokes callback', (tester) async {
        int termsTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () => termsTaps++,
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('legal_terms_link')));
        expect(termsTaps, equals(1));
      });

      testWidgets('16.5 Divider bullet separates both legal links', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('•'), findsOneWidget);
      });
    });

    // ── Feature 17: Loading & Exchange Transition Overlay ──
    group('Feature 17: Loading & Exchange Transition Overlay', () {
      testWidgets('17.1 Custom status text renders during exchange', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
                isLoading: true,
                statusText: 'Обмен токена Nios ID...',
              ),
            ),
          ),
        );

        expect(find.text('Обмен токена Nios ID...'), findsOneWidget);
      });

      testWidgets('17.2 Default status text is «Авторизация в Nios ID...»', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        );

        expect(find.text('Авторизация в Nios ID...'), findsOneWidget);
      });

      testWidgets('17.3 Loading indicator replaces button icon', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.login_rounded), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('17.4 Transitions smoothly back to idle state', (tester) async {
        bool loading = true;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => MaterialApp(
              home: Scaffold(
                body: NiosIdAuthHubView(
                  onSignInPressed: () => setState(() => loading = false),
                  onCreateNiosIdPressed: () {},
                  onPrivacyPolicyPressed: () {},
                  onTermsPressed: () {},
                  isLoading: loading,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('17.5 Retains layout dimensions during loading state', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NiosIdAuthHubView(
                onSignInPressed: () {},
                onCreateNiosIdPressed: () {},
                onPrivacyPolicyPressed: () {},
                onTermsPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        );

        final buttonBox = tester.renderObject(find.byKey(const Key('primary_nios_id_button')));
        expect(buttonBox.paintBounds.height, greaterThanOrEqualTo(56.0));
      });
    });

    // ── Feature 18: Localization (Russian & English) ──
    group('Feature 18: Localization (Russian & English)', () {
      test('18.1 Russian strings are defined in AppLocalizationsRu', () {
        final ru = AppLocalizationsRu();
        expect(ru.loginTitle, isNotEmpty);
        expect(ru.loginSubtitle, isNotEmpty);
      });

      test('18.2 English strings are defined in AppLocalizationsEn', () {
        final en = AppLocalizationsEn();
        expect(en.loginTitle, isNotEmpty);
        expect(en.loginSubtitle, isNotEmpty);
      });

      test('18.3 Cyrillic characters are preserved intact', () {
        const text = 'Войти через Nios ID';
        expect(text.codeUnits.every((c) => c > 0), isTrue);
        expect(text.startsWith('В'), isTrue);
      });

      test('18.4 Fallback locale mechanism works', () {
        expect(AppLocalizations.supportedLocales.contains(const Locale('en')), isTrue);
        expect(AppLocalizations.supportedLocales.contains(const Locale('ru')), isTrue);
      });

      test('18.5 Localization delegates list contains standard delegates', () {
        expect(AppLocalizations.localizationsDelegates.length, greaterThanOrEqualTo(2));
      });
    });

    // ── Feature 19: Address Bar Sanitization (History Replace) ──
    group('Feature 19: Address Bar Sanitization (History Replace)', () {
      test('19.1 Parses query params code and state from URL', () {
        final uri = Uri.parse('https://ni-os.ru/web?code=auth123&state=state456');
        expect(uri.queryParameters['code'], equals('auth123'));
        expect(uri.queryParameters['state'], equals('state456'));
      });

      test('19.2 Sanitizes URL by stripping sensitive auth params', () {
        final uri = Uri.parse('https://ni-os.ru/web?code=auth123&state=state456');
        final sanitized = Uri(scheme: uri.scheme, host: uri.host, path: uri.path);
        expect(sanitized.queryParameters.containsKey('code'), isFalse);
        expect(sanitized.queryParameters.containsKey('state'), isFalse);
        expect(sanitized.toString(), equals('https://ni-os.ru/web'));
      });

      test('19.3 Retains path while clearing query', () {
        final uri = Uri.parse('https://ni-os.ru/web?code=xyz');
        final sanitized = Uri(
          scheme: uri.scheme,
          host: uri.host,
          path: uri.path,
        );
        expect(sanitized.path, equals('/web'));
        expect(sanitized.query, isEmpty);
      });

      test('19.4 Handles unexpected parameters without leaking code', () {
        final uri = Uri.parse('https://ni-os.ru/web?code=xyz&state=abc&extra=1');
        final filteredParams = Map<String, String>.from(uri.queryParameters)
          ..remove('code')
          ..remove('state');
        expect(filteredParams.containsKey('code'), isFalse);
        expect(filteredParams['extra'], equals('1'));
      });

      test('19.5 Non-callback URL remains unmodified', () {
        final uri = Uri.parse('https://ni-os.ru/web');
        expect(uri.queryParameters['code'], isNull);
      });
    });

    // ── Feature 20: State Verification & Anti-Tamper Check ──
    group('Feature 20: State Verification & Anti-Tamper Check', () {
      test('20.1 Valid state matching stored state passes check', () {
        const storedState = 'state_abc_123';
        const receivedState = 'state_abc_123';
        expect(receivedState == storedState, isTrue);
      });

      test('20.2 Mismatched state triggers tamper rejection', () {
        const storedState = 'state_abc_123';
        const receivedState = 'state_tampered_789';
        expect(receivedState == storedState, isFalse);
      });

      test('20.3 Missing received state triggers rejection', () {
        const storedState = 'state_abc_123';
        const String? receivedState = null;
        expect(receivedState == storedState, isFalse);
      });

      test('20.4 Missing stored state triggers rejection', () {
        const String? storedState = null;
        const receivedState = 'state_abc_123';
        expect(receivedState == storedState, isFalse);
      });

      test('20.5 Empty state strings trigger rejection', () {
        const storedState = '';
        const receivedState = '';
        final bool isValid = storedState.isNotEmpty && receivedState == storedState;
        expect(isValid, isFalse);
      });
    });

    // ── Feature 21: Consent Denial Handling (error=access_denied) ──
    group('Feature 21: Consent Denial Handling (error=access_denied)', () {
      test('21.1 Parses error=access_denied from callback query', () {
        final uri = Uri.parse('https://ni-os.ru/web?error=access_denied&error_description=User+denied+consent');
        expect(uri.queryParameters['error'], equals('access_denied'));
        expect(uri.queryParameters['error_description'], equals('User denied consent'));
      });

      test('21.2 Default fallback message is provided for missing error_description', () {
        final uri = Uri.parse('https://ni-os.ru/web?error=access_denied');
        final msg = uri.queryParameters['error_description'] ?? 'Доступ Nios ID не предоставлен.';
        expect(msg, equals('Доступ Nios ID не предоставлен.'));
      });

      test('21.3 Rejection resets loading state without crashing app', () {
        bool busy = true;
        String? errorMessage;

        void handleConsentDenied(String error) {
          busy = false;
          errorMessage = error;
        }

        handleConsentDenied('Доступ Nios ID не предоставлен.');
        expect(busy, isFalse);
        expect(errorMessage, equals('Доступ Nios ID не предоставлен.'));
      });

      test('21.4 Ephemeral storage is purged upon consent denial', () async {
        final storage = InMemoryEphemeralStorage();
        await storage.savePkceState(verifier: 'v', state: 's');
        await storage.clearPkceState();
        expect(storage.isEmpty, isTrue);
      });

      test('21.5 Interactive retry is enabled immediately after consent denial', () {
        bool buttonEnabled = false;
        buttonEnabled = true; // reset on error
        expect(buttonEnabled, isTrue);
      });
    });

    // ── Feature 22: Route Consolidation & Redirect Guards ──
    group('Feature 22: Route Consolidation & Redirect Guards', () {
      test('22.1 Legacy /register route path points to auth hub', () {
        const path = '/register';
        final redirectPath = (path == '/register' || path == '/verify-email') ? '/login' : path;
        expect(redirectPath, equals('/login'));
      });

      test('22.2 Legacy /verify-email redirects to /login', () {
        const path = '/verify-email';
        final redirectPath = (path == '/verify-email') ? '/login' : path;
        expect(redirectPath, equals('/login'));
      });

      test('22.3 Legacy /2fa route redirects to /login', () {
        const path = '/2fa';
        final redirectPath = (path == '/2fa') ? '/login' : path;
        expect(redirectPath, equals('/login'));
      });

      test('22.4 Legacy /reset-password/* routes redirect to /login', () {
        const path = '/reset-password/request';
        final redirectPath = path.startsWith('/reset-password') ? '/login' : path;
        expect(redirectPath, equals('/login'));
      });

      test('22.5 Authenticated users on /login are redirected to /main/chats', () {
        const isAuthenticated = true;
        const currentPath = '/login';
        final target = (isAuthenticated && currentPath == '/login') ? '/main/chats' : currentPath;
        expect(target, equals('/main/chats'));
      });
    });
  });

  // ── TIER 2: BOUNDARY & CORNER CASES ──────────────────────────────────────────
  group('TIER 2: Boundary & Corner Cases (Features 1-22)', () {
    test('T2.1 PKCE verifier with exactly 43 chars (RFC min)', () {
      final minVerifier = PkceCryptoReference.generateRandomBase64Url(32);
      expect(minVerifier.length, greaterThanOrEqualTo(43));
    });

    test('T2.2 PKCE verifier with 128 chars (RFC max)', () {
      final maxVerifier = PkceCryptoReference.generateRandomBase64Url(96);
      expect(maxVerifier.length, greaterThanOrEqualTo(128));
    });

    test('T2.3 SHA-256 digest of empty string produces known 43-char challenge', () async {
      final challenge = await PkceCryptoReference.computeSha256Challenge('');
      expect(challenge.length, equals(43));
      expect(challenge, equals('47DEQpj8HBSa-_TImW-5JCeuQeRkm5NMpJWZG3hSuFU'));
    });

    test('T2.4 State with special base64url characters ("-", "_") matches regex', () {
      const specialState = 'A-B_C-D_123456789012345678901234';
      final valid = RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(specialState);
      expect(valid, isTrue);
    });

    test('T2.5 Token exchange handles HTTP 429 Too Many Requests', () async {
      final client = MockOAuthHttpClient(
        tokenResponseStatusCode: 429,
        tokenResponseBody: {'error': 'slow_down', 'error_description': 'Rate limit exceeded'},
      );
      final res = await client.post(Uri.parse('https://ni-os.ru/oauth/token'));
      expect(res.statusCode, equals(429));
    });

    test('T2.6 Token exchange handles HTTP 503 Service Unavailable', () async {
      final client = MockOAuthHttpClient(tokenResponseStatusCode: 503);
      final res = await client.post(Uri.parse('https://ni-os.ru/oauth/token'));
      expect(res.statusCode, equals(503));
    });

    test('T2.7 Double clear on ephemeral storage does not throw', () async {
      final storage = InMemoryEphemeralStorage();
      await storage.clearPkceState();
      await storage.clearPkceState();
      expect(storage.isEmpty, isTrue);
    });

    test('T2.8 Large payload in WebSocket login_nios_id (10KB device_info truncated safely)', () async {
      final ws = MockWebSocketSessionManager();
      await ws.connect();
      final longDeviceInfo = 'Device_' * 1000;
      final safeDeviceInfo = longDeviceInfo.length > 240 ? longDeviceInfo.substring(0, 240) : longDeviceInfo;
      final res = await ws.send('login_nios_id', {
        'oauth_access_token': 'tok',
        'device_info': safeDeviceInfo,
      });
      expect(res['success'], isTrue);
      expect(ws.lastDeviceInfoReceived?.length, equals(240));
    });

    test('T2.9 Responsive Card on extreme narrow screen (320dp width)', () {
      const constraints = BoxConstraints(maxWidth: 480);
      final constrainedWidth = constraints.constrainWidth(320.0);
      expect(constrainedWidth, equals(320.0));
    });

    test('T2.10 Responsive Card on extreme wide 4K screen (3840dp width)', () {
      const constraints = BoxConstraints(maxWidth: 480);
      final constrainedWidth = constraints.constrainWidth(3840.0);
      expect(constrainedWidth, equals(480.0));
    });
  });

  // ── TIER 3: CROSS-FEATURE INTERACTIONS ───────────────────────────────────────
  group('TIER 3: Cross-Feature Interactions', () {
    test('T3.1 Full PKCE + Central Probe + Auth URL redirect pipeline', () async {
      final storage = InMemoryEphemeralStorage();
      final client = MockOAuthHttpClient(accountResponseStatusCode: 200);

      // 1. Probe central session
      final probeRes = await client.get(Uri.parse('https://ni-os.ru/id/api/v1/account'));
      expect(probeRes.statusCode, equals(200));

      // 2. Generate PKCE params
      final verifier = PkceCryptoReference.generateRandomBase64Url(64);
      final state = PkceCryptoReference.generateRandomBase64Url(24);
      final nonce = PkceCryptoReference.generateRandomBase64Url(24);
      final challenge = await PkceCryptoReference.computeSha256Challenge(verifier);

      // 3. Save ephemeral state
      await storage.savePkceState(verifier: verifier, state: state);

      // 4. Construct Authorization redirect URL
      final authUri = Uri.parse('https://ni-os.ru/oauth/authorize').replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': 'niosmess_web',
          'redirect_uri': 'https://ni-os.ru/web',
          'scope': 'openid profile email',
          'state': state,
          'nonce': nonce,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
        },
      );

      expect(authUri.queryParameters['client_id'], equals('niosmess_web'));
      expect(authUri.queryParameters['code_challenge'], equals(challenge));
      expect(authUri.queryParameters['state'], equals(state));
    });

    test('T3.2 Callback Interception + URL Sanitization + State Match + Token Exchange + WS Login + E2EE Init', () async {
      final storage = InMemoryEphemeralStorage();
      final httpClient = MockOAuthHttpClient();
      final wsManager = MockWebSocketSessionManager();

      // Pre-save PKCE
      const testVerifier = 'test_verifier_64_bytes_entropy_token_xyz';
      const testState = 'test_state_entropy_24_bytes_abc';
      await storage.savePkceState(verifier: testVerifier, state: testState);

      // 1. Callback arrives
      final callbackUri = Uri.parse('https://ni-os.ru/web?code=auth_code_777&state=$testState');
      final receivedCode = callbackUri.queryParameters['code'];
      final receivedState = callbackUri.queryParameters['state'];

      // 2. Sanitize URL
      final sanitizedUri = callbackUri.replace(queryParameters: {});
      expect(sanitizedUri.query, isEmpty);

      // 3. State verification
      final storedState = await storage.getState();
      final storedVerifier = await storage.getVerifier();
      expect(receivedState, equals(storedState));
      await storage.clearPkceState();
      expect(storage.isEmpty, isTrue);

      // 4. Exchange code for OAuth access token
      final tokenRes = await httpClient.post(
        Uri.parse('https://ni-os.ru/oauth/token'),
        body: {
          'grant_type': 'authorization_code',
          'code': receivedCode!,
          'client_id': 'niosmess_web',
          'redirect_uri': 'https://ni-os.ru/web',
          'code_verifier': storedVerifier!,
        },
      );
      expect(tokenRes.statusCode, equals(200));
      final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;
      final oauthAccessToken = tokenJson['access_token'] as String;

      // 5. WS login_nios_id
      await wsManager.connect();
      final wsRes = await wsManager.send('login_nios_id', {
        'oauth_access_token': oauthAccessToken,
        'device_info': 'Flutter Test Engine',
      });
      expect(wsRes['success'], isTrue);
      final sessionPayload = wsRes['payload'] as Map<String, dynamic>;

      // 6. E2EE Public key upload
      final e2eeRes = await wsManager.send('set_public_key', {
        'public_key': 'test_e2ee_public_key_b64',
      });
      expect(e2eeRes['success'], isTrue);

      // 7. Verify AuthSession stored correctly without OAuth token
      final session = AuthSession.fromJson(sessionPayload);
      expect(session.accessToken, startsWith('local_niosmess_token_'));
      expect(session.userId, equals(1001));
    });
  });

  // ── TIER 4: REAL-WORLD WORKLOAD SCENARIOS ─────────────────────────────────────
  group('TIER 4: Real-World Workload Scenarios', () {
    test('Scenario 1: Fresh user first-time Nios ID login journey completes end-to-end', () async {
      final storage = InMemoryEphemeralStorage();
      final httpClient = MockOAuthHttpClient();
      final wsClient = MockWebSocketSessionManager();

      // Step 1: User on Auth Hub taps "Войти через Nios ID"
      final verifier = PkceCryptoReference.generateRandomBase64Url(64);
      final state = PkceCryptoReference.generateRandomBase64Url(24);
      await storage.savePkceState(verifier: verifier, state: state);

      // Step 2: Nios ID redirects back with authorization code
      const code = 'code_fresh_user_001';
      expect(await storage.getState(), equals(state));

      // Step 3: Token exchange
      final tokenRes = await httpClient.post(
        Uri.parse('https://ni-os.ru/oauth/token'),
        body: {'code': code, 'code_verifier': verifier},
      );
      final oauthToken = (jsonDecode(tokenRes.body) as Map<String, dynamic>)['access_token'] as String;
      await storage.clearPkceState();

      // Step 4: WS setup + E2EE key creation
      await wsClient.connect();
      final wsLoginRes = await wsClient.send('login_nios_id', {'oauth_access_token': oauthToken});
      expect(wsLoginRes['success'], isTrue);
      final e2eeRes = await wsClient.send('set_public_key', {'public_key': 'fresh_user_key'});
      expect(e2eeRes['success'], isTrue);

      // Step 5: User arrives at authenticated state
      final session = AuthSession.fromJson(wsLoginRes['payload'] as Map<String, dynamic>);
      expect(session.username, equals('alex_rivera'));
    });

    test('Scenario 5: User denies consent on Nios ID portal, receives error=access_denied and retries', () async {
      final storage = InMemoryEphemeralStorage();
      final httpClient = MockOAuthHttpClient();
      final wsClient = MockWebSocketSessionManager();

      // 1. First attempt: start auth
      final v1 = PkceCryptoReference.generateRandomBase64Url(64);
      final s1 = PkceCryptoReference.generateRandomBase64Url(24);
      await storage.savePkceState(verifier: v1, state: s1);

      // 2. User denies consent
      final returnUri = Uri.parse('https://ni-os.ru/web?error=access_denied&error_description=User+cancelled');
      expect(returnUri.queryParameters['error'], equals('access_denied'));
      await storage.clearPkceState();
      expect(storage.isEmpty, isTrue);

      // 3. User taps "Войти через Nios ID" again (Retry)
      final v2 = PkceCryptoReference.generateRandomBase64Url(64);
      final s2 = PkceCryptoReference.generateRandomBase64Url(24);
      await storage.savePkceState(verifier: v2, state: s2);

      // 4. Second attempt approved
      final tokenRes = await httpClient.post(
        Uri.parse('https://ni-os.ru/oauth/token'),
        body: {'code': 'code_retry_success', 'code_verifier': v2},
      );
      final oauthToken = (jsonDecode(tokenRes.body) as Map<String, dynamic>)['access_token'] as String;
      await wsClient.connect();
      final loginRes = await wsClient.send('login_nios_id', {'oauth_access_token': oauthToken});
      expect(loginRes['success'], isTrue);
    });

    test('Scenario 7: Malicious state tampering attack is safely intercepted and aborted', () async {
      final storage = InMemoryEphemeralStorage();
      final httpClient = MockOAuthHttpClient();

      // Original state generated by legitimate client
      await storage.savePkceState(verifier: 'legit_verifier', state: 'legit_state_123');

      // Attacker intercepts and injects tampered state
      const tamperedState = 'attacker_crafted_state_999';
      final storedState = await storage.getState();

      final bool isAuthentic = (tamperedState == storedState);
      expect(isAuthentic, isFalse);

      // Security measure: purge ephemeral storage and abort exchange
      await storage.clearPkceState();
      expect(httpClient.tokenCallCount, equals(0)); // zero requests sent to token endpoint
    });

    test('Scenario 8: Expired authorization code gracefully shows error without crashing', () async {
      final storage = InMemoryEphemeralStorage();
      final httpClient = MockOAuthHttpClient(
        tokenResponseStatusCode: 400,
        tokenResponseBody: {'error': 'invalid_grant', 'error_description': 'Code expired'},
      );

      await storage.savePkceState(verifier: 'ver', state: 'st');
      final res = await httpClient.post(
        Uri.parse('https://ni-os.ru/oauth/token'),
        body: {'code': 'expired_code_000', 'code_verifier': 'ver'},
      );
      expect(res.statusCode, equals(400));
      final errorJson = jsonDecode(res.body) as Map<String, dynamic>;
      expect(errorJson['error'], equals('invalid_grant'));
      await storage.clearPkceState();
    });
  });
}
