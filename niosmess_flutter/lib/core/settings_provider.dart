import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage/offline_cache.dart';

class SettingsController extends StateNotifier<Map<String, dynamic>> {
  SettingsController() : super({}) {
    _load();
  }

  Future<void> _load() async {
    state = await OfflineCache.loadSettings();
  }

  Future<void> setSetting(String key, dynamic value) async {
    state = {...state, key: value};
    await OfflineCache.saveSettings(state);
  }
}

final settingsProvider = StateNotifierProvider<SettingsController, Map<String, dynamic>>(
  (ref) => SettingsController(),
);

