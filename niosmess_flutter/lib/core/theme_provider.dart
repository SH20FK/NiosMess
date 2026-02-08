import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/nios_ui.dart';

const _themeKey = 'nios_theme_id';

class ThemeState {
  const ThemeState({required this.preset});
  final NiosThemePreset preset;
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController() : super(ThemeState(preset: niosThemePresets.first)) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_themeKey);
    if (id == null) return;
    final preset = niosThemePresets.firstWhere(
      (p) => p.id == id,
      orElse: () => niosThemePresets.first,
    );
    state = ThemeState(preset: preset);
  }

  Future<void> setTheme(String id) async {
    final preset = niosThemePresets.firstWhere(
      (p) => p.id == id,
      orElse: () => niosThemePresets.first,
    );
    state = ThemeState(preset: preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, preset.id);
  }
}

final themeProvider = StateNotifierProvider<ThemeController, ThemeState>((ref) {
  return ThemeController();
});
