import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:material_ui/material_ui.dart';
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
          compactMode: s.compactMode,
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
        // Moved from the appearance screen: what a chat looks like belongs
        // with the chat settings, and the appearance page stays short. The
        // anchor ids keep their old names so search deep links still land.
        SettingsSection(
          title: context.l10n.settingsChatsWallpaperSection,
          subtitle: context.l10n.settingsChatsWallpaperSectionDesc,
          accentIcon: Icons.texture_rounded,
          children: [
            SettingsAnchor(
              id: 'appearance.wallpaper',
              child: SettingsListItem.nav(
                key: const ValueKey('settings-wallpaper-entry'),
                icon: Icons.texture_rounded,
                leading: const _WallpaperThumbnail(),
                title: context.l10n.appearanceChatWallpaperTitle,
                subtitle: context.l10n.settingsWallpaperEntryHint,
                onTap: () => openSettingsPage(context, '/settings/wallpaper'),
              ),
            ),
            SettingsAnchor(
              id: 'appearance.compact',
              child: SettingsListItem.toggle(
                icon: Icons.density_small_rounded,
                title: context.l10n.appearanceCompactMode,
                subtitle: context.l10n.appearanceCompactModeSubtitle,
                value: settings.compactMode,
                onChanged: ref.read(uiSettingsProvider.notifier).setCompactMode,
              ),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsChatsQuickReaction,
          subtitle: context.l10n.settingsChatsQuickReactionDesc,
          accentIcon: Icons.add_reaction_rounded,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final emoji in _quickReactionEmojis)
                    _QuickReactionChip(
                      emoji: emoji,
                      selected: settings.doubleTapReactionEmoji == emoji,
                      onSelect: () => ref
                          .read(uiSettingsProvider.notifier)
                          .setDoubleTapReactionEmoji(emoji),
                    ),
                ],
              ),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsV2ChatAnimations,
          subtitle: context.l10n.settingsV2ChatAnimationsHint,
          accentIcon: Icons.animation_rounded,
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

/// The gradient tile that stands for the chat wallpaper in the nav row:
/// a small preview of the studio the row opens, not a live mirror of it.
class _WallpaperThumbnail extends StatelessWidget {
  const _WallpaperThumbnail();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: AppHeights.sm,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.primary,
              scheme.tertiaryContainer,
              scheme.secondaryContainer,
            ],
          ),
          shape: AppRadii.superellipse(AppRadii.of(context).md),
        ),
      ),
    );
  }
}

/// One emoji of the quick-reaction set. The glyph is the visual; the spoken
/// label names the setting it controls, so a screen reader announces
/// "Quick reaction ❤️, button, selected" instead of reading the raw symbol.
class _QuickReactionChip extends StatelessWidget {
  const _QuickReactionChip({
    required this.emoji,
    required this.selected,
    required this.onSelect,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onSelect;

  void _select() {
    HapticService.selection();
    onSelect();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: context.l10n.settingsChatsQuickReactionEmoji(emoji),
      onTap: _select,
      excludeSemantics: true,
      child: M3SelectionMotion(
        selected: selected,
        child: ChoiceChip(
          // The key stays on the chip itself: tests and the semantics node
          // both find the control, not the wrapper.
          key: ValueKey('settings-quick-reaction-$emoji'),
          selected: selected,
          label: Text(emoji, style: const TextStyle(fontSize: 24)),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onSelected: (_) => _select(),
        ),
      ),
    );
  }
}
