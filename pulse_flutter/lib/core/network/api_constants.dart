import 'package:flutter/foundation.dart';

class ApiConstants {
  const ApiConstants._();

  static const String origin = 'https://ni-os.ru';
  static String get baseUrl => '$devProxyOrigin/api/v1';

  static String get devProxyOrigin {
    if (kIsWeb) {
      final String originStr = Uri.base.origin;
      if (originStr.isNotEmpty &&
          originStr != 'null' &&
          !originStr.startsWith('file:') &&
          (originStr.contains('localhost') || originStr.contains('127.0.0.1'))) {
        return originStr;
      }
    }
    return origin;
  }

  // OAuth 2.0 PKCE & Central Identity Constants
  static String get clientId => kIsWeb ? 'niosmess_web' : 'niosmess_native';
  static String get redirectUri {
    if (kIsWeb) {
      final String originStr = Uri.base.origin;
      if (originStr.isNotEmpty && originStr != 'null' && !originStr.startsWith('file:')) {
        return '$originStr/web';
      }
    }
    return '$origin/web';
  }
  static const String scopes = 'openid profile email';
  static const String oauthAuthorizeUrl = '$origin/oauth/authorize';
  static String get oauthTokenUrl => '$devProxyOrigin/oauth/token';
  static String get oauthDeviceCodeUrl => '$devProxyOrigin/oauth/device/code';
  static String get accountCheckUrl => '$devProxyOrigin/id/api/v1/account';
  static String get centralLogoutUrl => '$devProxyOrigin/id/api/v1/logout';

  static String resolve(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final String raw = url.trim();
    if (raw.startsWith('http')) {
      if (kIsWeb && (raw.startsWith('https://ni-os.ru') || raw.startsWith('http://ni-os.ru'))) {
        return raw.replaceFirst(RegExp(r'https?://ni-os\.ru'), devProxyOrigin);
      }
      return raw;
    }
    return '$devProxyOrigin${raw.startsWith('/') ? '' : '/'}$raw';
  }
}
