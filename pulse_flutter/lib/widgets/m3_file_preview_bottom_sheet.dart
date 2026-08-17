import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/core/utils/file_opener.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';

class M3FilePreviewBottomSheet extends StatelessWidget {
  const M3FilePreviewBottomSheet({
    super.key,
    required this.fileName,
    required this.fileSize,
    this.fileBytes,
    this.filePath,
    this.mediaUrl,
    this.e2eeFileKey,
    this.onForward,
  });

  final Uint8List? fileBytes;
  final String fileName;
  final int fileSize;
  final String? filePath;
  final String? mediaUrl;
  final String? e2eeFileKey;
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
    final WebSocketClient wsClient = ProviderScope.containerOf(
      context,
    ).read(webSocketClientProvider);
    await saveM3File(
      context: context,
      fileName: fileName,
      fileSize: fileSize,
      fileBytes: fileBytes,
      mediaUrl: hasRemoteUrl ? mediaUrl : null,
      e2eeFileKey: e2eeFileKey,
      wsClient: wsClient,
    );
  }

  Future<void> _forwardFile(BuildContext context) async {
    Navigator.of(context).pop();
    await onForward?.call();
  }

  Future<void> _previewFile(BuildContext context) async {
    Navigator.of(context).pop();

    if (typeInfo.isImage) {
      Navigator.of(context).pop();
      await context.push(
        '/file-viewer?name=${Uri.encodeComponent(fileName)}'
        '${hasRemoteUrl ? '&url=${Uri.encodeComponent(mediaUrl!)}' : ''}'
        '${hasLocalPath ? '&path=${Uri.encodeComponent(filePath!)}' : ''}',
        extra: e2eeFileKey,
      );
      return;
    }

    if (typeInfo.isVideo && hasRemoteUrl) {
      Navigator.of(context).pop();
      await context.push(
        '/file-viewer?name=${Uri.encodeComponent(fileName)}'
        '&url=${Uri.encodeComponent(mediaUrl!)}',
        extra: e2eeFileKey,
      );
      return;
    }

    if (typeInfo.isAudio && (hasRemoteUrl || hasLocalPath)) {
      Navigator.of(context).pop();
      await context.push(
        '/file-viewer?name=${Uri.encodeComponent(fileName)}'
        '${hasRemoteUrl ? '&url=${Uri.encodeComponent(mediaUrl!)}' : ''}'
        '${hasLocalPath ? '&path=${Uri.encodeComponent(filePath!)}' : ''}',
        extra: e2eeFileKey,
      );
      return;
    }

    if (typeInfo.isPdf && (hasRemoteUrl || hasBytes)) {
      Navigator.of(context).pop();
      await context.push(
        '/file-viewer?name=${Uri.encodeComponent(fileName)}'
        '${hasRemoteUrl ? '&url=${Uri.encodeComponent(mediaUrl!)}' : ''}',
        extra: e2eeFileKey,
      );
      return;
    }

    if (typeInfo.isDocument) {
      Navigator.of(context).pop();
      await context.push(
        '/file-viewer?name=${Uri.encodeComponent(fileName)}'
        '${hasRemoteUrl ? '&url=${Uri.encodeComponent(mediaUrl!)}' : ''}'
        '${hasLocalPath ? '&path=${Uri.encodeComponent(filePath!)}' : ''}',
        extra: e2eeFileKey,
      );
      return;
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
    AppToast.showInfo(
      context,
      hasRemoteUrl ? context.l10n.filePreviewLinkCopied : context.l10n.filePreviewPathCopied,
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
  String? e2eeFileKey,
  WebSocketClient? wsClient,
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
      if (wsClient == null) {
        throw Exception('No download client available');
      }
      Uint8List? fileKey;
      if (e2eeFileKey != null && e2eeFileKey.isNotEmpty) {
        try {
          final Uint8List decoded = base64Decode(e2eeFileKey);
          fileKey = decoded;
        } catch (_) {
          fileKey = null;
        }
      } else {
        fileKey = null;
      }
      data = await WsMediaFetcher.fetchAndDecryptMedia(
        filePath: mediaUrl!,
        wsClient: wsClient,
        e2eeFileKey: fileKey,
      );
    } else {
      throw Exception('Nothing to save');
    }

    await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(data: data, fileName: fileName),
    );
    if (!context.mounted) return;
    AppToast.showSuccess(context, context.l10n.filePreviewSaved);
  } catch (error) {
    if (!context.mounted) return;
    AppToast.showError(context, context.l10n.filePreviewSaveError(error));
  }
}

Future<void> showM3FilePreview({
  required BuildContext context,
  required String fileName,
  required int fileSize,
  Uint8List? fileBytes,
  String? filePath,
  String? mediaUrl,
  String? e2eeFileKey,
  Future<void> Function()? onForward,
}) async {
  await AppBottomSheets.show<void>(
    context: context,
    
    isScrollControlled: true,
    builder: (BuildContext ctx) => M3FilePreviewBottomSheet(
      fileName: fileName,
      fileSize: fileSize,
      fileBytes: fileBytes,
      filePath: filePath,
      mediaUrl: mediaUrl,
      e2eeFileKey: e2eeFileKey,
      onForward: onForward,
    ),
  );
}
