import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:universal_io/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';

class M3FilePickerResult {
  M3FilePickerResult({
    required this.readStream,
    required this.fileName,
    required this.fileSize,
    required this.mediaSubtype,
    this.filePath,
  });

  final Stream<List<int>>? readStream;
  final String fileName;
  final int fileSize;
  final String mediaSubtype;
  final String? filePath;

  FileTypeInfo get typeInfo => FileTypeDetector.detect(fileName: fileName);
  String get formattedSize => FileTypeDetector.formatFileSize(fileSize);
}

Future<M3FilePickerResult?> showM3FilePicker(BuildContext context) async {
  return AppBottomSheets.show<M3FilePickerResult>(
    context: context,
    builder: (BuildContext ctx) => _CompactAttachmentMenu(),
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
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );

    if (result == null || result.files.isEmpty || !context.mounted) return;

    final PlatformFile file = result.files.first;
    final Stream<List<int>>? readStream = file.readStream;
    final String? filePath = file.path;

    if (readStream == null && filePath == null) {
      AppToast.showError(context, context.l10n.filePickerReadError);
      return;
    }

    Navigator.of(context).pop(
      M3FilePickerResult(
        readStream: readStream,
        filePath: filePath,
        fileName: file.name,
        fileSize: file.size,
        mediaSubtype: mediaSubtype,
      ),
    );
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
        onTap: () => _pickFile(context, type: FileType.media, mediaSubtype: 'media'),
      ),
      _AttachItem(
        icon: Icons.description_rounded,
        label: context.l10n.filePickerDocument,
        containerColor: scheme.secondaryContainer,
        iconColor: scheme.onSecondaryContainer,
        onTap: () => _pickFile(
          context,
          type: FileType.custom,
          allowedExtensions: const <String>['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
          mediaSubtype: 'media',
        ),
      ),
      _AttachItem(
        icon: Icons.music_note_rounded,
        label: context.l10n.filePickerAudio,
        containerColor: scheme.tertiaryContainer,
        iconColor: scheme.onTertiaryContainer,
        onTap: () => _pickFile(context, type: FileType.audio, mediaSubtype: 'voice'),
      ),
      _AttachItem(
        icon: Icons.folder_rounded,
        label: context.l10n.filePickerFile,
        containerColor: scheme.surfaceContainerHighest,
        iconColor: scheme.onSurfaceVariant,
        onTap: () => _pickFile(context, type: FileType.any, mediaSubtype: 'media'),
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          children: items.map(_buildGridItem).toList(),
        ),
      ),
    );
  }

  Widget _buildGridItem(_AttachItem item) {
    return Builder(
      builder: (BuildContext ctx) {
        final TextTheme textTheme = Theme.of(ctx).textTheme;
        return InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: item.containerColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttachItem {
  _AttachItem({
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
