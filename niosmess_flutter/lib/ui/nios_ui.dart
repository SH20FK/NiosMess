import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

const niosThemePresets = <NiosThemePreset>[
  NiosThemePreset(
    id: 'blue',
    label: 'Тёмная',
    background: Color(0xFF0E1621),
    surface: Color(0xFF17212B),
    surfaceAlt: Color(0xFF1E2732),
    surfaceHover: Color(0xFF242F3D),
    surfaceActive: Color(0xFF2B3847),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8B98A8),
    textTertiary: Color(0xFF6B7A8C),
    accent: Color(0xFF5288C1),
    accentHover: Color(0xFF6A9DD4),
    accentLight: Color(0xFF7BA9DB),
    messageOut: Color(0xFF2B5278),
    messageIn: Color(0xFF1E2732),
    border: Color.fromRGBO(255, 255, 255, 0.06),
    borderLight: Color.fromRGBO(255, 255, 255, 0.08),
    shadow: Color.fromRGBO(0, 0, 0, 0.5),
    shadowGlow: Color.fromRGBO(82, 136, 193, 0.3),
    glass: Color.fromRGBO(23, 33, 43, 0.95),
    glassHover: Color.fromRGBO(30, 39, 50, 0.95),
    chatPattern: 'https://i.imgur.com/ZUfitM7.png',
  ),
  NiosThemePreset(
    id: 'light',
    label: 'Светлая',
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F4F5),
    surfaceAlt: Color(0xFFE8E8EA),
    surfaceHover: Color(0xFFDFE1E4),
    surfaceActive: Color(0xFFD4D6D9),
    text: Color(0xFF000000),
    textSecondary: Color(0xFF707579),
    textTertiary: Color(0xFFA2ACB0),
    accent: Color(0xFF3390EC),
    accentHover: Color(0xFF4CA0F0),
    accentLight: Color(0xFF65B0F4),
    messageOut: Color(0xFFE7F8D4),
    messageIn: Color(0xFFFFFFFF),
    border: Color.fromRGBO(0, 0, 0, 0.08),
    borderLight: Color.fromRGBO(0, 0, 0, 0.12),
    shadow: Color.fromRGBO(0, 0, 0, 0.12),
    shadowGlow: Color.fromRGBO(51, 144, 236, 0.2),
    glass: Color.fromRGBO(255, 255, 255, 0.98),
    glassHover: Color.fromRGBO(244, 244, 245, 0.98),
    chatPattern: 'https://i.imgur.com/k9wk8YW.png',
  ),
  NiosThemePreset(
    id: 'violet',
    label: 'Фиолетовая',
    background: Color(0xFF1A1125),
    surface: Color(0xFF231931),
    surfaceAlt: Color(0xFF2C2139),
    surfaceHover: Color(0xFF362948),
    surfaceActive: Color(0xFF403152),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB5A5C9),
    textTertiary: Color(0xFF8D7BA5),
    accent: Color(0xFF8B7CBD),
    accentHover: Color(0xFF9D8ECD),
    accentLight: Color(0xFFAFA0DD),
    messageOut: Color(0xFF5A4575),
    messageIn: Color(0xFF2C2139),
    border: Color.fromRGBO(255, 255, 255, 0.06),
    borderLight: Color.fromRGBO(255, 255, 255, 0.08),
    shadow: Color.fromRGBO(0, 0, 0, 0.5),
    shadowGlow: Color.fromRGBO(139, 124, 189, 0.4),
    glass: Color.fromRGBO(35, 25, 49, 0.95),
    glassHover: Color.fromRGBO(44, 33, 57, 0.95),
    chatPattern: 'https://i.imgur.com/0ei9Yj5.png',
  ),
  NiosThemePreset(
    id: 'green',
    label: 'Зелёная',
    background: Color(0xFF0D1E16),
    surface: Color(0xFF162920),
    surfaceAlt: Color(0xFF1D332A),
    surfaceHover: Color(0xFF243D34),
    surfaceActive: Color(0xFF2B473E),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8FB399),
    textTertiary: Color(0xFF6D917D),
    accent: Color(0xFF5FA378),
    accentHover: Color(0xFF72B289),
    accentLight: Color(0xFF85C19A),
    messageOut: Color(0xFF2E5A42),
    messageIn: Color(0xFF1D332A),
    border: Color.fromRGBO(255, 255, 255, 0.06),
    borderLight: Color.fromRGBO(255, 255, 255, 0.08),
    shadow: Color.fromRGBO(0, 0, 0, 0.5),
    shadowGlow: Color.fromRGBO(95, 163, 120, 0.3),
    glass: Color.fromRGBO(22, 41, 32, 0.95),
    glassHover: Color.fromRGBO(29, 51, 42, 0.95),
    chatPattern: 'https://i.imgur.com/ZUfitM7.png',
  ),
  NiosThemePreset(
    id: 'pink',
    label: 'Розовая',
    background: Color(0xFF1E0E19),
    surface: Color(0xFF2A1525),
    surfaceAlt: Color(0xFF351C30),
    surfaceHover: Color(0xFF40233B),
    surfaceActive: Color(0xFF4B2A46),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD4A5C4),
    textTertiary: Color(0xFFB085A0),
    accent: Color(0xFFD77FA1),
    accentHover: Color(0xFFE092B1),
    accentLight: Color(0xFFE9A5C1),
    messageOut: Color(0xFF6B3D57),
    messageIn: Color(0xFF351C30),
    border: Color.fromRGBO(255, 255, 255, 0.06),
    borderLight: Color.fromRGBO(255, 255, 255, 0.08),
    shadow: Color.fromRGBO(0, 0, 0, 0.5),
    shadowGlow: Color.fromRGBO(215, 127, 161, 0.4),
    glass: Color.fromRGBO(42, 21, 37, 0.95),
    glassHover: Color.fromRGBO(53, 28, 48, 0.95),
    chatPattern: 'https://i.imgur.com/0ei9Yj5.png',
  ),
  NiosThemePreset(
    id: 'orange',
    label: 'Оранжевая',
    background: Color(0xFF1B0F0A),
    surface: Color(0xFF23130C),
    surfaceAlt: Color(0xFF2A1911),
    surfaceHover: Color(0xFF332017),
    surfaceActive: Color(0xFF3B271D),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE2C4B0),
    textTertiary: Color(0xFFC9A58E),
    accent: Color(0xFFF28A2E),
    accentHover: Color(0xFFF5A050),
    accentLight: Color(0xFFF7B36E),
    messageOut: Color(0xFF5A3722),
    messageIn: Color(0xFF2A1911),
    border: Color.fromRGBO(255, 255, 255, 0.06),
    borderLight: Color.fromRGBO(255, 255, 255, 0.08),
    shadow: Color.fromRGBO(0, 0, 0, 0.5),
    shadowGlow: Color.fromRGBO(242, 138, 46, 0.35),
    glass: Color.fromRGBO(35, 19, 12, 0.92),
    glassHover: Color.fromRGBO(42, 25, 17, 0.92),
    chatPattern: 'https://i.imgur.com/ZUfitM7.png',
  ),
  NiosThemePreset(
    id: 'teal',
    label: 'Бирюзовая',
    background: Color(0xFFF0F7F7),
    surface: Color(0xFFE4F1F1),
    surfaceAlt: Color(0xFFD8EBEB),
    surfaceHover: Color(0xFFCCE5E5),
    surfaceActive: Color(0xFFC0DFDF),
    text: Color(0xFF000000),
    textSecondary: Color(0xFF5A7A7A),
    textTertiary: Color(0xFF8A9F9F),
    accent: Color(0xFF24A89E),
    accentHover: Color(0xFF37B8AE),
    accentLight: Color(0xFF4AC8BE),
    messageOut: Color(0xFFC8F5E8),
    messageIn: Color(0xFFFFFFFF),
    border: Color.fromRGBO(0, 0, 0, 0.08),
    borderLight: Color.fromRGBO(0, 0, 0, 0.12),
    shadow: Color.fromRGBO(0, 0, 0, 0.12),
    shadowGlow: Color.fromRGBO(36, 168, 158, 0.2),
    glass: Color.fromRGBO(255, 255, 255, 0.98),
    glassHover: Color.fromRGBO(228, 241, 241, 0.98),
    chatPattern: 'https://i.imgur.com/k9wk8YW.png',
  ),
];

class NiosPalette {
  static Color background = niosThemePresets.first.background;
  static Color surface = niosThemePresets.first.surface;
  static Color surfaceAlt = niosThemePresets.first.surfaceAlt;
  static Color surfaceHover = niosThemePresets.first.surfaceHover;
  static Color surfaceActive = niosThemePresets.first.surfaceActive;
  static Color text = niosThemePresets.first.text;
  static Color textSecondary = niosThemePresets.first.textSecondary;
  static Color textTertiary = niosThemePresets.first.textTertiary;
  static Color accent = niosThemePresets.first.accent;
  static Color accentHover = niosThemePresets.first.accentHover;
  static Color accentLight = niosThemePresets.first.accentLight;
  static Color messageOut = niosThemePresets.first.messageOut;
  static Color messageIn = niosThemePresets.first.messageIn;
  static Color border = niosThemePresets.first.border;
  static Color borderLight = niosThemePresets.first.borderLight;
  static Color shadow = niosThemePresets.first.shadow;
  static Color shadowGlow = niosThemePresets.first.shadowGlow;
  static Color glass = niosThemePresets.first.glass;
  static Color glassHover = niosThemePresets.first.glassHover;
  static String chatPattern = niosThemePresets.first.chatPattern;

  static void apply(NiosThemePreset preset) {
    background = preset.background;
    surface = preset.surface;
    surfaceAlt = preset.surfaceAlt;
    surfaceHover = preset.surfaceHover;
    surfaceActive = preset.surfaceActive;
    text = preset.text;
    textSecondary = preset.textSecondary;
    textTertiary = preset.textTertiary;
    accent = preset.accent;
    accentHover = preset.accentHover;
    accentLight = preset.accentLight;
    messageOut = preset.messageOut;
    messageIn = preset.messageIn;
    border = preset.border;
    borderLight = preset.borderLight;
    shadow = preset.shadow;
    shadowGlow = preset.shadowGlow;
    glass = preset.glass;
    glassHover = preset.glassHover;
    chatPattern = preset.chatPattern;
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
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool usePattern;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: NiosPalette.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: usePattern
          ? Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.03,
                    child: CachedNetworkImage(
                      imageUrl: NiosPalette.chatPattern,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                SafeArea(child: body),
              ],
            )
          : SafeArea(child: body),
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
      color: useGlass ? NiosPalette.glass : NiosPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: NiosPalette.border, width: 0.5),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}


class NiosSectionTitle extends StatelessWidget {
  const NiosSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: NiosPalette.textSecondary,
        fontSize: 12,
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
    return ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: NiosPalette.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: NiosPalette.accent),
      child: Text(label),
    );
  }
}

InputDecoration niosInputDecoration(String hint, {IconData? icon}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: NiosPalette.surfaceAlt,
    prefixIcon: icon != null ? Icon(icon, color: NiosPalette.textSecondary) : null,
    hintStyle: TextStyle(color: NiosPalette.textSecondary),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: NiosPalette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: NiosPalette.accent),
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

class _NiosBadgeState extends State<NiosBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  OverlayEntry? _entry;
  final ValueNotifier<bool> _tooltipVisible = ValueNotifier(false);
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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
    final isAsset = icon.startsWith('assets/') || icon.endsWith('.png') || icon.endsWith('.jpg') || icon.endsWith('.webp');
    if (isUrl) {
      return CachedNetworkImage(
        imageUrl: icon,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Text('🦊', style: TextStyle(fontSize: widget.size * 0.46)),
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
  const _BadgeTooltip({required this.text, required this.visible, required this.width});
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
      final dot = Offset(center.dx + dist * math.cos(angle), center.dy + dist * math.sin(angle));
      final alpha = (0.5 + 0.5 * math.sin(angle + progress * 6)).clamp(0.2, 0.9);
      paint.color = NiosPalette.accent.withValues(alpha: alpha);

      canvas.drawCircle(dot, i % 3 == 0 ? 1.6 : 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
