import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/vector_illustrations.dart';

class WsCachedImage extends ConsumerStatefulWidget {
  const WsCachedImage({
    required this.mediaUrl,
    required this.chatId,
    required this.isE2ee,
    this.e2eeFileKey,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fit,
    this.placeholder,
    this.errorWidget,
    super.key,
  });

  final String mediaUrl;
  final int chatId;
  final bool isE2ee;

  /// Base64 AES key from the E2EE message envelope; null for plain media.
  final String? e2eeFileKey;
  final double? width;
  final double? height;

  /// Target decoding width in memory pixels for optimized gallery performance.
  final int? memCacheWidth;

  /// Target decoding height in memory pixels for optimized gallery performance.
  final int? memCacheHeight;

  final BoxFit? fit;
  final Widget Function(BuildContext)? placeholder;
  final Widget Function(BuildContext, Object)? errorWidget;

  @override
  ConsumerState<WsCachedImage> createState() => _WsCachedImageState();
}

class _WsCachedImageState extends ConsumerState<WsCachedImage> {
  Uint8List? _bytes;
  Object? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSyncCache();
    if (_bytes == null) {
      _load();
    }
  }

  void _checkSyncCache() {
    if (widget.mediaUrl.isEmpty || widget.mediaUrl.startsWith('local://')) return;
    Uint8List? fileKey;
    if (widget.e2eeFileKey != null && widget.e2eeFileKey!.isNotEmpty) {
      try {
        fileKey = base64Decode(widget.e2eeFileKey!);
      } catch (_) {}
    }
    final Uint8List? cached = WsMediaFetcher.getMemoryCachedBytes(
      filePath: widget.mediaUrl,
      e2eeFileKey: fileKey,
    );
    if (cached != null) {
      _bytes = cached;
      _isLoading = false;
    }
  }

  @override
  void didUpdateWidget(covariant WsCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl ||
        oldWidget.e2eeFileKey != widget.e2eeFileKey) {
      _bytes = null;
      _checkSyncCache();
      if (_bytes == null) {
        _load();
      } else {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Optimistic local messages reference a file on disk (or a
      // local:// placeholder while bytes are in flight) — never fetch those
      // over the network.
      if (widget.mediaUrl.startsWith('local://')) {
        final String localSubPath =
            widget.mediaUrl.substring('local://'.length);
        final File local = File(localSubPath);
        if (await local.exists()) {
          final Uint8List localBytes = await local.readAsBytes();
          if (mounted) {
            setState(() {
              _bytes = localBytes;
              _isLoading = false;
            });
          }
          return;
        }
        // Local pseudo-path not on disk; keep placeholder without attempting network
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final File? local = _tryLocalFile(widget.mediaUrl);
      if (local != null && await local.exists()) {
        final Uint8List localBytes = await local.readAsBytes();
        if (mounted) {
          setState(() {
            _bytes = localBytes;
            _isLoading = false;
          });
        }
        return;
      }

      final wsClient = ref.read(webSocketClientProvider);
      Uint8List? fileKey;
      if (widget.e2eeFileKey != null && widget.e2eeFileKey!.isNotEmpty) {
        fileKey = base64Decode(widget.e2eeFileKey!);
      }

      final bytes = await WsMediaFetcher.fetchAndDecryptMedia(
        filePath: widget.mediaUrl,
        wsClient: wsClient,
        e2eeFileKey: fileKey,
      );

      if (mounted) {
        setState(() {
          _bytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  /// Returns a [File] when [path] points at the local filesystem.
  static File? _tryLocalFile(String path) {
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('local://')) {
      return null;
    }
    if (path.contains('://')) return null; // other schemes
    try {
      return File(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder?.call(context) ??
          MediaPlaceholderIllustration(
            width: widget.width ?? double.infinity,
            height: widget.height ?? 200,
          );
    }

    if (_error != null || _bytes == null) {
      return widget.errorWidget?.call(context, _error ?? 'Unknown error') ??
          MediaErrorIllustration(
            width: widget.width ?? double.infinity,
            height: widget.height ?? 160,
            message:
                _error != null ? 'Ошибка загрузки' : 'Изображение недоступно',
          );
    }

    final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final int? cacheWidth;
    final int? cacheHeight;

    if (widget.memCacheWidth != null || widget.memCacheHeight != null) {
      cacheWidth = widget.memCacheWidth;
      cacheHeight = widget.memCacheHeight;
    } else {
      final bool hasFiniteWidth =
          widget.width != null && widget.width!.isFinite;
      final bool hasFiniteHeight =
          widget.height != null && widget.height!.isFinite;

      if (hasFiniteWidth) {
        cacheWidth = (widget.width! * dpr).round();
        cacheHeight = hasFiniteHeight ? (widget.height! * dpr).round() : null;
      } else if (hasFiniteHeight) {
        cacheWidth = null;
        cacheHeight = (widget.height! * dpr).round();
      } else {
        cacheWidth = 1080;
        cacheHeight = null;
      }
    }

    return Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      fit: widget.fit,
    );
  }
}
