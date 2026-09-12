import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/sticker_formatter.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';

class _PickedStickerFile {
  _PickedStickerFile({
    required this.rawBytes,
    required this.formattedBytes,
    required this.name,
    required this.extension,
    this.emoji = '✨',
    this.fitMode = StickerFitMode.fit,
  });

  final Uint8List rawBytes;
  Uint8List formattedBytes;
  final String name;
  String extension;
  String emoji;
  StickerFitMode fitMode;
  bool isFormatting = false;
}

class AddStickerDialog extends ConsumerStatefulWidget {
  const AddStickerDialog({
    required this.setId,
    this.setTitle,
    super.key,
  });

  final int setId;
  final String? setTitle;

  static Future<bool?> show(
    BuildContext context, {
    required int setId,
    String? setTitle,
  }) {
    return AppBottomSheets.show<bool>(
      context: context,
      builder: (BuildContext ctx) => AddStickerDialog(
        setId: setId,
        setTitle: setTitle,
      ),
    );
  }

  @override
  ConsumerState<AddStickerDialog> createState() => _AddStickerDialogState();
}

class _AddStickerDialogState extends ConsumerState<AddStickerDialog> {
  final List<_PickedStickerFile> _files = <_PickedStickerFile>[];
  final TextEditingController _globalEmojiController =
      TextEditingController(text: '✨');
  StickerFitMode _globalFitMode = StickerFitMode.fit;
  bool _isLoading = false;
  bool _isFormatting = false;
  int _uploadProgress = 0;

  static const List<String> _suggestedEmojis = <String>[
    '✨', '🔥', '😂', '❤️', '👍', '🥺', '🎉', '🚀', '🐱', '😎', '👏', '👀'
  ];

  @override
  void dispose() {
    _globalEmojiController.dispose();
    super.dispose();
  }

  Future<void> _changeFitMode(StickerFitMode mode) async {
    if (_globalFitMode == mode || _files.isEmpty) {
      setState(() => _globalFitMode = mode);
      return;
    }
    HapticService.tap();
    setState(() {
      _globalFitMode = mode;
      _isFormatting = true;
    });

    for (final _PickedStickerFile file in _files) {
      final StickerFormatResult res =
          await StickerFormatter.formatBytes(file.rawBytes, mode: mode);
      file.formattedBytes = res.bytes;
      file.extension = res.extension;
      file.fitMode = mode;
    }

    if (mounted) {
      setState(() => _isFormatting = false);
    }
  }

  Future<void> _pickFiles() async {
    try {
      final List<PlatformFile> picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>[
          'png',
          'webp',
          'jpg',
          'jpeg',
          'jfif',
          'gif',
          'bmp',
          'ico',
          'tiff',
          'svg',
          'mp4',
          'webm',
          'mov',
        ],
      );

      if (picked.isEmpty) return;

      setState(() => _isFormatting = true);

      final List<_PickedStickerFile> newFiles = <_PickedStickerFile>[];

      for (final PlatformFile file in picked) {
        final Uint8List bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;

        final String ext = (file.extension ?? '').toLowerCase();
        final bool isVideoOrGif =
            ext == 'mp4' || ext == 'webm' || ext == 'mov' || ext == 'gif';
        final int maxBytes =
            isVideoOrGif ? 25 * 1024 * 1024 : 10 * 1024 * 1024;

        if (bytes.length > maxBytes) {
          if (mounted) {
            AppToast.showError(
              context,
              'Файл "${file.name}" превышает лимит размера (${isVideoOrGif ? '25' : '10'} МБ)',
            );
          }
          continue;
        }

        // Auto-format any image on-device into compliant 512x512
        final StickerFormatResult formatted =
            await StickerFormatter.formatBytes(bytes, mode: _globalFitMode);

        newFiles.add(
          _PickedStickerFile(
            rawBytes: bytes,
            formattedBytes: formatted.bytes,
            name: file.name,
            extension: formatted.extension,
            emoji: _globalEmojiController.text.trim().isNotEmpty
                ? _globalEmojiController.text.trim()
                : '✨',
            fitMode: _globalFitMode,
          ),
        );
      }

      if (newFiles.isNotEmpty) {
        setState(() {
          _files.addAll(newFiles);
        });
        HapticService.tap();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Ошибка выбора файлов: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isFormatting = false);
      }
    }
  }

  Future<void> _submitUpload() async {
    if (_files.isEmpty) {
      AppToast.showError(context, 'Выберите хотя бы одно изображение или видео');
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });
    HapticService.confirm();

    int successCount = 0;
    final int total = _files.length;

    try {
      for (int i = 0; i < total; i++) {
        final _PickedStickerFile item = _files[i];
        final String base64Data = base64Encode(item.formattedBytes);
        final String safeFilename =
            'sticker_${widget.setId}_${DateTime.now().millisecondsSinceEpoch}_$i.${item.extension}';

        await ref.read(stickerSetsProvider.notifier).addSticker(
              setId: widget.setId,
              filename: safeFilename,
              dataBase64: base64Data,
              width: StickerFormatter.kStickerDimension,
              height: StickerFormatter.kStickerDimension,
              emoji: item.emoji.isNotEmpty ? item.emoji : '✨',
            );

        successCount++;
        if (mounted) {
          setState(() {
            _uploadProgress = successCount;
          });
        }
      }

      // Refresh full provider to synchronize with server state
      await ref.read(stickerSetsProvider.notifier).refresh();

      if (mounted) {
        AppToast.showSuccess(
          context,
          successCount == 1
              ? 'Стикер успешно добавлен!'
              : 'Добавлено стикеров: $successCount',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          'Загружено $successCount из $total. Ошибка: $e',
        );
        // Still refresh provider for partially uploaded stickers
        if (successCount > 0) {
          ref.read(stickerSetsProvider.notifier).refresh();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Google Pixel Drag Handle
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header with Material You styling
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add_photo_alternate_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.setTitle != null && widget.setTitle!.isNotEmpty
                            ? 'Добавить в «${widget.setTitle}»'
                            : 'Добавить стикеры',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Поддерживаются PNG, WEBP, GIF, видео до 25 МБ',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Emoji association bar with Pixel pills
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.tag_faces_rounded,
                          size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Привязать эмодзи',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 70,
                        height: 34,
                        child: TextField(
                          controller: _globalEmojiController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (String val) {
                            if (val.isNotEmpty) {
                              for (final file in _files) {
                                file.emoji = val;
                              }
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Quick suggestion chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _suggestedEmojis.map((String emoji) {
                      final bool isSelected =
                          _globalEmojiController.text == emoji;
                      return InkWell(
                        onTap: () {
                          HapticService.tap();
                          setState(() {
                            _globalEmojiController.text = emoji;
                            for (final file in _files) {
                              file.emoji = emoji;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? scheme.primary
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (_files.isNotEmpty) ...[
              SegmentedButton<StickerFitMode>(
                segments: const <ButtonSegment<StickerFitMode>>[
                  ButtonSegment(
                    value: StickerFitMode.fit,
                    icon: Icon(Icons.fit_screen_rounded, size: 16),
                    label: Text('Вписать целиком'),
                  ),
                  ButtonSegment(
                    value: StickerFitMode.crop,
                    icon: Icon(Icons.crop_square_rounded, size: 16),
                    label: Text('В квадрат'),
                  ),
                ],
                selected: <StickerFitMode>{_globalFitMode},
                onSelectionChanged: (Set<StickerFitMode> selected) =>
                    _changeFitMode(selected.first),
              ),
              const SizedBox(height: 12),
            ],

            // Files list or drop zone
            Expanded(
              child: _files.isEmpty
                  ? InkWell(
                      onTap: _pickFiles,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.cloud_upload_outlined,
                                size: 32,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Выбрать любые картинки',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Клиент автоматически конвертирует их в 512x512',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              'Выбрано стикеров: ${_files.length}',
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_isFormatting) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ],
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _pickFiles,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Добавить ещё'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 100,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: _files.length,
                            itemBuilder: (BuildContext context, int index) {
                              final _PickedStickerFile item = _files[index];
                              return Stack(
                                children: <Widget>[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? scheme.surfaceContainerHigh
                                          : const Color(0xFFF0F0F0),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: scheme.outlineVariant
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Center(
                                      child: item.extension == 'mp4' ||
                                              item.extension == 'webm' ||
                                              item.extension == 'mov'
                                          ? Icon(
                                              Icons.videocam_rounded,
                                              size: 32,
                                              color: scheme.primary,
                                            )
                                          : Image.memory(
                                              item.formattedBytes,
                                              fit: BoxFit.contain,
                                            ),
                                    ),
                                  ),
                                  // Emoji badge
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: scheme.surface.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.emoji,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  // Remove button
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: InkWell(
                                      onTap: () {
                                        HapticService.tap();
                                        setState(() {
                                          _files.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: scheme.error.withValues(alpha: 0.9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: scheme.onError,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Google Pixel Pill Action Button
            FilledButton.icon(
              onPressed: (_isLoading || _files.isEmpty) ? null : _submitUpload,
              icon: _isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                _isLoading
                    ? 'Загрузка ($_uploadProgress / ${_files.length})...'
                    : (_files.isEmpty
                        ? 'Выберите стикеры для загрузки'
                        : 'Загрузить в стикерпак (${_files.length})'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
