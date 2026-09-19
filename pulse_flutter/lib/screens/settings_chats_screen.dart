import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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

    return SettingsShell(
      title: context.l10n.settingsChatsTitle,
      isEmbedded: isEmbedded,
      children: <Widget>[
        SettingsNavBanner(
          illustrationCategory: SettingsIllustrationCategory.preferences,
          subtitle: context.l10n.settingsChatsSubtitle,
          iconColor: scheme.primary,
        ),

        // 1. Text input & Keyboard
        SettingsSection(
          title: context.l10n.settingsChatsSendSection,
          subtitle: context.l10n.settingsChatsSendSectionDesc,
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.keyboard_return_rounded,
              title: context.l10n.settingsChatsSendOnEnter,
              subtitle: context.l10n.settingsChatsSendOnEnterDesc,
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
          title: context.l10n.settingsChatsQuickReaction,
          subtitle: context.l10n.settingsChatsQuickReactionDesc,
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
                              context.l10n.settingsChatsSelectedEmoji,
                              style: textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              context.l10n.settingsChatsDoubleTapHint,
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
          title: context.l10n.settingsChatsAutoDownload,
          subtitle: context.l10n.settingsChatsAutoDownloadDesc,
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.wifi_rounded,
              title: context.l10n.settingsChatsAutoDownloadWifi,
              subtitle: context.l10n.settingsChatsAutoDownloadWifiDesc,
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
              title: context.l10n.settingsChatsAutoDownloadCellular,
              subtitle: context.l10n.settingsChatsAutoDownloadCellularDesc,
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

        // 4. Camera & Video circles
        SettingsSection(
          title: context.l10n.settingsChatsCameraSection,
          subtitle: context.l10n.settingsChatsCameraSectionDesc,
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.camera_enhance_rounded,
              title: context.l10n.settingsChatsCamera2Api,
              subtitle: context.l10n.settingsChatsCamera2ApiDesc,
              iconColor: scheme.primary,
              value: settings.camera2Api,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setCamera2Api(value);
              },
            ),
          ],
        ),

        // 5. Video playback
        SettingsSection(
          title: 'Воспроизведение видео',
          subtitle: 'Управление перемоткой и поведением плеера',
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Шаг быстрой перемотки',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Интервал пропуска при двойном тапе по краям видеоплеера',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<int>>[
                        ButtonSegment<int>(value: 5, label: Text('5 сек')),
                        ButtonSegment<int>(value: 10, label: Text('10 сек')),
                        ButtonSegment<int>(value: 15, label: Text('15 сек')),
                      ],
                      selected: <int>{settings.videoSeekSeconds},
                      onSelectionChanged: (Set<int> selected) {
                        HapticService.tap();
                        ref
                            .read(uiSettingsProvider.notifier)
                            .setVideoSeekSeconds(selected.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
            SettingsSwitchTile(
              icon: Icons.pause_circle_outline_rounded,
              title: 'Пауза при сворачивании',
              subtitle: 'Автоматически приостанавливать видео при переходе в фоновый режим',
              iconColor: scheme.primary,
              value: settings.autoPauseVideoOnBackground,
              onChanged: (bool value) {
                ref
                    .read(uiSettingsProvider.notifier)
                    .setAutoPauseVideoOnBackground(value);
              },
            ),
          ],
        ),

        // 6. Message & Chat list display
        SettingsSection(
          title: 'Отображение и список чатов',
          subtitle: 'Стилизация облачков сообщений и компактность интерфейса',
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Скрывать «хвостики» сообщений',
              subtitle: 'Убирает заострённые уголки у входящих и исходящих облачков',
              iconColor: scheme.primary,
              value: settings.hideBubbleTails,
              onChanged: (bool value) {
                ref
                    .read(uiSettingsProvider.notifier)
                    .setHideBubbleTails(value);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.edit_note_rounded,
              title: 'Иконка для изменённых сообщений',
              subtitle: 'Показывать компактный значок карандаша вместо надписи «изменено»',
              iconColor: scheme.primary,
              value: settings.replaceEditedWithIcon,
              onChanged: (bool value) {
                ref
                    .read(uiSettingsProvider.notifier)
                    .setReplaceEditedWithIcon(value);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Плотность списка чатов',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Размер отступов и миниатюр на главном экране',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'standard',
                          label: Text('Стандартная'),
                          icon: Icon(Icons.view_agenda_outlined, size: 18),
                        ),
                        ButtonSegment<String>(
                          value: 'compact',
                          label: Text('Компактная'),
                          icon: Icon(Icons.view_headline_rounded, size: 18),
                        ),
                      ],
                      selected: <String>{settings.chatListDensity},
                      onSelectionChanged: (Set<String> selected) {
                        HapticService.tap();
                        ref
                            .read(uiSettingsProvider.notifier)
                            .setChatListDensity(selected.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // 7. Chat wallpaper & visual
        SettingsSection(
          title: context.l10n.settingsChatsWallpaperSection,
          subtitle: context.l10n.settingsChatsWallpaperSectionDesc,
          children: <Widget>[
            SettingsTile(
              icon: Icons.wallpaper_rounded,
              title: context.l10n.settingsChatsWallpaperGenerator,
              subtitle: context.l10n.settingsChatsWallpaperGeneratorDesc,
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
