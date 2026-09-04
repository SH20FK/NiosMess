import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsChatsScreen extends ConsumerWidget {
  const SettingsChatsScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  static const List<String> _quickReactionEmojis = <String>[
    '❤️',
    '👍',
    '🔥',
    '😂',
    '🎉',
    '⚡',
    '👏',
    '💩',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SettingsScaffold(
      title: 'Чаты и медиа',
      isEmbedded: isEmbedded,
      children: <Widget>[
        SettingsNavBanner(
          illustrationCategory: SettingsIllustrationCategory.preferences,
          title: 'Чаты и медиа',
          subtitle: 'Параметры ввода, быстрые реакции и автозагрузка медиа',
          iconColor: scheme.primary,
        ),

        // 1. Text input & Keyboard
        SettingsSection(
          title: 'Отправка сообщений',
          subtitle: 'Поведение клавиатуры и клавиши ввода',
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.keyboard_return_rounded,
              title: 'Отправка по клавише Enter',
              subtitle:
                  'На клавиатурах Enter отправляет сообщение, Shift + Enter выполняет перенос строки',
              iconColor: scheme.primary,
              value: settings.sendOnEnter,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setSendOnEnter(value);
              },
            ),
          ],
        ),

        // 2. Quick double-tap reaction
        SettingsSection(
          title: 'Быстрая реакция',
          subtitle: 'Эмодзи для мгновенной реакции при двойном нажатии на сообщение',
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          settings.doubleTapReactionEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Выбранный эмодзи',
                              style: textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Двойной тап по сообщению отправит эту реакцию',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _quickReactionEmojis.map((String emoji) {
                      final bool isSelected =
                          settings.doubleTapReactionEmoji == emoji;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticService.tap();
                            ref
                                .read(uiSettingsProvider.notifier)
                                .setDoubleTapReactionEmoji(emoji);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? scheme.primary
                                    : scheme.outlineVariant.withValues(alpha: 0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              emoji,
                              style: TextStyle(
                                fontSize: isSelected ? 24 : 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),

        // 3. Media auto-download
        SettingsSection(
          title: 'Автозагрузка медиафайлов',
          subtitle: 'Настройка автоматического сохранения трафика',
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.wifi_rounded,
              title: 'Через сеть Wi-Fi',
              subtitle: 'Автоматически загружать фото, видео и голосовые сообщения',
              iconColor: scheme.secondary,
              value: settings.autoDownloadWifi,
              onChanged: (bool value) {
                ref
                    .read(uiSettingsProvider.notifier)
                    .setAutoDownloadWifi(value);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.signal_cellular_alt_rounded,
              title: 'Через мобильную сеть',
              subtitle: 'Экономия трафика: предпросмотр медиа только по нажатию',
              iconColor: scheme.secondary,
              value: settings.autoDownloadCellular,
              onChanged: (bool value) {
                ref
                    .read(uiSettingsProvider.notifier)
                    .setAutoDownloadCellular(value);
              },
            ),
          ],
        ),

        // 4. Chat wallpaper & visual
        SettingsSection(
          title: 'Оформление и фон',
          subtitle: 'Индивидуальные обои и генератор векторных узоров',
          children: <Widget>[
            SettingsTile(
              icon: Icons.wallpaper_rounded,
              title: 'Генератор обоев чатов',
              subtitle: 'Настройка паттернов, анимации и цветовой гаммы',
              iconColor: scheme.primary,
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
              onTap: () {
                context.push('/settings/wallpaper');
              },
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}
