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

enum _LastMessageKind { photo, video, audio, file }

/// Trailing room for the composer button.
///
/// Its own widget on purpose: the button hides and returns while the list
/// scrolls, and only this sliver has to follow, not the whole screen.
class _ComposerClearance extends ConsumerWidget {
  const _ComposerClearance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool composerVisible =
        ref.watch(chatListFabVisibleProvider) &&
        !ref.watch(
          inboxSearchProvider.select((InboxSearchState s) => s.active),
        );
    return SliverPadding(
      padding: EdgeInsets.only(
        // 24 resting + the 56 dp FAB and its 16 dp gap when the floating
        // button is visible + the system inset.
        bottom:
            24 +
            (composerVisible ? 72 : 0) +
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
    super.dispose();
  }

  final ScrollController _scrollController = ScrollController();

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

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
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
            child: const ChatListHeader(),
          ),
          backgroundColor: Colors.transparent,
          body: AppRefreshIndicator(
            onRefresh: () async {
              if (ref.read(uiSettingsProvider).haptics) HapticService.confirm();
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
                        // 8 above the 40 dp control row, 12 below it: the row
                        // holds its own 16 dp horizontal inset.
                        const SizedBox(height: 8),
                        RepaintBoundary(child: ChatFilterBar(compact: compact)),
                        const SizedBox(height: 12),
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
    );
  }

  double _scrollDistance = 0.0;
  static const double _kScrollHysteresis = 28.0;

  bool _handleScrollNotification(ScrollNotification notification) {
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
        const SliverFillRemaining(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ChatListSkeleton(),
          ),
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
                enabled: chat.unreadCount > 0,
                // 35% (~119 dp on a 340 dp row) leaves room for the whole
                // "Прочитано" label; 40% used to trigger on a clipped label.
                threshold: 0.35,
                background: _swipeBackground(
                  context: context,
                  icon: Icons.done_all_rounded,
                  label: context.l10n.deliveryRead,
                ),
                onTriggered: () {
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.tap();
                  }
                  unawaited(_markRead(chat));
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
                      onTap: () {
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
                      onLongPress: () => _showChatContextMenu(context, chat),
                      onSecondaryTapDown: (Offset position) =>
                          _showChatContextMenu(context, chat, anchor: position),
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
    final String typedPreview = kind == null
        ? preview
        : hasMessage
        ? '${_lastMessageKindLabel(kind)} · $preview'
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
        final author = lastMessage.senderDisplayName.trim().isNotEmpty
            ? lastMessage.senderDisplayName.trim()
            : lastMessage.senderUsername.trim();
        return author.isEmpty ? typedPreview : '$author: $typedPreview';
      }
      if (description.isNotEmpty) {
        return description;
      }
      return context.l10n.chatNoMessages;
    }
    return typedPreview;
  }

  Color _avatarColor(int seed, ColorScheme scheme) {
    return NiosMark.resolveColor('$seed', scheme);
  }

  /// Action painted behind a row that is being swiped towards the start.
  ///
  /// No vertical margin: the 2 dp gap lives between the tiles, so the backdrop
  /// must not shrink behind them. The radius is the tile radius, and the text
  /// is `labelLarge` so the label fits the 35% reveal.
  Widget _swipeBackground({
    required BuildContext context,
    required IconData icon,
    required String label,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final BorderRadius radius = AppRadii.of(context).lgRadius;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: radius,
      ),
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
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
      if (chat.isSecret && !chat.keyMismatch) {
        final secret = await ref.read(secretChatCoordinatorProvider.future);
        if (secret == null) throw StateError('Secret account unavailable');
        await secret.deleteConversation(chat.id);
      } else {
        await ref.read(chatRepositoryProvider).leaveChat(chat.id);
      }
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

  /// Opens the chat action modal.
  ///
  /// [anchor] carries the desktop pointer position captured by
  /// `TouchContainer.onSecondaryTapDown`; it is kept in the signature so the
  /// modal can be swapped for a cursor-anchored MenuAnchor without another
  /// wiring pass through the tile.
  Future<void> _showChatContextMenu(
    BuildContext context,
    ApiChatSummary chat, {
    Offset? anchor,
  }) async {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isMuted = ref.read(chatMutedProvider(chat.id)).value ?? false;
    final ChatActionResult? action = await ChatActionsModal.show(
      context,
      chat: chat,
      avatarColor: _avatarColor(chat.id, scheme),
      isMuted: isMuted,
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case ChatActionResult.markRead:
        await _markRead(chat);
        return;
      case ChatActionResult.toggleMute:
        try {
          await ref.read(chatMutedProvider(chat.id).notifier).toggle();
        } catch (error) {
          if (context.mounted) AppToast.showError(context, error);
          return;
        }
        if (context.mounted) {
          AppToast.showInfo(
            context,
            isMuted
                ? context.l10n.profileUnmuteNotifications
                : context.l10n.profileMuteNotifications,
          );
        }
        return;
      case ChatActionResult.leave:
        await _leaveChat(context, chat);
        return;
    }
  }
}
