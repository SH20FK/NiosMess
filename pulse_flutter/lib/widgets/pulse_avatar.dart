import 'dart:collection';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/providers/token_provider.dart';

class PulseAvatar extends StatelessWidget {
  const PulseAvatar({
    required this.name,
    this.avatarUrl,
    this.radius = 24,
    this.fallbackColor,
    this.textColor,
    this.borderColor,
    this.borderWidth = 0,
    super.key,
  });

  static final LinkedHashMap<String, Color> _colorCache =
      LinkedHashMap<String, Color>();

  static Color _colorFromName(String name) {
    if (_colorCache.containsKey(name)) return _colorCache[name]!;
    if (_colorCache.length >= 200) _colorCache.remove(_colorCache.keys.first);
    final int hash = name.hashCode;
    final Color color = HSLColor.fromAHSL(
      1.0,
      (hash.abs() % 360).toDouble(),
      0.35,
      0.82,
    ).toColor();
    _colorCache[name] = color;
    return color;
  }

  final String name;
  final String? avatarUrl;
  final double radius;
  final Color? fallbackColor;
  final Color? textColor;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color background = fallbackColor ?? _colorFromName(name);
    final Color foreground = textColor ?? scheme.onPrimaryContainer;
    final String initials = _initials(name);
    final String url = ApiConstants.resolve(avatarUrl);

    final Widget fallback = _fallbackAvatar(
      initials: initials,
      background: background,
      foreground: foreground,
      textTheme: textTheme,
    );

    final Widget child;
    if (url.isEmpty) {
      child = fallback;
    } else if (kIsWeb) {
      // In Flutter Web, Image.network avoids CanvasKit black texture rendering bugs
      child = ClipOval(
        child: Image.network(
          url,
          headers: cachedAuthHeaders(),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _ShimmerPlaceholder(
              radius: radius,
              background: background,
            );
          },
        ),
      );
    } else {
      child = ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          httpHeaders: cachedAuthHeaders(),
          memCacheWidth: (radius * 2 * 2).toInt(),
          memCacheHeight: (radius * 2 * 2).toInt(),
          placeholder: (context, url) => _ShimmerPlaceholder(
            radius: radius,
            background: background,
          ),
          errorWidget: (context, url, error) => fallback,
          fadeInDuration: const Duration(milliseconds: 300),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    }

    final Widget avatar = borderWidth <= 0
        ? SizedBox(width: radius * 2, height: radius * 2, child: child)
        : Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor ?? scheme.surface,
                width: borderWidth,
              ),
            ),
            child: child,
          );

    return Semantics(
      label: context.l10n.semanticsAvatar(name),
      image: true,
      child: avatar,
    );
  }

  Widget _fallbackAvatar({
    required String initials,
    required Color background,
    required Color foreground,
    required TextTheme textTheme,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        initials,
        style: textTheme.titleMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials(String raw) {
    final List<String> parts =
        raw.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.characters.take(1).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }
}

class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder({required this.radius, required this.background});
  final double radius;
  final Color background;

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double opacity = 0.5 + (_controller.value * 0.4);
        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.background.withValues(alpha: opacity),
        );
      },
    );
  }
}
