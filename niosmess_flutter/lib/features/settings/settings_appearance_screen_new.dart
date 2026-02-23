import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:dynamic_color/dynamic_color.dart';
import '../../core/theme_provider.dart';
import '../../core/bubble_style_provider.dart';
import '../../core/settings_provider.dart';
import '../../ui/widgets/animated_list_item.dart';

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
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: onBack,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back),
              ),
            ),
            title: Text(
              'Внешний вид',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
          ),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: AnimatedListItem(
                  index: 0,
                  child: _buildThemeSection(context, ref, themeState, dynamicAvailable),
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedListItem(
                  index: 1,
                  child: _buildTextSection(context, ref, textScale),
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedListItem(
                  index: 2,
                  child: _buildMessagesSection(context, ref, bubbleStyle),
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedListItem(
                  index: 3,
                  child: _buildLivePreview(context, ref, themeState, bubbleStyle),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeSection(BuildContext context, WidgetRef ref, ThemeState themeState, bool dynamicAvailable) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 100, 16, 8),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Тема',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              Text(
                'Цветовая схема',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _SeedColorPicker(
                current: themeState.seedColor,
                onPick: (color) => ref.read(themeProvider.notifier).setSeedColor(color),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: themeState.useDynamicColor,
                onChanged: dynamicAvailable
                    ? (value) => ref.read(themeProvider.notifier).setUseDynamicColor(value)
                    : null,
                title: const Text('Динамические цвета'),
                subtitle: Text(dynamicAvailable ? 'Android 12+' : 'Недоступно на этом устройстве'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextSection(BuildContext context, WidgetRef ref, double textScale) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Размер текста',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Пример текста для проверки читаемости.',
                  textScaler: TextScaler.linear(textScale),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesSection(BuildContext context, WidgetRef ref, bubbleStyle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Сообщения',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Скругление пузырей',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 20),
              Text(
                'Внутренний отступ',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => ref.read(bubbleStyleProvider.notifier).resetToDefaults(),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Сбросить стиль'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreview(BuildContext context, WidgetRef ref, ThemeState themeState, bubbleStyle) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Предпросмотр чата',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Incoming message
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.all(bubbleStyle.bubblePadding),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(bubbleStyle.cornerRadius),
                            topRight: Radius.circular(bubbleStyle.cornerRadius),
                            bottomRight: Radius.circular(bubbleStyle.cornerRadius),
                            bottomLeft: const Radius.circular(4),
                          ),
                        ),
                        child: Text(
                          'Привет! Как дела?',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Outgoing message
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: EdgeInsets.all(bubbleStyle.bubblePadding),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(bubbleStyle.cornerRadius),
                            topRight: Radius.circular(bubbleStyle.cornerRadius),
                            bottomLeft: Radius.circular(bubbleStyle.cornerRadius),
                            bottomRight: const Radius.circular(4),
                          ),
                        ),
                        child: Text(
                          'Отлично! Спасибо 😊',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
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
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFF2563EB), // Blue
      const Color(0xFF0EA5A8), // Cyan
      const Color(0xFF16A34A), // Green
      const Color(0xFFF97316), // Orange
      const Color(0xFFDB2777), // Pink
      const Color(0xFF7C3AED), // Violet
      const Color(0xFFDC2626), // Red
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ...presets.map((color) {
          final selected = color.value == current.value;
          return GestureDetector(
            onTap: () => onPick(color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
                    )
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
          label: const Text('Свой'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
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
