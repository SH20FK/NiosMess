import 'package:flutter/foundation.dart';

class ApiConstants {
  const ApiConstants._();

  static const String origin = 'https://ni-os.ru';
  static String get baseUrl => '$devProxyOrigin/api/v1';

  static String get devProxyOrigin {
    if (kIsWeb) {
      final base = Uri.base;
      if ((base.scheme == 'http' || base.scheme == 'https') &&
          const {'localhost', '127.0.0.1', '::1'}.contains(base.host)) {
        return base.origin;
      }
    }
    return origin;
  }

  // OAuth 2.0 PKCE & Central Identity Constants
  static String get clientId => kIsWeb ? 'niosmess_web' : 'niosmess_native';
  static String get redirectUri {
    if (kIsWeb) {
      final String originStr = Uri.base.origin;
      if (originStr.isNotEmpty &&
          originStr != 'null' &&
          !originStr.startsWith('file:')) {
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
    final raw = url.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.userInfo.isNotEmpty) return '';
    if (uri.hasScheme || uri.hasAuthority) {
      if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
        return '';
      }
      if (kIsWeb && sameOrigin(uri, Uri.parse(origin))) {
        final proxy = Uri.parse(devProxyOrigin);
        return uri
            .replace(scheme: proxy.scheme, host: proxy.host, port: proxy.port)
            .toString();
      }
      return raw;
    }
    return '$devProxyOrigin${raw.startsWith('/') ? '' : '/'}$raw';
  }

  /// Credentials are only valid for this exact HTTP origin, including its port.
  static bool sameOrigin(Uri destination, Uri trusted) =>
      (destination.scheme == 'http' || destination.scheme == 'https') &&
      destination.userInfo.isEmpty &&
      destination.host.isNotEmpty &&
      destination.scheme == trusted.scheme &&
      destination.host == trusted.host &&
      destination.port == trusted.port;

  static bool isAuthenticatedMediaUrl(String? url) {
    final resolved = resolve(url);
    final uri = Uri.tryParse(resolved);
    return resolved.isNotEmpty &&
        uri != null &&
        sameOrigin(uri, Uri.parse(devProxyOrigin));
  }
}
