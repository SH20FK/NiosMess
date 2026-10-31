import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';

String? _cachedToken;

Map<String, String> cachedAuthHeaders(String? destinationUrl) {
  if (_cachedToken == null ||
      _cachedToken!.isEmpty ||
      !ApiConstants.isAuthenticatedMediaUrl(destinationUrl)) {
    return const {};
  }
  return {'Authorization': 'Bearer $_cachedToken'};
}

/// Isolate protected image entries by account without persisting credentials.
String? accountScopedAvatarCacheKey(String url, int? accountId) {
  if (!ApiConstants.isAuthenticatedMediaUrl(url)) return null;
  return 'avatar-v1:${accountId ?? 'anonymous'}:$url';
}

class SessionAccessTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setToken(String? token) {
    state = token;
    _cachedToken = token;
  }

  void clear() {
    state = null;
    _cachedToken = null;
  }
}

/// Canonical provider for user session access token.
/// Distinct from AI quota/character limits to eliminate naming drift.
final NotifierProvider<SessionAccessTokenNotifier, String?>
sessionAccessTokenProvider =
    NotifierProvider<SessionAccessTokenNotifier, String?>(
      SessionAccessTokenNotifier.new,
    );

/// Backward-compatibility alias for [sessionAccessTokenProvider].
final NotifierProvider<SessionAccessTokenNotifier, String?> authTokenProvider =
    sessionAccessTokenProvider;

/// Backward-compatibility type alias for [SessionAccessTokenNotifier].
typedef AuthTokenNotifier = SessionAccessTokenNotifier;
