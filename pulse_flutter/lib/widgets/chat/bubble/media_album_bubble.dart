import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/media/media_album.dart';
import 'package:pulse_flutter/core/media/media_playback_visibility.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class MediaAlbumBubble extends ConsumerStatefulWidget {
  const MediaAlbumBubble({
    required this.url,
    required this.wsClient,
    this.fileKey,
    this.localBytes,
    this.encrypted = false,
    super.key,
  });
  final String url;
  final WebSocketClient wsClient;
  final String? fileKey;
  final Uint8List? localBytes;
  final bool encrypted;
  @override
  ConsumerState<MediaAlbumBubble> createState() => _MediaAlbumBubbleState();
}

class _MediaAlbumBubbleState extends ConsumerState<MediaAlbumBubble> {
  Future<List<AlbumImage>>? _images;
  bool _visible = false;
  Future<List<AlbumImage>> _read() async {
    final local = widget.localBytes;
    if (local != null) return compute(MediaAlbum.decode, local);
    final key = widget.fileKey;
    if (widget.encrypted && (key == null || key.isEmpty)) {
      throw StateError('album_key_unavailable');
    }
    final bytes = await WsMediaFetcher.fetchAndDecryptMedia(
      filePath: widget.url,
      wsClient: widget.wsClient,
      e2eeFileKey: key == null || key.isEmpty ? null : base64Decode(key),
    );
    return compute(MediaAlbum.decode, bytes);
  }

  void _load() {
    if (_images == null && mounted) {
      final pending = _read();
      setState(() {
        _images = pending;
      });
    }
  }

  void _visibility(bool visible) {
    _visible = visible;
    if (visible &&
        (widget.localBytes != null || ref.read(autoDownloadAllowedProvider))) {
      _load();
    } else if (!visible && _images != null) {
      // Keep decoded private albums scoped to the visible message/viewer.
      setState(() => _images = null);
    }
  }

  @override
  void didUpdateWidget(covariant MediaAlbumBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.fileKey != widget.fileKey ||
        oldWidget.localBytes != widget.localBytes) {
      _images = null;
      if (_visible &&
          (widget.localBytes != null ||
              ref.read(autoDownloadAllowedProvider))) {
        _images = _read();
      }
    }
  }

  @override
  Widget build(BuildContext context) => MediaPlaybackVisibility(
    onChanged: _visibility,
    child: SizedBox(
      width: 320,
      height: 230,
      child: _images == null
          ? Center(
              child: TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(context.l10n.chatAlbumOpen),
              ),
            )
          : FutureBuilder<List<AlbumImage>>(
              future: _images,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _images = null);
                        _load();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.l10n.commonRetry),
                    ),
                  );
                }
                final images = snapshot.data;
                if (images == null) {
                  return const Center(child: AppLoadingIndicator(size: 32));
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      for (
                        var row = 0;
                        row < (images.length > 2 ? 2 : 1);
                        row++
                      )
                        Expanded(
                          child: Row(
                            children: [
                              for (var col = 0; col < 2; col++)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(1),
                                    child: row * 2 + col >= images.length
                                        ? const SizedBox.shrink()
                                        : InkWell(
                                            onTap: () =>
                                                _open(images, row * 2 + col),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                _AlbumPhoto(
                                                  bytes: images[row * 2 + col]
                                                      .bytes,
                                                  decodeWidth: 640,
                                                  fit: BoxFit.cover,
                                                ),
                                                if (row * 2 + col == 3 &&
                                                    images.length > 4)
                                                  Center(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHigh,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              24,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '+${images.length - 4}',
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.titleLarge,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    ),
  );

  Future<void> _open(List<AlbumImage> images, int selected) async {
    final page = PageController(initialPage: selected);
    try {
      await AppModal.showDialog<void>(
        context: context,
        maxWidth: 1000,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .62,
              child: PageView.builder(
                controller: page,
                itemCount: images.length,
                itemBuilder: (context, index) => InteractiveViewer(
                  child: _AlbumPhoto(
                    bytes: images[index].bytes,
                    decodeWidth: 2048,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: context.l10n.chatAlbumPrevious,
                  onPressed: () {
                    if ((page.page ?? 0) > 0) {
                      page.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: M3SpringCurves.gentle,
                      );
                    }
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('${images.length}'),
                IconButton(
                  tooltip: context.l10n.chatAlbumNext,
                  onPressed: () {
                    if ((page.page ?? 0) < images.length - 1) {
                      page.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: M3SpringCurves.gentle,
                      );
                    }
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        ),
      );
    } finally {
      page.dispose();
    }
  }
}

/// Private attachment pixels never enter Flutter's global ImageCache.
/// Their lifetime is exactly the visible tile or album viewer page.
class _AlbumPhoto extends StatefulWidget {
  const _AlbumPhoto({
    required this.bytes,
    required this.decodeWidth,
    required this.fit,
  });
  final Uint8List bytes;
  final int decodeWidth;
  final BoxFit fit;
  @override
  State<_AlbumPhoto> createState() => _AlbumPhotoState();
}

class _AlbumPhotoState extends State<_AlbumPhoto> {
  ui.Image? _image;
  bool _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_decode());
  }

  @override
  void didUpdateWidget(covariant _AlbumPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes ||
        oldWidget.decodeWidth != widget.decodeWidth) {
      _image?.dispose();
      _image = null;
      _failed = false;
      unawaited(_decode());
    }
  }

  Future<void> _decode() async {
    final generation = ++_generation;
    ui.Codec? codec;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(widget.bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final scale = longest > widget.decodeWidth
          ? widget.decodeWidth / longest
          : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(
          1,
          widget.decodeWidth,
        ),
        targetHeight: (descriptor.height * scale).round().clamp(
          1,
          widget.decodeWidth,
        ),
      );
      final frame = await codec.getNextFrame();
      if (!mounted || generation != _generation) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  void dispose() {
    ++_generation;
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _image != null
      ? RawImage(image: _image, fit: widget.fit)
      : Center(
          child: _failed
              ? const Icon(Icons.broken_image_outlined)
              : const AppLoadingIndicator(size: 24),
        );
}
