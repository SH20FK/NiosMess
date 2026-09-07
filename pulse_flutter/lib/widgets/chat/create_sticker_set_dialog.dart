import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';

class CreateStickerSetDialog extends ConsumerStatefulWidget {
  const CreateStickerSetDialog({super.key});

  static Future<ApiStickerSet?> show(BuildContext context) {
    return AppBottomSheets.show<ApiStickerSet>(
      context: context,
      builder: (BuildContext ctx) => const CreateStickerSetDialog(),
    );
  }

  @override
  ConsumerState<CreateStickerSetDialog> createState() =>
      _CreateStickerSetDialogState();
}

class _CreateStickerSetDialogState extends ConsumerState<CreateStickerSetDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emojiController = TextEditingController(text: '✨');

  bool _isPublic = true;
  bool _isLoading = false;

  Uint8List? _pickedBytes;
  String? _pickedFilename;

  @override
  void dispose() {
    _titleController.dispose();
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final List<PlatformFile> picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>[
          'png',
          'webp',
          'jpg',
          'jpeg',
          'gif',
          'mp4',
          'webm',
          'mov',
        ],
      );

      if (picked.isEmpty) return;

      final PlatformFile file = picked.first;
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          AppToast.showError(context, 'Не удалось прочитать выбранный файл');
        }
        return;
      }

      final String ext = (file.extension ?? '').toLowerCase();
      final bool isVideoOrGif =
          ext == 'mp4' || ext == 'webm' || ext == 'mov' || ext == 'gif';
      final int maxBytes =
          isVideoOrGif ? 25 * 1024 * 1024 : 5 * 1024 * 1024;

      if (bytes.length > maxBytes) {
        if (mounted) {
          AppToast.showError(
            context,
            isVideoOrGif
                ? 'Видео/GIF стикер не должен превышать 25 МБ'
                : 'Изображение стикера не должно превышать 5 МБ',
          );
        }
        return;
      }

      setState(() {
        _pickedBytes = bytes;
        _pickedFilename = file.name.isNotEmpty ? file.name : 'sticker.$ext';
      });
      HapticService.tap();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Ошибка выбора файла: $e');
      }
    }
  }

  Future<void> _onSubmit() async {
    final String title = _titleController.text.trim();
    String name = _nameController.text.trim().toLowerCase();

    if (title.isEmpty) {
      AppToast.showError(context, 'Введите название стикерпака');
      return;
    }

    if (name.isEmpty) {
      // Auto-generate name slug from title
      name = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      if (name.isEmpty) name = 'pack_${DateTime.now().millisecondsSinceEpoch}';
    }

    if (_pickedBytes == null || _pickedFilename == null) {
      AppToast.showError(context, 'Выберите первый стикер (обложку набора)');
      return;
    }

    setState(() => _isLoading = true);
    HapticService.confirm();

    try {
      final ApiStickerSet newSet = await ref
          .read(stickerSetsProvider.notifier)
          .createStickerSet(
            name: name,
            title: title,
            isPublic: _isPublic,
          );

      final String base64Data = base64Encode(_pickedBytes!);
      final String emoji = _emojiController.text.trim().isNotEmpty
          ? _emojiController.text.trim()
          : '✨';

      await ref.read(stickerSetsProvider.notifier).addSticker(
            setId: newSet.id,
            filename: _pickedFilename!,
            dataBase64: base64Data,
            emoji: emoji,
          );

      if (mounted) {
        AppToast.showSuccess(context, 'Стикерпак успешно создан!');
        Navigator.pop(context, newSet);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Не удалось создать стикерпак: $e');
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Новый стикерпак',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Title input
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Название набора',
              hintText: 'Например: Милые котики',
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 12),

          // Name (slug) input
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Короткое имя (slug)',
              hintText: 'cute_cats',
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 12),

          // Public toggle
          SwitchListTile.adaptive(
            value: _isPublic,
            onChanged: (bool value) => setState(() => _isPublic = value),
            title: const Text('Публичный набор'),
            subtitle: Text(
              'Будет доступен другим пользователям по ссылке',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),

          // Initial sticker file selector
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _pickedBytes != null
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.5),
                  width: _pickedBytes != null ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _pickedBytes != null
                        ? Image.memory(_pickedBytes!, fit: BoxFit.contain)
                        : Icon(
                            Icons.add_photo_alternate_outlined,
                            color: scheme.primary,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _pickedFilename ?? 'Выбрать стикер (обложка)',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _pickedFilename != null
                                ? scheme.onSurface
                                : scheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PNG, WebP, GIF, MP4 (до 5 / 25 МБ)',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Associated emoji
          TextField(
            controller: _emojiController,
            decoration: InputDecoration(
              labelText: 'Связанный эмодзи',
              hintText: '🐱',
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.emoji_emotions_outlined),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _isLoading ? null : _onSubmit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Text(
                      'Создать набор',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
