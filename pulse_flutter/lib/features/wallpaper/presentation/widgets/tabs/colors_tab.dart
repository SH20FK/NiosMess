import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

class ColorsTab extends StatelessWidget {
  const ColorsTab({
    required this.config,
    required this.onChanged,
    super.key,
  });

  final ChatWallpaperConfig config;
  final ValueChanged<ChatWallpaperConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Background Style
          Text('Стиль фона', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<WallpaperBackgroundStyle>(
            segments: const <ButtonSegment<WallpaperBackgroundStyle>>[
              ButtonSegment(value: WallpaperBackgroundStyle.solid, label: Text('Однотонный')),
              ButtonSegment(value: WallpaperBackgroundStyle.linearGradient, label: Text('Градиент')),
              ButtonSegment(value: WallpaperBackgroundStyle.radialGlow, label: Text('Свечение')),
            ],
            selected: <WallpaperBackgroundStyle>{config.backgroundStyle},
            onSelectionChanged: (Set<WallpaperBackgroundStyle> selected) {
              onChanged(config.copyWith(backgroundStyle: selected.first));
            },
          ),
          const SizedBox(height: 18),

          // Color Palette Mode
          Text('Режим цвета узора', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<WallpaperColorMode>(
            segments: const <ButtonSegment<WallpaperColorMode>>[
              ButtonSegment(value: WallpaperColorMode.singleTone, label: Text('Моно')),
              ButtonSegment(value: WallpaperColorMode.tonalAccent, label: Text('Акцент')),
              ButtonSegment(value: WallpaperColorMode.palette, label: Text('Палитра')),
            ],
            selected: <WallpaperColorMode>{config.colorMode},
            onSelectionChanged: (Set<WallpaperColorMode> selected) {
              onChanged(config.copyWith(colorMode: selected.first));
            },
          ),
          const SizedBox(height: 18),

          // Icon Transparency / Alpha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Прозрачность узора', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text('${(config.iconAlpha * 100).toInt()}%', style: textTheme.labelMedium),
            ],
          ),
          Slider(
            value: config.iconAlpha.clamp(0.04, 0.40),
            min: 0.04,
            max: 0.40,
            divisions: 18,
            onChanged: (double val) {
              onChanged(config.copyWith(iconAlpha: val));
            },
          ),
        ],
      ),
    );
  }
}
