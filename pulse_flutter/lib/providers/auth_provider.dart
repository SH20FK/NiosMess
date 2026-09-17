import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/services/oauth_service.dart';
import 'dart:async';
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
  const AuthActionResult({
    required this.success,
    this.message,
  });

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
            debugPrint('[auth_provider] Mock reset flag detected! Clearing mock data...');
            await _clearSessionStorage();
            await ref.read(cacheServiceProvider).clearAll();
            state = const AuthState.initial().copyWith(hydrated: true);
            return;
          }
        }
      } catch (_) {}
    }

    final String? raw = await _storage.read(key: _sessionKey);
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
      await _storage.delete(key: _sessionKey);
      await ref.read(cacheServiceProvider).clearAll();
      session = null;
    }

    if (session != null && session.accessToken.isNotEmpty) {
      ref.read(authTokenProvider.notifier).setToken(session.accessToken);
    }

    state = state.copyWith(hydrated: true, session: session);

    if (state.isAuthenticated) {
      try {
        await refreshProfile();
      } catch (e) {
        debugPrint('[auth_provider] Refresh profile error on load: $e');
      }
      _registerFcmToken();
      _updateBackgroundService();
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    final String serialized = jsonEncode(session.toJson());
    await _storage.write(key: _sessionKey, value: serialized);
    ref.read(authTokenProvider.notifier).setToken(session.accessToken);
  }

  Future<void> _clearSessionStorage() async {
    await _storage.delete(key: _sessionKey);
    ref.read(authTokenProvider.notifier).clear();
  }

  Future<AuthActionResult> loginWithOAuth({
    required String oauthAccessToken,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final String deviceInfo = kIsWeb
          ? 'Web Browser'
          : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.trim();

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
      _registerFcmToken();
      _updateBackgroundService();
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

  Future<void> logout() async {
    try {
      if (state.isAuthenticated) {
        try {
          final String? fcmToken = await PushNotificationService.getToken();
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await ref.read(authRepositoryProvider).unregisterFcmToken(fcmToken);
          }
        } catch (e) {
          debugPrint('[auth_provider.dart] FCM unregister failed: $e');
        }
        await ref.read(authRepositoryProvider).logout();
        try {
          await ref.read(oauthServiceProvider).logoutCentralNiosId();
        } catch (_) {}
      }
    } catch (e) { debugPrint('[auth_provider.dart] Error: $e'); }

    BackgroundService.stop();
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
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void setPendingIdentifier(String value) {
    state = state.copyWith(pendingIdentifier: value);
  }

  Future<void> _registerFcmToken() async {
    await _fcmTokenRefreshSubscription?.cancel();
    _fcmTokenRefreshSubscription = null;

    _wsConnectedSubscription ??= ref.read(webSocketClientProvider).onConnected.listen((_) {
      if (state.isAuthenticated) {
        debugPrint('[AuthNotifier] Socket connected/reconnected: refreshing FCM registration');
        _registerFcmToken();
      }
    });

    try {
      final String? fcmToken = await PushNotificationService.getToken();
      final String platform = kIsWeb
          ? 'web'
          : (Platform.isAndroid ? 'android' : 'ios');

      if (fcmToken != null && fcmToken.isNotEmpty) {
        unawaited(_sendFcmTokenWithRetry(fcmToken, platform));
      }

      _fcmTokenRefreshSubscription = PushNotificationService.onTokenRefresh.listen((newToken) {
        unawaited(_sendFcmTokenWithRetry(newToken, platform));
      });
    } catch (e) {
      debugPrint('[AuthNotifier] Failed to register FCM token: $e');
    }
  }

  Future<void> _sendFcmTokenWithRetry(String token, String platform) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await ref.read(webSocketClientProvider).request(
              'register_fcm_token',
              payload: {
                'fcm_token': token,
                'platform': platform,
              },
            );
        debugPrint('[AuthNotifier] FCM token registered successfully (attempt $attempt)');
        break;
      } catch (e) {
        debugPrint('[AuthNotifier] FCM token register attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
  }

  Future<void> refreshFcmTokenRegistration() => _registerFcmToken();

  void _updateBackgroundService() {
    if (kIsWeb) return;
    try {
      final BackgroundMode mode = ref.read(uiSettingsProvider).backgroundMode;
      if (mode == BackgroundMode.reliable) {
        BackgroundService.startReliable();
      }
    } catch (e) {
      debugPrint('[auth_provider] _updateBackgroundService error: $e');
    }
  }
}

final NotifierProvider<AuthNotifier, AuthState> authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
