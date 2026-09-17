import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

/// Reusable horizontal strip displaying attached photos/videos for post composers.
class PostMediaStrip extends StatelessWidget {
  const PostMediaStrip({
    super.key,
    required this.selectedFiles,
    required this.previewBytesList,
    required this.onRemove,
    this.onAdd,
    this.isLoading = false,
    this.maxFiles = 5,
    this.tileSize = 80.0,
  });

  final List<PlatformFile> selectedFiles;
  final List<Uint8List> previewBytesList;
  final void Function(int index) onRemove;
  final VoidCallback? onAdd;
  final bool isLoading;
  final int maxFiles;
  final double tileSize;

  static bool isVideoFile(String name) {
    final String ext = name.split('.').last.toLowerCase();
    return ext == 'mp4' ||
        ext == 'mov' ||
        ext == 'mkv' ||
        ext == 'webm' ||
        ext == 'avi' ||
        ext == '3gp';
  }

  @override
  Widget build(BuildContext context) {
    if (selectedFiles.isEmpty) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool canAddMore = selectedFiles.length < maxFiles && onAdd != null;
    final int itemCount = selectedFiles.length + (canAddMore ? 1 : 0);

    return SizedBox(
      height: tileSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          if (index == selectedFiles.length) {
            // [+] Add more media slot
            return Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isLoading ? null : onAdd,
                child: Container(
                  width: tileSize,
                  height: tileSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 22,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.l10n.postAttachMedia,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final PlatformFile file = selectedFiles[index];
          final bool isVideo = isVideoFile(file.name);
          final bool hasValidBytes = index < previewBytesList.length &&
              previewBytesList[index].isNotEmpty;

          return Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: isVideo
                    ? Container(
                        width: tileSize,
                        height: tileSize,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.videocam_rounded,
                              size: 28,
                              color: scheme.primary,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Видео',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : hasValidBytes
                        ? Image.memory(
                            previewBytesList[index],
                            width: tileSize,
                            height: tileSize,
                            cacheWidth: 200,
                            cacheHeight: 200,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: tileSize,
                            height: tileSize,
                            color: scheme.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 24,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: scheme.scrim.withValues(alpha: 0.65),
                  shape: const CircleBorder(),
                  child: Tooltip(
                    message: context.l10n.postRemove,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isLoading ? null : () => onRemove(index),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
