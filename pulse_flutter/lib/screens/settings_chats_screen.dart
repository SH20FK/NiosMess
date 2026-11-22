import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/calls/call_devices_dialog.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:pulse_flutter/widgets/motion/m3_selection_motion.dart';
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
    final settings = ref.watch(
      uiSettingsProvider.select(
        (UiSettingsState s) => (
          sendOnEnter: s.sendOnEnter,
          doubleTapReactionEmoji: s.doubleTapReactionEmoji,
          animateStickers: s.animateStickers,
          animateEmoji: s.animateEmoji,
        ),
      ),
    );
    return SettingsShell(
      title: context.l10n.settingsV2Chats,
      isEmbedded: isEmbedded,
      children: [
        SettingsSection(
          children: [
            SettingsListItem.nav(
              icon: Icons.folder_outlined,
              title: context.l10n.inboxFolders,
              onTap: () => openChatFolders(context),
            ),
            SettingsAnchor(
              id: 'chats.sendOnEnter',
              child: SettingsListItem.toggle(
                icon: Icons.keyboard_return_rounded,
                title: context.l10n.settingsChatsSendOnEnter,
                subtitle: context.l10n.settingsChatsSendOnEnterDesc,
                value: settings.sendOnEnter,
                onChanged: ref.read(uiSettingsProvider.notifier).setSendOnEnter,
              ),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsChatsQuickReaction,
          subtitle: context.l10n.settingsChatsQuickReactionDesc,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final emoji in _quickReactionEmojis)
                    M3SelectionMotion(
                      selected: settings.doubleTapReactionEmoji == emoji,
                      child: ChoiceChip(
                        key: ValueKey('settings-quick-reaction-$emoji'),
                        selected: settings.doubleTapReactionEmoji == emoji,
                        label: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: (_) {
                          HapticService.selection();
                          ref
                              .read(uiSettingsProvider.notifier)
                              .setDoubleTapReactionEmoji(emoji);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsV2ChatAnimations,
          subtitle: context.l10n.settingsV2ChatAnimationsHint,
          children: [
            SettingsAnchor(
              id: 'motion.stickers',
              child: SettingsListItem.toggle(
                icon: Icons.auto_awesome_motion_rounded,
                title: context.l10n.settingsV2Stickers,
                subtitle: context.l10n.settingsV2StickersHint,
                value: settings.animateStickers,
                onChanged: ref
                    .read(uiSettingsProvider.notifier)
                    .setAnimateStickers,
              ),
            ),
            SettingsAnchor(
              id: 'motion.emoji',
              child: SettingsListItem.toggle(
                icon: Icons.mood_rounded,
                title: context.l10n.settingsV2Emoji,
                subtitle: context.l10n.settingsV2EmojiHint,
                value: settings.animateEmoji,
                onChanged: ref
                    .read(uiSettingsProvider.notifier)
                    .setAnimateEmoji,
              ),
            ),
          ],
        ),
        SettingsSection(
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
