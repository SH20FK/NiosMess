import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsEnergySavingScreen extends ConsumerWidget {
  const SettingsEnergySavingScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  String _thresholdLabel(int val) {
    if (val <= 0) return 'Отключено';
    if (val >= 100) return 'Всегда включено';
    return 'При заряде ниже $val%';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SettingsShell(
      title: 'Энергосбережение',
      isEmbedded: isEmbedded,
      children: <Widget>[
        SettingsNavBanner(
          illustrationCategory: SettingsIllustrationCategory.preferences,
          subtitle: 'Управление анимациями и расходом батареи',
          iconColor: scheme.primary,
        ),

        // 1. Master Battery Threshold Card
        SettingsSection(
          title: 'Автоматическое включение',
          subtitle: 'Укажите уровень заряда батареи, при котором приложение автоматически перейдёт в режим экономии',
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            settings.energySavingThreshold > 0
                                ? Icons.battery_saver_rounded
                                : Icons.battery_std_rounded,
                            color: scheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Порог активации',
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _thresholdLabel(settings.energySavingThreshold),
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: scheme.primary,
                      inactiveTrackColor: scheme.surfaceContainerHighest,
                      thumbColor: scheme.primary,
                      overlayColor: scheme.primary.withValues(alpha: 0.12),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: settings.energySavingThreshold.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 10,
                      label: _thresholdLabel(settings.energySavingThreshold),
                      onChanged: (double val) {
                        HapticService.selection();
                        ref
                            .read(uiSettingsProvider.notifier)
                            .setEnergySavingThreshold(val.round());
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        '0% (Выкл)',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '10%',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '20%',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '100% (Всегда)',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // 2. Chat Animations
        SettingsSection(
          title: 'Анимации в чатах',
          subtitle: 'Отключение визуальных эффектов существенно продлевает время автономной работы',
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.auto_awesome_motion_rounded,
              title: 'Анимация стикеров',
              subtitle: 'Автоматически воспроизводить стикеры в чате',
              iconColor: scheme.secondary,
              value: settings.animateStickers,
              onChanged: (bool val) {
                ref.read(uiSettingsProvider.notifier).setAnimateStickers(val);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.mood_rounded,
              title: 'Анимированные эмодзи',
              subtitle: 'Воспроизводить живые эмодзи в сообщениях и реакциях',
              iconColor: scheme.secondary,
              value: settings.animateEmoji,
              onChanged: (bool val) {
                ref.read(uiSettingsProvider.notifier).setAnimateEmoji(val);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.flare_rounded,
              title: 'Эффекты чата',
              subtitle: 'Вспышки, частицы и конфетти при отправке сообщений',
              iconColor: scheme.secondary,
              value: settings.chatEffectsEnabled,
              onChanged: (bool val) {
                ref.read(uiSettingsProvider.notifier).setChatEffectsEnabled(val);
              },
            ),
          ],
        ),

        // 3. Device & Graphics Optimization
        SettingsSection(
          title: 'Рендеринг и графические эффекты',
          subtitle: 'Снижение нагрузки на графический процессор (GPU)',
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.speed_rounded,
              title: 'Оптимизация для слабых устройств',
              subtitle: 'Отключает шейдерные размытия и градиенты в пользу высокой частоты кадров',
              iconColor: scheme.primary,
              value: settings.optimizeForWeakDevices,
              onChanged: (bool val) {
                ref
                    .read(uiSettingsProvider.notifier)
                    .setOptimizeForWeakDevices(val);
              },
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}
