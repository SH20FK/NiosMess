import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

enum NetworkType {
  wifi,
  cellular,
  other,
  none,
}

bool _isConnected(List<ConnectivityResult> results) {
  if (kIsWeb) return true;
  final bool hasActive = results.any((r) => r != ConnectivityResult.none);
  if (hasActive) return true;
  // On desktop, fallback to true if results are empty or indeterminate
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    return results.isEmpty;
  }
  return false;
}

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final Connectivity connectivity = Connectivity();

  // Initial state — true = connected, false = disconnected
  final List<ConnectivityResult> initialResult = await connectivity.checkConnectivity();
  yield _isConnected(initialResult);

  // Stream state
  await for (final List<ConnectivityResult> result in connectivity.onConnectivityChanged) {
    yield _isConnected(result);
  }
});

final networkTypeProvider = StreamProvider<NetworkType>((ref) async* {
  final Connectivity connectivity = Connectivity();

  NetworkType mapResults(List<ConnectivityResult> results) {
    final bool hasActive = results.any((r) => r != ConnectivityResult.none);
    if (!hasActive) {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux)) {
        return NetworkType.other;
      }
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

