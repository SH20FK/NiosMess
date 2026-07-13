import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/utils/file_opener.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class M3FilePreviewBottomSheet extends StatelessWidget {
  const M3FilePreviewBottomSheet({
    super.key,
    required this.fileName,
    required this.fileSize,
    this.fileBytes,
    this.filePath,
    this.mediaUrl,
    this.onForward,
  });

  final Uint8List? fileBytes;
  final String fileName;
  final int fileSize;
  final String? filePath;
  final String? mediaUrl;
  final Future<void> Function()? onForward;

  FileTypeInfo get typeInfo =>
      FileTypeDetector.detect(fileName: fileName, filePath: filePath);

  bool get hasBytes => fileBytes != null && fileBytes!.isNotEmpty;
  bool get hasLocalPath => (filePath ?? '').trim().isNotEmpty;
  bool get hasRemoteUrl => (mediaUrl ?? '').trim().isNotEmpty;
  bool get canPreviewNow {
    if (typeInfo.isImage) return hasRemoteUrl || hasBytes;
    if (typeInfo.isVideo) return hasRemoteUrl;
    if (typeInfo.isAudio) return hasRemoteUrl || hasLocalPath;
    if (typeInfo.isPdf) return hasRemoteUrl || hasBytes;
    return false;
  }

  bool get canOpenNow => hasRemoteUrl || hasLocalPath;
  bool get canDownloadNow => hasRemoteUrl || hasBytes;
  bool get canCopyReference => hasRemoteUrl || hasLocalPath;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.30,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              InkWell(
                onTap: () => _showFullName(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                         getIconDataByName(typeInfo.icon),
                        color: Color(typeInfo.color),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _shortFileName(fileName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        FileTypeDetector.formatFileSize(fileSize),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _PreviewActionButton(
                    icon: Icons.save_alt_rounded,
                    label: context.l10n.filePreviewSave,
                    onPressed: canDownloadNow ? () => _saveFile(context) : null,
                  ),
                  _PreviewActionButton(
                    icon: Icons.link_rounded,
                    label: context.l10n.filePreviewLink,
                    onPressed: canCopyReference
                        ? () => _copyReference(context)
                        : null,
                  ),
                  _PreviewActionButton(
                    icon: Icons.open_in_new_rounded,
                    label: context.l10n.filePreviewOpen,
                    onPressed: canPreviewNow || canOpenNow
                        ? () => _openPrimary(context)
                        : null,
                  ),
                  _PreviewActionButton(
                    icon: Icons.forward_to_inbox_rounded,
                    label: context.l10n.filePreviewForward,
                    onPressed: onForward == null
                        ? null
                        : () => _forwardFile(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortFileName(String name) {
    final String trimmed = name.trim();
    if (trimmed.length <= 24) return trimmed;
    final int dot = trimmed.lastIndexOf('.');
    final String ext = dot > 0 && trimmed.length - dot <= 8
        ? trimmed.substring(dot)
        : '';
    final String stem = ext.isEmpty ? trimmed : trimmed.substring(0, dot);
    if (stem.length <= 18) return trimmed;
    return '${stem.substring(0, 8)}...${stem.substring(stem.length - 6)}$ext';
  }

  Future<void> _showFullName(BuildContext context) async {
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AppDialog(
        title: context.l10n.filePreviewFileName,
        icon: Icons.description_rounded,
        actions: <AppDialogAction>[
          AppDialogAction(
            label: context.l10n.filePreviewClose,
            isPrimary: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
        child: SelectableText(fileName),
      ),
    );
  }

  Future<void> _openPrimary(BuildContext context) async {
    if (canPreviewNow) {
      await _previewFile(context);
      return;
    }
    await _openFile(context);
  }

  Future<void> _saveFile(BuildContext context) async {
    Navigator.of(context).pop();
    await saveM3File(
      context: context,
      fileName: fileName,
      fileSize: fileSize,
      fileBytes: fileBytes,
      mediaUrl: hasRemoteUrl ? mediaUrl : null,
    );
  }

  Future<void> _forwardFile(BuildContext context) async {
    Navigator.of(context).pop();
    await onForward?.call();
  }

  Future<void> _previewFile(BuildContext context) async {
    Navigator.of(context).pop();

    if (typeInfo.isImage) {
      if (hasRemoteUrl) {
        await context.push('/media-viewer?url=${Uri.encodeComponent(mediaUrl!)}&title=${Uri.encodeComponent(fileName)}&type=image');
        return;
      }
      if (hasBytes) {
        await showDialog<void>(
          context: context,
          builder: (BuildContext ctx) {
            final ColorScheme scheme = Theme.of(ctx).colorScheme;
            return Dialog.fullscreen(
              child: Stack(
                children: <Widget>[
                  Container(
                    color: scheme.scrim,
                    alignment: Alignment.center,
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Image.memory(fileBytes!, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton.filled(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
      return;
    }

    if (typeInfo.isVideo && hasRemoteUrl) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              _VideoPreviewScreen(fileName: fileName, videoUrl: mediaUrl!),
        ),
      );
      return;
    }

    if (typeInfo.isAudio && (hasRemoteUrl || hasLocalPath)) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _AudioPreviewContent(
                fileName: fileName,
                remoteUrl: hasRemoteUrl ? mediaUrl : null,
                localPath: hasLocalPath ? filePath : null,
              ),
            ),
          );
        },
      );
      return;
    }

    if (typeInfo.isPdf && (hasRemoteUrl || hasBytes)) {
      await _openFile(context);
    }
  }

  Future<void> _openFile(BuildContext context) async {
    Navigator.of(context).pop();
    if (hasRemoteUrl) {
      await FileOpener.openUrl(context, mediaUrl!);
      return;
    }
    if (hasLocalPath) {
      await FileOpener.openFile(
        context: context,
        filePath: filePath!,
        fileName: fileName,
      );
    }
  }

  Future<void> _copyReference(BuildContext context) async {
    Navigator.of(context).pop();
    final String reference = hasRemoteUrl ? mediaUrl! : (filePath ?? fileName);
    await Clipboard.setData(ClipboardData(text: reference));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasRemoteUrl
              ? context.l10n.filePreviewLinkCopied
              : context.l10n.filePreviewPathCopied,
        ),
      ),
    );
  }
}

class _PreviewActionButton extends StatelessWidget {
  const _PreviewActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool enabled = onPressed != null;

    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton.filledTonal(onPressed: onPressed, icon: Icon(icon)),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: enabled
                  ? scheme.onSurfaceVariant
                  : scheme.onSurface.withValues(alpha: 0.38),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> saveM3File({
  required BuildContext context,
  required String fileName,
  required int fileSize,
  Uint8List? fileBytes,
  String? mediaUrl,
}) async {
  final bool hasBytes = fileBytes != null && fileBytes.isNotEmpty;
  final bool hasRemoteUrl = (mediaUrl ?? '').trim().isNotEmpty;

  try {
    if (kIsWeb && hasRemoteUrl) {
      final Uri? uri = Uri.tryParse(mediaUrl!);
      if (uri == null) throw Exception('Invalid download URL');
      final bool launched = await launchUrl(uri);
      if (!launched) throw Exception('Failed to open download link');
      return;
    }

    final Uint8List data;
    if (hasBytes) {
      data = fileBytes;
    } else if (hasRemoteUrl) {
      final http.Client client = http.Client();
      try {
        final http.StreamedResponse response = await client.send(
          http.Request('GET', Uri.parse(mediaUrl!)),
        ).timeout(const Duration(seconds: 60));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Download failed (${response.statusCode})');
        }
        final List<int> chunks = <int>[];
        await for (final List<int> chunk in response.stream) {
          chunks.addAll(chunk);
        }
        data = Uint8List.fromList(chunks);
      } finally {
        client.close();
      }
    } else {
      throw Exception('Nothing to save');
    }

    await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(data: data, fileName: fileName),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.filePreviewSaved)));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.filePreviewSaveError(error))));
  }
}

class _VideoPreviewScreen extends StatefulWidget {
  const _VideoPreviewScreen({required this.fileName, required this.videoUrl});

  final String fileName;
  final String videoUrl;

  @override
  State<_VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<_VideoPreviewScreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final Uri? uri = Uri.tryParse(widget.videoUrl);
    if (uri == null) return;
    _controller = VideoPlayerController.networkUrl(uri)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller?.play();
        }
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _controller?.value.isInitialized == true;

    return Scaffold(
      appBar: AppBar(title: Text(widget.fileName)),
      body: Center(
        child: ready
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                      });
                    },
                    icon: Icon(
                      _controller!.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(_controller!.value.isPlaying ? context.l10n.filePreviewPause : context.l10n.filePreviewPlay),
                  ),
                ],
              )
            : const AppLoadingIndicator(),
      ),
    );
  }
}

class _AudioPreviewContent extends StatefulWidget {
  const _AudioPreviewContent({
    required this.fileName,
    this.remoteUrl,
    this.localPath,
  });

  final String fileName;
  final String? remoteUrl;
  final String? localPath;

  @override
  State<_AudioPreviewContent> createState() => _AudioPreviewContentState();
}

class _AudioPreviewContentState extends State<_AudioPreviewContent> {
  late final AudioPlayer _player;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: <AVAudioSessionOptions>{AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }

    try {
      if ((widget.remoteUrl ?? '').trim().isNotEmpty) {
        await _player.play(UrlSource(widget.remoteUrl!));
      } else if ((widget.localPath ?? '').trim().isNotEmpty) {
        await _player.play(DeviceFileSource(widget.localPath!));
      }
      if (mounted) setState(() => _playing = true);
    } catch (e) {
      debugPrint('[AudioPreview] Play error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.commonFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.fileName,
          style: textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _toggle,
          icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          label: Text(_playing ? context.l10n.filePreviewPause : context.l10n.filePreviewPlay),
        ),
      ],
    );
  }
}

Future<void> showM3FilePreview({
  required BuildContext context,
  required String fileName,
  required int fileSize,
  Uint8List? fileBytes,
  String? filePath,
  String? mediaUrl,
  Future<void> Function()? onForward,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) => M3FilePreviewBottomSheet(
      fileName: fileName,
      fileSize: fileSize,
      fileBytes: fileBytes,
      filePath: filePath,
      mediaUrl: mediaUrl,
      onForward: onForward,
    ),
  );
}
