import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';

class FileUploadProgressWidget extends StatelessWidget {
  const FileUploadProgressWidget({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.progress,
    this.onCancel,
  });

  final String fileName;
  final int fileSize;
  final double progress;
  final VoidCallback? onCancel;

  FileTypeInfo get typeInfo => FileTypeDetector.detect(fileName: fileName);

  String get _sizeLabel => FileTypeDetector.formatFileSize(fileSize);

  String get _progressLabel {
    final int percent = (progress * 100).clamp(0, 100).toInt();
    final int sent = (fileSize * progress.clamp(0, 1)).toInt();
    return '$percent% • ${FileTypeDetector.formatFileSize(sent)} / $_sizeLabel';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(typeInfo.color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                   getIconDataByName(typeInfo.icon),
                  color: Color(typeInfo.color),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _progressLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onCancel != null)
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
