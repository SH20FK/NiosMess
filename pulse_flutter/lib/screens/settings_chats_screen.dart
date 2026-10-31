import 'package:pulse_flutter/widgets/calls/call_devices_dialog.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsChatsScreen extends ConsumerWidget {
  const SettingsChatsScreen({this.isEmbedded = false, super.key});

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
      title: context.l10n.settingsV2Chats,
      isEmbedded: isEmbedded,
      children: <Widget>[
        SettingsSection(
          title: context.l10n.inboxFolders,
          children: [
            SettingsListItem.nav(
              icon: Icons.folder_outlined,
              title: context.l10n.inboxFolders,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChatFoldersScreen(),
                ),
              ),
            ),
          ],
        ),
        // 1. Text input & Keyboard
        SettingsSection(
          title: context.l10n.settingsChatsSendSection,
          subtitle: context.l10n.settingsChatsSendSectionDesc,
          children: <Widget>[
            SettingsAnchor(
              id: 'chats.sendOnEnter',
              child: SettingsSwitchTile(
                icon: Icons.keyboard_return_rounded,
                title: context.l10n.settingsChatsSendOnEnter,
                subtitle: context.l10n.settingsChatsSendOnEnterDesc,
                iconColor: scheme.primary,
                value: settings.sendOnEnter,
                onChanged: (bool value) {
                  ref.read(uiSettingsProvider.notifier).setSendOnEnter(value);
                },
              ),
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
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.8,
                                ),
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
                                  : scheme.surfaceContainerHigh.withValues(
                                      alpha: 0.5,
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? scheme.primary
                                    : scheme.outlineVariant.withValues(
                                        alpha: 0.3,
                                      ),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              emoji,
                              style: TextStyle(fontSize: isSelected ? 24 : 20),
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

        SettingsSection(
          title: context.l10n.callDevicesTitle,
          children: [
            SettingsAnchor(
              id: 'chats.callDevices',
              child: SettingsListItem.nav(
                icon: Icons.headset_mic_rounded,
                title: context.l10n.callDevicesTitle,
                subtitle: context.l10n.callDevicesLocalHint,
                onTap: () => showCallDevicesDialog(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
