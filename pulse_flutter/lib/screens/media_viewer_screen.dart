import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaViewerScreen extends ConsumerWidget {
  const MediaViewerScreen({
    required this.url,
    this.title,
    this.isImage = false,
    this.filePath,
    this.mediaName,
    super.key,
  });

  final String url;
  final String? title;
  final bool isImage;
  final String? filePath;
  final String? mediaName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String displayTitle = (title ?? '').trim().isEmpty
        ? context.l10n.mediaViewerTitle
        : title!.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: context.l10n.mediaViewerDownload,
            onPressed: () => _downloadMedia(context, ref),
          ),
        ],
      ),
      body: isImage
          ? Container(
              color: scheme.scrim,
              alignment: Alignment.center,
              child: InteractiveViewer(
                minScale: 0.6,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (BuildContext context, String _) {
                    return PulseLoadingIndicator(size: 32);
                  },
                  errorWidget: (BuildContext context, String _, Object error) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.l10n.mediaViewerImageLoadFailed('$error'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurface),
                      ),
                    );
                  },
                ),
              ),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.open_in_new_rounded, size: 48, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(context.l10n.mediaViewerCannotPreview),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _downloadMedia(context, ref),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(context.l10n.mediaDownloadAndOpen),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: Text(context.l10n.mediaViewerOpenExternal),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _downloadMedia(BuildContext context, WidgetRef ref) async {
    if (kIsWeb) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.mediaViewerDownloadWeb)),
      );
      return;
    }
    try {
      final fileName = mediaName ?? title ?? 'download';
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';

      if (filePath != null && filePath!.isNotEmpty) {
        final bytes = await ref.read(chatRepositoryProvider).downloadMedia(filePath!);
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.mediaSavedTo(savePath))),
        );
      } else {
        try {
          final bytes = await ref.read(chatRepositoryProvider).downloadMedia(url);
          final file = File(savePath);
          await file.writeAsBytes(bytes);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.mediaSavedTo(savePath))),
          );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.mediaViewerDownloadFailedExt)),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.mediaDownloadFailed('$e'))),
      );
    }
  }
}
