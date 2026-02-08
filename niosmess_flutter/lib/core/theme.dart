import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/nios_ui.dart';

/// Telegram-style theme with Material 3 and 120Hz smooth animations
ThemeData buildNiosTheme(NiosThemePreset preset) {
  NiosPalette.apply(preset);
  final isLight = preset.id == 'light' || preset.id == 'teal';
  final baseTextTheme = GoogleFonts.interTextTheme();
  
  // Material 3 ColorScheme
  final colorScheme = ColorScheme(
    brightness: isLight ? Brightness.light : Brightness.dark,
    primary: NiosPalette.accent,
    onPrimary: Colors.white,
    primaryContainer: NiosPalette.accent.withValues(alpha: 0.15),
    onPrimaryContainer: NiosPalette.accent,
    secondary: NiosPalette.accentHover,
    onSecondary: Colors.white,
    secondaryContainer: NiosPalette.accentHover.withValues(alpha: 0.15),
    onSecondaryContainer: NiosPalette.accentHover,
    surface: NiosPalette.surface,
    onSurface: NiosPalette.text,
    surfaceContainerHighest: NiosPalette.surfaceAlt,
    onSurfaceVariant: NiosPalette.textSecondary,
    outline: NiosPalette.border,
    outlineVariant: NiosPalette.borderLight,
    shadow: NiosPalette.shadow,
    scrim: NiosPalette.shadow.withValues(alpha: 0.8),
    inverseSurface: isLight ? NiosPalette.text : NiosPalette.surfaceAlt,
    onInverseSurface: isLight ? Colors.white : NiosPalette.text,
    inversePrimary: NiosPalette.accentLight,
    surfaceTint: NiosPalette.accent.withValues(alpha: 0.05),
    error: const Color(0xFFE53935),
    onError: Colors.white,
    errorContainer: const Color(0xFFFFCDD2),
    onErrorContainer: const Color(0xFFB71C1C),
    tertiary: NiosPalette.accentLight,
    onTertiary: Colors.white,
    tertiaryContainer: NiosPalette.accentLight.withValues(alpha: 0.15),
    onTertiaryContainer: NiosPalette.accentLight,
  );
  
  return ThemeData(
    brightness: isLight ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: NiosPalette.background,
    colorScheme: colorScheme,
    cardColor: NiosPalette.surface,
    
    // Material 3 Typography with improved readability
    textTheme: baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        color: NiosPalette.text,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        fontSize: 57,
        height: 1.12,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        color: NiosPalette.text,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        fontSize: 45,
        height: 1.16,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        color: NiosPalette.text,
        fontWeight: FontWeight.w600,
        fontSize: 36,
        height: 1.22,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        color: NiosPalette.text,
        fontWeight: FontWeight.w600,
        fontSize: 32,
        height: 1.25,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: NiosPalette.text,
        fontWeight: FontWeight.w600,
        fontSize: 28,
        height: 1.29,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: NiosPalette.text,
        fontWeight: FontWeight.w600,
        fontSize: 24,
        height: 1.33,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: NiosPalette.text, 
        fontWeight: FontWeight.w600,
        fontSize: 22,
        letterSpacing: -0.2,
        height: 1.27,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: NiosPalette.text, 
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        color: NiosPalette.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: NiosPalette.text,
        fontSize: 16,
        height: 1.5,
        letterSpacing: 0.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: NiosPalette.text,
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.25,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: NiosPalette.textSecondary,
        fontSize: 12,
        height: 1.33,
        letterSpacing: 0.4,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        color: NiosPalette.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        color: NiosPalette.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        color: NiosPalette.textTertiary,
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 0.5,
        height: 1.45,
      ),
    ),
    
    // Telegram-style AppBar - clean and minimal
    appBarTheme: AppBarTheme(
      backgroundColor: NiosPalette.surface,
      foregroundColor: NiosPalette.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      ),
      titleTextStyle: baseTextTheme.titleLarge?.copyWith(
        color: NiosPalette.text,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
      toolbarHeight: 56,
      iconTheme: IconThemeData(
        color: NiosPalette.text,
        size: 24,
      ),
      actionsIconTheme: IconThemeData(
        color: NiosPalette.textSecondary,
        size: 24,
      ),
    ),
    
    // Material 3 Card theme
    cardTheme: CardThemeData(
      color: NiosPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: NiosPalette.border, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),
    
    // List tile theme - compact Telegram style
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minLeadingWidth: 48,
      minVerticalPadding: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      iconColor: NiosPalette.textSecondary,
      textColor: NiosPalette.text,
      titleTextStyle: baseTextTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      subtitleTextStyle: baseTextTheme.bodyMedium?.copyWith(
        color: NiosPalette.textSecondary,
        fontSize: 14,
      ),
    ),
    
    // Input decoration - clean Telegram style with Material 3
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NiosPalette.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: NiosPalette.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      hintStyle: TextStyle(
        color: NiosPalette.textTertiary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      labelStyle: TextStyle(
        color: NiosPalette.textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      floatingLabelStyle: TextStyle(
        color: NiosPalette.accent,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    
    // Material 3 Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NiosPalette.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.1,
        ),
        minimumSize: const Size(64, 40),
      ),
    ),
    
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NiosPalette.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.1,
        ),
        minimumSize: const Size(64, 40),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NiosPalette.accent,
        side: BorderSide(color: NiosPalette.border, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.1,
        ),
        minimumSize: const Size(64, 40),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NiosPalette.accent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.1,
        ),
        minimumSize: const Size(48, 36),
      ),
    ),
    
    // Icon button theme
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: NiosPalette.textSecondary,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(40, 40),
      ),
    ),
    
    // Icon theme
    iconTheme: IconThemeData(
      color: NiosPalette.textSecondary,
      size: 24,
    ),
    
    // Divider theme
    dividerTheme: DividerThemeData(
      color: NiosPalette.border,
      thickness: 0.5,
      space: 1,
      indent: 0,
      endIndent: 0,
    ),
    
    // Snackbar theme - floating with rounded corners
    snackBarTheme: SnackBarThemeData(
      backgroundColor: NiosPalette.surface,
      contentTextStyle: TextStyle(
        color: NiosPalette.text,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: NiosPalette.border, width: 0.5),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      actionTextColor: NiosPalette.accent,
    ),
    
    // Dialog theme
    dialogTheme: DialogThemeData(
      backgroundColor: NiosPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: NiosPalette.border, width: 0.5),
      ),
      titleTextStyle: baseTextTheme.headlineSmall?.copyWith(
        color: NiosPalette.text,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
        color: NiosPalette.textSecondary,
      ),
    ),
    
    // Bottom sheet theme
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: NiosPalette.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      modalBackgroundColor: NiosPalette.surface,
      modalElevation: 0,
      clipBehavior: Clip.antiAlias,
    ),
    
    // Page transitions - 120Hz smooth animations
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    ),
    
    // Ripple and splash effects - subtle and smooth
    splashColor: NiosPalette.accent.withValues(alpha: 0.08),
    highlightColor: NiosPalette.accent.withValues(alpha: 0.04),
    hoverColor: NiosPalette.accent.withValues(alpha: 0.02),
    focusColor: NiosPalette.accent.withValues(alpha: 0.08),
    
    // Material 3 specific
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    
    // Scrollbar theme
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(NiosPalette.textTertiary.withValues(alpha: 0.4)),
      trackColor: WidgetStateProperty.all(Colors.transparent),
      thickness: WidgetStateProperty.all(4),
      radius: const Radius.circular(4),
      minThumbLength: 48,
      crossAxisMargin: 2,
      mainAxisMargin: 2,
    ),
    
    // Chip theme
    chipTheme: ChipThemeData(
      backgroundColor: NiosPalette.surfaceAlt,
      disabledColor: NiosPalette.surfaceAlt.withValues(alpha: 0.5),
      selectedColor: NiosPalette.accent.withValues(alpha: 0.15),
      secondarySelectedColor: NiosPalette.accent.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: NiosPalette.border, width: 0.5),
      ),
      labelStyle: baseTextTheme.labelLarge?.copyWith(
        color: NiosPalette.text,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: baseTextTheme.labelLarge?.copyWith(
        color: NiosPalette.accent,
        fontWeight: FontWeight.w500,
      ),
      iconTheme: IconThemeData(
        color: NiosPalette.textSecondary,
        size: 18,
      ),
    ),
    
    // Badge theme
    badgeTheme: BadgeThemeData(
      backgroundColor: NiosPalette.accent,
      textColor: Colors.white,
      smallSize: 6,
      largeSize: 16,
      textStyle: baseTextTheme.labelSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    
    // Tooltip theme
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: NiosPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NiosPalette.border, width: 0.5),
      ),
      textStyle: baseTextTheme.bodySmall?.copyWith(
        color: NiosPalette.text,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.all(8),
      waitDuration: const Duration(milliseconds: 500),
      showDuration: const Duration(seconds: 3),
    ),
    
    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return NiosPalette.accent;
        }
        return NiosPalette.surfaceAlt;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return NiosPalette.accent.withValues(alpha: 0.5);
        }
        return NiosPalette.border;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    
    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return NiosPalette.accent;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: BorderSide(color: NiosPalette.border, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    
    // Radio theme
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return NiosPalette.accent;
        }
        return NiosPalette.border;
      }),
    ),
    
    // Slider theme
    sliderTheme: SliderThemeData(
      activeTrackColor: NiosPalette.accent,
      inactiveTrackColor: NiosPalette.border,
      thumbColor: NiosPalette.accent,
      overlayColor: NiosPalette.accent.withValues(alpha: 0.12),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
    ),
    
    // Progress indicator theme
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: NiosPalette.accent,
      linearTrackColor: NiosPalette.border,
      circularTrackColor: NiosPalette.border,
      refreshBackgroundColor: NiosPalette.surface,
    ),
    
    // Floating action button theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: NiosPalette.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      sizeConstraints: const BoxConstraints.tightFor(width: 56, height: 56),
      smallSizeConstraints: const BoxConstraints.tightFor(width: 40, height: 40),
    ),
    
    // Navigation bar theme
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NiosPalette.surface,
      elevation: 0,
      height: 80,
      indicatorColor: NiosPalette.accent.withValues(alpha: 0.15),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return baseTextTheme.labelMedium?.copyWith(
            color: NiosPalette.accent,
            fontWeight: FontWeight.w600,
          );
        }
        return baseTextTheme.labelMedium?.copyWith(
          color: NiosPalette.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(
            color: NiosPalette.accent,
            size: 24,
          );
        }
        return IconThemeData(
          color: NiosPalette.textSecondary,
          size: 24,
        );
      }),
    ),
    
    // Navigation rail theme
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: NiosPalette.surface,
      elevation: 0,
      indicatorColor: NiosPalette.accent.withValues(alpha: 0.15),
      selectedIconTheme: IconThemeData(
        color: NiosPalette.accent,
        size: 24,
      ),
      unselectedIconTheme: IconThemeData(
        color: NiosPalette.textSecondary,
        size: 24,
      ),
      selectedLabelTextStyle: baseTextTheme.labelMedium?.copyWith(
        color: NiosPalette.accent,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: baseTextTheme.labelMedium?.copyWith(
        color: NiosPalette.textSecondary,
      ),
    ),
    
    // Tab bar theme
    tabBarTheme: TabBarThemeData(
      dividerColor: NiosPalette.border,
      indicatorColor: NiosPalette.accent,
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: NiosPalette.accent,
      unselectedLabelColor: NiosPalette.textSecondary,
      labelStyle: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: NiosPalette.accent, width: 2),
      ),
    ),
  );
}

/// Extension for 120Hz smooth animation curves
class NiosAnimations {
  // 120Hz optimized curves for smooth 60-120fps animations
  static const Curve easeOutExpo = Cubic(0.16, 1, 0.3, 1);
  static const Curve easeInExpo = Cubic(0.7, 0, 0.84, 0);
  static const Curve easeOutBack = Cubic(0.34, 1.56, 0.64, 1);
  static const Curve easeInOutQuint = Cubic(0.83, 0, 0.17, 1);
  static const Curve easeOutQuart = Cubic(0.25, 1, 0.5, 1);
  static const Curve easeOutQuint = Cubic(0.22, 1, 0.36, 1);
  
  // Standard durations optimized for 120Hz
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration verySlow = Duration(milliseconds: 500);
  
  // Stagger delays
  static const Duration staggerFast = Duration(milliseconds: 25);
  static const Duration staggerNormal = Duration(milliseconds: 40);
  static const Duration staggerSlow = Duration(milliseconds: 60);
}
