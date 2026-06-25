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
        : (rawUrl.startsWith('http')
            ? rawUrl
            : '${ApiConstants.origin}${rawUrl.startsWith('/') ? '' : '/'}$rawUrl');

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

    if (borderWidth <= 0) {
      return SizedBox(width: radius * 2, height: radius * 2, child: ClipOval(child: child));
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
  bool _listening = false;

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
    stream.addListener(ImageStreamListener(_onImage));
    _listening = true;
  }

  void _onImage(ImageInfo info, bool _) {
    if (!mounted) return;
    setState(() => _currentInfo = info);
  }

  void _stopListening() {
    if (_listening && _imageStream != null) {
      _imageStream!.removeListener(ImageStreamListener(_onImage));
      _listening = false;
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
