import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:dynamic_color/dynamic_color.dart';
import '../../core/theme_provider.dart';
import '../../core/bubble_style_provider.dart';
import '../../core/settings_provider.dart';

class SettingsAppearanceScreen extends ConsumerWidget {
  const SettingsAppearanceScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final bubbleStyle = ref.watch(bubbleStyleProvider);
    final settings = ref.watch(settingsProvider);
    final textScale = (settings['text_scale'] as num?)?.toDouble() ?? 1.0;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final dynamicAvailable = lightDynamic != null && darkDynamic != null;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            title: const Text('Внешний вид'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
          Text('Тема', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Система'),
                        icon: Icon(Icons.settings),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Светлая'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Темная'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {themeState.mode},
                    onSelectionChanged: (value) {
                      ref.read(themeProvider.notifier).setThemeMode(value.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Цветовая схема', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 12),
                  _SeedColorPicker(
                    current: themeState.seedColor,
                    onPick: (color) => ref.read(themeProvider.notifier).setSeedColor(color),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: themeState.useDynamicColor,
                    onChanged: dynamicAvailable
                        ? (value) => ref.read(themeProvider.notifier).setUseDynamicColor(value)
                        : null,
                    title: const Text('Динамические цвета'),
                    subtitle: Text(dynamicAvailable ? 'Android 12+' : 'Недоступно на этом устройстве'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Текст', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Размер текста', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Slider(
                    value: textScale,
                    min: 0.85,
                    max: 1.15,
                    divisions: 6,
                    label: '${(textScale * 100).round()}%',
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setSetting('text_scale', value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Пример текста для проверки читаемости.',
                      textScaler: TextScaler.linear(textScale),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Сообщения', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Скругление пузырей', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Slider(
                    value: bubbleStyle.cornerRadius,
                    min: 8,
                    max: 24,
                    divisions: 8,
                    label: bubbleStyle.cornerRadius.round().toString(),
                    onChanged: (value) {
                      ref.read(bubbleStyleProvider.notifier).setCornerRadius(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('Внутренний отступ', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Slider(
                    value: bubbleStyle.bubblePadding,
                    min: 8,
                    max: 20,
                    divisions: 6,
                    label: bubbleStyle.bubblePadding.round().toString(),
                    onChanged: (value) {
                      ref.read(bubbleStyleProvider.notifier).setBubblePadding(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => ref.read(bubbleStyleProvider.notifier).resetToDefaults(),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Сбросить стиль'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _BubblePreview(
                    radius: bubbleStyle.cornerRadius,
                    padding: bubbleStyle.bubblePadding,
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        );
      },
    );
  }
}

class _SeedColorPicker extends StatelessWidget {
  const _SeedColorPicker({
    required this.current,
    required this.onPick,
  });

  final Color current;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    final presets = <Color>[
      const Color(0xFF4F46E5),
      const Color(0xFF2563EB),
      const Color(0xFF0EA5A8),
      const Color(0xFF16A34A),
      const Color(0xFFF97316),
      const Color(0xFFDB2777),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ...presets.map((color) {
          final selected = color.value == current.value;
          return GestureDetector(
            onTap: () => onPick(color),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary)
                  : null,
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await _showColorPicker(context, current);
            if (picked != null) onPick(picked);
          },
          icon: const Icon(Icons.color_lens_outlined),
          label: const Text('Выбрать'),
        ),
      ],
    );
  }

  Future<Color?> _showColorPicker(BuildContext context, Color current) {
    return showDialog<Color>(
      context: context,
      builder: (context) {
        Color temp = current;
        return AlertDialog(
          title: const Text('Цвет темы'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: current,
              onColorChanged: (color) => temp = color,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, temp),
              child: const Text('Готово'),
            ),
          ],
        );
      },
    );
  }
}

class _BubblePreview extends StatelessWidget {
  const _BubblePreview({
    required this.radius,
    required this.padding,
  });

  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: const Text('Пример входящего сообщения'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Text(
              'Пример исходящего сообщения',
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
          ),
        ),
      ],
    );
  }
}
