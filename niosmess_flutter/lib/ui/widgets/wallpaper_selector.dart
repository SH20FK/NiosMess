import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../core/wallpaper_provider.dart';

/// Widget for selecting and previewing chat wallpapers
class WallpaperSelector extends ConsumerWidget {
  const WallpaperSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaper = ref.watch(wallpaperProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview Area
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Wallpaper
                if (wallpaper.wallpaperUrl != null)
                  Image.network(
                    wallpaper.wallpaperUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  )
                else
                  Container(color: colorScheme.background),

                // Blur overlay
                if (wallpaper.blurAmount > 0)
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: wallpaper.blurAmount,
                      sigmaY: wallpaper.blurAmount,
                    ),
                    child: Container(color: Colors.transparent),
                  ),

                // Opacity overlay
                Container(
                  color: Colors.black.withOpacity(1 - wallpaper.opacity),
                ),

                // Sample messages
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Входящее сообщение',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Исходящее сообщение',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Preset Wallpapers
        Text(
          'Пресеты обоев',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: WallpaperNotifier.presetWallpapers.length,
            itemBuilder: (context, index) {
              final url = WallpaperNotifier.presetWallpapers[index];
              final isSelected = wallpaper.wallpaperUrl == url;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => ref.read(wallpaperProvider.notifier).setWallpaper(url),
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              color: colorScheme.primary.withOpacity(0.3),
                              child: Icon(
                                Icons.check,
                                color: colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Adjustments
        _buildSlider(
          title: 'Размытие',
          value: wallpaper.blurAmount,
          max: 20,
          onChanged: (value) => ref.read(wallpaperProvider.notifier).setBlurAmount(value),
        ),
        const SizedBox(height: 16),
        _buildSlider(
          title: 'Непрозрачность',
          value: wallpaper.opacity,
          onChanged: (value) => ref.read(wallpaperProvider.notifier).setOpacity(value),
        ),
        const SizedBox(height: 16),
        _buildToggle(
          title: 'Параллакс эффект',
          value: wallpaper.useParallax,
          onChanged: (value) => ref.read(wallpaperProvider.notifier).setUseParallax(value),
        ),
        const SizedBox(height: 24),

        // Clear Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => ref.read(wallpaperProvider.notifier).clearWallpaper(),
            icon: const Icon(Icons.clear),
            label: const Text('Убрать обои'),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String title,
    required double value,
    double max = 1.0,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              max == 1.0 ? '${(value * 100).toInt()}%' : '${value.toInt()}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
