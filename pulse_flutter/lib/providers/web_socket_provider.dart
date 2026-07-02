import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

final Provider<WebSocketClient> webSocketClientProvider = Provider<WebSocketClient>((Ref ref) {
  const String fromDefine = String.fromEnvironment('API_BASE_URL');
  final String selectedBase = fromDefine.trim().isEmpty
      ? ApiConstants.baseUrl
      : fromDefine.trim();

  final String normalizedBase = selectedBase.endsWith('/')
      ? selectedBase.substring(0, selectedBase.length - 1)
      : selectedBase;

  final WebSocketClient client = WebSocketClient(
    baseUrl: normalizedBase,
    readToken: () => ref.read(authTokenProvider),
    onUnauthorized: () {
      ref.read(authProvider.notifier).logout();
    },
  );

  ref.onDispose(() {
    client.close();
  });

  return client;
});
