import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/features/chats/presentation/compose_action_sheet.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class ChatListHeader extends ConsumerWidget implements PreferredSizeWidget {
  const ChatListHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    final profile = ref.watch(authProvider.select((s) => s.profile));
    final sessionName = ref.watch(
      authProvider.select((s) => s.session?.displayName),
    );

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Text(
        l10n.tabChats,
        style: theme.textTheme.titleLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),
      centerTitle: false,
      actions: <Widget>[
        IconButton(
          tooltip: l10n.chatListSearchMessagesHint,
          onPressed: () => context.push('/chats/search'),
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          key: const ValueKey('inbox-profile-settings'),
          tooltip: l10n.tabSettings,
          onPressed: () => context.go('/main/settings'),
          icon: PulseAvatar(
            avatarUrl: profile?.avatarUrl,
            name: profile?.displayName ?? sessionName ?? '',
            radius: 16,
          ),
        ),
        MenuAnchor(
          menuChildren: <Widget>[
            MenuItemButton(
              leadingIcon: const ProductivityIcon('bookmark'),
              onPressed: () => openSavedMessages(context, ref),
              child: Text(l10n.savedMessagesTitle),
            ),
            MenuItemButton(
              leadingIcon: const ProductivityIcon('clock'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScheduledMessagesScreen(),
                ),
              ),
              child: Text(l10n.inboxScheduledMessages),
            ),
            MenuItemButton(
              leadingIcon: const ProductivityIcon('folder'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChatFoldersScreen(),
                ),
              ),
              child: Text(l10n.inboxFolders),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.edit_rounded),
              onPressed: () => openComposeActions(context),
              child: Text(l10n.inboxCreateMenu),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.contacts_rounded),
              onPressed: () => context.push('/contacts'),
              child: Text(l10n.tabContacts),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.settings_outlined),
              onPressed: () => context.go('/main/settings'),
              child: Text(l10n.tabSettings),
            ),
          ],
          builder: (context, controller, child) => IconButton(
            tooltip: l10n.inboxActions,
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
        const SizedBox(width: 4),
      ],
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
