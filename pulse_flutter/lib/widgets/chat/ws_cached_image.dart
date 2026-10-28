import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
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
  bool _manualDownloadRequired = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _checkSyncCache();
    if (_bytes == null) {
      final bool autoAllowed = ref.read(autoDownloadAllowedProvider);
      final bool isLocal = widget.mediaUrl.startsWith('local://');
      _load(cacheOnly: !autoAllowed && !isLocal);
    }
  }

  void _checkSyncCache() {
    if (widget.mediaUrl.isEmpty || widget.mediaUrl.startsWith('local://')) {
      return;
    }
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
    if (oldWidget.chatId != widget.chatId ||
        oldWidget.isE2ee != widget.isE2ee ||
        oldWidget.mediaUrl != widget.mediaUrl ||
        oldWidget.e2eeFileKey != widget.e2eeFileKey) {
      _loadGeneration++;
      _bytes = null;
      _checkSyncCache();
      if (_bytes == null) {
        final bool autoAllowed = ref.read(autoDownloadAllowedProvider);
        final bool isLocal = widget.mediaUrl.startsWith('local://');
        _load(cacheOnly: !autoAllowed && !isLocal);
      } else {
        setState(() {
          _isLoading = false;
          _error = null;
          _manualDownloadRequired = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  Future<void> _load({bool cacheOnly = false}) async {
    final generation = ++_loadGeneration;
    final mediaUrl = widget.mediaUrl;
    final encodedKey = widget.e2eeFileKey;
    setState(() {
      _isLoading = true;
      _error = null;
      _manualDownloadRequired = false;
    });

    try {
      // Optimistic local messages reference a file on disk (or a
      // local:// placeholder while bytes are in flight) — never fetch those
      // over the network.
      if (mediaUrl.startsWith('local://')) {
        // These are identifiers for pending uploads, not filesystem paths.
        if (mounted && generation == _loadGeneration) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      Uint8List? fileKey;
      if (encodedKey != null && encodedKey.isNotEmpty) {
        fileKey = base64Decode(encodedKey);
      }

      final bytes = cacheOnly
          ? await WsMediaFetcher.getDiskCachedBytes(
              filePath: mediaUrl,
              e2eeFileKey: fileKey,
            )
          : await WsMediaFetcher.fetchAndDecryptMedia(
              filePath: mediaUrl,
              wsClient: ref.read(webSocketClientProvider),
              e2eeFileKey: fileKey,
            );

      if (mounted && generation == _loadGeneration) {
        setState(() {
          _bytes = bytes;
          _isLoading = false;
          _manualDownloadRequired = bytes == null;
        });
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null && widget.mediaUrl.startsWith('local://')) {
      return widget.placeholder?.call(context) ??
          MediaPlaceholderIllustration(
            width: widget.width ?? double.infinity,
            height: widget.height ?? 200,
          );
    }
    if (_manualDownloadRequired) {
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final TextTheme textTheme = Theme.of(context).textTheme;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticService.lightImpact();
            setState(() {
              _manualDownloadRequired = false;
            });
            _load();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: widget.width ?? double.infinity,
            height: widget.height ?? 180,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.20),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.sharedMediaTapToDownload,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
            message: _error != null
                ? context.l10n.sharedMediaDownloadError
                : context.l10n.sharedMediaUnavailable,
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
        cacheWidth = 720;
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
