import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/nios_ui.dart';

ThemeData buildNiosTheme(NiosThemePreset preset) {
  NiosPalette.apply(preset);
  final isLight = preset.id == 'light' || preset.id == 'teal';
  final baseTextTheme = GoogleFonts.interTextTheme();
  return ThemeData(
    brightness: isLight ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: NiosPalette.background,
    colorScheme: (isLight
            ? const ColorScheme.light()
            : const ColorScheme.dark())
        .copyWith(
      primary: NiosPalette.accent,
      secondary: NiosPalette.accentHover,
      surface: NiosPalette.surface,
    ),
    cardColor: NiosPalette.surface,
    textTheme: baseTextTheme.copyWith(
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: NiosPalette.text),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: NiosPalette.textSecondary),
      titleMedium: baseTextTheme.titleMedium?.copyWith(color: NiosPalette.text, fontWeight: FontWeight.w600),
      titleLarge: baseTextTheme.titleLarge?.copyWith(color: NiosPalette.text, fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: NiosPalette.text,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: NiosPalette.surface,
      contentTextStyle: TextStyle(color: NiosPalette.text),
    ),
    useMaterial3: true,
  );
}
