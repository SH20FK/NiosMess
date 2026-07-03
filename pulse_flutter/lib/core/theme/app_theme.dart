import 'package:flutter/material.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static final Map<int, ThemeData> _themeCache = {};

  static DynamicSchemeVariant _variant(Md3Variant variant) {
    return switch (variant) {
      Md3Variant.tonalSpot => DynamicSchemeVariant.tonalSpot,
      Md3Variant.vibrant => DynamicSchemeVariant.vibrant,
      Md3Variant.expressive => DynamicSchemeVariant.expressive,
      Md3Variant.neutral => DynamicSchemeVariant.neutral,
      Md3Variant.monochrome => DynamicSchemeVariant.monochrome,
      Md3Variant.fidelity => DynamicSchemeVariant.fidelity,
    };
  }

  static ColorScheme _scheme(UiSettingsState settings, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: settings.seedColor,
      brightness: brightness,
      dynamicSchemeVariant: _variant(settings.variant),
    );
  }

  static LinearGradient heroGradient(ColorScheme scheme) {
    final Color top = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.20),
      scheme.surface,
    );
    final Color mid = Color.alphaBlend(
      scheme.secondary.withValues(alpha: 0.09),
      scheme.surface,
    );
    final Color end = Color.alphaBlend(
      scheme.tertiary.withValues(alpha: 0.08),
      scheme.surface,
    );
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[top, mid, end],
    );
  }

  static ThemeData themed(UiSettingsState settings, Brightness brightness) {
    final int cacheKey = settings.seedColor.value ^ brightness.index ^ settings.variant.index ^ (settings.predictiveBackEnabled ? 1 : 0);
    final ThemeData? cached = _themeCache[cacheKey];
    if (cached != null) return cached;

    final ColorScheme scheme = _scheme(settings, brightness);
    final TextTheme textTheme = AppTypography.build(scheme);

    final ThemeData theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: const StadiumBorder(),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.96),
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: WidgetStateProperty.all<double>(0),
        backgroundColor: WidgetStateProperty.all<Color>(
          scheme.surfaceContainerHigh,
        ),
        surfaceTintColor: WidgetStateProperty.all<Color>(Colors.transparent),
        padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
          const EdgeInsets.symmetric(horizontal: 14),
        ),
        shape: WidgetStateProperty.all<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        textStyle: WidgetStateProperty.all<TextStyle?>(textTheme.bodyLarge),
        hintStyle: WidgetStateProperty.all<TextStyle?>(
          textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      searchViewTheme: SearchViewThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        dividerColor: scheme.outlineVariant.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        headerTextStyle: textTheme.bodyLarge,
        headerHintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        iconColor: scheme.primary,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        modalBackgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.38),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          iconColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) => states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.38)
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
        refreshBackgroundColor: scheme.surfaceContainerHigh,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        textStyle: textTheme.labelSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow.withValues(alpha: 0.82),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          shape: WidgetStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          side: WidgetStateProperty.resolveWith<BorderSide?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return BorderSide(color: scheme.primary.withValues(alpha: 0.28));
            }
            return BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.22),
            );
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primaryContainer.withValues(alpha: 0.82);
            }
            return scheme.surfaceContainerLow.withValues(alpha: 0.72);
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onPrimaryContainer;
            }
            return scheme.onSurfaceVariant;
          }),
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: settings.predictiveBackEnabled
              ? const PredictiveBackPageTransitionsBuilder()
              : const CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: const CupertinoPageTransitionsBuilder(),
        },
      ),
    );
    if (_themeCache.length > 20) _themeCache.clear();
    _themeCache[cacheKey] = theme;
    return theme;
  }
}
