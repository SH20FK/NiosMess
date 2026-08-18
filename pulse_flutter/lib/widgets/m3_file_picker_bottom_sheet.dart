import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/widgets/media_grid_picker.dart';

class M3FilePickerResult {
  M3FilePickerResult({
    required this.fileName,
    required this.fileSize,
    required this.mediaSubtype,
    this.filePath,
    this.fileBytes,
  });

  final String fileName;
  final int fileSize;
  final String mediaSubtype;
  final String? filePath;
  final Uint8List? fileBytes;

  FileTypeInfo get typeInfo => FileTypeDetector.detect(fileName: fileName);
  String get formattedSize => FileTypeDetector.formatFileSize(fileSize);
}

Future<List<M3FilePickerResult>?> showM3FilePicker(BuildContext context) async {
  return AppBottomSheets.show<List<M3FilePickerResult>>(
    context: context,
    builder: (BuildContext ctx) => const _CompactAttachmentMenu(),
  );
}

class _CompactAttachmentMenu extends StatelessWidget {
  const _CompactAttachmentMenu();

  Future<void> _pickFile(
    BuildContext context, {
    required FileType type,
    List<String>? allowedExtensions,
    required String mediaSubtype,
  }) async {
    final List<PlatformFile> result = await FilePicker.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
    );

    if (result.isEmpty || !context.mounted) return;

    final PlatformFile file = result.first;
    final String? filePath = file.path;
    Uint8List? fileBytes;
    try {
      fileBytes = await file.readAsBytes();
    } catch (_) {}

    if (filePath == null && fileBytes == null) {
      if (context.mounted) {
        AppToast.showError(context, context.l10n.filePickerReadError);
      }
      return;
    }

    final int fileSize = fileBytes?.length ??
        (filePath != null ? await file.length() : 0);
    if (!context.mounted) return;

    Navigator.of(context).pop(<M3FilePickerResult>[
      M3FilePickerResult(
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: file.name,
        fileSize: fileSize,
        mediaSubtype: mediaSubtype,
      ),
    ]);
  }

  Future<void> _openMediaGrid(BuildContext context) async {
    if (kIsWeb) {
      // On Web, media gallery picker is not supported via photo_manager, so we open system file picker
      await _pickFile(
        context,
        type: FileType.media,
        mediaSubtype: 'media',
      );
      return;
    }

    final List<MediaGridPickerResult>? results =
        await showModalBottomSheet<List<MediaGridPickerResult>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const MediaGridPicker(),
    );

    if (results == null || results.isEmpty || !context.mounted) return;

    final List<M3FilePickerResult> converted = results
        .where((r) => r.filePath.isNotEmpty)
        .map((r) => M3FilePickerResult(
              filePath: r.filePath,
              fileName: r.fileName,
              fileSize: r.fileSize,
              mediaSubtype: 'media',
            ))
        .toList();

    if (converted.isEmpty) return;

    Navigator.of(context).pop(converted);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<_AttachItem> items = <_AttachItem>[
      _AttachItem(
        icon: Icons.photo_rounded,
        label: context.l10n.filePickerGallery,
        containerColor: scheme.primaryContainer,
        iconColor: scheme.onPrimaryContainer,
        onTap: () => _openMediaGrid(context),
      ),
      _AttachItem(
        icon: Icons.description_rounded,
        label: context.l10n.filePickerDocument,
        containerColor: scheme.secondaryContainer,
        iconColor: scheme.onSecondaryContainer,
        onTap: () => _pickFile(
          context,
          type: FileType.custom,
          allowedExtensions: const <String>[
            'pdf',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'txt',
            'zip',
            'apk',
          ],
          mediaSubtype: 'media',
        ),
      ),
      _AttachItem(
        icon: Icons.music_note_rounded,
        label: context.l10n.filePickerAudio,
        containerColor: scheme.tertiaryContainer,
        iconColor: scheme.onTertiaryContainer,
        onTap: () => _pickFile(
          context,
          type: FileType.audio,
          mediaSubtype: 'media',
        ),
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                context.l10n.filePickerFile,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: items.map((_AttachItem item) {
                return InkWell(
                  onTap: () => item.onTap(),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: item.containerColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            item.icon,
                            color: item.iconColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AttachItem {
  const _AttachItem({
    required this.icon,
    required this.label,
    required this.containerColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color containerColor;
  final Color iconColor;
  final VoidCallback onTap;
}
