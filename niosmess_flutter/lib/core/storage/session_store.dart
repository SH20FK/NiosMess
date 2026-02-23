import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Secure session storage using FlutterSecureStorage
/// Tokens are encrypted at rest to prevent theft
class SessionStore {
  static const _key = 'session';
  static final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Save session securely (encrypts token)
  static Future<void> save(Map<String, dynamic> session) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(session));
      debugPrint('Session saved securely');
    } catch (e) {
      debugPrint('Error saving session: $e');
      rethrow;
    }
  }

  /// Load session from secure storage
  static Future<Map<String, dynamic>?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading session: $e');
      return null;
    }
  }

  /// Clear session securely
  static Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
      debugPrint('Session cleared');
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }

  /// Delete all secure storage (use with caution)
  static Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('All secure storage cleared');
    } catch (e) {
      debugPrint('Error clearing all storage: $e');
    }
  }
}
