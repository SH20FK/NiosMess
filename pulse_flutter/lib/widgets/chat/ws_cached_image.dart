import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class WsCachedImage extends ConsumerStatefulWidget {
  const WsCachedImage({
    required this.mediaUrl,
    required this.chatId,
    required this.isE2ee,
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
      final e2eeService = ref.read(e2eeServiceProvider);
      
      final bytes = await WsMediaFetcher.fetchAndDecryptMedia(
        filePath: widget.mediaUrl,
        wsClient: wsClient,
        isE2ee: widget.isE2ee,
        chatId: widget.chatId,
        e2eeService: e2eeService,
        theirPublicKeyBase64: null, // Depending on where public key is stored
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
