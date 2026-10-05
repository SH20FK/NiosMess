import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

class EffectsTab extends StatelessWidget {
  const EffectsTab({
    required this.config,
    required this.onChanged,
    super.key,
  });

  final ChatWallpaperConfig config;
  final ValueChanged<ChatWallpaperConfig> onChanged;

  Future<void> _pickImage(BuildContext context) async {
    try {
      final List<PlatformFile> result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (result.isNotEmpty && result.first.path != null) {
        onChanged(config.copyWith(imagePath: result.first.path));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final bool hasImage = config.imagePath != null && config.imagePath!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Photo wallpaper action
          if (!hasImage)
            FilledButton.tonalIcon(
              onPressed: () => _pickImage(context),
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(context.l10n.wallpaperChoosePhoto),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          else ...[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(context),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Сменить фото'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => onChanged(config.copyWith(imagePath: null)),
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.errorContainer.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image Dim Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(context.l10n.wallpaperPhotoDim, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text('${(config.imageDim * 100).toInt()}%', style: textTheme.labelMedium),
              ],
            ),
            Slider(
              value: config.imageDim.clamp(0.0, 0.8),
              min: 0.0,
              max: 0.8,
              divisions: 16,
              onChanged: (double val) {
                onChanged(config.copyWith(imageDim: val));
              },
            ),
            const SizedBox(height: 12),

            // Image Blur Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(context.l10n.wallpaperPhotoBlur, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text('${config.imageBlur.toInt()} px', style: textTheme.labelMedium),
              ],
            ),
            Slider(
              value: config.imageBlur.clamp(0.0, 20.0),
              min: 0.0,
              max: 20.0,
              divisions: 20,
              onChanged: (double val) {
                onChanged(config.copyWith(imageBlur: val));
              },
            ),
          ],

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.shield_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Размытие и затемнение предварительно рассчитываются в кэше для сохранения 60–120 FPS.',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
