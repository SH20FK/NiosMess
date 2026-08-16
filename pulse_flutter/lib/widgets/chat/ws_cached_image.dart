import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class WsCachedImage extends ConsumerStatefulWidget {
  const WsCachedImage({
    required this.mediaUrl,
    required this.chatId,
    required this.isE2ee,
    this.e2eeFileKey,
    this.width,
    this.height,
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
    _load();
  }

  @override
  void didUpdateWidget(covariant WsCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder?.call(context) ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(child: AppLoadingIndicator()),
          );
    }

    if (_error != null || _bytes == null) {
      return widget.errorWidget?.call(context, _error ?? 'Unknown error') ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: const Center(child: Icon(Icons.broken_image_rounded)),
          );
    }

    return Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }
}
