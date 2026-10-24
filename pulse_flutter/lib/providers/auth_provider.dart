import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/services/oauth_service.dart';
import 'package:pulse_flutter/services/protocol/nios_protocol_accounts.dart';
import 'dart:async';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/providers/in_app_notification_provider.dart';
import 'package:pulse_flutter/core/notifications/notification_history_store.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:universal_io/io.dart';

class AuthState {
  const AuthState({
    required this.hydrated,
    required this.busy,
    required this.session,
    required this.pendingIdentifier,
    required this.error,
    required this.profile,
  });

  const AuthState.initial()
    : hydrated = false,
      busy = false,
      session = null,
      pendingIdentifier = null,
      error = null,
      profile = null;

  final bool hydrated;
  final bool busy;
  final AuthSession? session;
  final String? pendingIdentifier;
  final String? error;
  final ApiProfile? profile;

  bool get isAuthenticated {
    return session != null && session!.accessToken.isNotEmpty;
  }

  AuthState copyWith({
    bool? hydrated,
    bool? busy,
    AuthSession? session,
    bool clearSession = false,
    String? pendingIdentifier,
    bool clearPendingIdentifier = false,
    String? error,
    bool clearError = false,
    ApiProfile? profile,
    bool clearProfile = false,
  }) {
    return AuthState(
      hydrated: hydrated ?? this.hydrated,
      busy: busy ?? this.busy,
      session: clearSession ? null : (session ?? this.session),
      pendingIdentifier: clearPendingIdentifier
          ? null
          : (pendingIdentifier ?? this.pendingIdentifier),
      error: clearError ? null : (error ?? this.error),
      profile: clearProfile ? null : (profile ?? this.profile),
    );
  }
}

class AuthActionResult {
  const AuthActionResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class AuthNotifier extends Notifier<AuthState> {
  static const String _sessionKey = 'auth.session';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  Future<void>? _loadFuture;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  StreamSubscription<void>? _wsConnectedSubscription;

  @override
  AuthState build() {
    listenSelf((previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated && !_loggingOut) {
        unawaited(BackgroundService.setAuthenticated(next.isAuthenticated));
      }
    });
    _loadFuture = _load();
    ref.onDispose(() {
      _fcmTokenRefreshSubscription?.cancel();
      _wsConnectedSubscription?.cancel();
    });
    return const AuthState.initial();
  }

  Future<void> ensureLoaded() async {
    await (_loadFuture ?? Future<void>.value());
  }

  Future<void> _load() async {
    if (kIsWeb) {
      try {
        final http.Response resp = await http
            .get(Uri.parse('/mock_reset.json'))
            .timeout(const Duration(seconds: 2));
        if (resp.statusCode == 200) {
          final dynamic data = jsonDecode(resp.body);
          if (data is Map && data['reset'] == true) {
            debugPrint(
              '[auth_provider] Mock reset flag detected! Clearing mock data...',
            );
            await _clearSessionStorage();
            await ref.read(cacheServiceProvider).clearAll();
            state = const AuthState.initial().copyWith(hydrated: true);
            return;
          }
        }
      } catch (_) {}
    }

    String? raw;
    try {
      raw = await _storage.read(key: _sessionKey);
    } catch (e) {
      debugPrint('[auth_provider] Secure storage read failed: $e');
    }
    // One-time legacy migration from SharedPreferences to secure storage:
    if (raw == null || raw.isEmpty) {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(_sessionKey);
        if (raw != null && raw.isNotEmpty) {
          try {
            await _storage.write(key: _sessionKey, value: raw);
          } catch (e) {
            debugPrint(
              '[auth_provider] Secure storage migration write failed: ',
            );
          }
          await prefs.remove(_sessionKey);
          debugPrint(
            '[auth_provider] Migrated session from SharedPreferences to secure storage',
          );
        }
      } catch (_) {}
    } else {
      // Proactively scrub any stale plaintext session from SharedPreferences
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey(_sessionKey)) {
          await prefs.remove(_sessionKey);
        }
      } catch (_) {}
    }

    AuthSession? session;

    if (raw != null && raw.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          session = AuthSession.fromJson(decoded);
        }
      } catch (e) {
        debugPrint('[auth_provider] Session deserialize error: $e');
        session = null;
      }
    }

    if (session != null && session.accessToken.startsWith('demo_')) {
      await _clearSessionStorage();
      await ref.read(cacheServiceProvider).clearAll();
      session = null;
    }

    if (session != null && session.accessToken.isNotEmpty) {
      ref
          .read(sessionAccessTokenProvider.notifier)
          .setToken(session.accessToken);
    }

    state = state.copyWith(hydrated: true, session: session);

    if (state.isAuthenticated) {
      try {
        await refreshProfile();
      } catch (e) {
        debugPrint('[auth_provider] Refresh profile error on load: $e');
      }
      unawaited(
        _registerFcmToken().catchError((Object _) {
          debugPrint('[Auth] FCM_REGISTRATION_PENDING');
        }),
      );
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    final String serialized = jsonEncode(session.toJson());
    try {
      await _storage.write(key: _sessionKey, value: serialized);
    } catch (e) {
      debugPrint('[auth_provider] Secure storage write error: $e');
    }
    // Plaintext SharedPreferences write eliminated for security hardening (Audit P0 #3)
    ref.read(sessionAccessTokenProvider.notifier).setToken(session.accessToken);
  }

  Future<void> _clearSessionStorage() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {}
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
    ref.read(sessionAccessTokenProvider.notifier).clear();
  }

  Future<AuthActionResult> loginWithOAuth({
    required String oauthAccessToken,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final String deviceInfo = kIsWeb
          ? 'Web Browser'
          : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'
                .trim();

      final AuthLoginResult result = await ref
          .read(authRepositoryProvider)
          .loginNiosId(
            oauthAccessToken: oauthAccessToken,
            deviceInfo: deviceInfo,
          );

      if (!result.isSuccess ||
          result.userId == null ||
          result.username == null) {
        state = state.copyWith(
          busy: false,
          error: result.message ?? 'OAuth login failed',
        );
        return AuthActionResult(success: false, message: result.message);
      }

      final int userId = result.userId ?? 0;
      final String username = result.username ?? result.displayName ?? 'user';
      final String displayName = result.displayName ?? username;
      final String accessToken = result.accessToken ?? '';

      final AuthSession session = AuthSession(
        accessToken: accessToken,
        userId: userId,
        username: username,
        displayName: displayName,
        niosId: username,
      );

      await _saveSession(session);
      state = state.copyWith(
        busy: false,
        session: session,
        clearPendingIdentifier: true,
        clearError: true,
      );
      await refreshProfile();
      unawaited(
        _registerFcmToken().catchError((Object _) {
          debugPrint('[Auth] FCM_REGISTRATION_PENDING');
        }),
      );
      return const AuthActionResult(success: true);
    } catch (error) {
      state = state.copyWith(busy: false, error: '$error');
      return AuthActionResult(success: false, message: '$error');
    }
  }

  Future<void> refreshProfile() async {
    if (!state.isAuthenticated) {
      return;
    }
    try {
      final ApiProfile profile = await ref.read(authRepositoryProvider).getMe();
      if (!ref.mounted) return;
      state = state.copyWith(profile: profile, clearError: true);
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(error: '$error');
    }
  }

  void updateAiUsage(ApiAiUsage aiUsage) {
    if (state.profile != null) {
      final ApiProfile updated = state.profile!.copyWith(aiUsage: aiUsage);
      state = state.copyWith(profile: updated);
      ref.read(cacheServiceProvider).saveProfile(updated);
    }
  }

  Future<AuthActionResult> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? phoneNumber,
    String? birthday,
    WorkingHours? workingHours,
    bool clearPhoneNumber = false,
    bool clearBirthday = false,
    bool clearWorkingHours = false,
  }) async {
    if (!state.isAuthenticated) {
      return const AuthActionResult(
        success: false,
        message: 'Not authenticated',
      );
    }

    state = state.copyWith(busy: true, clearError: true);
    try {
      final ApiProfile profile = await ref
          .read(authRepositoryProvider)
          .updateProfile(
            displayName: displayName,
            username: username,
            bio: bio,
            phoneNumber: phoneNumber,
            birthday: birthday,
            workingHours: workingHours,
            clearPhoneNumber: clearPhoneNumber,
            clearBirthday: clearBirthday,
            clearWorkingHours: clearWorkingHours,
          );
      final ApiProfile effectiveProfile = profile.aiUsage != null
          ? profile
          : profile.copyWith(aiUsage: state.profile?.aiUsage);
      state = state.copyWith(
        busy: false,
        profile: effectiveProfile,
        session: state.session == null
            ? null
            : AuthSession(
                accessToken: state.session!.accessToken,
                userId: state.session!.userId,
                username: profile.username,
                displayName: profile.displayName,
              ),
      );

      if (state.session != null) {
        await _saveSession(state.session!);
      }

      return const AuthActionResult(success: true);
    } catch (error) {
      state = state.copyWith(busy: false, error: '$error');
      return AuthActionResult(success: false, message: '$error');
    }
  }

  bool _loggingOut = false;
  bool get isLoggingOut => _loggingOut;
  Future<void> logout({bool eraseSecretData = true}) async {
    if (_loggingOut) return;
    _loggingOut = true;
    // Revoke service requests before any asynchronous account cleanup. Late
    // uploads/call updates may still notify widgets while auth state is visible.
    final backgroundStopped = BackgroundService.stop();
    final accountId = state.session?.userId;
    ref.read(notificationsProvider.notifier).stopAccount();
    ref.read(inAppNotificationProvider.notifier).clearAccount();
    final notificationsStopped = () async {
      await PushNotificationService.clearAccount();
      if (accountId != null && eraseSecretData) {
        await NotificationHistoryStore.eraseAccount(accountId);
      }
    }();
    final secretStopped = accountId == null
        ? Future<List<int>>.value([])
        : SecretChatCoordinator.shutdownAccount(
            accountId,
            erase: eraseSecretData,
          );
    final protocolStopped = accountId == null
        ? Future<void>.value()
        : ref
              .read(niosProtocolAccountsProvider)
              .shutdownAccount(accountId.toString(), erase: eraseSecretData);
    final stopped = Future.wait<Object?>([
      backgroundStopped,
      secretStopped,
      protocolStopped,
      notificationsStopped,
    ]);
    try {
      final stoppedData = await stopped;
      final chatIds = stoppedData[1] as List<int>;
      if (accountId != null && eraseSecretData) {
        await EncryptedMessageCache.clearAccount(accountId, chatIds);
        await ref.read(e2eeServiceProvider).deleteKeyPair();
        final prefs = await SharedPreferences.getInstance();
        for (final id in chatIds) {
          await prefs.remove('draft.$id');
        }
      }

      try {
        if (state.isAuthenticated && eraseSecretData) {
          try {
            final String? fcmToken = (await SharedPreferences.getInstance())
                .getString('notifications.registered_token');
            if (fcmToken != null && fcmToken.isNotEmpty) {
              await ref
                  .read(authRepositoryProvider)
                  .unregisterFcmToken(fcmToken);
            }
          } catch (e) {
            debugPrint('[Auth] FCM_UNREGISTER_UNAVAILABLE');
          }
          await PushNotificationService.revokeToken();
          await ref.read(authRepositoryProvider).logout();
          try {
            await ref.read(oauthServiceProvider).logoutCentralNiosId();
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[auth_provider.dart] Error: $e');
      }

      await _fcmTokenRefreshSubscription?.cancel();
      _fcmTokenRefreshSubscription = null;
      await _wsConnectedSubscription?.cancel();
      _wsConnectedSubscription = null;

      ref.read(webSocketClientProvider).disconnect();
      await _clearSessionStorage();
      try {
        await ref.read(cacheServiceProvider).clearAll();
      } catch (e) {
        debugPrint('[auth_provider.dart] Cache clear error: $e');
      }
      state = state.copyWith(
        clearSession: true,
        clearPendingIdentifier: true,
        clearError: true,
        clearProfile: true,
      );
    } finally {
      _loggingOut = false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void setPendingIdentifier(String value) {
    state = state.copyWith(pendingIdentifier: value);
  }

  Future<void>? _notificationRegistration;
  bool _notificationRegistrationRequested = false;
  Future<void> _registerFcmToken() {
    _notificationRegistrationRequested = true;
    return _notificationRegistration ??= _drainNotificationRegistration()
        .whenComplete(() {
          _notificationRegistration = null;
        });
  }

  Future<void> _drainNotificationRegistration() async {
    while (_notificationRegistrationRequested && !_loggingOut) {
      _notificationRegistrationRequested = false;
      await _registerFcmTokenOnce();
    }
  }

  Future<void> _registerFcmTokenOnce() async {
    PushNotificationService.deviceRegistered.value = false;
    // FCM is exclusively supported on mobile (Android/iOS) and Web.
    // Calling Firebase on desktop throws [core/no-app].
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    await _fcmTokenRefreshSubscription?.cancel();
    _fcmTokenRefreshSubscription = null;

    _wsConnectedSubscription ??= ref
        .read(webSocketClientProvider)
        .onConnected
        .listen((_) {
          if (state.isAuthenticated) {
            debugPrint(
              '[AuthNotifier] Socket connected/reconnected: refreshing FCM registration',
            );
            unawaited(
              _registerFcmToken().catchError((Object _) {
                debugPrint('[Auth] FCM_REGISTRATION_PENDING');
              }),
            );
          }
        });

    final session = state.session;
    if (session == null || _loggingOut) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = ref.read(uiSettingsProvider).notifications;
      if (!identical(state.session, session) || _loggingOut) return;
      await PushNotificationService.configureAccount(session.userId);
      if (!enabled) {
        final token = prefs.getString('notifications.registered_token');
        if (token != null) {
          await ref.read(authRepositoryProvider).unregisterFcmToken(token);
        }
        return;
      }
      final token = await PushNotificationService.getToken();
      if (!identical(state.session, session) || _loggingOut) return;
      final platform = kIsWeb
          ? 'web'
          : Platform.isAndroid
          ? 'android'
          : 'ios';
      if (token != null && token.isNotEmpty) {
        await _sendFcmTokenWithRetry(token, platform);
      }
      _fcmTokenRefreshSubscription = PushNotificationService.onTokenRefresh
          .listen((newToken) {
            if (identical(state.session, session) && !_loggingOut) {
              unawaited(
                _sendFcmTokenWithRetry(newToken, platform).catchError((
                  Object _,
                ) {
                  debugPrint('[Auth] FCM_REFRESH_PENDING');
                }),
              );
            }
          });
    } catch (_) {
      debugPrint('[Auth] FCM_REGISTRATION_PENDING');
      rethrow;
    }
  }

  Future<void> _sendFcmTokenWithRetry(String token, String platform) async {
    final session = state.session;
    for (int attempt = 1; attempt <= 3; attempt++) {
      if (session == null ||
          !identical(state.session, session) ||
          _loggingOut ||
          !ref.read(uiSettingsProvider).notifications) {
        return;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        final options = jsonDecode(
          prefs.getString('notification_preferences_${session.userId}') ?? '{}',
        );
        final prefix = 'chat_notifications_muted_${session.userId}_';
        final muted = prefs
            .getKeys()
            .where(
              (key) => key.startsWith(prefix) && prefs.getBool(key) == true,
            )
            .map((key) => int.tryParse(key.substring(prefix.length)))
            .whereType<int>()
            .toList();
        await ref
            .read(webSocketClientProvider)
            .request(
              'register_fcm_token',
              payload: {
                'fcm_token': token,
                'platform': platform,
                'notification_protocol': 2,
                'notification_preferences': {
                  ...options,
                  'enabled': true,
                  'muted_chat_ids': muted,
                  'locale':
                      ref.read(uiSettingsProvider).localeCode ??
                      PlatformDispatcher.instance.locale.languageCode,
                },
              },
            );
        if (!identical(state.session, session) || _loggingOut) return;
        await prefs.setString('notifications.registered_token', token);
        PushNotificationService.deviceRegistered.value = true;
        return;
      } catch (_) {
        if (attempt == 3) rethrow;
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  Future<void> refreshFcmTokenRegistration() => _registerFcmToken();
}

final NotifierProvider<AuthNotifier, AuthState> authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
