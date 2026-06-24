import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';

class FileAttachmentChip extends StatelessWidget {
  const FileAttachmentChip({
    super.key,
    required this.fileName,
    required this.fileSize,
    this.onTap,
    this.onRemove,
  });

  final String fileName;
  final int fileSize;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  FileTypeInfo get typeInfo => FileTypeDetector.detect(fileName: fileName);

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Color(typeInfo.color).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color(typeInfo.color).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconData(typeInfo.icon),
              color: Color(typeInfo.color),
              size: 18,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
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
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'image':
        return Icons.image_rounded;
      case 'videocam':
        return Icons.videocam_rounded;
      case 'audiotrack':
        return Icons.audiotrack_rounded;
      case 'description':
        return Icons.description_rounded;
      case 'android':
        return Icons.android_rounded;
      case 'desktop_windows':
        return Icons.desktop_windows_rounded;
      case 'folder_zip':
        return Icons.folder_zip_rounded;
      case 'text_snippet':
        return Icons.text_snippet_rounded;
      case 'code':
        return Icons.code_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
