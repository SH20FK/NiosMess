import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/core/services/biometric_service.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';

const String _appLockEnabledKey = 'app_lock.enabled';
const String _appLockTimeoutKey = 'app_lock.timeout';
const String _legacyBiometricEnabledKey = 'biometric.enabled';

class AppLockNotifier extends Notifier<AppLockState> {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  AppLockState build() {
    _init();
    return const AppLockState();
  }

  BiometricService get _biometricService => ref.read(biometricServiceProvider);

  Future<void> _init() async {
    final bool supported = await _biometricService.canCheckBiometrics;
    
    // Check modern key or fallback to legacy biometric.enabled
    String? enabledVal = await _storage.read(key: _appLockEnabledKey);
    if (enabledVal == null) {
      final String? legacyVal = await _storage.read(key: _legacyBiometricEnabledKey);
      if (legacyVal != null) {
        enabledVal = legacyVal;
        await _storage.write(key: _appLockEnabledKey, value: legacyVal);
      }
    }
    final bool isEnabled = enabledVal == 'true';

    final String? timeoutVal = await _storage.read(key: _appLockTimeoutKey);
    final AppLockTimeout timeout = AppLockTimeout.fromString(timeoutVal);

    // If enabled, lock initially on startup
    state = state.copyWith(
      isEnabled: isEnabled,
      timeout: timeout,
      isSupported: supported,
      isLocked: isEnabled,
    );
  }

  void onAppBackgrounded() {
    if (!state.isEnabled) return;
    state = state.copyWith(
      lastBackgroundedAt: DateTime.now(),
    );
  }

  void onAppResumed() {
    if (!state.isEnabled) return;
    final DateTime? bgTime = state.lastBackgroundedAt;
    if (bgTime == null) return;

    final Duration elapsed = DateTime.now().difference(bgTime);
    if (state.timeout == AppLockTimeout.immediately ||
        elapsed >= state.timeout.duration) {
      state = state.copyWith(isLocked: true);
    }
  }

  Future<bool> setEnabled(bool enabled, {String? authReason}) async {
    // Changing lock status requires authentication for security
    final bool authenticated = await _biometricService.authenticate(
      reason: authReason ?? 'Подтвердите личность для изменения блокировки приложения',
    );
    if (!authenticated) return false;

    await _storage.write(key: _appLockEnabledKey, value: enabled.toString());
    await _biometricService.setBiometricEnabled(enabled);

    state = state.copyWith(
      isEnabled: enabled,
      isLocked: false,
      clearLastBackgroundedAt: true,
    );
    return true;
  }

  Future<void> setTimeout(AppLockTimeout timeout) async {
    await _storage.write(key: _appLockTimeoutKey, value: timeout.name);
    state = state.copyWith(timeout: timeout);
  }

  Future<bool> authenticateAndUnlock({String? reason}) async {
    if (state.isAuthenticating) return false;
    state = state.copyWith(isAuthenticating: true);
    try {
      final bool authenticated = await _biometricService.authenticate(
        reason: reason ?? 'Разблокируйте NiosMess',
      );
      if (authenticated) {
        state = state.copyWith(
          isLocked: false,
          clearLastBackgroundedAt: true,
          isAuthenticating: false,
        );
        return true;
      }
    } finally {
      if (state.isAuthenticating) {
        state = state.copyWith(isAuthenticating: false);
      }
    }
    return false;
  }

  void lockManually() {
    if (!state.isEnabled) return;
    state = state.copyWith(isLocked: true);
  }
}

final NotifierProvider<AppLockNotifier, AppLockState> appLockProvider =
    NotifierProvider<AppLockNotifier, AppLockState>(AppLockNotifier.new);
