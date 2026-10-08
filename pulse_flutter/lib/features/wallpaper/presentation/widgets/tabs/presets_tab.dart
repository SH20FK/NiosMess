import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/wallpaper/domain/wallpaper_preset.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

class PresetsTab extends StatelessWidget {
  const PresetsTab({
    required this.currentConfig,
    required this.onSelectConfig,
    super.key,
  });

  final ChatWallpaperConfig currentConfig;
  final ValueChanged<ChatWallpaperConfig> onSelectConfig;

  void _generateVariant() {
    HapticService.selection();
    final Random random = Random();
    final int nextSeed = random.nextInt(9999);
    final List<WallpaperLayoutMode> modes = WallpaperLayoutMode.values;
    final WallpaperLayoutMode nextMode = modes[random.nextInt(modes.length)];
    final double nextDensity = 0.45 + random.nextDouble() * 0.40;

    final ChatWallpaperConfig variant = currentConfig.copyWith(
      seed: nextSeed,
      layoutMode: nextMode,
      density: nextDensity,
    );
    onSelectConfig(variant);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Generate variant button
          FilledButton.tonalIcon(
            onPressed: _generateVariant,
            icon: const Icon(Icons.shuffle_rounded),
            label: const Text('Сгенерировать вариант'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),

          // Curated Presets Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kCuratedWallpaperPresets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemBuilder: (BuildContext ctx, int index) {
              final CuratedWallpaperPreset preset = kCuratedWallpaperPresets[index];
              final bool isSelected = currentConfig.seed == preset.config.seed &&
                  currentConfig.layoutMode == preset.config.layoutMode;

              return InkWell(
                onTap: () {
                  HapticService.selection();
                  onSelectConfig(preset.config);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Icon(
                            preset.icon,
                            color: isSelected ? scheme.onPrimaryContainer : scheme.primary,
                            size: 22,
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            preset.name,
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.description,
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: isSelected ? scheme.onPrimaryContainer.withValues(alpha: 0.8) : scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
