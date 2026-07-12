import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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

  static final LinkedHashMap<String, Color> _colorCache = LinkedHashMap<String, Color>();

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
      context,
      initials: initials,
      background: background,
      foreground: foreground,
      textTheme: textTheme,
    );

    final Widget child = url.isEmpty
        ? fallback
        : _CachedAvatar(
            url: url,
            radius: radius,
            fallback: fallback,
          );

    final Widget avatar = borderWidth <= 0
        ? SizedBox(width: radius * 2, height: radius * 2, child: ClipOval(child: child))
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
            child: ClipOval(child: child),
          );

    return Semantics(
      label: context.l10n.semanticsAvatar(name),
      image: true,
      child: avatar,
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

class _CachedAvatar extends StatefulWidget {
  const _CachedAvatar({
    required this.url,
    required this.radius,
    required this.fallback,
  });

  final String url;
  final double radius;
  final Widget fallback;

  @override
  State<_CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<_CachedAvatar> {
  ImageStream? _imageStream;
  ImageInfo? _currentInfo;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(_CachedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _stopListening();
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _resolveImage() {
    final ImageProvider provider = CachedNetworkImageProvider(
      widget.url,
      maxWidth: (widget.radius * 2 * 2).toInt(),
      maxHeight: (widget.radius * 2 * 2).toInt(),
    );

    final ImageStream stream = provider.resolve(
      ImageConfiguration.empty,
    );

    _stopListening();
    _imageStream = stream;
    _listener = ImageStreamListener(_onImage);
    stream.addListener(_listener!);
  }

  void _onImage(ImageInfo info, bool _) {
    if (!mounted) return;
    setState(() => _currentInfo = info);
  }

  void _stopListening() {
    if (_listener != null && _imageStream != null) {
      _imageStream!.removeListener(_listener!);
      _listener = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentInfo != null) {
      return RawImage(
        image: _currentInfo!.image,
        width: widget.radius * 2,
        height: widget.radius * 2,
        fit: BoxFit.cover,
      );
    }
    return widget.fallback;
  }
}
