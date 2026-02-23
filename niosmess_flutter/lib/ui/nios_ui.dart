import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// NIOSMESS Design System Colors - Exact from specification
class NiosColors {
  // Background colors (Aurora Glass)
  static const Color bgPrimary = Color(0xFF0A0F1E);
  static const Color bgSurface = Color(0xFF121A2A);
  static const Color bgSurfaceAlt = Color(0xFF1A2336);

  // Accent colors
  static const Color accentBlue = Color(0xFF6C8BFF);
  static const Color accentBlueLight = Color(0xFF9BB4FF);
  static const Color accentTeal = Color(0xFF5EEAD4);
  static const Color accentViolet = Color(0xFFA78BFA);

  // Text colors
  static const Color textWhite = Color(0xFFF7F9FF);
  static const Color textGrey = Color(0xFFB2BCD1);
  static const Color textMuted = Color(0xFF7E8799);

  // Status colors
  static const Color greenOnline = Color(0xFF4ADE80);

  // Glass colors
  static const Color glassSoft = Color.fromRGBO(18, 26, 42, 0.55);
  static const Color glassStrong = Color.fromRGBO(18, 26, 42, 0.75);
  static const Color glassBorder = Color.fromRGBO(255, 255, 255, 0.12);
  static const Color glassHighlight = Color.fromRGBO(255, 255, 255, 0.22);

  // Typography (Inter font family sizes)
  static const double displaySize = 32.0;
  static const double headlineSize = 24.0;
  static const double titleSize = 18.0;
  static const double bodySize = 16.0;
  static const double bodySmallSize = 14.0;
  static const double captionSize = 12.0;
  static const double buttonSize = 16.0;

  // Font weights
  static const FontWeight weightBold = FontWeight.w700;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightRegular = FontWeight.w400;

  // Spacing Scale (8dp grid)
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Corner Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXlarge = 24.0;
  static const double radiusFull = 999.0;

  // Shadows
  static const List<BoxShadow> elevationLow = [
    BoxShadow(
      color: Color.fromRGBO(3, 6, 16, 0.35),
      blurRadius: 10,
      offset: Offset(0, 6),
    ),
  ];
  static const List<BoxShadow> elevationMedium = [
    BoxShadow(
      color: Color.fromRGBO(3, 6, 16, 0.45),
      blurRadius: 18,
      offset: Offset(0, 10),
    ),
  ];
  static const List<BoxShadow> elevationHigh = [
    BoxShadow(
      color: Color.fromRGBO(3, 6, 16, 0.55),
      blurRadius: 28,
      offset: Offset(0, 14),
    ),
  ];
}

class NiosSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets page = EdgeInsets.fromLTRB(16, 16, 16, 24);
}

class NiosRadii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double pill = 999.0;
}

/// Gradients for icons and backgrounds
class NiosGradients {
  // Aurora gradients
  static const LinearGradient gradientBlue = LinearGradient(
    colors: [Color(0xFF6C8BFF), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientOrange = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFEC84B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientPurple = LinearGradient(
    colors: [Color(0xFFA78BFA), Color(0xFFF472B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientGreen = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF6EE7B7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientPink = LinearGradient(
    colors: [Color(0xFFF472B6), Color(0xFFFB7185)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientRed = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient background = LinearGradient(
    colors: [
      Color(0xFF0A0F1E),
      Color(0xFF121A2A),
      Color(0xFF10182A),
      Color(0xFF0A0F1E),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassSheen = LinearGradient(
    colors: [
      Color.fromRGBO(255, 255, 255, 0.16),
      Color.fromRGBO(255, 255, 255, 0.02),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class NiosThemePreset {
  const NiosThemePreset({
    required this.id,
    required this.label,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceHover,
    required this.surfaceActive,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentHover,
    required this.accentLight,
    required this.messageOut,
    required this.messageIn,
    required this.border,
    required this.borderLight,
    required this.shadow,
    required this.shadowGlow,
    required this.glass,
    required this.glassHover,
    required this.chatPattern,
  });

  final String id;
  final String label;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceHover;
  final Color surfaceActive;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentHover;
  final Color accentLight;
  final Color messageOut;
  final Color messageIn;
  final Color border;
  final Color borderLight;
  final Color shadow;
  final Color shadowGlow;
  final Color glass;
  final Color glassHover;
  final String chatPattern;
}

final niosThemePresets = <NiosThemePreset>[
  NiosThemePreset(
    id: 'blue',
    label: 'Dark',
    background: const Color(0xFF0A0F1E),
    surface: const Color(0xFF121A2A),
    surfaceAlt: const Color(0xFF1A2336),
    surfaceHover: const Color(0xFF1F2B44),
    surfaceActive: const Color(0xFF27324D),
    text: const Color(0xFFF7F9FF),
    textSecondary: const Color(0xFFB2BCD1),
    textTertiary: const Color(0xFF8C96A8),
    accent: const Color(0xFF6C8BFF),
    accentHover: const Color(0xFF84A0FF),
    accentLight: const Color(0xFFA1B6FF),
    messageOut: const Color(0xFF2D3E64),
    messageIn: const Color(0xFF1A2336),
    border: const Color.fromRGBO(255, 255, 255, 0.08),
    borderLight: const Color.fromRGBO(255, 255, 255, 0.14),
    shadow: const Color.fromRGBO(3, 6, 16, 0.55),
    shadowGlow: const Color.fromRGBO(108, 139, 255, 0.35),
    glass: const Color.fromRGBO(18, 26, 42, 0.6),
    glassHover: const Color.fromRGBO(26, 35, 54, 0.72),
    chatPattern: 'https://i.imgur.com/ZUfitM7.png',
  ),
  NiosThemePreset(
    id: 'light',
    label: 'Light',
    background: const Color(0xFFF3F6FC),
    surface: const Color(0xFFFFFFFF),
    surfaceAlt: const Color(0xFFEEF2F7),
    surfaceHover: const Color(0xFFE6EBF3),
    surfaceActive: const Color(0xFFDDE3EE),
    text: const Color(0xFF0B0F17),
    textSecondary: const Color(0xFF5C6473),
    textTertiary: const Color(0xFF8A93A4),
    accent: const Color(0xFF4F46E5),
    accentHover: const Color(0xFF6366F1),
    accentLight: const Color(0xFF818CF8),
    messageOut: const Color(0xFFE6F2FF),
    messageIn: const Color(0xFFFFFFFF),
    border: const Color.fromRGBO(0, 0, 0, 0.08),
    borderLight: const Color.fromRGBO(0, 0, 0, 0.12),
    shadow: const Color.fromRGBO(18, 27, 46, 0.12),
    shadowGlow: const Color.fromRGBO(79, 70, 229, 0.2),
    glass: const Color.fromRGBO(255, 255, 255, 0.7),
    glassHover: const Color.fromRGBO(243, 246, 252, 0.85),
    chatPattern: 'https://i.imgur.com/k9wk8YW.png',
  ),
  NiosThemePreset(
    id: 'violet',
    label: 'Violet',
    background: const Color(0xFF140F26),
    surface: const Color(0xFF1C1533),
    surfaceAlt: const Color(0xFF241B40),
    surfaceHover: const Color(0xFF2A214A),
    surfaceActive: const Color(0xFF322857),
    text: const Color(0xFFF7F3FF),
    textSecondary: const Color(0xFFC6B6E6),
    textTertiary: const Color(0xFFA08DBD),
    accent: const Color(0xFFC084FC),
    accentHover: const Color(0xFFD8B4FE),
    accentLight: const Color(0xFFE9D5FF),
    messageOut: const Color(0xFF4B3568),
    messageIn: const Color(0xFF241B40),
    border: const Color.fromRGBO(255, 255, 255, 0.08),
    borderLight: const Color.fromRGBO(255, 255, 255, 0.14),
    shadow: const Color.fromRGBO(3, 6, 16, 0.6),
    shadowGlow: const Color.fromRGBO(192, 132, 252, 0.35),
    glass: const Color.fromRGBO(28, 21, 51, 0.6),
    glassHover: const Color.fromRGBO(36, 27, 64, 0.72),
    chatPattern: 'https://i.imgur.com/0ei9Yj5.png',
  ),
  NiosThemePreset(
    id: 'green',
    label: 'Green',
    background: const Color(0xFF0B1A14),
    surface: const Color(0xFF12241C),
    surfaceAlt: const Color(0xFF182E23),
    surfaceHover: const Color(0xFF1E392A),
    surfaceActive: const Color(0xFF244433),
    text: const Color(0xFFF2FFF9),
    textSecondary: const Color(0xFFA7C6B5),
    textTertiary: const Color(0xFF7FA18E),
    accent: const Color(0xFF34D399),
    accentHover: const Color(0xFF6EE7B7),
    accentLight: const Color(0xFFA7F3D0),
    messageOut: const Color(0xFF245A45),
    messageIn: const Color(0xFF182E23),
    border: const Color.fromRGBO(255, 255, 255, 0.08),
    borderLight: const Color.fromRGBO(255, 255, 255, 0.14),
    shadow: const Color.fromRGBO(3, 6, 16, 0.55),
    shadowGlow: const Color.fromRGBO(52, 211, 153, 0.3),
    glass: const Color.fromRGBO(18, 36, 28, 0.6),
    glassHover: const Color.fromRGBO(24, 46, 35, 0.72),
    chatPattern: 'https://i.imgur.com/ZUfitM7.png',
  ),
  NiosThemePreset(
    id: 'pink',
    label: 'Pink',
    background: const Color(0xFF1A0E17),
    surface: const Color(0xFF241321),
    surfaceAlt: const Color(0xFF2E192A),
    surfaceHover: const Color(0xFF382034),
    surfaceActive: const Color(0xFF43273E),
    text: const Color(0xFFFFF6FB),
    textSecondary: const Color(0xFFD6ABC4),
    textTertiary: const Color(0xFFB185A3),
    accent: const Color(0xFFFB7185),
    accentHover: const Color(0xFFFDA4AF),
    accentLight: const Color(0xFFFECACA),
    messageOut: const Color(0xFF5C2E44),
    messageIn: const Color(0xFF2E192A),
    border: const Color.fromRGBO(255, 255, 255, 0.08),
    borderLight: const Color.fromRGBO(255, 255, 255, 0.14),
    shadow: const Color.fromRGBO(3, 6, 16, 0.55),
    shadowGlow: const Color.fromRGBO(251, 113, 133, 0.35),
    glass: const Color.fromRGBO(36, 19, 33, 0.6),
    glassHover: const Color.fromRGBO(46, 25, 42, 0.72),
    chatPattern: 'https://i.imgur.com/0ei9Yj5.png',
  ),
  NiosThemePreset(
    id: 'orange',
    label: 'Orange',
    background: const Color(0xFF1A0F0A),
    surface: const Color(0xFF23150E),
    surfaceAlt: const Color(0xFF2C1B12),
    surfaceHover: const Color(0xFF352218),
    surfaceActive: const Color(0xFF3F281E),
    text: const Color(0xFFFFF6EF),
    textSecondary: const Color(0xFFE0BFA9),
    textTertiary: const Color(0xFFC19980),
    accent: const Color(0xFFF59E0B),
    accentHover: const Color(0xFFFBBF24),
    accentLight: const Color(0xFFFCD34D),
    messageOut: const Color(0xFF5A3722),
    messageIn: const Color(0xFF2C1B12),
    border: const Color.fromRGBO(255, 255, 255, 0.08),
    borderLight: const Color.fromRGBO(255, 255, 255, 0.14),
    shadow: const Color.fromRGBO(3, 6, 16, 0.55),
    shadowGlow: const Color.fromRGBO(245, 158, 11, 0.35),
    glass: const Color.fromRGBO(35, 21, 14, 0.6),
    glassHover: const Color.fromRGBO(44, 27, 18, 0.72),
    chatPattern: 'https://i.imgur.com/ZUfitM7.png',
  ),
  NiosThemePreset(
    id: 'teal',
    label: 'Teal',
    background: const Color(0xFFEFFBFB),
    surface: const Color(0xFFFFFFFF),
    surfaceAlt: const Color(0xFFE6F4F4),
    surfaceHover: const Color(0xFFDDEDED),
    surfaceActive: const Color(0xFFD2E6E6),
    text: const Color(0xFF0B0F17),
    textSecondary: const Color(0xFF4E6D6D),
    textTertiary: const Color(0xFF7B9191),
    accent: const Color(0xFF0EA5A8),
    accentHover: const Color(0xFF2DD4BF),
    accentLight: const Color(0xFF5EEAD4),
    messageOut: const Color(0xFFD9F7F1),
    messageIn: const Color(0xFFFFFFFF),
    border: const Color.fromRGBO(0, 0, 0, 0.08),
    borderLight: const Color.fromRGBO(0, 0, 0, 0.12),
    shadow: const Color.fromRGBO(18, 27, 46, 0.12),
    shadowGlow: const Color.fromRGBO(14, 165, 168, 0.2),
    glass: const Color.fromRGBO(255, 255, 255, 0.7),
    glassHover: const Color.fromRGBO(239, 251, 251, 0.85),
    chatPattern: 'https://i.imgur.com/k9wk8YW.png',
  ),
];

class NiosPalette {
  static ColorScheme _scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4F46E5),
    brightness: Brightness.dark,
  );

  // Active theme values (Material 3 derived)
  static Color background = _scheme.surface;
  static Color surface = _scheme.surface;
  static Color surfaceAlt = _scheme.surfaceVariant;
  static Color surfaceHover = _scheme.surfaceVariant;
  static Color surfaceActive = _scheme.surfaceVariant;
  static Color text = _scheme.onSurface;
  static Color textSecondary = _scheme.onSurfaceVariant;
  static Color textTertiary = _scheme.onSurfaceVariant.withValues(alpha: 0.7);
  static Color accent = _scheme.primary;
  static Color accentHover = _scheme.primary;
  static Color accentLight = _scheme.primaryContainer;
  static Color messageOut = _scheme.primaryContainer;
  static Color messageIn = _scheme.surfaceVariant;
  static Color border = _scheme.outline;
  static Color borderLight = _scheme.outlineVariant;
  static Color shadow = Colors.black.withValues(alpha: 0.2);
  static Color shadowGlow = _scheme.primary.withValues(alpha: 0.16);
  static Color glass = _scheme.surface;
  static Color glassHover = _scheme.surfaceVariant;
  static String chatPattern = '';

  // Online status
  static Color online = NiosColors.greenOnline;

  static void apply(ColorScheme scheme) {
    _scheme = scheme;
    background = scheme.surface;
    surface = scheme.surface;
    surfaceAlt = scheme.surfaceVariant;
    surfaceHover = scheme.surfaceVariant;
    surfaceActive = scheme.surfaceVariant;
    text = scheme.onSurface;
    textSecondary = scheme.onSurfaceVariant;
    textTertiary = scheme.onSurfaceVariant.withValues(alpha: 0.7);
    accent = scheme.primary;
    accentHover = scheme.primary;
    accentLight = scheme.primaryContainer;
    messageOut = scheme.primaryContainer;
    messageIn = scheme.surfaceVariant;
    border = scheme.outline;
    borderLight = scheme.outlineVariant;
    shadow = Colors.black.withValues(alpha: 0.2);
    shadowGlow = scheme.primary.withValues(alpha: 0.16);
    glass = scheme.surface;
    glassHover = scheme.surfaceVariant;
    chatPattern = '';
  }
}

class NiosScaffold extends StatelessWidget {
  const NiosScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.usePattern = false,
    this.useAurora = true,
    this.useNoise = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool usePattern;
  final bool useAurora;
  final bool useNoise;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: Theme.of(context).colorScheme.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(child: body),
    );
  }
}

class NiosCard extends StatelessWidget {
  const NiosCard({
    super.key,
    required this.child,
    this.padding,
    this.useGlass = false,
    this.elevation = 0,
  });

  final Widget child;
  final EdgeInsets? padding;
  final bool useGlass;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NiosRadii.md),
        side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(NiosSpacing.md),
        child: child,
      ),
    );
  }
}

class NiosGlass extends StatelessWidget {
  const NiosGlass({
    super.key,
    required this.child,
    this.radius = 16,
    this.blur = 18,
    this.color,
    this.gradient,
    this.padding,
    this.borderColor,
    this.borderWidth = 0.6,
    this.shadow,
    this.showSheen = true,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color? color;
  final Gradient? gradient;
  final EdgeInsets? padding;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadow;
  final bool showSheen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? scheme.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: borderColor ?? scheme.outlineVariant,
            width: borderWidth,
          ),
          boxShadow: shadow,
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

class NiosSectionTitle extends StatelessWidget {
  const NiosSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class NiosPrimaryButton extends StatelessWidget {
  const NiosPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: loading ? null : onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
          ] else if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class NiosGhostButton extends StatelessWidget {
  const NiosGhostButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label),
    );
  }
}

InputDecoration niosInputDecoration(String hint, {IconData? icon}) {
  final scheme = NiosPalette._scheme;
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: scheme.surfaceVariant,
    prefixIcon:
        icon != null ? Icon(icon, color: scheme.onSurfaceVariant) : null,
    hintStyle: TextStyle(color: scheme.onSurfaceVariant),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NiosRadii.md),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NiosRadii.md),
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NiosRadii.md),
      borderSide: BorderSide(color: scheme.primary),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NiosRadii.md),
      borderSide: BorderSide(color: scheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NiosRadii.md),
      borderSide: BorderSide(color: scheme.error),
    ),
  );
}

class NiosBadge extends StatefulWidget {
  const NiosBadge({
    super.key,
    required this.tooltip,
    this.icon = '🦊',
    this.size = 20,
    this.reduceMotion = false,
  });

  final String tooltip;
  final String icon;
  final double size;
  final bool reduceMotion;

  @override
  State<NiosBadge> createState() => _NiosBadgeState();
}

class _NiosBadgeState extends State<NiosBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  OverlayEntry? _entry;
  final ValueNotifier<bool> _tooltipVisible = ValueNotifier(false);
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    if (!widget.reduceMotion) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant NiosBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion) {
      if (widget.reduceMotion) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _removeTooltip();
    _tooltipVisible.dispose();
    super.dispose();
  }

  void _removeTooltip() {
    _entry?.remove();
    _entry = null;
  }

  void _toggleTooltip() {
    if (_open) {
      _open = false;
      _tooltipVisible.value = false;
      Future.delayed(const Duration(milliseconds: 220), _removeTooltip);
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    _open = true;
    _tooltipVisible.value = true;

    _entry = OverlayEntry(
      builder: (context) {
        final screen = MediaQuery.of(context).size;
        const tooltipWidth = 280.0;
        final left = (offset.dx + size.width / 2 - tooltipWidth / 2)
            .clamp(8.0, screen.width - tooltipWidth - 8.0);
        return Positioned(
          top: offset.dy + size.height + 8,
          left: left,
          child: ValueListenableBuilder<bool>(
            valueListenable: _tooltipVisible,
            builder: (context, visible, _) => _BadgeTooltip(
              text: widget.tooltip,
              visible: visible,
              width: tooltipWidth,
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_entry!);
  }

  String _mapIcon(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '🦊';
    if (value.toLowerCase() == 'fox') return '🦊';
    return value;
  }

  Widget _buildIcon() {
    final icon = _mapIcon(widget.icon);
    final isUrl = icon.startsWith('http://') || icon.startsWith('https://');
    final isAsset = icon.startsWith('assets/') ||
        icon.endsWith('.png') ||
        icon.endsWith('.jpg') ||
        icon.endsWith('.webp');
    if (isUrl) {
      return CachedNetworkImage(
        imageUrl: icon,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) =>
            Text('🦊', style: TextStyle(fontSize: widget.size * 0.46)),
      );
    }
    if (isAsset) {
      return Image.asset(icon, fit: BoxFit.cover);
    }
    return Text(icon, style: TextStyle(fontSize: widget.size * 0.46));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleTooltip,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _BadgeParticlesPainter(_controller.value),
                size: Size(widget.size, widget.size),
              ),
            ),
            Container(
              width: widget.size * 0.72,
              height: widget.size * 0.72,
              decoration: BoxDecoration(
                color: NiosPalette.surfaceHover,
                shape: BoxShape.circle,
                border: Border.all(color: NiosPalette.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: NiosPalette.shadowGlow,
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _buildIcon(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTooltip extends StatelessWidget {
  const _BadgeTooltip(
      {required this.text, required this.visible, required this.width});
  final String text;
  final bool visible;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: visible ? 1 : 0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: visible ? 1 : 0.96,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: NiosPalette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NiosPalette.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(color: NiosPalette.text, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeParticlesPainter extends CustomPainter {
  _BadgeParticlesPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final radius = size.width * 0.45;
    for (var i = 0; i < 12; i++) {
      final angle = (progress * 2 * math.pi) + (i * 0.52);
      final dist = radius + (i % 3) * 2;
      final dot = Offset(center.dx + dist * math.cos(angle),
          center.dy + dist * math.sin(angle));
      final alpha =
          (0.5 + 0.5 * math.sin(angle + progress * 6)).clamp(0.2, 0.9);
      paint.color = NiosPalette.accent.withValues(alpha: alpha);

      canvas.drawCircle(dot, i % 3 == 0 ? 1.6 : 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _NoiseLayer extends StatelessWidget {
  const _NoiseLayer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NoisePainter(),
    );
  }
}

class _NoisePainter extends CustomPainter {
  Size? _lastSize;
  List<Offset> _points = const [];

  @override
  void paint(Canvas canvas, Size size) {
    if (_lastSize != size) {
      _lastSize = size;
      final seed = size.width.toInt() * 37 + size.height.toInt() * 91;
      final rng = math.Random(seed);
      final count = (size.width * size.height / 140).round().clamp(600, 2400);
      _points = List<Offset>.generate(
        count,
        (_) => Offset(
            rng.nextDouble() * size.width, rng.nextDouble() * size.height),
      );
    }
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawPoints(ui.PointMode.points, _points, paint);
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}
