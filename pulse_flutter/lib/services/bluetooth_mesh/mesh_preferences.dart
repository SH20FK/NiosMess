import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool get meshPlatformSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows);

class MeshPreference extends Notifier<bool> {
  static const key = 'niosmess.bluetooth_fallback.v1';
  int _generation = 0;
  Future<void> _loading = Future.value();
  Future<void> get loaded => _loading;
  bool hydrated = false;
  @override
  bool build() {
    final generation = ++_generation;
    if (!meshPlatformSupported) {
      hydrated = true;
      return false;
    }
    _loading = SharedPreferences.getInstance()
        .then((prefs) {
          if (ref.mounted && generation == _generation) {
            state = prefs.getBool(key) ?? true;
          }
        })
        .catchError((Object _) {
          /* Keep the default when local settings are unavailable. */
        })
        .whenComplete(() => hydrated = true);
    unawaited(_loading);
    return true;
  }

  Future<void> setEnabled(bool value) async {
    if (!meshPlatformSupported) return;
    _generation++;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(key, value)) {
      throw StateError('Не удалось сохранить настройку');
    }
    hydrated = true;
    if (ref.mounted) state = value;
  }
}

final meshPreferenceProvider = NotifierProvider<MeshPreference, bool>(
  MeshPreference.new,
);
