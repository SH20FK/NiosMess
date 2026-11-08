import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

/// Standard AppBar for ChatListScreen, maintaining PreferredSizeWidget compatibility.
class ChatListHeader extends ConsumerWidget implements PreferredSizeWidget {
  const ChatListHeader({
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.onCloseSelection,
    this.onPinSelected,
    this.onMuteSelected,
    this.onMarkReadSelected,
    this.onDeleteSelected,
    this.isSearchOpen = false,
    this.searchController,
    this.onSearchToggle,
    this.onSearchChanged,
    super.key,
  });

  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback? onCloseSelection;
  final VoidCallback? onPinSelected;
  final VoidCallback? onMuteSelected;
  final VoidCallback? onMarkReadSelected;
  final VoidCallback? onDeleteSelected;

  final bool isSearchOpen;
  final TextEditingController? searchController;
  final VoidCallback? onSearchToggle;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    if (isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: onCloseSelection,
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
        title: Text(
          '$selectedCount',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          if (onPinSelected != null)
            IconButton(
              icon: const Icon(Icons.push_pin_rounded),
              tooltip: 'Закрепить / Открепить',
              onPressed: onPinSelected,
            ),
          if (onMuteSelected != null)
            IconButton(
              icon: const Icon(Icons.notifications_off_rounded),
              tooltip: 'Без звука',
              onPressed: onMuteSelected,
            ),
          if (onMarkReadSelected != null)
            IconButton(
              icon: const Icon(Icons.mark_chat_read_rounded),
              tooltip: 'Прочитано',
              onPressed: onMarkReadSelected,
            ),
          if (onDeleteSelected != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Удалить',
              onPressed: onDeleteSelected,
            ),
          const SizedBox(width: 4),
        ],
        backgroundColor: scheme.surfaceContainer,
        elevation: 0,
      );
    }

    if (isSearchOpen) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onSearchToggle,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        title: TextField(
          controller: searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.chatListSearchMessagesHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: onSearchChanged,
        ),
        actions: [
          if (searchController?.text.isNotEmpty == true)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                searchController?.clear();
                onSearchChanged?.call('');
              },
            ),
        ],
        backgroundColor: scheme.surfaceContainer,
        elevation: 0,
      );
    }

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
          onPressed: onSearchToggle ?? () => context.push('/chats/search'),
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
        const SizedBox(width: 4),
      ],
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Flexible Material 3 Collapsing Large Top App Bar for the inbox list.
///
/// Features large expanding headline title that smoothly shrinks into compact
/// title on scroll, seamless inline search expansion, and contextual action bar
/// for multi-selection on long-press.
class SliverChatListHeader extends ConsumerWidget {
  const SliverChatListHeader({
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.onCloseSelection,
    this.onPinSelected,
    this.onMuteSelected,
    this.onMarkReadSelected,
    this.onDeleteSelected,
    this.isSearchOpen = false,
    this.searchController,
    this.onSearchToggle,
    this.onSearchChanged,
    super.key,
  });

  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback? onCloseSelection;
  final VoidCallback? onPinSelected;
  final VoidCallback? onMuteSelected;
  final VoidCallback? onMarkReadSelected;
  final VoidCallback? onDeleteSelected;

  final bool isSearchOpen;
  final TextEditingController? searchController;
  final VoidCallback? onSearchToggle;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    if (isSelectionMode || isSearchOpen) {
      // In contextual selection or search mode, keep pinned compact height
      return SliverAppBar(
        pinned: true,
        floating: false,
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: onCloseSelection,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onSearchToggle,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
        title: isSelectionMode
            ? Text(
                '$selectedCount',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              )
            : TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.chatListSearchMessagesHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: onSearchChanged,
              ),
        actions: isSelectionMode
            ? [
                if (onPinSelected != null)
                  IconButton(
                    icon: const Icon(Icons.push_pin_rounded),
                    tooltip: 'Закрепить',
                    onPressed: onPinSelected,
                  ),
                if (onMuteSelected != null)
                  IconButton(
                    icon: const Icon(Icons.notifications_off_rounded),
                    tooltip: 'Без звука',
                    onPressed: onMuteSelected,
                  ),
                if (onMarkReadSelected != null)
                  IconButton(
                    icon: const Icon(Icons.mark_chat_read_rounded),
                    tooltip: 'Прочитано',
                    onPressed: onMarkReadSelected,
                  ),
                if (onDeleteSelected != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Удалить',
                    onPressed: onDeleteSelected,
                  ),
                const SizedBox(width: 4),
              ]
            : [
                if (searchController?.text.isNotEmpty == true)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      searchController?.clear();
                      onSearchChanged?.call('');
                    },
                  ),
              ],
      );
    }

    final profile = ref.watch(authProvider.select((s) => s.profile));
    final sessionName = ref.watch(
      authProvider.select((s) => s.session?.displayName),
    );

    return SliverAppBar.large(
      pinned: true,
      floating: false,
      elevation: 0,
      scrolledUnderElevation: 2.0,
      surfaceTintColor: scheme.surfaceTint,
      backgroundColor: scheme.surface,
      automaticallyImplyLeading: false,
      title: Text(
        l10n.tabChats,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
      ),
      actions: <Widget>[
        IconButton(
          tooltip: l10n.chatListSearchMessagesHint,
          onPressed: onSearchToggle ?? () => context.push('/chats/search'),
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
        const SizedBox(width: 4),
      ],
    );
  }
}
