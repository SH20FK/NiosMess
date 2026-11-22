import 'package:pulse_flutter/widgets/app_refresh_indicator.dart';
import 'package:pulse_flutter/providers/encrypted_draft_sync_provider.dart';
import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:pulse_flutter/models/live_location.dart';
import 'package:pulse_flutter/widgets/chat/ordinary_e2ee_notice.dart';
import 'dart:async';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/core/utils/message_preview_text.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/identity/nios_mark.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';
import 'package:pulse_flutter/widgets/empty_state_widget.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_filter_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_header.dart';
import 'package:pulse_flutter/widgets/chat/inbox_compose_button.dart';
import 'package:pulse_flutter/widgets/chat/reorder_slide.dart';
import 'package:pulse_flutter/widgets/chat/swipe_action_row.dart';
import 'package:pulse_flutter/providers/chat_list_fab_provider.dart';
import 'package:pulse_flutter/providers/chat_list_scroll_provider.dart';
import 'package:pulse_flutter/features/chats/presentation/compose_action_sheet.dart';
import 'package:pulse_flutter/features/chats/application/inbox_search_controller.dart';
import 'package:pulse_flutter/features/chats/presentation/inbox_search_results.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/chat/chat_actions_modal.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/features/chats/application/inbox_selection_controller.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/widgets/common/app_action_menu_item.dart';
import 'package:pulse_flutter/widgets/motion/m3_entrance.dart';

enum _LastMessageKind { photo, video, audio, file }

/// Trailing room for the composer button.
///
/// Its own widget on purpose: the button hides and returns while the list
/// scrolls, and only this sliver has to follow, not the whole screen.
class _ComposerClearance extends ConsumerWidget {
  const _ComposerClearance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool composerVisible = ref.watch(inboxComposerVisibleProvider);
    return SliverPadding(
      padding: EdgeInsets.only(
        // The strip the composer button and its scrim occupy, or 24 dp of
        // resting room without the button, + the system inset.
        bottom:
            (composerVisible ? kInboxComposerClearance : 24) +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
    );
  }
}

/// The inbox snapshot the screen subscribes to. Two snapshots are equal when
/// they differ only in presence, so `select` skips the screen for those.
class _PresenceBlindChats {
  const _PresenceBlindChats(this.chats);

  final AsyncValue<List<ApiChatSummary>> chats;

  @override
  bool operator ==(Object other) {
    if (other is! _PresenceBlindChats) return false;
    final AsyncValue<List<ApiChatSummary>> a = chats;
    final AsyncValue<List<ApiChatSummary>> b = other.chats;
    if (identical(a, b)) return true;
    if (a.runtimeType != b.runtimeType ||
        a.isLoading != b.isLoading ||
        !identical(a.error, b.error)) {
      return false;
    }
    final List<ApiChatSummary>? x = a.value;
    final List<ApiChatSummary>? y = b.value;
    if (x == null || y == null) return x == null && y == null;
    if (x.length != y.length) return false;
    for (int i = 0; i < x.length; i++) {
      if (!x[i].sameExceptPresence(y[i])) return false;
    }
    return true;
  }

  // Only `==` is used by `select`; equal snapshots must share a hash.
  @override
  int get hashCode => 0;
}

/// Action painted behind a row that is being swiped.
///
/// No vertical margin: the 2 dp gap lives between the tiles, so the backdrop
/// must not shrink behind them. The radius is the tile radius, and the text
/// is `labelLarge` so the label fits the 35% reveal. Once the pull is far
/// enough to trigger, the backdrop takes the accent tone and the icon springs
/// up: letting go now does the action.
class _SwipeBackdrop extends StatelessWidget {
  const _SwipeBackdrop({
    required this.icon,
    required this.label,
    this.atEnd = false,
  });

  final IconData icon;
  final String label;

  /// Revealed at the end edge: content hugs that edge, icon outermost.
  final bool atEnd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool armed = SwipeActionRow.armedOf(context);
    final bool animate = !context.reduceMotion;
    final Color foreground = armed
        ? scheme.onPrimaryContainer
        : scheme.onSecondaryContainer;

    final List<Widget> content = <Widget>[
      // Scale may overshoot on the spatial spring; colour rides an effects
      // curve and never does.
      AnimatedScale(
        scale: armed ? 1.25 : 1,
        duration: animate ? M3Durations.spatialFast : Duration.zero,
        curve: M3SpringCurves.spatialFast,
        child: Icon(icon, size: 20, color: foreground),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        maxLines: 1,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    ];

    return AnimatedContainer(
      duration: animate ? M3Durations.short3 : Duration.zero,
      curve: M3SpringCurves.effectsFast,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: armed ? scheme.primaryContainer : scheme.secondaryContainer,
        borderRadius: AppRadii.of(context).lgRadius,
      ),
      alignment: atEnd
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: atEnd ? content.reversed.toList(growable: false) : content,
      ),
    );
  }
}

/// End-edge backdrop of a chat row: offers the opposite of the chat's current
/// mute state. Built only while the row is pulled, so a resting list holds no
/// extra subscriptions.
class _MuteSwipeBackdrop extends ConsumerWidget {
  const _MuteSwipeBackdrop({required this.chatId});

  final int chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool muted = ref.watch(chatMutedProvider(chatId)).value ?? false;
    return _SwipeBackdrop(
      icon: muted
          ? Icons.notifications_active_rounded
          : Icons.notifications_off_rounded,
      label: muted
          ? context.l10n.inboxSwipeUnmute
          : context.l10n.inboxSwipeMute,
      atEnd: true,
    );
  }
}

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  static final RegExp _forwardedPattern = RegExp(r'^_fwd from\s+(.+?):');

  @override
  void initState() {
    super.initState();
    ref.listenManual(authProvider.select((s) => s.session?.userId), (
      before,
      after,
    ) {
      if (before != after) _previewFormatter.clear();
    });
    ref.listenManual(chatListScrollToTopProvider, (_, _) => _scrollToTop());
    // A picked chat that left the list (deleted, left on another device)
    // leaves the selection too.
    ref.listenManual(visibleChatsProvider, (_, next) {
      final List<ApiChatSummary>? chats = next.value;
      if (chats == null || ref.read(inboxSelectionProvider).isEmpty) return;
      ref.read(inboxSelectionProvider.notifier).retainAll(<int>{
        for (final ApiChatSummary chat in chats) chat.id,
      });
    });
    ref.listenManual(
      inboxSearchProvider.select((InboxSearchState s) => s.hasQuery),
      (_, _) {
        // Results and the chat list are different content: start at the top,
        // once the new slivers are laid out.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      },
    );
    // The provider already fetches on first build and WebSocket push keeps data fresh.
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cursorMenuChat.dispose();
    super.dispose();
  }

  final ScrollController _scrollController = ScrollController();

  // One menu anchor serves every row: a right click opens it at the pointer
  // with the actions of the chat under it.
  final MenuController _cursorMenu = MenuController();
  final GlobalKey _cursorMenuKey = GlobalKey(debugLabel: 'inbox-cursor-menu');
  final ValueNotifier<ApiChatSummary?> _cursorMenuChat =
      ValueNotifier<ApiChatSummary?>(null);

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    final ScrollPosition position = _scrollController.position;
    if (position.pixels <= 0) return;
    if (context.reduceMotion) {
      position.jumpTo(0);
      return;
    }
    // A long list is not replayed row by row: jump close, then glide home.
    final double near = position.viewportDimension * 1.5;
    if (position.pixels > near) position.jumpTo(near);
    unawaited(
      position.animateTo(
        0,
        duration: M3Durations.medium2,
        curve: M3SpringCurves.expressiveDecel,
      ),
    );
  }

  final _previewFormatter = MessagePreviewFormatter();
  bool _retrying = false;
  final Set<int> _markingRead = {};

  Future<void> _retryChats() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await ref.read(chatsProvider.notifier).refreshOrThrow();
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          context.l10n.inboxRefreshFailed,
          onRetry: _retryChats,
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _markRead(ApiChatSummary chat) async {
    if (!_markingRead.add(chat.id)) return;
    try {
      if (chat.isSecret) {
        // Secret receipts go through the chat's own engine.
        await ref
            .read(chatMessagesProvider(chat.id).notifier)
            .markRead(reportFailure: true);
      } else {
        await ref.read(chatsProvider.notifier).markReadFromInbox(chat.id);
      }
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, error, onRetry: () => _markRead(chat));
      }
    } finally {
      _markingRead.remove(chat.id);
    }
  }

  void _resetInboxFilters() {
    if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
    ref.read(chatFilterProvider.notifier).updateFilter(ChatFilter.all);
    ref.read(selectedChatFolderProvider.notifier).select(null);
  }

  List<ApiChatSummary> _applyFilter(
    List<ApiChatSummary> chats,
    ChatFilter filter,
  ) {
    switch (filter) {
      case ChatFilter.all:
        return chats;
      case ChatFilter.unread:
        return chats
            .where((ApiChatSummary c) => c.unreadCount > 0)
            .toList(growable: false);
      case ChatFilter.groups:
        return chats
            .where((ApiChatSummary c) => c.chatType == 'group')
            .toList(growable: false);
      case ChatFilter.channels:
        return chats
            .where((ApiChatSummary c) => c.chatType == 'channel')
            .toList(growable: false);
      case ChatFilter.direct:
        return chats
            .where((ApiChatSummary c) => c.chatType == 'direct' && !c.isBotChat)
            .toList(growable: false);
      case ChatFilter.bots:
        return chats
            .where((ApiChatSummary c) => c.chatType == 'bot' || c.isBotChat)
            .toList(growable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(encryptedDraftSyncProvider);
    final bool compact = ref.watch(
      uiSettingsProvider.select((s) => s.compactMode),
    );
    final bool isAuthenticated = ref.watch(
      authProvider.select((s) => s.isAuthenticated),
    );
    // Presence is watched by each row: an online/offline push must not rebuild
    // the whole list.
    final AsyncValue<List<ApiChatSummary>> chatsAsync = ref
        .watch(visibleChatsProvider.select(_PresenceBlindChats.new))
        .chats;
    final filter = ref.watch(chatFilterProvider);
    final browserWorkspace = ref
        .watch(clientCapabilitiesProvider)
        .browserWorkspace;
    final int? desktopChatId = browserWorkspace
        ? int.tryParse(
            GoRouterState.of(context).uri.queryParameters['chat'] ?? '',
          )
        : ref.watch(desktopSelectedChatProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // With a query typed into the header, results replace the chat list.
    final bool searching = ref.watch(
      inboxSearchProvider.select((InboxSearchState s) => s.hasQuery),
    );
    final bool selecting = ref.watch(
      inboxSelectionProvider.select((Set<int> s) => s.isNotEmpty),
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Bound only while picking, so Escape is not swallowed otherwise.
        if (selecting)
          const SingleActivator(LogicalKeyboardKey.escape): _endSelection,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            ref.read(inboxSearchProvider.notifier).open(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            ref.read(inboxSearchProvider.notifier).open(),
      },
      child: Focus(
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(
              ChatListHeader.heightFor(context, compact: compact),
            ),
            child: ChatListHeader(
              selectionBar: InboxSelectionBar(
                onMarkRead: _markSelectedRead,
                onToggleMute: _toggleSelectedMute,
                onDelete: _deleteSelected,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          // The list is the builder's child: opening the menu for another
          // chat rebuilds the anchor, not the rows.
          body: ValueListenableBuilder<ApiChatSummary?>(
            valueListenable: _cursorMenuChat,
            builder: _buildCursorMenu,
            child: AppRefreshIndicator(
              onRefresh: () async {
                if (ref.read(uiSettingsProvider).haptics) {
                  HapticService.confirm();
                }
                await _retryChats();
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // 8 dp around the 48 dp rail; its pills start on
                          // the 16 dp column of the header title.
                          const SizedBox(height: 8),
                          RepaintBoundary(
                            child: ChatFilterBar(compact: compact),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    if (searching)
                      const InboxSearchResults()
                    else ...<Widget>[
                      const SliverToBoxAdapter(child: OrdinaryE2eeNotice()),
                      ..._buildChatSlivers(
                        isAuthenticated,
                        chatsAsync,
                        compact,
                        scheme,
                        filter,
                        desktopChatId,
                      ),
                    ],
                    const _ComposerClearance(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCursorMenu(
    BuildContext context,
    ApiChatSummary? chat,
    Widget? list,
  ) {
    return MenuAnchor(
      key: _cursorMenuKey,
      controller: _cursorMenu,
      menuChildren: chat == null
          ? const <Widget>[]
          : _cursorMenuItems(context, chat),
      child: list,
    );
  }

  /// The same five actions as the long-press sheet, in the same order.
  List<Widget> _cursorMenuItems(BuildContext context, ApiChatSummary chat) {
    final l10n = context.l10n;
    final bool muted = ref.read(chatMutedProvider(chat.id)).value ?? false;
    final bool isDirect =
        chat.chatType != 'group' && chat.chatType != 'channel';
    final List<(ChatActionResult, String, IconData, bool)> rows =
        <(ChatActionResult, String, IconData, bool)>[
          (
            ChatActionResult.markRead,
            l10n.chatListMarkRead,
            Icons.done_all_rounded,
            chat.unreadCount > 0,
          ),
          (
            ChatActionResult.toggleMute,
            muted
                ? l10n.profileUnmuteNotifications
                : l10n.profileMuteNotifications,
            muted
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            true,
          ),
          (
            ChatActionResult.addToFolder,
            l10n.inboxAddToFolder,
            Icons.folder_outlined,
            true,
          ),
          (
            ChatActionResult.select,
            l10n.inboxSelect,
            Icons.check_circle_outline_rounded,
            true,
          ),
          (
            ChatActionResult.leave,
            isDirect ? l10n.chatDelete : l10n.chatListLeave,
            isDirect ? Icons.delete_outline_rounded : Icons.logout_rounded,
            true,
          ),
        ];
    return <Widget>[
      for (final (
            int index,
            (
              ChatActionResult action,
              String label,
              IconData icon,
              bool enabled,
            ),
          )
          in rows.indexed) ...<Widget>[
        if (action == ChatActionResult.leave) const Divider(height: 8),
        // The menu is mounted anew on every opening, so the rows rise into
        // place one after another each time.
        M3Entrance(
          key: ValueKey<String>('chat-cursor-menu-${action.name}'),
          delay: Duration(milliseconds: 20 * index),
          offsetY: 6,
          child: AppActionMenuItem(
            label: label,
            icon: icon,
            isDisabled: !enabled,
            isDestructive: action == ChatActionResult.leave,
            onPressed: () => unawaited(_runChatAction(chat, action)),
          ).toMenuItem(context),
        ),
      ],
    ];
  }

  /// Opens the menu of [chat] at [globalPosition]. Returns `false` when the
  /// anchor is not laid out yet, so the caller can fall back to the sheet.
  bool _openCursorMenu(ApiChatSummary chat, Offset globalPosition) {
    final RenderObject? box = _cursorMenuKey.currentContext
        ?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    _cursorMenuChat.value = chat;
    _cursorMenu.open(position: box.globalToLocal(globalPosition));
    return true;
  }

  double _scrollDistance = 0.0;
  static const double _kScrollHysteresis = 28.0;

  bool _handleScrollNotification(ScrollNotification notification) {
    // The cursor menu belongs to a row that is about to move away.
    if (notification is ScrollStartNotification && _cursorMenu.isOpen) {
      _cursorMenu.close();
    }
    ref
        .read(chatListScrolledProvider.notifier)
        .setScrolled(notification.metrics.pixels > ChatListHeader.scrimOffset);
    if (notification.metrics.pixels <= 0) {
      ref.read(chatListFabVisibleProvider.notifier).show();
      _scrollDistance = 0.0;
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      final double delta = notification.scrollDelta ?? 0.0;
      if (delta > 0) {
        // Scrolling downwards: hide FAB after exceeding threshold
        if (_scrollDistance < 0) _scrollDistance = 0;
        _scrollDistance += delta;
        if (_scrollDistance > _kScrollHysteresis) {
          ref.read(chatListFabVisibleProvider.notifier).hide();
        }
      } else if (delta < 0) {
        // Scrolling upwards: reveal FAB smoothly after threshold
        if (_scrollDistance > 0) _scrollDistance = 0;
        _scrollDistance += delta;
        if (_scrollDistance < -_kScrollHysteresis) {
          ref.read(chatListFabVisibleProvider.notifier).show();
        }
      }
    } else if (notification is ScrollEndNotification) {
      _scrollDistance = 0.0;
    }
    return false;
  }

  Widget _savedShortcut(ColorScheme scheme, bool compact) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
    sliver: SliverToBoxAdapter(
      child: ChatTile(
        key: const ValueKey('saved-chat-shortcut'),
        title: context.l10n.savedMessagesTitle,
        subtitle: context.l10n.savedMessagesSubtitle,
        formattedTime: '',
        unreadCount: 0,
        avatarText: context.l10n.savedMessagesTitle,
        avatarColor: scheme.primaryContainer,
        isSaved: true,
        compact: compact,
        onTap: () => openSavedMessages(context, ref),
      ),
    ),
  );

  List<Widget> _buildChatSlivers(
    bool isAuthenticated,
    AsyncValue<List<ApiChatSummary>> chatsAsync,
    bool compact,
    ColorScheme scheme,
    ChatFilter filter,
    int? desktopChatId,
  ) {
    if (!isAuthenticated) {
      return <Widget>[
        SliverFillRemaining(
          child: EmptyStateWidget(
            title: context.l10n.chatListNotAuthenticated,
            icon: Icons.lock_outline_rounded,
          ),
        ),
      ];
    }

    final List<ApiChatSummary>? cachedChats = chatsAsync.asData?.value;
    if (cachedChats != null && cachedChats.isNotEmpty) {
      return _buildChatItemsSlivers(
        chats: cachedChats,
        compact: compact,
        scheme: scheme,
        filter: filter,
        desktopChatId: desktopChatId,
      );
    }

    return chatsAsync.when(
      data: (List<ApiChatSummary> chats) => _buildChatItemsSlivers(
        chats: chats,
        compact: compact,
        scheme: scheme,
        filter: filter,
        desktopChatId: desktopChatId,
      ),
      loading: () => <Widget>[
        if (filter == ChatFilter.all &&
            ref.watch(selectedChatFolderProvider) == null)
          _savedShortcut(scheme, compact),
        SliverFillRemaining(
          child: ChatListSkeleton(outerInset: 0, compact: compact),
        ),
      ],
      error: (Object error, StackTrace stack) => <Widget>[
        if (filter == ChatFilter.all &&
            ref.watch(selectedChatFolderProvider) == null)
          _savedShortcut(scheme, compact),
        SliverFillRemaining(
          child: EmptyStateWidget(
            title: context.l10n.inboxRefreshFailed,
            actionLabel: context.l10n.commonRetry,
            onAction: _retryChats,
            isBusy: _retrying,
            icon: Icons.error_outline_rounded,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChatItemsSlivers({
    required List<ApiChatSummary> chats,
    required bool compact,
    required ColorScheme scheme,
    required ChatFilter filter,
    required int? desktopChatId,
  }) {
    final folders = ref.watch(chatFoldersProvider).value ?? [];
    final selected = ref.watch(selectedChatFolderProvider);
    final folder = folders.where((f) => f.id == selected).firstOrNull;
    final List<ApiChatSummary> filtered = List<ApiChatSummary>.of(
      _applyFilter(
        folder == null ? chats : chats.where(folder.includes).toList(),
        filter,
      ),
    );
    final bool hasActiveFolder = folder != null;
    final bool canResetFilters = filter != ChatFilter.all || hasActiveFolder;
    // Each row watches its own pick; the list only follows the mode itself.
    final bool selecting = ref.watch(
      inboxSelectionProvider.select((Set<int> s) => s.isNotEmpty),
    );

    // The self-chat is always the first pinned item in the main inbox.
    if (!hasActiveFolder && filter == ChatFilter.all) {
      final index = filtered.indexWhere((chat) => chat.isSaved);
      if (index > 0) filtered.insert(0, filtered.removeAt(index));
    }
    final showSavedShortcut =
        !hasActiveFolder &&
        filter == ChatFilter.all &&
        !filtered.any((chat) => chat.isSaved);

    if (filtered.isEmpty) {
      // An account without chats gets a way forward; an empty filter only
      // offers the way back to every chat.
      final bool noChatsAtAll = !canResetFilters;
      return <Widget>[
        if (showSavedShortcut) _savedShortcut(scheme, compact),
        SliverFillRemaining(
          child: EmptyStateWidget(
            // A filter that matched nothing is a passing state and gets the
            // quiet variant; the full-size one is for an account without chats.
            compact: !noChatsAtAll,
            title: noChatsAtAll
                ? context.l10n.inboxEmptyTitle
                : filter == ChatFilter.unread
                ? context.l10n.inboxNoUnread
                : context.l10n.inboxCategoryEmpty,
            subtitle: noChatsAtAll
                ? context.l10n.inboxEmptyHint
                : context.l10n.inboxFilterResetHint,
            actionLabel: noChatsAtAll
                ? context.l10n.inboxComposeTitle
                : context.l10n.inboxResetFilters,
            onAction: noChatsAtAll
                ? () => openComposeActions(context)
                : _resetInboxFilters,
            icon: noChatsAtAll
                ? Icons.forum_outlined
                : filter == ChatFilter.unread
                ? Icons.mark_chat_read_outlined
                : Icons.filter_list_off_rounded,
          ),
        ),
      ];
    }

    final Map<int, int> idToIndex = <int, int>{
      for (int i = 0; i < filtered.length; i++) filtered[i].id: i,
    };

    return <Widget>[
      if (showSavedShortcut) _savedShortcut(scheme, compact),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final ApiChatSummary chat = filtered[index];
              final Widget item = SwipeActionRow(
                key: ValueKey<String>('chat_${chat.id}'),
                // Rows do not travel while chats are being picked.
                enabled: !selecting,
                // 35% (~119 dp on a 340 dp row) leaves room for the whole
                // label; 40% used to trigger on a clipped label.
                threshold: 0.35,
                onArmed: () {
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.selection();
                  }
                },
                // Towards the end edge: read. Nothing to read, no travel.
                background: _SwipeBackdrop(
                  icon: Icons.done_all_rounded,
                  label: context.l10n.deliveryRead,
                ),
                onTriggered: chat.unreadCount > 0
                    ? () {
                        if (ref.read(uiSettingsProvider).haptics) {
                          HapticService.tap();
                        }
                        unawaited(_markRead(chat));
                      }
                    : null,
                // Towards the start edge: mute or unmute. The saved chat
                // never notifies, so it has nothing to mute.
                endBackground: _MuteSwipeBackdrop(chatId: chat.id),
                onEndTriggered: chat.isSaved
                    ? null
                    : () {
                        if (ref.read(uiSettingsProvider).haptics) {
                          HapticService.tap();
                        }
                        unawaited(_toggleMute(chat));
                      },
                child: Consumer(
                  builder: (BuildContext context, WidgetRef ref, _) {
                    final int typingCount = chat.isSaved
                        ? 0
                        : ref.watch(
                            typingProvider(chat.id).select(
                              (TypingState s) => s.typingUserIds.length,
                            ),
                          );
                    final bool isTyping = typingCount > 0;
                    String? draft;
                    if (chat.isSecret) {
                      ref.watch(secretChatRevisionProvider);
                      draft =
                          ref
                                  .watch(secretChatEngineProvider)
                                  ?.chat(chat.id)['draft']
                              as String?;
                    } else {
                      draft = ref.watch(
                        liveDraftMapProvider.select(
                          (value) => value.value?[chat.id],
                        ),
                      );
                    }
                    final hasDraft = draft?.trim().isNotEmpty == true;
                    final bool picked = ref.watch(
                      inboxSelectionProvider.select(
                        (Set<int> s) => s.contains(chat.id),
                      ),
                    );
                    return ChatTile(
                      title: chat.isSaved
                          ? context.l10n.savedMessagesTitle
                          : chat.name,
                      draftLabel: hasDraft && !isTyping
                          ? context.l10n.inboxDraftLabel
                          : null,
                      enableHaptics: ref.watch(
                        uiSettingsProvider.select((s) => s.haptics),
                      ),
                      // Typing is live and short-lived, so it wins over the
                      // draft and the last message.
                      subtitle: isTyping
                          ? (typingCount > 1
                                ? context.l10n.chatTypingMultiple
                                : context.l10n.chatTyping)
                          : hasDraft
                          ? messagePreviewText(draft!)
                          : _chatPreview(chat),
                      isTyping: isTyping,
                      formattedTime: formatRelativeTime(
                        chat.lastMessage?.sentAt ?? chat.lastActivity,
                        localeCode: context.l10n.localeName,
                      ),
                      deliveryIcon:
                          chat.lastMessage != null &&
                              chat.lastMessage!.senderId ==
                                  ref.read(authProvider).session?.userId
                          ? (chat.lastMessage!.isFailed
                                ? Icons.error_outline_rounded
                                : chat.lastMessage!.isSending ||
                                      chat.lastMessage!.id <= 0
                                ? Icons.schedule_rounded
                                : chat.lastMessage!.isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded)
                          : null,
                      unreadCount: chat.unreadCount,
                      avatarText: chat.isSaved
                          ? context.l10n.savedMessagesTitle
                          : chat.name,
                      avatarUrl: chat.avatarUrl,
                      avatarColor: _avatarColor(chat.id, scheme),
                      subtitleIcon: hasDraft || isTyping
                          ? null
                          : _chatPreviewIcon(chat),
                      subtitlePrefix: hasDraft || isTyping
                          ? null
                          : _chatPreviewAuthor(chat),
                      compact: compact,
                      // Presence has its own subscription: the list snapshot
                      // this row was built from is blind to it.
                      isOnline:
                          !chat.isSaved &&
                          chat.chatType == 'direct' &&
                          ref.watch(chatOnlineProvider(chat.id)),
                      isSecret: chat.isSecret,
                      isSaved: chat.isSaved,
                      partnerBadges: chat.partnerBadges,
                      isMuted:
                          ref.watch(chatMutedProvider(chat.id)).value ?? false,
                      deliveryLabel:
                          chat.lastMessage?.senderId ==
                              ref.read(authProvider).session?.userId
                          ? chat.lastMessage?.isFailed == true
                                ? context.l10n.inboxSendFailed
                                : chat.lastMessage?.isSending == true ||
                                      (chat.lastMessage?.id ?? 1) <= 0
                                ? context.l10n.inboxWaitingToSend
                                : null
                          : null,
                      chatId: chat.id,
                      keyMismatch: chat.keyMismatch,
                      isSelected: desktopChatId == chat.id,
                      isPicked: picked,
                      // Delete on a focused row asks before it removes.
                      onDeleteRequested: selecting
                          ? null
                          : () => unawaited(_leaveChat(context, chat)),
                      onTap: () {
                        if (selecting) {
                          _togglePick(chat.id);
                          return;
                        }
                        if (ref
                            .read(clientCapabilitiesProvider)
                            .browserWorkspace) {
                          context.go('/main/chats?chat=${chat.id}');
                        } else if (Breakpoints.twoPane(
                          MediaQuery.sizeOf(context),
                        )) {
                          ref
                              .read(desktopSelectedChatProvider.notifier)
                              .setSelectedChat(chat.id);
                        } else {
                          context.push('/chat/${chat.id}');
                        }
                      },
                      // While chats are being picked, any press on a row
                      // picks it; the menu returns when the mode ends.
                      onLongPress: () {
                        if (selecting) {
                          _togglePick(chat.id);
                        } else {
                          unawaited(_showChatContextMenu(context, chat));
                        }
                      },
                      onSecondaryTapDown: (Offset position) {
                        if (selecting) {
                          _togglePick(chat.id);
                        } else {
                          unawaited(
                            _showChatContextMenu(
                              context,
                              chat,
                              anchor: position,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              );

              return RepaintBoundary(
                key: ValueKey<int>(chat.id),
                child: Padding(
                  // 2 dp: unread tiles used to fuse into one block.
                  padding: EdgeInsets.only(
                    bottom: index == filtered.length - 1 ? 0 : 2,
                  ),
                  // A chat that changes place (new message, pin) slides to
                  // its new slot; switching filter or folder does not.
                  child: ReorderSlide(
                    index: index,
                    scope: (filter, selected),
                    gap: 2,
                    child: item,
                  ),
                ),
              );
            },
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            findChildIndexCallback: (Key key) {
              if (key is! ValueKey<int>) return null;
              final int id = key.value;
              return idToIndex[id];
            },
            childCount: filtered.length,
          ),
        ),
      ),
    ];
  }

  String _previewText(String? raw, {bool cache = true}) {
    final String text =
        (LiveLocation.parse(raw ?? '')?.preview ??
                InteractiveMessage.parse(raw ?? '')?.preview ??
                raw ??
                '')
            .trim();
    if (text.isEmpty) return context.l10n.chatNoMessages;
    final Match? match = _forwardedPattern.firstMatch(text);
    if (match != null) {
      return context.l10n.chatPreviewForwardedFrom(
        match.group(1) ?? context.l10n.commonUnknown,
      );
    }
    return _previewFormatter.format(text, cache: cache);
  }

  _LastMessageKind? _lastMessageKind(ApiMessage? message) {
    if (message == null || !message.hasMedia) {
      return null;
    }
    final String mediaType = (message.mediaType ?? '').toLowerCase();
    final String msgType = message.msgType.toLowerCase();
    final String fileName = (message.mediaName ?? message.mediaUrl ?? '')
        .trim();

    if (mediaType.startsWith('image/') || msgType.contains('image')) {
      return _LastMessageKind.photo;
    }
    if (mediaType.startsWith('video/') || msgType.contains('video')) {
      return _LastMessageKind.video;
    }
    if (mediaType.startsWith('audio/') ||
        msgType.contains('audio') ||
        msgType.contains('voice')) {
      return _LastMessageKind.audio;
    }

    final FileTypeInfo info = FileTypeDetector.detect(
      fileName: fileName,
      mimeType: mediaType,
    );
    return switch (info.category) {
      FileTypeCategory.image => _LastMessageKind.photo,
      FileTypeCategory.video => _LastMessageKind.video,
      FileTypeCategory.audio => _LastMessageKind.audio,
      _ => _LastMessageKind.file,
    };
  }

  String _lastMessageKindLabel(_LastMessageKind kind) {
    return switch (kind) {
      _LastMessageKind.photo => context.l10n.chatPreviewPhoto,
      _LastMessageKind.video => context.l10n.chatPreviewVideo,
      _LastMessageKind.audio => context.l10n.chatPreviewAudio,
      _LastMessageKind.file => context.l10n.chatPreviewFile,
    };
  }

  IconData? _chatPreviewIcon(ApiChatSummary chat) {
    if (chat.isSecret) return null;
    final _LastMessageKind? kind = _lastMessageKind(chat.lastMessage);
    if (kind == null) return null;
    return switch (kind) {
      _LastMessageKind.photo => Icons.photo_camera_rounded,
      _LastMessageKind.video => Icons.videocam_rounded,
      _LastMessageKind.audio => Icons.audiotrack_rounded,
      _LastMessageKind.file => Icons.attach_file_rounded,
    };
  }

  String _chatPreview(ApiChatSummary chat) {
    final message = chat.lastMessage;
    if (chat.isSecret) return context.l10n.inboxEncryptedPreview;
    if (message != null &&
        !message.isDecrypted &&
        (message.e2eeContent != null || message.isE2ee)) {
      return context.l10n.noticeNewMessage;
    }
    final ApiMessage? lastMessage = chat.lastMessage;
    final String preview = _previewText(
      lastMessage?.content,
      cache: !chat.isSecret,
    );
    final bool hasMessage = (lastMessage?.content ?? '').trim().isNotEmpty;
    final _LastMessageKind? kind = _lastMessageKind(lastMessage);
    // The icon before the preview already names the media type. The word is
    // used only when there is no caption to show.
    final String typedPreview = kind == null || hasMessage
        ? preview
        : _lastMessageKindLabel(kind);
    final String description = chat.description.trim();
    if (chat.chatType == 'channel') {
      if (lastMessage != null) {
        return typedPreview;
      }
      if (description.isNotEmpty) {
        return description;
      }
      return context.l10n.groupNoPostsYet;
    }
    if (chat.chatType == 'group') {
      if (lastMessage != null) {
        // The tile paints the author itself, see [_chatPreviewAuthor].
        return typedPreview;
      }
      if (description.isNotEmpty) {
        return description;
      }
      return context.l10n.chatNoMessages;
    }
    return typedPreview;
  }

  /// Author of the last message of a group, shown before its preview.
  String? _chatPreviewAuthor(ApiChatSummary chat) {
    final ApiMessage? message = chat.lastMessage;
    if (chat.chatType != 'group' || chat.isSecret || message == null) {
      return null;
    }
    // An undecrypted message shows a neutral notice without a name.
    if (!message.isDecrypted &&
        (message.e2eeContent != null || message.isE2ee)) {
      return null;
    }
    final String author = message.senderDisplayName.trim().isNotEmpty
        ? message.senderDisplayName.trim()
        : message.senderUsername.trim();
    return author.isEmpty ? null : author;
  }

  Color _avatarColor(int seed, ColorScheme scheme) {
    return NiosMark.resolveColor('$seed', scheme);
  }

  /// Mutes or unmutes [chat] and says which of the two happened.
  Future<void> _toggleMute(ApiChatSummary chat) async {
    final bool wasMuted = ref.read(chatMutedProvider(chat.id)).value ?? false;
    try {
      await ref.read(chatMutedProvider(chat.id).notifier).toggle();
    } catch (error) {
      if (mounted) AppToast.showError(context, error);
      return;
    }
    if (!mounted) return;
    AppToast.showInfo(
      context,
      wasMuted ? context.l10n.inboxUnmutedToast : context.l10n.inboxMutedToast,
    );
  }

  /// Deletes a direct or secret conversation, or leaves a group or channel.
  /// No confirmation and no list refresh: the callers own both.
  Future<void> _removeChat(ApiChatSummary chat) async {
    if (chat.isSecret && !chat.keyMismatch) {
      final secret = await ref.read(secretChatCoordinatorProvider.future);
      if (secret == null) throw StateError('Secret account unavailable');
      await secret.deleteConversation(chat.id);
    } else {
      await ref.read(chatRepositoryProvider).leaveChat(chat.id);
    }
  }

  Future<void> _leaveChat(BuildContext context, ApiChatSummary chat) async {
    final bool isDirect =
        chat.chatType != 'group' && chat.chatType != 'channel';
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: isDirect
          ? context.l10n.inboxDeleteNamed(chat.name)
          : context.l10n.inboxLeaveNamed(chat.name),
      subtitle: chat.isSecret
          ? context.l10n.secretDeleteWarning
          : isDirect
          ? context.l10n.modalDeleteChatBody
          : context.l10n.groupManageLeaveBody,
      confirmLabel: isDirect
          ? context.l10n.commonDelete
          : context.l10n.groupManageLeave,
      cancelLabel: context.l10n.commonCancel,
      icon: isDirect ? Icons.delete_outline_rounded : Icons.logout_rounded,
      destructive: true,
    );
    if (confirmed != true) return;

    try {
      await _removeChat(chat);
      await ref.read(chatsProvider.notifier).refresh();
      if (!context.mounted) return;
      AppToast.showSuccess(
        context,
        isDirect ? context.l10n.inboxDeleted : context.l10n.chatListLeft,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppToast.showError(context, e);
    }
  }

  /// Opens the actions of [chat]: a menu at the pointer for a right click
  /// ([anchor] is its global position), the action sheet for a long press.
  Future<void> _showChatContextMenu(
    BuildContext context,
    ApiChatSummary chat, {
    Offset? anchor,
  }) async {
    if (anchor != null && _openCursorMenu(chat, anchor)) return;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isMuted = ref.read(chatMutedProvider(chat.id)).value ?? false;
    final ChatActionResult? action = await ChatActionsModal.show(
      context,
      chat: chat,
      avatarColor: _avatarColor(chat.id, scheme),
      isMuted: isMuted,
    );

    if (action == null || !context.mounted) return;
    await _runChatAction(chat, action);
  }

  /// Runs one action of the sheet or of the cursor menu on [chat].
  Future<void> _runChatAction(
    ApiChatSummary chat,
    ChatActionResult action,
  ) async {
    if (!mounted) return;
    switch (action) {
      case ChatActionResult.markRead:
        await _markRead(chat);
        return;
      case ChatActionResult.toggleMute:
        await _toggleMute(chat);
        return;
      case ChatActionResult.addToFolder:
        await _addToFolder(context, chat);
        return;
      case ChatActionResult.select:
        _togglePick(chat.id);
        return;
      case ChatActionResult.leave:
        await _leaveChat(context, chat);
        return;
    }
  }

  /// Adds [chat] to a folder's own list, or takes it out of it.
  Future<void> _addToFolder(BuildContext context, ApiChatSummary chat) async {
    final List<ChatFolder> folders =
        ref.read(chatFoldersProvider).value ?? const <ChatFolder>[];
    if (folders.isEmpty) {
      // Nothing to add to yet: folder management creates the first one.
      await openChatFolders(context);
      return;
    }
    final ChatFolder? folder = await ChatActionsModal.pickFolder(
      context,
      chat: chat,
      folders: folders,
    );
    if (folder == null || !context.mounted) return;

    final bool remove = folder.chatIds.contains(chat.id);
    final List<int> chatIds = remove
        ? folder.chatIds.where((int id) => id != chat.id).toList()
        : <int>[...folder.chatIds, chat.id];
    if (chatIds.isEmpty && folder.types.isEmpty) {
      // A folder cannot be left without a single rule: taking out its last
      // chat is a decision about the folder itself.
      await openChatFolders(context);
      return;
    }
    try {
      await ref
          .read(chatFoldersProvider.notifier)
          .save(
            ChatFolder(
              id: folder.id,
              title: folder.title,
              chatIds: chatIds,
              types: folder.types,
              unreadOnly: folder.unreadOnly,
              position: folder.position,
              version: folder.version,
            ),
          );
    } on ChatFolderVersionConflict {
      if (context.mounted) {
        AppToast.showError(context, context.l10n.inboxFolderConflict);
      }
      return;
    } catch (error) {
      if (context.mounted) AppToast.showError(context, error);
      return;
    }
    if (!context.mounted) return;
    AppToast.showSuccess(
      context,
      remove
          ? context.l10n.inboxFolderRemoved(folder.title)
          : context.l10n.inboxFolderAdded(folder.title),
    );
  }

  /// Picks or unpicks [chatId]. The first pick enters multi-select, unpicking
  /// the last chat leaves it.
  void _togglePick(int chatId) {
    ref.read(inboxSelectionProvider.notifier).toggle(chatId);
  }

  void _endSelection() => ref.read(inboxSelectionProvider.notifier).clear();

  /// Picked chats that are still in the list.
  List<ApiChatSummary> _selectedChats() {
    final Set<int> ids = ref.read(inboxSelectionProvider);
    final List<ApiChatSummary> chats =
        ref.read(visibleChatsProvider).value ?? const <ApiChatSummary>[];
    return chats
        .where((ApiChatSummary chat) => ids.contains(chat.id))
        .toList(growable: false);
  }

  Future<void> _markSelectedRead() async {
    final List<ApiChatSummary> unread = _selectedChats()
        .where((ApiChatSummary chat) => chat.unreadCount > 0)
        .toList(growable: false);
    _endSelection();
    // Each chat reports its own failure, with a retry.
    await Future.wait(unread.map(_markRead));
  }

  /// Mutes every picked chat; when all of them are muted already, unmutes.
  Future<void> _toggleSelectedMute() async {
    final List<int> ids = _selectedChats()
        .where((ApiChatSummary chat) => !chat.isSaved)
        .map((ApiChatSummary chat) => chat.id)
        .toList(growable: false);
    _endSelection();
    if (ids.isEmpty) return;
    try {
      final Set<int> muted = await ref.read(chatMuteHubProvider.future);
      final bool mute = !ids.every(muted.contains);
      await ref.read(chatMuteHubProvider.notifier).setMutedAll(ids, mute);
      if (!mounted) return;
      AppToast.showInfo(
        context,
        mute ? context.l10n.inboxMutedToast : context.l10n.inboxUnmutedToast,
      );
    } catch (error) {
      if (mounted) AppToast.showError(context, error);
    }
  }

  /// Deletes the picked direct chats and leaves the picked groups and
  /// channels, after one confirmation for all of them.
  Future<void> _deleteSelected() async {
    final List<ApiChatSummary> chats = _selectedChats();
    if (chats.isEmpty) {
      _endSelection();
      return;
    }
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.inboxDeleteSelectedTitle(chats.length),
      subtitle: context.l10n.inboxDeleteSelectedBody,
      confirmLabel: context.l10n.commonDelete,
      cancelLabel: context.l10n.commonCancel,
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    _endSelection();

    int removed = 0;
    Object? failure;
    for (final ApiChatSummary chat in chats) {
      try {
        await _removeChat(chat);
        removed++;
      } catch (error) {
        // One chat that refuses does not stop the rest.
        failure ??= error;
      }
    }
    await ref.read(chatsProvider.notifier).refresh();
    if (!mounted) return;
    final Object? error = failure;
    if (error != null) AppToast.showError(context, error);
    if (removed > 0) {
      AppToast.showSuccess(context, context.l10n.inboxDeletedCount(removed));
    }
  }
}
