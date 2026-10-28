import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/core/storage/niosgram_saved_store.dart';
import 'package:pulse_flutter/core/storage/niosgram_draft_store.dart';
import 'package:pulse_flutter/services/encrypted_draft_sync.dart';
import 'package:pulse_flutter/services/live_location_service.dart';
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
  static const String _signedOutKey = 'auth.signed_out';
  FlutterSecureStorage get _storage => ref.read(authSecureStorageProvider);
  Future<void>? _loadFuture;
  int _authEpoch = 0;
  int _profileRequest = 0;
  int _profileMutation = 0;
  Future<void> _sessionWrites = Future<void>.value();

  bool _current(int epoch, [AuthSession? session]) =>
      ref.mounted &&
      epoch == _authEpoch &&
      !_loggingOut &&
      (session == null || identical(state.session, session));

  Future<void> _sessionStorageOperation(Future<void> Function() operation) {
    final job = _sessionWrites.then((_) => operation());
    _sessionWrites = job.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return job;
  }

  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  StreamSubscription<void>? _wsConnectedSubscription;

  @override
  AuthState build() {
    listenSelf((previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated && !_loggingOut) {
        unawaited(BackgroundService.setAuthenticated(next.isAuthenticated));
      }
    });
    final epoch = ++_authEpoch;
    _loadFuture = _load(epoch);
    ref.onDispose(() {
      _authEpoch++;
      _fcmTokenRefreshSubscription?.cancel();
      _wsConnectedSubscription?.cancel();
    });
    return const AuthState.initial();
  }

  Future<void> ensureLoaded() async {
    await (_loadFuture ?? Future<void>.value());
  }

  Future<void> _load(int epoch) async {
    final SharedPreferences preferences;
    try {
      preferences = await ref.read(authPreferencesLoaderProvider)();
    } catch (_) {
      // If the sign-out fence cannot be read, do not revive a possibly revoked
      // secure-storage session. Surface a recoverable startup state instead.
      if (_current(epoch)) {
        state = const AuthState.initial().copyWith(
          hydrated: true,
          error: 'AUTH_LOCAL_STATE_UNAVAILABLE',
        );
      }
      return;
    }
    if (!_current(epoch)) return;
    if (preferences.getBool(_signedOutKey) == true) {
      try {
        await _clearSessionStorage();
      } catch (_) {
        /* Retry cleanup on next launch. */
      }
      if (_current(epoch)) {
        state = const AuthState.initial().copyWith(hydrated: true);
      }
      return;
    }
    if (kIsWeb) {
      try {
        final http.Response resp = await http
            .get(Uri.parse('/mock_reset.json'))
            .timeout(const Duration(seconds: 2));
        if (resp.statusCode == 200) {
          final dynamic data = jsonDecode(resp.body);
          if (data is Map && data['reset'] == true && _current(epoch)) {
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

    if (!_current(epoch)) return;
    String? raw;
    try {
      raw = await _storage.read(key: _sessionKey);
    } catch (e) {
      debugPrint('[auth_provider] Secure storage read failed: $e');
    }
    if (!_current(epoch)) return;
    // One-time legacy migration from SharedPreferences to secure storage:
    if (raw == null || raw.isEmpty) {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(_sessionKey);
        if (raw != null && raw.isNotEmpty) {
          try {
            await _sessionStorageOperation(() async {
              if (!_current(epoch)) return;
              await _storage.write(key: _sessionKey, value: raw);
              if (_current(epoch)) await prefs.remove(_sessionKey);
            });
          } catch (e) {
            debugPrint(
              '[auth_provider] Secure storage migration write failed: ',
            );
          }
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

    if (!_current(epoch)) return;
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

    if (!_current(epoch)) return;
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

  Future<void> _saveSession(AuthSession session, int epoch) async {
    await _sessionStorageOperation(() async {
      if (!_current(epoch)) return;
      try {
        await _storage.write(
          key: _sessionKey,
          value: jsonEncode(session.toJson()),
        );
      } catch (_) {
        throw StateError('AUTH_SESSION_STORAGE_UNAVAILABLE');
      }
      if (_current(epoch)) {
        final prefs = await SharedPreferences.getInstance();
        if (!_current(epoch)) return;
        if (!await prefs.remove(_signedOutKey)) {
          throw StateError('AUTH_SESSION_STORAGE_UNAVAILABLE');
        }
        if (_current(epoch)) {
          ref
              .read(sessionAccessTokenProvider.notifier)
              .setToken(session.accessToken);
        }
      }
    });
  }

  Future<void> _clearSessionStorage() => _sessionStorageOperation(() async {
    Object? failure;
    try {
      await _storage.delete(key: _sessionKey);
    } catch (error) {
      failure = error;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.remove(_sessionKey)) {
        failure ??= StateError('AUTH_SESSION_STORAGE_UNAVAILABLE');
      }
    } catch (error) {
      failure ??= error;
    }
    if (ref.mounted) ref.read(sessionAccessTokenProvider.notifier).clear();
    if (failure != null) throw StateError('AUTH_SESSION_STORAGE_UNAVAILABLE');
  });

  Future<AuthActionResult> loginWithOAuth({
    required String oauthAccessToken,
  }) async {
    if (_loggingOut) return const AuthActionResult(success: false);
    final epoch = ++_authEpoch;
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

      if (!_current(epoch)) return const AuthActionResult(success: false);
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

      await _saveSession(session, epoch);
      if (!_current(epoch)) return const AuthActionResult(success: false);
      state = state.copyWith(
        busy: false,
        session: session,
        clearProfile: true,
        hydrated: true,
        clearPendingIdentifier: true,
        clearError: true,
      );
      await refreshProfile();
      if (!_current(epoch)) return const AuthActionResult(success: false);
      unawaited(
        _registerFcmToken().catchError((Object _) {
          debugPrint('[Auth] FCM_REGISTRATION_PENDING');
        }),
      );
      return const AuthActionResult(success: true);
    } catch (error) {
      if (!_current(epoch)) return const AuthActionResult(success: false);
      state = state.copyWith(busy: false, error: '$error');
      return AuthActionResult(success: false, message: '$error');
    }
  }

  Future<void> refreshProfile() async {
    final session = state.session;
    if (session == null || !state.isAuthenticated || _loggingOut) return;
    final epoch = _authEpoch,
        request = ++_profileRequest,
        mutation = _profileMutation;
    try {
      final profile = await ref.read(authRepositoryProvider).getMe();
      if (!_current(epoch, session) ||
          request != _profileRequest ||
          mutation != _profileMutation) {
        return;
      }
      state = state.copyWith(profile: profile, clearError: true);
    } catch (error) {
      if (!_current(epoch, session) ||
          request != _profileRequest ||
          mutation != _profileMutation) {
        return;
      }
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

    final session = state.session!;
    final epoch = _authEpoch, request = ++_profileMutation;
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
      if (!_current(epoch, session) || request != _profileMutation) {
        return const AuthActionResult(success: false);
      }
      final ApiProfile effectiveProfile = profile.aiUsage != null
          ? profile
          : profile.copyWith(aiUsage: state.profile?.aiUsage);
      final nextSession = AuthSession(
        accessToken: session.accessToken,
        userId: session.userId,
        username: profile.username,
        displayName: profile.displayName,
        niosId: session.niosId,
      );
      await _saveSession(nextSession, epoch);
      if (!_current(epoch, session) || request != _profileMutation) {
        return const AuthActionResult(success: false);
      }
      _profileRequest++;
      state = state.copyWith(
        busy: false,
        profile: effectiveProfile,
        session: nextSession,
      );

      return const AuthActionResult(success: true);
    } catch (error) {
      if (!_current(epoch, session) || request != _profileMutation) {
        return const AuthActionResult(success: false);
      }
      state = state.copyWith(busy: false, error: '$error');
      return AuthActionResult(success: false, message: '$error');
    }
  }

  bool _loggingOut = false;
  bool get isLoggingOut => _loggingOut;
  Future<void> logout({bool eraseSecretData = true}) async {
    if (_loggingOut) return;
    _loggingOut = true;
    _authEpoch++;
    final accountId = state.session?.userId;
    Object? failure;
    Future<void> attempt(Future<void> Function() work) async {
      try {
        await work();
      } catch (error) {
        failure ??= error;
      }
    }

    var handlersStopped = true;
    Future<void> stopHandler(Future<void> Function() work) => attempt(() async {
      try {
        await work();
      } catch (_) {
        handlersStopped = false;
        rethrow;
      }
    });
    var secretStopped = accountId == null;
    var chatIds = <int>[];
    try {
      // The non-secret tombstone prevents a failed secure-storage delete from
      // silently reviving this session on the next cold start.
      await attempt(
        () => _sessionStorageOperation(() async {
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setBool(_signedOutKey, true)) {
            throw StateError('AUTH_LOGOUT_MARKER_UNAVAILABLE');
          }
        }),
      );
      if (ref.exists(notificationsProvider)) {
        ref.read(notificationsProvider.notifier).stopAccount();
      }
      if (ref.exists(inAppNotificationProvider)) {
        ref.read(inAppNotificationProvider.notifier).clearAccount();
      }
      if (ref.exists(incomingCallProvider)) {
        ref.read(incomingCallProvider.notifier).set(null);
      }
      // Release native media and notification/background handlers before any
      // account journal/history erasure can begin.
      await Future.wait([
        if (accountId != null)
          stopHandler(() => LiveLocationService.shutdownAccount(accountId)),
        if (accountId != null)
          stopHandler(() => EncryptedDraftSync.shutdownAccount(accountId)),
        stopHandler(BackgroundService.stop),
        if (ref.exists(callSessionProvider))
          stopHandler(
            () =>
                ref.read(callSessionProvider.notifier).shutdownForAccountExit(),
          ),
        stopHandler(PushNotificationService.clearAccount),
      ]);
      // Even if a handler failed, stop account services. Keep their private
      // data for recovery rather than erase under a still-running handler.
      final eraseAccountData = eraseSecretData && handlersStopped;
      await Future.wait([
        if (accountId != null)
          attempt(() async {
            chatIds = await SecretChatCoordinator.shutdownAccount(
              accountId,
              erase: eraseAccountData,
            );
            secretStopped = true;
          }),
        if (accountId != null)
          attempt(
            () => ref
                .read(niosProtocolAccountsProvider)
                .shutdownAccount(accountId.toString(), erase: eraseAccountData),
          ),
        if (accountId != null && eraseAccountData)
          attempt(() => NotificationHistoryStore.eraseAccount(accountId)),
      ]);
      if (accountId != null && eraseSecretData) {
        await Future.wait([
          attempt(() => NiosgramSavedStore.eraseAccount(accountId)),
          attempt(() => NiosgramDraftStore.eraseAccount(accountId)),
        ]);
      }
      if (accountId != null && eraseAccountData && secretStopped) {
        await attempt(() async {
          await DraftStorage.eraseAccount(accountId);
          await EncryptedMessageCache.clearAccount(accountId, chatIds);
          // Legacy keys belong to the installation's proven source account.
          if (await const FlutterSecureStorage().read(
                key: 'e2ee.legacy_owner',
              ) ==
              '$accountId') {
            await ref.read(e2eeServiceProvider).deleteKeyPair();
          }
          final prefs = await SharedPreferences.getInstance();
          for (final id in chatIds) {
            await prefs.remove('draft.$id');
          }
        });
      }
      if (state.isAuthenticated && eraseSecretData) {
        // Remote revocation is best effort; local logout never waits for it to
        // succeed before clearing the session and closing the socket.
        try {
          final token = (await SharedPreferences.getInstance()).getString(
            'notifications.registered_token',
          );
          if (token != null && token.isNotEmpty) {
            await ref.read(authRepositoryProvider).unregisterFcmToken(token);
          }
        } catch (_) {
          debugPrint('[Auth] FCM_UNREGISTER_UNAVAILABLE');
        }
        try {
          await PushNotificationService.revokeToken();
        } catch (_) {}
        try {
          await ref.read(authRepositoryProvider).logout();
        } catch (_) {}
        try {
          await ref.read(oauthServiceProvider).logoutCentralNiosId();
        } catch (_) {}
      }
    } finally {
      await attempt(() async {
        await _fcmTokenRefreshSubscription?.cancel();
        _fcmTokenRefreshSubscription = null;
        await _wsConnectedSubscription?.cancel();
        _wsConnectedSubscription = null;
      });
      await attempt(() async {
        if (ref.mounted) ref.read(webSocketClientProvider).disconnect();
      });
      await attempt(_clearSessionStorage);
      await attempt(() async {
        if (ref.mounted) await ref.read(cacheServiceProvider).clearAll();
      });
      if (ref.mounted) {
        state = const AuthState.initial().copyWith(
          hydrated: true,
          error: failure == null ? null : 'AUTH_LOGOUT_CLEANUP_INCOMPLETE',
        );
      }
      _loggingOut = false;
    }
    if (failure != null) throw StateError('AUTH_LOGOUT_CLEANUP_INCOMPLETE');
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

final authPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>(
      (ref) => SharedPreferences.getInstance,
    );

final authSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final NotifierProvider<AuthNotifier, AuthState> authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
