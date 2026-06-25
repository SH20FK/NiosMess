import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setToken(String? token) => state = token;

  void clear() => state = null;
}

final NotifierProvider<AuthTokenNotifier, String?> authTokenProvider =
    NotifierProvider<AuthTokenNotifier, String?>(AuthTokenNotifier.new);
