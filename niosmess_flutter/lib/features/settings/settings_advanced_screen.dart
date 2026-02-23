import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_provider.dart';
import '../../ui/widgets/animated_list_item.dart';

class SettingsAdvancedScreen extends ConsumerWidget {
  const SettingsAdvancedScreen({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final reduceMotion = settings['reduce_motion'] ?? false;
    final hardwareAccel = settings['hardware_acceleration'] ?? true;
    final smoothScroll = settings['smooth_scrolling'] ?? true;
    final repaintBoundaries = settings['repaint_boundaries'] ?? true;
    final imageCache = settings['image_caching'] ?? true;
    final experimental = settings['experimental_features'] ?? false;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              color: colorScheme.surface.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back),
          ),
        ),
        title: Text(
          'Дополнительно',
          style: textTheme.titleLarge?.copyWith(
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
              child: _buildPerformanceSection(
                context,
                ref,
                reduceMotion,
                hardwareAccel,
                smoothScroll,
                repaintBoundaries,
                imageCache,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 1,
              child: _buildExperimentalSection(context, ref, experimental),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 2,
              child: _buildAboutSection(context),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection(
    BuildContext context,
    WidgetRef ref,
    bool reduceMotion,
    bool hardwareAccel,
    bool smoothScroll,
    bool repaintBoundaries,
    bool imageCache,
  ) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 100, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.speed_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Производительность',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                _buildAnimatedSwitch(
                  context,
                  title: 'Аппаратное ускорение',
                  subtitle: 'Использовать GPU для рендеринга',
                  icon: Icons.memory_outlined,
                  value: hardwareAccel,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('hardware_acceleration', v),
                ),
                const Divider(height: 1, indent: 56),
                _buildAnimatedSwitch(
                  context,
                  title: 'Плавный скроллинг',
                  subtitle: '120Hz анимации прокрутки',
                  icon: Icons.swipe_outlined,
                  value: smoothScroll,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('smooth_scrolling', v),
                ),
                const Divider(height: 1, indent: 56),
                _buildAnimatedSwitch(
                  context,
                  title: 'Repaint Boundaries',
                  subtitle: 'Оптимизация перерисовки виджетов',
                  icon: Icons.auto_fix_high_outlined,
                  value: repaintBoundaries,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('repaint_boundaries', v),
                ),
                const Divider(height: 1, indent: 56),
                _buildAnimatedSwitch(
                  context,
                  title: 'Кэширование изображений',
                  subtitle: 'Сохранять изображения в памяти',
                  icon: Icons.image_outlined,
                  value: imageCache,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('image_caching', v),
                ),
                const Divider(height: 1, indent: 56),
                _buildAnimatedSwitch(
                  context,
                  title: 'Снизить анимации',
                  subtitle: 'Подходит для слабых устройств',
                  icon: Icons.animation_outlined,
                  value: reduceMotion,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('reduce_motion', v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperimentalSection(BuildContext context, WidgetRef ref, bool experimental) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 18,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Экспериментальные',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: experimental
                    ? Border.all(
                        color: colorScheme.tertiary.withOpacity(0.5),
                        width: 2,
                      )
                    : null,
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    title: Text(
                      'Бета‑функции',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Включить нестабильные возможности',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: experimental,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('experimental_features', v),
                  ),
                  if (experimental)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 16,
                            color: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Экспериментальные функции могут работать нестабильно',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.tertiary,
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
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'О приложении',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                _buildAboutTile(
                  context,
                  icon: Icons.info_outline,
                  title: 'Версия',
                  subtitle: 'NiosMess v2.0.0',
                ),
                const Divider(height: 1, indent: 56),
                _buildAboutTile(
                  context,
                  icon: Icons.code_outlined,
                  title: 'Разработчик',
                  subtitle: 'Nios Team',
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(
                    'Лицензии',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'NiosMess',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: value 
              ? colorScheme.primaryContainer 
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: value 
              ? colorScheme.onPrimaryContainer 
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildAboutTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
