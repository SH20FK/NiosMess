import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

class PatternTab extends StatelessWidget {
  const PatternTab({
    required this.config,
    required this.onChanged,
    super.key,
  });

  final ChatWallpaperConfig config;
  final ValueChanged<ChatWallpaperConfig> onChanged;

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
          // Layout Mode Selector
          Text('Расположение элементов', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<WallpaperLayoutMode>(
            segments: const <ButtonSegment<WallpaperLayoutMode>>[
              ButtonSegment(value: WallpaperLayoutMode.grid, label: Text('Сетка')),
              ButtonSegment(value: WallpaperLayoutMode.stagger, label: Text('Ряды')),
              ButtonSegment(value: WallpaperLayoutMode.scatter, label: Text('Хаос')),
              ButtonSegment(value: WallpaperLayoutMode.hex, label: Text('Hex')),
            ],
            selected: <WallpaperLayoutMode>{config.layoutMode},
            onSelectionChanged: (Set<WallpaperLayoutMode> selected) {
              onChanged(config.copyWith(layoutMode: selected.first));
            },
          ),
          const SizedBox(height: 18),

          // Density Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Плотность узора', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text('${(config.density * 100).toInt()}%', style: textTheme.labelMedium),
            ],
          ),
          Slider(
            value: config.density.clamp(0.1, 1.0),
            min: 0.1,
            max: 1.0,
            divisions: 18,
            onChanged: (double val) {
              onChanged(config.copyWith(density: val));
            },
          ),
          const SizedBox(height: 12),

          // Cell Size Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Размер ячейки', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text('${config.cellSize.toInt()} dp', style: textTheme.labelMedium),
            ],
          ),
          Slider(
            value: config.cellSize.clamp(32.0, 128.0),
            min: 32.0,
            max: 128.0,
            divisions: 24,
            onChanged: (double val) {
              onChanged(config.copyWith(cellSize: val));
            },
          ),
          const SizedBox(height: 12),

          // Filled vs Outline switch
          SwitchListTile(
            title: const Text('Сплошная заливка'),
            subtitle: const Text('Залитые силуэты вместо контурных линий'),
            value: config.filled,
            onChanged: (bool val) {
              onChanged(config.copyWith(filled: val));
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),

          // Rotation jitter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Случайный поворот', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text('${config.randomRotationDeg.toInt()}°', style: textTheme.labelMedium),
            ],
          ),
          Slider(
            value: config.randomRotationDeg.clamp(0.0, 45.0),
            min: 0.0,
            max: 45.0,
            divisions: 9,
            onChanged: (double val) {
              onChanged(config.copyWith(randomRotationDeg: val));
            },
          ),
        ],
      ),
    );
  }
}
