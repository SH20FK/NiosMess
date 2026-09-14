import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

enum NetworkType {
  wifi,
  cellular,
  other,
  none,
}

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final Connectivity connectivity = Connectivity();

  // Initial state — true = connected, false = disconnected
  final List<ConnectivityResult> initialResult = await connectivity.checkConnectivity();
  yield !initialResult.contains(ConnectivityResult.none);

  // Stream state
  await for (final List<ConnectivityResult> result in connectivity.onConnectivityChanged) {
    yield !result.contains(ConnectivityResult.none);
  }
});

final networkTypeProvider = StreamProvider<NetworkType>((ref) async* {
  final Connectivity connectivity = Connectivity();

  NetworkType mapResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      return NetworkType.none;
    }
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return NetworkType.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return NetworkType.cellular;
    }
    return NetworkType.other;
  }

  final List<ConnectivityResult> initialResult = await connectivity.checkConnectivity();
  yield mapResults(initialResult);

  await for (final List<ConnectivityResult> result in connectivity.onConnectivityChanged) {
    yield mapResults(result);
  }
});

/// Reactive provider indicating if automatic media downloading is allowed
/// based on the current network connection and user settings.
final autoDownloadAllowedProvider = Provider<bool>((ref) {
  final UiSettingsState settings = ref.watch(uiSettingsProvider);
  final NetworkType netType = ref.watch(networkTypeProvider).value ?? NetworkType.wifi;
  if (netType == NetworkType.wifi || netType == NetworkType.other) {
    return settings.autoDownloadWifi;
  } else if (netType == NetworkType.cellular) {
    return settings.autoDownloadCellular;
  }
  return false;
});

