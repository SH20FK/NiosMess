import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/features/chats/presentation/compose_action_sheet.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';

class ChatListHeader extends ConsumerWidget implements PreferredSizeWidget {
  const ChatListHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final totalUnread = ref.watch(totalUnreadCountProvider);

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            l10n.tabChats,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: scheme.onSurface,
            ),
          ),
          if (totalUnread > 0) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                totalUnread > 999 ? '999+' : '$totalUnread',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
      centerTitle: false,
      actions: <Widget>[
        MenuAnchor(
          menuChildren: <Widget>[
            MenuItemButton(
              leadingIcon: const Icon(Icons.edit_rounded),
              onPressed: () => openComposeActions(context),
              child: Text(l10n.chatCreatePersonal),
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
