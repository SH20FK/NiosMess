import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:universal_io/io.dart';

class NativeFileViewerScreen extends StatefulWidget {
  const NativeFileViewerScreen({
    required this.fileName,
    required this.fileType,
    this.url,
    this.localPath,
    this.bytes,
    super.key,
  });

  final String fileName;
  final FileTypeInfo fileType;
  final String? url;
  final String? localPath;
  final Uint8List? bytes;

  @override
  State<NativeFileViewerScreen> createState() => _NativeFileViewerScreenState();
}

class _NativeFileViewerScreenState extends State<NativeFileViewerScreen> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: _buildViewer(),
    );
  }

  Widget _buildViewer() {
    final ft = widget.fileType;

    if (ft.isImage) {
      return _ImageViewer(
        url: widget.url,
        bytes: widget.bytes,
        isSvg: widget.fileName.toLowerCase().endsWith('.svg'),
      );
    }

    if (ft.isVideo) {
      return _VideoViewer(
        url: widget.url,
        localPath: widget.localPath,
      );
    }

    if (ft.isAudio) {
      return _MusicPlayer(
        fileName: widget.fileName,
        url: widget.url,
        localPath: widget.localPath,
      );
    }

    if (ft.isPdf) {
      return _PdfViewer(
        url: widget.url,
        localPath: widget.localPath,
        bytes: widget.bytes,
      );
    }

    // Word, Excel, PowerPoint, etc — show document info card
    return _DocumentInfoViewer(
      fileName: widget.fileName,
      fileType: ft,
      url: widget.url,
      localPath: widget.localPath,
    );
  }
}

// ── Image Viewer (with SVG support) ──────────────────────────
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({this.url, this.bytes, this.isSvg = false});

  final String? url;
  final Uint8List? bytes;
  final bool isSvg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5.0,
      child: Center(
        child: _buildContent(scheme),
      ),
    );
  }

  Widget _buildContent(ColorScheme scheme) {
    if (isSvg && bytes != null) {
      return SvgPicture.memory(
        bytes!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (isSvg && url != null) {
      return SvgPicture.network(
        url!,
        headers: cachedAuthHeaders(),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        placeholderBuilder: (_, __) => const Center(
          child: AppLoadingIndicator(size: 32),
        ),
      );
    }

    if (bytes != null) {
      return Image.memory(bytes!, fit: BoxFit.contain);
    }

    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url!,
        httpHeaders: cachedAuthHeaders(),
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child: AppLoadingIndicator(size: 32),
        ),
        errorWidget: (_, __, ___) => Icon(
          Icons.broken_image_rounded,
          color: scheme.outline,
          size: 56,
        ),
      );
    }

    return const Center(child: Text('No image data'));
  }
}

// ── Video Viewer ──────────────────────────────────────────────
class _VideoViewer extends StatefulWidget {
  const _VideoViewer({this.url, this.localPath});

  final String? url;
  final String? localPath;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.scrim,
      alignment: Alignment.center,
      child: const Center(
        child: AppLoadingIndicator(size: 32),
      ),
    );
  }
}

// ── PDF Viewer ────────────────────────────────────────────────
class _PdfViewer extends StatefulWidget {
  const _PdfViewer({this.url, this.localPath, this.bytes});

  final String? url;
  final String? localPath;
  final Uint8List? bytes;

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  int _totalPages = 0;
  int _currentPage = 1;
  bool _ready = false;
  String? _error;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    if (widget.localPath != null) {
      _localPath = widget.localPath;
      setState(() {});
      return;
    }

    if (widget.bytes != null) {
      try {
        final tempDir = await _getTempDir();
        final tempFile = File('$tempDir/temp_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await tempFile.writeAsBytes(widget.bytes!);
        _localPath = tempFile.path;
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      }
    }
  }

  Future<String> _getTempDir() async {
    return '/tmp';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Failed to load PDF: $_error',
            style: textTheme.bodyLarge?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_localPath == null) {
      return const Center(child: AppLoadingIndicator(size: 32));
    }

    return Stack(
      children: <Widget>[
        PdfView(
          filePath: _localPath,
          onRender: (pages) {
            setState(() {
              _totalPages = pages ?? 0;
              _ready = true;
            });
          },
          onError: (error) {
            setState(() => _error = error.toString());
          },
          onPageError: (page, error) {
            debugPrint('[PDF] Page $page error: $error');
          },
          onViewCreated: (controller) {
            // controller ready
          },
          onPageChanged: (page, total) {
            setState(() {
              _currentPage = (page ?? 0) + 1;
              _totalPages = total ?? 0;
            });
          },
        ),
        if (_ready && _totalPages > 0)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Music Player ──────────────────────────────────────────────
class _MusicPlayer extends StatefulWidget {
  const _MusicPlayer({required this.fileName, this.url, this.localPath});

  final String fileName;
  final String? url;
  final String? localPath;

  @override
  State<_MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<_MusicPlayer> {
  late final AudioPlayer _player;
  bool _playing = false;
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _playing = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _playing = false;
            _position = Duration.zero;
          }
        });
      }
    });
  }

  Future<void> _initPlayer() async {
    setState(() => _loading = true);
    try {
      if (widget.localPath != null) {
        await _player.setAudioSource(AudioSource.file(widget.localPath!));
      } else if (widget.url != null) {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(widget.url!)));
      }
    } catch (e) {
      debugPrint('[MusicPlayer] Init error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      if (_position >= _duration && _duration > Duration.zero) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  void _seek(double fraction) {
    final target = _duration * fraction.clamp(0.0, 1.0);
    _player.seek(target);
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Album art placeholder
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer,
                    scheme.tertiaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: 80,
                color: scheme.onPrimaryContainer,
              ),
            ),

            const SizedBox(height: 32),

            // File name
            Text(
              widget.fileName,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 32),

            // Seekbar
            if (_duration > Duration.zero)
              Column(
                children: [
                  Slider(
                    value: _position.inMilliseconds.toDouble(),
                    min: 0,
                    max: _duration.inMilliseconds.toDouble(),
                    onChanged: (v) => _seek(v / _duration.inMilliseconds),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(_position),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _formatTime(_duration),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Rewind 10s
                IconButton.filledTonal(
                  onPressed: () {
                    final target = _position - const Duration(seconds: 10);
                    _player.seek(target < Duration.zero ? Duration.zero : target);
                  },
                  icon: const Icon(Icons.replay_10_rounded),
                  iconSize: 28,
                ),

                const SizedBox(width: 16),

                // Play/Pause
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _togglePlay,
                          icon: Icon(
                            _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: scheme.onPrimary,
                            size: 36,
                          ),
                        ),
                ),

                const SizedBox(width: 16),

                // Forward 10s
                IconButton.filledTonal(
                  onPressed: () {
                    final target = _position + const Duration(seconds: 10);
                    _player.seek(target > _duration ? _duration : target);
                  },
                  icon: const Icon(Icons.forward_10_rounded),
                  iconSize: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Document Info Viewer (Word, Excel, etc) ───────────────────
class _DocumentInfoViewer extends StatelessWidget {
  const _DocumentInfoViewer({
    required this.fileName,
    required this.fileType,
    this.url,
    this.localPath,
  });

  final String fileName;
  final FileTypeInfo fileType;
  final String? url;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final IconData docIcon = _getDocIcon();
    final Color docColor = Color(fileType.color);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Document icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: docColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                docIcon,
                size: 56,
                color: docColor,
              ),
            ),

            const SizedBox(height: 24),

            // File name
            Text(
              fileName,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // File type label
            Text(
              fileType.label,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // Open externally button
            FilledButton.icon(
              onPressed: () {
                if (url != null) {
                  AppToast.showInfo(context, context.l10n.filePreviewOpenExternal);
                } else if (localPath != null) {
                  AppToast.showInfo(context, context.l10n.filePreviewOpenExternal);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(context.l10n.filePreviewOpenExternal),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Download button
            if (url != null)
              FilledButton.tonalIcon(
                onPressed: () {
                  AppToast.showInfo(context, context.l10n.filePreviewSaved);
                },
                icon: const Icon(Icons.download_rounded),
                label: Text(context.l10n.filePreviewSave),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getDocIcon() {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'odt':
        return Icons.article_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
