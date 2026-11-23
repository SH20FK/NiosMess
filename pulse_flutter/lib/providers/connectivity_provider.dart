import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/settings/auto_download.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

enum NetworkType { wifi, cellular, other, none }

bool _isConnected(List<ConnectivityResult> results) {
  final bool hasActive = results.any((r) => r != ConnectivityResult.none);
  if (hasActive) return true;
  if (kIsWeb) return results.isEmpty;
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
  final List<ConnectivityResult> initialResult = await connectivity
      .checkConnectivity();
  yield _isConnected(initialResult);

  // Stream state
  await for (final List<ConnectivityResult> result
      in connectivity.onConnectivityChanged) {
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

  final List<ConnectivityResult> initialResult = await connectivity
      .checkConnectivity();
  yield mapResults(initialResult);

  await for (final List<ConnectivityResult> result
      in connectivity.onConnectivityChanged) {
    yield mapResults(result);
  }
});

/// Reactive provider indicating if automatic media downloading is allowed
/// for [AutoDownloadMediaType] based on the current network connection and
/// the user settings for that media type.
final autoDownloadAllowedProvider =
    Provider.family<bool, AutoDownloadMediaType>((ref, type) {
      final bool wifiAllowed = ref.watch(
        uiSettingsProvider.select(
          (UiSettingsState s) =>
              s.autoDownloadFor(type, AutoDownloadNetwork.wifi),
        ),
      );
      if (kIsWeb) {
        return (ref.watch(connectivityProvider).value ?? true) && wifiAllowed;
      }
      final bool cellularAllowed = ref.watch(
        uiSettingsProvider.select(
          (UiSettingsState s) =>
              s.autoDownloadFor(type, AutoDownloadNetwork.cellular),
        ),
      );
      final NetworkType netType =
          ref.watch(networkTypeProvider).value ?? NetworkType.wifi;
      if (netType == NetworkType.wifi || netType == NetworkType.other) {
        return wifiAllowed;
      } else if (netType == NetworkType.cellular) {
        return cellularAllowed;
      }
      return false;
    });
