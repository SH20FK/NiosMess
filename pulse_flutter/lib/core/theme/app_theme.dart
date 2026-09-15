import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/pulse_predictive_back_transition.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

import 'app_typography.dart';
import 'expressive_tokens.dart';

class AppTheme {
  const AppTheme._();

  static final LinkedHashMap<int, ThemeData> _themeCache =
      LinkedHashMap<int, ThemeData>();

  static ColorScheme _scheme(
    VisualThemeSettings settings,
    Brightness brightness,
    double contrastLevel,
  ) {
    return ColorScheme.fromSeed(
      seedColor: settings.seedColor,
      brightness: brightness,
      dynamicSchemeVariant: settings.paletteStyle.variant,
      contrastLevel: contrastLevel,
    );
  }

  static LinearGradient heroGradient(ColorScheme scheme) {
    final Color top = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.06),
      scheme.surface,
    );
    final Color mid = scheme.surface;
    final Color end = Color.alphaBlend(
      scheme.tertiary.withValues(alpha: 0.04),
      scheme.surface,
    );
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[top, mid, end],
    );
  }

  static ThemeData themed(
    VisualThemeSettings settings,
    Brightness brightness, {
    ColorScheme? dynamicScheme,
    double contrastLevel = 0.0,
  }) {
    final bool isOled = settings.pureBlackOled && brightness == Brightness.dark;
    final int cacheKey = settings.seedColor.toARGB32() ^ 
                         brightness.index ^ 
                         (settings.themeMode.index << 8) ^ 
                         (settings.useSystemDynamic ? 1 : 0) ^
                         (settings.predictiveBackEnabled ? ((settings.predictiveBackStrength * 100).round() << 4) : 0) ^
                         (settings.pureBlackOled ? 4 : 0) ^
                         (settings.uiCornerRadius.round() << 12) ^
                         (settings.paletteStyle.index << 18) ^
                         ((contrastLevel * 100).round() << 21) ^
                         (dynamicScheme?.primary.toARGB32() ?? 0);
    final ThemeData? cached = _themeCache[cacheKey];
    if (cached != null) return cached;

    final ColorScheme baseScheme = (settings.useSystemDynamic && dynamicScheme != null)
        ? dynamicScheme
        : _scheme(settings, brightness, contrastLevel);
    final ColorScheme scheme = isOled
        ? baseScheme.copyWith(
            surface: const Color(0xFF000000),
            surfaceDim: const Color(0xFF000000),
            surfaceBright: const Color(0xFF141414),
            surfaceContainerLowest: const Color(0xFF000000),
            surfaceContainerLow: const Color(0xFF080808),
            surfaceContainer: const Color(0xFF101010),
            surfaceContainerHigh: const Color(0xFF161616),
            surfaceContainerHighest: const Color(0xFF202020),
            inverseSurface: const Color(0xFFE0E0E0),
            onInverseSurface: const Color(0xFF1A1A1A),
            scrim: const Color(0xFF000000),
          )
        : baseScheme;
    final TextTheme textTheme = AppTypography.build(scheme);

    final ThemeData theme = ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      colorScheme: scheme,
      scaffoldBackgroundColor: isOled ? const Color(0xFF000000) : scheme.surface,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        AppRadiiTheme.fromCornerRadius(settings.uiCornerRadius),
      ],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1.5,
        surfaceTintColor: scheme.surfaceContainer,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: const StadiumBorder(),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(settings.uiCornerRadius),
          ),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 2,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: textTheme.labelMedium,
        elevation: 0,
        pressElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.96),
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll<double>(0),
        backgroundColor: WidgetStatePropertyAll<Color>(
          scheme.surfaceContainerHigh,
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 14),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(
              settings.uiCornerRadius > 24 ? settings.uiCornerRadius : 28,
            ),
          ),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.bodyLarge),
        hintStyle: WidgetStatePropertyAll<TextStyle?>(
          textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      searchViewTheme: SearchViewThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        dividerColor: scheme.outlineVariant.withValues(alpha: 0.28),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(
            settings.uiCornerRadius > 24 ? settings.uiCornerRadius : 28,
          ),
        ),
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
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
        ),
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
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.38),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(settings.uiCornerRadius),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
        ),
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
        // ignore: deprecated_member_use
        year2023: false,
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
        refreshBackgroundColor: scheme.surfaceContainerHigh,
      ),
      sliderTheme: SliderThemeData(
        // ignore: deprecated_member_use
        year2023: false,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return scheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
        side: BorderSide(color: scheme.onSurfaceVariant, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.onSurfaceVariant;
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.22),
        space: 1,
        thickness: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: scheme.onInverseSurface),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        dividerColor: scheme.outlineVariant.withValues(alpha: 0.22),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(settings.uiCornerRadius),
          ),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
        ),
        headerBackgroundColor: scheme.surfaceContainerHigh,
        headerForegroundColor: scheme.onSurface,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(scheme.surfaceContainerHigh),
          elevation: const WidgetStatePropertyAll<double>(0),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(settings.uiCornerRadius),
            ),
          ),
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        textStyle: textTheme.labelSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
          borderSide: BorderSide(
            color: scheme.error,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
          borderSide: BorderSide(
            color: scheme.error,
            width: 1.8,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
          borderSide: BorderSide.none,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(settings.uiCornerRadius),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(settings.uiCornerRadius),
            ),
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
              return scheme.secondaryContainer.withValues(alpha: 0.82);
            }
            return scheme.surfaceContainerLow.withValues(alpha: 0.72);
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onSecondaryContainer;
            }
            return scheme.onSurfaceVariant;
          }),
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: settings.predictiveBackEnabled
              ? PulsePredictiveBackPageTransitionsBuilder(
                  strength: settings.predictiveBackStrength,
                )
              : const ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: const ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: const ZoomPageTransitionsBuilder(),
        },
      ),
    );
    _themeCache[cacheKey] = theme;
    while (_themeCache.length > 20) {
      _themeCache.remove(_themeCache.keys.first);
    }
    return theme;
  }
}
