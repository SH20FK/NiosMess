import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService();

  final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _enabledKey = 'biometric.enabled';

  Future<bool> get isBiometricEnabled async {
    final String? value = await _storage.read(key: _enabledKey);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool value) async {
    await _storage.write(key: _enabledKey, value: value.toString());
  }

  Future<bool> get isDeviceSupported async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  Future<bool> get canCheckBiometrics async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Подтвердите личность'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticateIfEnabled() async {
    if (!await isBiometricEnabled) return true;
    return authenticate();
  }
}

final Provider<BiometricService> biometricServiceProvider =
    Provider<BiometricService>((Ref ref) => BiometricService());
