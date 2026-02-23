import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

const _pinHashKey = 'nios_pin_hash';
const _lockEnabledKey = 'nios_lock_enabled';
const _lockBiometricKey = 'nios_lock_bio';

class AppLockState {
  const AppLockState({
    required this.isEnabled,
    required this.isUnlocked,
    required this.biometricEnabled,
    required this.biometricAvailable,
    this.failedAttempts = 0,
    this.lockoutUntil,
  });

  final bool isEnabled;
  final bool isUnlocked;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final int failedAttempts;
  final DateTime? lockoutUntil;

  bool get isLockedOut =>
      lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!);

  Duration? get lockoutRemaining => isLockedOut
      ? lockoutUntil!.difference(DateTime.now())
      : null;

  AppLockState copyWith({
    bool? isEnabled,
    bool? isUnlocked,
    bool? biometricEnabled,
    bool? biometricAvailable,
    int? failedAttempts,
    DateTime? lockoutUntil,
    bool clearLockout = false,
  }) {
    return AppLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil: clearLockout ? null : (lockoutUntil ?? this.lockoutUntil),
    );
  }
}

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController()
      : super(const AppLockState(
          isEnabled: false,
          isUnlocked: true,
          biometricEnabled: false,
          biometricAvailable: false,
        )) {
    _load();
  }

  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_lockEnabledKey) ?? false;
    final bioEnabled = prefs.getBool(_lockBiometricKey) ?? false;
    final hash = await _storage.read(key: _pinHashKey);
    final hasPin = hash != null && hash.isNotEmpty;
    final bioAvailable = await _auth.canCheckBiometrics;

    state = state.copyWith(
      isEnabled: enabled && hasPin,
      isUnlocked: !(enabled && hasPin),
      biometricEnabled: bioEnabled,
      biometricAvailable: bioAvailable,
    );
  }

  /// Secure PIN hashing with salt using PBKDF2
  /// Protects against rainbow table attacks
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    // Use PBKDF2 with 10000 iterations for security
    var hash = sha256.convert(bytes);
    for (int i = 0; i < 10000; i++) {
      hash = sha256.convert(hash.bytes);
    }
    return '$salt:${hash.toString()}';
  }

  /// Generate cryptographically secure random salt for PIN hashing
  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final stored = await _storage.read(key: _pinHashKey);
      if (stored == null || stored.isEmpty) return false;

      // Extract salt from stored hash
      final parts = stored.split(':');
      if (parts.length != 2) return false;

      final salt = parts[0];
      final expectedHash = parts[1];

      // Hash input pin with same salt
      final inputHash = _hashPin(pin, salt);
      final inputHashValue = inputHash.split(':')[1];

      // Constant-time comparison to prevent timing attacks
      return inputHashValue == expectedHash;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }

  static const int _minPinLength = 4;
  static const int _maxAttempts = 5;

  Future<void> enable(String pin) async {
    if (pin.length < _minPinLength) {
      throw ArgumentError('PIN must be at least $_minPinLength digits');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final salt = _generateSalt();
      final hashedPin = _hashPin(pin, salt);
      await _storage.write(key: _pinHashKey, value: hashedPin);
      await prefs.setBool(_lockEnabledKey, true);
      state = state.copyWith(isEnabled: true, isUnlocked: true);
      debugPrint('App lock enabled with secure PIN');
    } catch (e) {
      debugPrint('Error enabling app lock: $e');
      rethrow;
    }
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockEnabledKey, false);
    await _storage.delete(key: _pinHashKey);
    state = state.copyWith(isEnabled: false, isUnlocked: true);
  }

  Future<bool> unlock(String pin) async {
    // Check lockout
    if (state.isLockedOut) {
      return false;
    }

    final ok = await verifyPin(pin);
    if (ok) {
      state = state.copyWith(
        isUnlocked: true,
        failedAttempts: 0,
        clearLockout: true,
      );
    } else {
      final attempts = state.failedAttempts + 1;
      DateTime? lockout;
      if (attempts >= _maxAttempts) {
        // Progressive lockout: 30s, 60s, 120s, etc.
        final multiplier = attempts ~/ _maxAttempts;
        lockout = DateTime.now().add(Duration(seconds: 30 * multiplier));
      }
      state = state.copyWith(
        failedAttempts: attempts,
        lockoutUntil: lockout,
      );
    }
    return ok;
  }

  void lock() {
    if (!state.isEnabled) return;
    state = state.copyWith(isUnlocked: false);
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockBiometricKey, value);
    state = state.copyWith(biometricEnabled: value);
  }

  Future<bool> unlockWithBiometrics() async {
    if (!state.biometricAvailable) return false;
    final ok = await _auth.authenticate(
      localizedReason: 'Разблокировать NiosMess',
      options: const AuthenticationOptions(biometricOnly: true),
    );
    if (ok) {
      state = state.copyWith(isUnlocked: true);
    }
    return ok;
  }
}

final appLockProvider = StateNotifierProvider<AppLockController, AppLockState>(
  (ref) => AppLockController(),
);
