import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';
import 'package:pulse_flutter/widgets/empty_state_widget.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_filter_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_search_field.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_header.dart';
import 'package:flutter/rendering.dart';
import 'package:pulse_flutter/providers/chat_list_fab_provider.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';


enum _LastMessageKind { photo, video, audio, file }

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // The provider already fetches on first build and WebSocket push keeps data fresh.
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
            .where((ApiChatSummary c) => c.chatType == 'direct')
            .toList(growable: false);
      case ChatFilter.bots:
        return chats
            .where((ApiChatSummary c) => c.chatType == 'bot' || c.isBotChat)
            .toList(growable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = ref.watch(
      uiSettingsProvider.select((s) => s.compactMode),
    );
    final bool isAuthenticated = ref.watch(
      authProvider.select((s) => s.isAuthenticated),
    );
    final AsyncValue<List<ApiChatSummary>> chatsAsync = ref.watch(
      chatsProvider,
    );
    final AsyncValue<ApiSearchResult> searchAsync = ref.watch(chatListSearchProvider);
    final filter = ref.watch(chatFilterProvider);
    final int? desktopChatId = ref.watch(desktopSelectedChatProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const ChatListHeader(),
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          HapticService.confirm();
          await ref.read(chatsProvider.notifier).refresh();
        },
        displacement: 40,
        color: scheme.primary,
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        child: NotificationListener<UserScrollNotification>(
          onNotification: _handleUserScroll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.screenHorizontalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      SizedBox(height: 4),
                      RepaintBoundary(child: ChatSearchField()),
                      SizedBox(height: 10),
                      RepaintBoundary(child: ChatListFilterBar()),
                      SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              ..._buildChatSlivers(
                isAuthenticated,
                chatsAsync,
                compact,
                scheme,
                textTheme,
                searchAsync.asData?.value,
                filter,
                desktopChatId,
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      ref.read(chatListFabVisibleProvider.notifier).hide();
    } else if (notification.direction == ScrollDirection.forward) {
      ref.read(chatListFabVisibleProvider.notifier).show();
    }
    return false;
  }

  List<Widget> _buildChatSlivers(
    bool isAuthenticated,
    AsyncValue<List<ApiChatSummary>> chatsAsync,
    bool compact,
    ColorScheme scheme,
    TextTheme textTheme,
    ApiSearchResult? searchResult,
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
        searchResult: searchResult,
        filter: filter,
        desktopChatId: desktopChatId,
      );
    }

    return chatsAsync.when(
      data: (List<ApiChatSummary> chats) => _buildChatItemsSlivers(
        chats: chats,
        compact: compact,
        scheme: scheme,
        searchResult: searchResult,
        filter: filter,
        desktopChatId: desktopChatId,
      ),
      loading: () => const <Widget>[
        SliverFillRemaining(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ChatListSkeleton(),
          ),
        ),
      ],
      error: (Object error, StackTrace stack) => <Widget>[
        SliverFillRemaining(
          child: EmptyStateWidget(
            title: context.l10n.chatListFailedLoad('$error'),
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
    required ApiSearchResult? searchResult,
    required ChatFilter filter,
    required int? desktopChatId,
  }) {
    final List<ApiChatSummary> filtered = _applyFilter(chats, filter);
    final Set<int> resultChatIds = <int>{
      ...?searchResult?.chats.map((ApiSearchChat chat) => chat.id),
      ...?searchResult?.messages.map(
        (ApiSearchMessage message) => message.chatId,
      ),
    };
    final bool isSearchActive =
        searchResult != null && searchResult.messages.isNotEmpty;
    final List<ApiChatSummary> searched = filtered
        .where((ApiChatSummary chat) {
          if (!isSearchActive) return true;
          return resultChatIds.contains(chat.id);
        })
        .toList(growable: false);

    if (searched.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          child: EmptyStateWidget(
            title: context.l10n.chatListNoChats,
            icon: Icons.chat_bubble_outline_rounded,
          ),
        ),
      ];
    }

    final Map<int, int> idToIndex = <int, int>{
      for (int i = 0; i < searched.length; i++) searched[i].id: i,
    };

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final ApiChatSummary chat = searched[index];
              final Widget item = Padding(
                padding: EdgeInsets.only(bottom: compact ? 8 : 10),
                child: Dismissible(
                  key: ValueKey<String>('chat_${chat.id}'),
                  direction: DismissDirection.endToStart,
                  background: _swipeBackground(
                    scheme: scheme,
                    alignment: Alignment.centerRight,
                    icon: Icons.delete_outline_rounded,
                    label: context.l10n.commonDelete,
                    destructive: true,
                  ),
                  confirmDismiss: (DismissDirection direction) async {
                    if (ref.read(uiSettingsProvider).haptics) {
                      HapticService.tap();
                    }
                    await _leaveChat(context, chat);
                    return false;
                  },
                  child: GestureDetector(
                    onSecondaryTapDown: (TapDownDetails details) {
                      _showChatContextMenu(context, chat);
                    },
                    child: Consumer(
                      builder: (BuildContext context, WidgetRef ref, _) {
                        final bool isTyping = ref.watch(
                          typingProvider(chat.id).select(
                            (TypingState s) => s.typingUserIds.isNotEmpty,
                          ),
                        );
                        return ChatTile(
                          title: chat.name,
                          subtitle: isTyping
                              ? context.l10n.chatTyping
                              : _chatPreview(chat),
                          formattedTime: formatRelativeTime(chat.lastActivity),
                          unreadCount: chat.unreadCount,
                          avatarText: chat.name,
                          avatarUrl: chat.avatarUrl,
                          avatarColor: _avatarColor(chat.id, scheme),
                          subtitleIcon: isTyping
                              ? Icons.edit_note_rounded
                              : _chatPreviewIcon(chat),
                          compact: compact,
                          isOnline: chat.chatType == 'direct' && chat.isOnline,
                          isSecret: chat.isSecret,
                          partnerBadges: chat.partnerBadges,
                          chatId: chat.id,
                          isSelected: desktopChatId == chat.id,
                          onTap: () {
                            if (MediaQuery.sizeOf(context).width >=
                                Breakpoints.medium) {
                              ref
                                  .read(desktopSelectedChatProvider.notifier)
                                  .setSelectedChat(chat.id);
                            } else {
                              context.push('/chat/${chat.id}');
                            }
                          },
                          onLongPress: () =>
                              _showChatContextMenu(context, chat),
                        );
                      },
                    ),
                  ),
                ),
              );

              return RepaintBoundary(
                key: ValueKey<int>(chat.id),
                child: item,
              );
            },
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            findChildIndexCallback: (Key key) {
              if (key is! ValueKey<int>) return null;
              return idToIndex[key.value];
            },
            childCount: searched.length,
          ),
        ),
      ),
    ];
  }

  String _previewText(String? raw) {
    final String text = (raw ?? '').trim();
    if (text.isEmpty) return context.l10n.chatNoMessages;
    final RegExp forwarded = RegExp(r'^_fwd from\s+(.+?):');
    final Match? match = forwarded.firstMatch(text);
    if (match != null) {
      return context.l10n.chatPreviewForwardedFrom(match.group(1) ?? 'Unknown');
    }
    return text;
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
    final ApiMessage? lastMessage = chat.lastMessage;
    final String preview = _previewText(lastMessage?.content);
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
        return context.l10n.chatListChannelPreview(typedPreview);
      }
      if (description.isNotEmpty) {
        return context.l10n.chatListChannelPreview(description);
      }
      return context.l10n.chatListChannelPreview(context.l10n.groupNoPostsYet);
    }
    if (chat.chatType == 'group') {
      if (lastMessage != null) {
        return context.l10n.chatListGroupPreview(typedPreview);
      }
      if (description.isNotEmpty) {
        return context.l10n.chatListGroupPreview(description);
      }
      return context.l10n.chatListGroupPreview(context.l10n.chatNoMessages);
    }
    return typedPreview;
  }

  Color _avatarColor(int seed, ColorScheme scheme) {
    final List<Color> colors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.secondaryContainer,
    ];
    return colors[seed.abs() % colors.length];
  }

  Widget _swipeBackground({
    required ColorScheme scheme,
    required Alignment alignment,
    required IconData icon,
    required String label,
    bool destructive = false,
  }) {
    final Color seed = destructive ? scheme.error : scheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: seed.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (alignment == Alignment.centerRight) ...<Widget>[
            Text(
              label,
              style: TextStyle(color: seed, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: seed),
          if (alignment == Alignment.centerLeft) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: seed, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _leaveChat(BuildContext context, ApiChatSummary chat) async {
    final bool isDirect = chat.chatType == 'direct';
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: isDirect
          ? context.l10n.chatDelete
          : context.l10n.groupManageLeaveTitle,
      subtitle: isDirect
          ? context.l10n.chatDeleteMessageBody
          : context.l10n.groupManageLeaveBody,
      confirmLabel:
          isDirect ? context.l10n.commonDelete : context.l10n.groupManageLeave,
      cancelLabel: context.l10n.commonCancel,
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (confirmed != true) return;

    try {
      await ref.read(chatRepositoryProvider).leaveChat(chat.id);
      await ref.read(chatsProvider.notifier).refresh();
      if (!context.mounted) return;
      AppToast.showSuccess(
        context,
        context.l10n.chatListLeft,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppToast.showError(context, e);
    }
  }

  Future<void> _showChatContextMenu(
    BuildContext context,
    ApiChatSummary chat,
  ) async {
    final bool isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    Widget buildMenuContent(BuildContext ctx) {
      final ColorScheme scheme = Theme.of(ctx).colorScheme;
      final TextTheme textTheme = Theme.of(ctx).textTheme;

      Widget actionTile({
        required IconData icon,
        required String title,
        String? subtitle,
        required String value,
        bool destructive = false,
      }) {
        final Color fg = destructive ? scheme.error : scheme.onSurface;
        return InkWell(
          onTap: () => Navigator.of(ctx).pop(value),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (destructive ? scheme.error : scheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(color: fg),
                      ),
                      if ((subtitle ?? '').isNotEmpty)
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    PulseAvatar(
                      radius: 24,
                      name: chat.name,
                      avatarUrl: chat.avatarUrl,
                      fallbackColor: _avatarColor(chat.id, scheme),
                      textColor: scheme.onPrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(chat.name, style: textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            _contextMenuSubtitle(chat),
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    actionTile(
                      icon: Icons.visibility_rounded,
                      title: context.l10n.chatListMarkRead,
                      subtitle: context.l10n.chatListMarkReadSubtitle,
                      value: 'read',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.14),
                  ),
                ),
                child: actionTile(
                  icon: Icons.delete_outline_rounded,
                  title: context.l10n.chatListLeave,
                  subtitle: context.l10n.chatListLeaveSubtitle,
                  value: 'leave',
                  destructive: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final String? action = await (isWide
        ? showDialog<String>(
            context: context,
            builder: (BuildContext ctx) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: SizedBox(
                width: 380,
                child: buildMenuContent(ctx),
              ),
            ),
          )
        : AppBottomSheets.show<String>(
            context: context,
            
            builder: buildMenuContent,
          ));

    if (action == null || !context.mounted) return;

    switch (action) {
      case 'read':
        await ref.read(chatMessagesProvider(chat.id).notifier).markRead();
        return;
      case 'leave':
        await _leaveChat(context, chat);
        return;
    }
  }

  String _contextMenuSubtitle(ApiChatSummary chat) {
    final String type = switch (chat.chatType) {
      'channel' => context.l10n.groupTypeChannel,
      'group' => context.l10n.groupTypeGroup,
      _ => context.l10n.chatListFilterDirect,
    };
    if (chat.unreadCount <= 0) return type;
    return '${context.l10n.chatListUnreadCount(chat.unreadCount)} • $type';
  }
}


