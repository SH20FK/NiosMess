import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/services/biometric_service.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';

const String _appLockEnabledKey = 'app_lock.enabled';
const String _appLockTimeoutKey = 'app_lock.timeout';
const String _legacyBiometricEnabledKey = 'biometric.enabled';

class AppLockNotifier extends Notifier<AppLockState> {
  int _epoch = 0;
  FlutterSecureStorage get _storage => ref.read(appLockStorageProvider);
  bool get _supportedClient =>
      ref.mounted && !ref.read(clientCapabilitiesProvider).isWeb;
  bool _current(int epoch) => _supportedClient && epoch == _epoch;
  bool _ready(int epoch) =>
      _current(epoch) && !state.isInitializing && !state.hasInitializationError;

  @override
  AppLockState build() {
    final capabilities = ref.watch(clientCapabilitiesProvider);
    final epoch = ++_epoch;
    ref.onDispose(() {
      if (epoch == _epoch) _epoch++;
    });
    if (capabilities.isWeb) return const AppLockState(isSupported: false);
    unawaited(_init(epoch));
    return const AppLockState(isInitializing: true);
  }

  BiometricService get _biometricService => ref.read(biometricServiceProvider);

  Future<void> _init(int epoch) async {
    try {
      await _loadSettings(epoch);
    } catch (_) {
      if (_current(epoch)) {
        // A failed native settings read must not expose authenticated content.
        // Preserve any already known lock policy and leave the stored value.
        state = state.copyWith(
          isInitializing: false,
          hasInitializationError: true,
        );
      }
    }
  }

  Future<void> retryInit() async {
    if (!_supportedClient ||
        state.isInitializing ||
        !state.hasInitializationError) {
      return;
    }
    final epoch = ++_epoch;
    state = state.copyWith(isInitializing: true, hasInitializationError: false);
    await _init(epoch);
  }

  Future<void> _loadSettings(int epoch) async {
    final biometric = _biometricService;
    final storage = _storage;
    final bool supported = await biometric.canCheckBiometrics;
    if (!_current(epoch)) return;

    // Check modern key or fallback to legacy biometric.enabled
    String? enabledVal = await storage.read(key: _appLockEnabledKey);
    if (!_current(epoch)) return;
    if (enabledVal == null) {
      final String? legacyVal = await storage.read(
        key: _legacyBiometricEnabledKey,
      );
      if (!_current(epoch)) return;
      if (legacyVal != null) {
        enabledVal = legacyVal;
        await storage.write(key: _appLockEnabledKey, value: legacyVal);
        if (!_current(epoch)) return;
      }
    }
    final bool isEnabled = enabledVal == 'true';

    final String? timeoutVal = await storage.read(key: _appLockTimeoutKey);
    if (!_current(epoch)) return;
    final AppLockTimeout timeout = AppLockTimeout.fromString(timeoutVal);

    // If enabled, lock initially on startup
    state = state.copyWith(
      isEnabled: isEnabled,
      timeout: timeout,
      isSupported: supported,
      isLocked: isEnabled,
      isAuthenticating: false,
      isInitializing: false,
      hasInitializationError: false,
    );
  }

  void onAppBackgrounded() {
    if (!_ready(_epoch) || !state.isEnabled) return;
    state = state.copyWith(lastBackgroundedAt: DateTime.now());
  }

  void onAppResumed() {
    if (!_ready(_epoch) || !state.isEnabled) return;
    final DateTime? bgTime = state.lastBackgroundedAt;
    if (bgTime == null) return;

    final Duration elapsed = DateTime.now().difference(bgTime);
    if (state.timeout == AppLockTimeout.immediately ||
        elapsed >= state.timeout.duration) {
      state = state.copyWith(isLocked: true);
    }
  }

  Future<bool> setEnabled(bool enabled, {String? authReason}) async {
    final epoch = _epoch;
    if (!_ready(epoch)) return false;
    final biometric = _biometricService;
    final storage = _storage;
    // Changing lock status requires authentication for security
    final bool authenticated = await biometric.authenticate(
      reason:
          authReason ??
          'Подтвердите личность для изменения блокировки приложения',
    );
    if (!_current(epoch) || !authenticated) return false;

    await storage.write(key: _appLockEnabledKey, value: enabled.toString());
    if (!_current(epoch)) return false;
    await biometric.setBiometricEnabled(enabled);
    if (!_current(epoch)) return false;

    state = state.copyWith(
      isEnabled: enabled,
      isLocked: false,
      clearLastBackgroundedAt: true,
    );
    return true;
  }

  Future<void> setTimeout(AppLockTimeout timeout) async {
    final epoch = _epoch;
    if (!_ready(epoch)) return;
    await _storage.write(key: _appLockTimeoutKey, value: timeout.name);
    if (!_current(epoch)) return;
    state = state.copyWith(timeout: timeout);
  }

  Future<bool> authenticateAndUnlock({String? reason}) async {
    final epoch = _epoch;
    if (!_ready(epoch) || state.isAuthenticating) return false;
    final biometric = _biometricService;
    state = state.copyWith(isAuthenticating: true);
    try {
      final bool authenticated = await biometric.authenticate(
        reason: reason ?? 'Разблокируйте NiosMess',
      );
      if (!_current(epoch)) return false;
      if (authenticated) {
        state = state.copyWith(
          isLocked: false,
          clearLastBackgroundedAt: true,
          isAuthenticating: false,
        );
        return true;
      }
    } finally {
      if (_current(epoch) && state.isAuthenticating) {
        state = state.copyWith(isAuthenticating: false);
      }
    }
    return false;
  }

  void lockManually() {
    if (!_ready(_epoch) || !state.isEnabled) return;
    state = state.copyWith(isLocked: true);
  }
}

final appLockStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final NotifierProvider<AppLockNotifier, AppLockState> appLockProvider =
    NotifierProvider<AppLockNotifier, AppLockState>(AppLockNotifier.new);
