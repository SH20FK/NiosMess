import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'dart:async';
import 'dart:convert';
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
    this.requiresTwoFa = false,
    this.message,
  });

  final bool success;
  final bool requiresTwoFa;
  final String? message;
}

class AuthNotifier extends Notifier<AuthState> {
  static const String _sessionKey = 'auth.session';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  Future<void>? _loadFuture;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  String? _pendingEmail;
  String? _pendingPassword;

  @override
  AuthState build() {
    _loadFuture = _load();
    ref.onDispose(() {
      _fcmTokenRefreshSubscription?.cancel();
    });
    return const AuthState.initial();
  }

  Future<void> ensureLoaded() async {
    await (_loadFuture ?? Future<void>.value());
  }

  Future<void> _load() async {
    final String? raw = await _storage.read(key: _sessionKey);
    AuthSession? session;

    if (raw != null && raw.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          session = AuthSession.fromJson(decoded);
        }
      } catch (_) {
        session = null;
      }
    }

    if (session != null && session.accessToken.isNotEmpty) {
      ref.read(authTokenProvider.notifier).setToken(session.accessToken);
    }

    state = state.copyWith(hydrated: true, session: session);

    if (state.isAuthenticated) {
      await refreshProfile();
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

  Future<AuthActionResult> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final AuthLoginResult result = await ref
          .read(authRepositoryProvider)
          .login(identifier: identifier, password: password);

      if (result.twoFaRequired) {
        state = state.copyWith(
          busy: false,
          pendingIdentifier: identifier,
          clearError: true,
        );
        return AuthActionResult(
          success: false,
          requiresTwoFa: true,
          message: result.message,
        );
      }

      if (!result.isSuccess ||
          result.userId == null ||
          result.username == null) {
        state = state.copyWith(
          busy: false,
          error: result.message ?? 'Login failed',
        );
        return AuthActionResult(success: false, message: result.message);
      }

      final AuthSession session = AuthSession(
        accessToken: result.accessToken!,
        userId: result.userId!,
        username: result.username!,
        displayName: result.displayName ?? result.username!,
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

  Future<AuthActionResult> verifyTwoFa({required String code}) async {
    final String? identifier = state.pendingIdentifier;
    if (identifier == null || identifier.isEmpty) {
      return const AuthActionResult(
        success: false,
        message: '2FA session is missing. Login again.',
      );
    }

    state = state.copyWith(busy: true, clearError: true);
    try {
      final AuthLoginResult result = await ref
          .read(authRepositoryProvider)
          .verifyTwoFa(identifier: identifier, code: code);

      if (!result.isSuccess ||
          result.userId == null ||
          result.username == null) {
        state = state.copyWith(
          busy: false,
          error: result.message ?? '2FA verification failed',
        );
        return AuthActionResult(success: false, message: result.message);
      }

      final AuthSession session = AuthSession(
        accessToken: result.accessToken!,
        userId: result.userId!,
        username: result.username!,
        displayName: result.displayName ?? result.username!,
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

  Future<AuthActionResult> register({
    required String email,
    required String username,
    required String displayName,
    required String password,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final Map<String, dynamic> response = await ref
          .read(authRepositoryProvider)
          .register(
            email: email,
            username: username,
            displayName: displayName,
            password: password,
          );
      state = state.copyWith(busy: false);
      _pendingEmail = email;
      _pendingPassword = password;
      return AuthActionResult(
        success: true,
        message: response['message'] as String?,
      );
    } catch (error) {
      state = state.copyWith(busy: false, error: '$error');
      return AuthActionResult(success: false, message: '$error');
    }
  }

  Future<AuthActionResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final Map<String, dynamic> response = await ref
          .read(authRepositoryProvider)
          .verifyEmail(email: email, code: code);
      state = state.copyWith(busy: false);

      if (_pendingEmail != null && _pendingPassword != null) {
        final AuthLoginResult loginResult = await ref
            .read(authRepositoryProvider)
            .login(identifier: _pendingEmail!, password: _pendingPassword!);

        if (loginResult.isSuccess &&
            loginResult.userId != null &&
            loginResult.username != null) {
          final AuthSession session = AuthSession(
            accessToken: loginResult.accessToken!,
            userId: loginResult.userId!,
            username: loginResult.username!,
            displayName: loginResult.displayName ?? loginResult.username!,
          );
          await _saveSession(session);
          state = state.copyWith(
            busy: false,
            session: session,
            clearError: true,
          );
          _pendingEmail = null;
          _pendingPassword = null;
          await refreshProfile();
          _registerFcmToken();
      _updateBackgroundService();
          return AuthActionResult(
            success: true,
            message: response['message'] as String?,
          );
        }
      }

      _pendingEmail = null;
      _pendingPassword = null;
      return AuthActionResult(
        success: true,
        message: response['message'] as String?,
      );
    } catch (error) {
      state = state.copyWith(busy: false, error: '$error');
      _pendingEmail = null;
      _pendingPassword = null;
      return AuthActionResult(success: false, message: '$error');
    }
  }

  Future<AuthActionResult> requestPasswordReset({required String email}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final Map<String, dynamic> response = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: email);
      state = state.copyWith(busy: false);
      return AuthActionResult(
        success: true,
        message: response['message'] as String?,
      );
    } catch (error) {
      state = state.copyWith(busy: false, error: '$error');
      return AuthActionResult(success: false, message: '$error');
    }
  }

  Future<AuthActionResult> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final Map<String, dynamic> response = await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(
            email: email,
            code: code,
            newPassword: newPassword,
          );
      state = state.copyWith(busy: false);
      return AuthActionResult(
        success: true,
        message: response['message'] as String?,
      );
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
      state = state.copyWith(profile: profile, clearError: true);
    } catch (error) {
      state = state.copyWith(error: '$error');
    }
  }

  Future<AuthActionResult> updateProfile({
    String? displayName,
    String? username,
    String? bio,
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
          );
      state = state.copyWith(
        busy: false,
        profile: profile,
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
        await ref.read(authRepositoryProvider).logout();
      }
    } catch (e) { debugPrint('[auth_provider.dart] Error: $e'); }

    BackgroundService.stop();
    await _fcmTokenRefreshSubscription?.cancel();
    _fcmTokenRefreshSubscription = null;

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
    if (kIsWeb) return;
    await _fcmTokenRefreshSubscription?.cancel();
    _fcmTokenRefreshSubscription = null;
    try {
      final String? fcmToken = await PushNotificationService.getToken();
      if (fcmToken != null) {
        ref.read(webSocketClientProvider).request(
              'register_fcm_token',
              payload: {
                'fcm_token': fcmToken,
                'platform': Platform.isAndroid ? 'android' : 'ios',
              },
            );
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Failed to register FCM token: $e');
    }

    _fcmTokenRefreshSubscription = PushNotificationService.onTokenRefresh.listen((newToken) {
      ref.read(webSocketClientProvider).request(
            'register_fcm_token',
            payload: {
              'fcm_token': newToken,
              'platform': Platform.isAndroid ? 'android' : 'ios',
            },
          );
    });
  }

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
