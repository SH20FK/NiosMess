import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

/// Combined app-level connection state for UI (banner, indicators).
enum AppConnectionState {
  /// Device online and WS session fully established.
  online,

  /// Device claims to be online, but the WS session is (re)connecting.
  reconnecting,

  /// No network at the device level, or the server is unreachable.
  offline,
}

/// Device adapter state (wifi/cellular/ethernet) — true = has an adapter up.
/// NOTE: this does NOT guarantee real internet access.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final Connectivity connectivity = Connectivity();

  final List<ConnectivityResult> initialResult =
      await connectivity.checkConnectivity();
  yield !initialResult.contains(ConnectivityResult.none);

  await for (final List<ConnectivityResult> result
      in connectivity.onConnectivityChanged) {
    yield !result.contains(ConnectivityResult.none);
  }
});

/// Real WS session state (connected / connecting / reconnecting / offline).
final wsConnectionStateProvider = StreamProvider<WsConnectionState>((ref) {
  final WebSocketClient client = ref.watch(webSocketClientProvider);
  final StreamController<WsConnectionState> controller =
      StreamController<WsConnectionState>();

  // Seed with current state so new listeners don't wait for the next change.
  controller.add(client.state);
  final StreamSubscription<WsConnectionState> sub =
      client.stateStream.listen(controller.add);

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Combines the device adapter state with the real WS session state.
/// This is what the offline banner should watch.
final appConnectionStateProvider = Provider<AppConnectionState>((ref) {
  final bool deviceOnline = ref.watch(connectivityProvider).value ?? true;
  final WsConnectionState wsState =
      ref.watch(wsConnectionStateProvider).value ?? WsConnectionState.connecting;

  if (!deviceOnline) return AppConnectionState.offline;

  switch (wsState) {
    case WsConnectionState.connected:
      return AppConnectionState.online;
    case WsConnectionState.connecting:
    case WsConnectionState.reconnecting:
      return AppConnectionState.reconnecting;
    case WsConnectionState.offline:
      return AppConnectionState.offline;
  }
});
