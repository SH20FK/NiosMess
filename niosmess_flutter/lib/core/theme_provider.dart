import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/nios_ui.dart';
import 'settings_provider.dart';

class ThemeState {
  const ThemeState({
    required this.mode,
    required this.seedColor,
    required this.useDynamicColor,
  });

  final ThemeMode mode;
  final Color seedColor;
  final bool useDynamicColor;

  ThemeState copyWith({
    ThemeMode? mode,
    Color? seedColor,
    bool? useDynamicColor,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    );
  }
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController(this.ref)
      : super(_fromSettings(ref.read(settingsProvider))) {
    ref.listen<Map<String, dynamic>>(settingsProvider, (prev, next) {
      final nextState = _fromSettings(next);
      if (nextState.mode != state.mode ||
          nextState.seedColor.value != state.seedColor.value ||
          nextState.useDynamicColor != state.useDynamicColor) {
        state = nextState;
      }
    });
  }

  final Ref ref;

  static ThemeState _fromSettings(Map<String, dynamic> settings) {
    final rawMode = settings['theme_mode']?.toString() ?? 'system';
    ThemeMode mode = ThemeMode.system;
    if (rawMode == 'light') mode = ThemeMode.light;
    if (rawMode == 'dark') mode = ThemeMode.dark;
    final seedValue = settings['seed_color'] as int? ?? 0xFF4F46E5;
    final dyn = settings['use_dynamic_color'] as bool? ?? false;
    return ThemeState(
      mode: mode,
      seedColor: Color(seedValue),
      useDynamicColor: dyn,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await ref.read(settingsProvider.notifier).setSetting('theme_mode', value);
  }

  Future<void> setSeedColor(Color color) async {
    await ref.read(settingsProvider.notifier).setSetting('seed_color', color.value);
  }

  Future<void> setUseDynamicColor(bool value) async {
    await ref.read(settingsProvider.notifier).setSetting('use_dynamic_color', value);
  }

  Future<void> setTheme(String id) async {
    final preset = niosThemePresets.firstWhere(
      (p) => p.id == id,
      orElse: () => niosThemePresets.first,
    );
    await setSeedColor(preset.accent);
  }
}

final themeProvider = StateNotifierProvider<ThemeController, ThemeState>(
  (ref) => ThemeController(ref),
);
