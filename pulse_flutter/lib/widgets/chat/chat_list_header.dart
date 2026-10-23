import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/features/chats/presentation/compose_action_sheet.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class ChatListHeader extends StatelessWidget implements PreferredSizeWidget {
  const ChatListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

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
        MenuAnchor(
          menuChildren: <Widget>[
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
