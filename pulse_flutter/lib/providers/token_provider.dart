import 'package:flutter_riverpod/flutter_riverpod.dart';

String? _cachedToken;

Map<String, String> cachedAuthHeaders() {
  if (_cachedToken == null || _cachedToken!.isEmpty) return const {};
  return {'Authorization': 'Bearer $_cachedToken'};
}

class AuthTokenNotifier extends Notifier<String?> {
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

final NotifierProvider<AuthTokenNotifier, String?> authTokenProvider =
    NotifierProvider<AuthTokenNotifier, String?>(AuthTokenNotifier.new);
