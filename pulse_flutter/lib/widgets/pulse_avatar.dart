import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';

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
    final Color background = fallbackColor ?? scheme.primaryContainer;
    final Color foreground = textColor ?? scheme.onPrimaryContainer;
    final String initials = _initials(name);
    final String rawUrl = (avatarUrl ?? '').trim();
    final String url = rawUrl.isEmpty 
        ? '' 
        : (rawUrl.startsWith('http') ? rawUrl : '${ApiConstants.origin}${rawUrl.startsWith('/') ? '' : '/'}$rawUrl');

    final Widget fallback = _fallbackAvatar(
      context,
      initials: initials,
      background: background,
      foreground: foreground,
      textTheme: textTheme,
    );

    final Widget child = url.isEmpty
        ? fallback
        : ClipOval(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: radius * 2,
              height: radius * 2,
              memCacheWidth: (radius * 2 * 2).toInt(),
              memCacheHeight: (radius * 2 * 2).toInt(),
              maxWidthDiskCache: 200,
              maxHeightDiskCache: 200,
              fadeInDuration: const Duration(milliseconds: 140),
              placeholder: (BuildContext context, String _) => fallback,
              errorWidget: (BuildContext context, String _, Object error) {
                return fallback;
              },
            ),
          );

    if (borderWidth <= 0) {
      return SizedBox(width: radius * 2, height: radius * 2, child: child);
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? scheme.surface,
          width: borderWidth,
        ),
      ),
      child: ClipOval(child: child),
    );
  }

  Widget _fallbackAvatar(
    BuildContext context, {
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
    final List<String> parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
