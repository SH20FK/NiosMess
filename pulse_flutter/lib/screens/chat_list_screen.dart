import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';

enum _ChatFilter { all, unread, groups, channels, direct, bots }

enum _LastMessageKind { photo, video, audio, file }

enum _ChatSwipeAction { delete }

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({this.onFabExtendedChanged, super.key});

  final ValueChanged<bool>? onFabExtendedChanged;

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final SearchController _searchController = SearchController();
  late final TabController _filterController;
  String _query = '';
  _ChatFilter _filter = _ChatFilter.all;

  bool _isInitialLoaded = false;

  @override
  void initState() {
    super.initState();
    _filterController = TabController(
      length: _ChatFilter.values.length,
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatsProvider.notifier).refresh();
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _isInitialLoaded = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    ref.read(chatListSearchProvider.notifier).clear();
    _searchController.dispose();
    super.dispose();
  }

  List<ApiChatSummary> _applyFilter(
    List<ApiChatSummary> chats,
    _ChatFilter filter,
  ) {
    switch (filter) {
      case _ChatFilter.all:
        return chats;
      case _ChatFilter.unread:
        return chats
            .where((ApiChatSummary c) => c.unreadCount > 0)
            .toList(growable: false);
      case _ChatFilter.groups:
        return chats
            .where((ApiChatSummary c) => c.chatType == 'group')
            .toList(growable: false);
      case _ChatFilter.channels:
        return chats
            .where((ApiChatSummary c) => c.chatType == 'channel')
            .toList(growable: false);
      case _ChatFilter.direct:
        return chats
            .where((ApiChatSummary c) => c.chatType == 'direct')
            .toList(growable: false);
      case _ChatFilter.bots:
        return chats
            .where((ApiChatSummary c) => c.chatType == 'bot')
            .toList(growable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool compact = settings.compactMode;
    final bool optimize = settings.optimizeForWeakDevices;
    final AuthState auth = ref.watch(authProvider);
    final AsyncValue<List<ApiChatSummary>> chatsAsync = ref.watch(
      chatsProvider,
    );
    final String query = _query.trim();
    final AsyncValue<ApiSearchResult> searchAsync = query.isEmpty
        ? const AsyncValue<ApiSearchResult>.data(ApiSearchResult.empty())
        : ref.watch(chatListSearchProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: optimize
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: scheme.surface.withValues(alpha: 0.95),
                  child: Text(context.l10n.tabChats),
                )
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: scheme.surface.withValues(alpha: 0.6),
                    child: Text(context.l10n.tabChats),
                  ),
                ),
        ),
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: <Widget>[
          IconButton(
            onPressed: () => _showCreateMenu(context),
            tooltip: context.l10n.groupCreateOrJoin,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: _handleUserScroll,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.only(
                top: MediaQuery.viewPaddingOf(context).top + kToolbarHeight,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenHorizontalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 10),
                    _searchAndFilter(scheme, textTheme, searchAsync),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            ..._buildChatSlivers(
              auth,
              chatsAsync,
              compact,
              scheme,
              textTheme,
              searchAsync.asData?.value,
            ),
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchAndFilter(
    ColorScheme scheme,
    TextTheme textTheme,
    AsyncValue<ApiSearchResult> searchAsync,
  ) {
    final Widget searchField = SearchBar(
      controller: _searchController,
      onChanged: _onSearchChanged,
      onSubmitted: (_) => _openFirstMessageMatch(searchAsync),
      hintText: context.l10n.chatListSearchMessagesHint,
      leading: const Icon(Icons.search_rounded),
      trailing: <Widget>[
        if (_query.isNotEmpty)
          IconButton(
            onPressed: _clearSearch,
            icon: const Icon(Icons.close_rounded),
            tooltip: context.l10n.commonCancel,
          )
        else
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
            tooltip: context.l10n.commonSearch,
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        searchField,
        _messageSearchPreview(searchAsync, scheme, textTheme),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: TabBar(
            controller: _filterController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (int index) {
              setState(() => _filter = _ChatFilter.values[index]);
            },
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            labelColor: scheme.onPrimaryContainer,
            unselectedLabelColor: scheme.onSurfaceVariant,
            labelStyle: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            splashBorderRadius: BorderRadius.circular(28),
            tabs: _ChatFilter.values
                .map(
                  (_ChatFilter value) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(_filterIcon(value), size: 18),
                        const SizedBox(width: 7),
                        Text(_filterShortLabel(value)),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.direction == ScrollDirection.reverse) {
      widget.onFabExtendedChanged?.call(false);
    } else if (notification.direction == ScrollDirection.forward ||
        notification.metrics.pixels <= 0) {
      widget.onFabExtendedChanged?.call(true);
    }
    return false;
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    if (value.trim().isEmpty) {
      ref.read(chatListSearchProvider.notifier).clear();
      return;
    }
    ref.read(chatListSearchProvider.notifier).search(value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    ref.read(chatListSearchProvider.notifier).clear();
  }

  void _openFirstMessageMatch(AsyncValue<ApiSearchResult> searchAsync) {
    final ApiSearchResult? result = searchAsync.asData?.value;
    if (result == null || result.messages.isEmpty) {
      return;
    }
    final ApiSearchMessage message = result.messages.first;
    if (MediaQuery.sizeOf(context).width >= 760) {
      ref.read(desktopSelectedChatProvider.notifier).setSelectedChat(message.chatId);
      // We also need to handle message highlighting on desktop later if possible, but basic routing first
    } else {
      context.push('/chat/${message.chatId}?highlight=${message.id}');
    }
  }

  Widget _messageSearchPreview(
    AsyncValue<ApiSearchResult> searchAsync,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (_query.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: searchAsync.when(
        data: (ApiSearchResult result) {
          if (result.messages.isEmpty) {
            return const SizedBox.shrink();
          }
          final List<ApiSearchMessage> messages = result.messages
              .take(3)
              .toList(growable: false);
          return Padding(
            key: ValueKey<int>(messages.length),
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.manage_search_rounded,
                          size: 20,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.chatListMessageMatches,
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${result.messages.length}',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final ApiSearchMessage message in messages)
                    _messageResultTile(message, scheme, textTheme),
                ],
              ),
            ),
          );
        },
        loading: () => Padding(
          key: const ValueKey<String>('loading'),
          padding: const EdgeInsets.only(top: 10),
          child: LinearProgressIndicator(
            year2023: false,
            minHeight: 2,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(key: ValueKey<String>('error')),
      ),
    );
  }

  Widget _messageResultTile(
    ApiSearchMessage message,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return InkWell(
      onTap: () {
        if (MediaQuery.sizeOf(context).width >= 760) {
          ref.read(desktopSelectedChatProvider.notifier).setSelectedChat(message.chatId);
        } else {
          context.push('/chat/${message.chatId}?highlight=${message.id}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message.senderDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _filterShortLabel(_ChatFilter value) {
    return switch (value) {
      _ChatFilter.all => context.l10n.chatListFilterAll,
      _ChatFilter.unread => context.l10n.chatListFilterUnread,
      _ChatFilter.groups => context.l10n.chatListFilterGroups,
      _ChatFilter.channels => context.l10n.chatListFilterChannels,
      _ChatFilter.direct => context.l10n.chatListFilterDirect,
      _ChatFilter.bots => context.l10n.chatListFilterBots,
    };
  }

  List<Widget> _buildChatSlivers(
    AuthState auth,
    AsyncValue<List<ApiChatSummary>> chatsAsync,
    bool compact,
    ColorScheme scheme,
    TextTheme textTheme,
    ApiSearchResult? searchResult,
  ) {
    if (!auth.isAuthenticated) {
      return <Widget>[
        SliverFillRemaining(
          child: _CenteredNote(
            context.l10n.chatListNotAuthenticated,
            icon: Icons.lock_outline_rounded,
          ),
        ),
      ];
    }

    return chatsAsync.when(
      data: (List<ApiChatSummary> chats) {
        final List<ApiChatSummary> filtered = _applyFilter(chats, _filter);
        final String query = _query.trim().toLowerCase();
        final Set<int> resultChatIds = <int>{
          ...?searchResult?.chats.map((ApiSearchChat chat) => chat.id),
          ...?searchResult?.messages.map(
            (ApiSearchMessage message) => message.chatId,
          ),
        };
        final List<ApiChatSummary> searched = filtered
            .where((ApiChatSummary chat) {
              if (query.isEmpty) return true;
              return chat.name.toLowerCase().contains(query) ||
                  (chat.lastMessage?.content ?? '').toLowerCase().contains(
                    query,
                  ) ||
                  resultChatIds.contains(chat.id);
            })
            .toList(growable: false);

        if (searched.isEmpty) {
          return <Widget>[
            SliverFillRemaining(
              child: _CenteredNote(
                context.l10n.chatListNoChats,
                icon: Icons.chat_bubble_outline_rounded,
              ),
            ),
          ];
        }

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
                        await _handleChatSwipe(context, chat, direction);
                        return false;
                      },
                      child: GestureDetector(
                        onSecondaryTapDown: (TapDownDetails details) {
                          _showChatContextMenu(context, chat);
                        },
                        child: ChatTile(
                          key: ValueKey<int>(chat.id),
                          title: chat.name,
                          subtitle: _chatPreview(chat),
                          formattedTime: formatRelativeTime(chat.lastActivity),
                          unreadCount: chat.unreadCount,
                          avatarText: chat.name,
                          avatarUrl: chat.avatarUrl,
                          avatarColor: _avatarColor(chat.id, scheme),
                          subtitleIcon: _chatPreviewIcon(chat),
                          compact: compact,
                          partnerBadges: chat.partnerBadges,
                          onTap: () {
                            if (MediaQuery.sizeOf(context).width >= 760) {
                              ref
                                  .read(desktopSelectedChatProvider.notifier)
                                  .setSelectedChat(chat.id);
                            } else {
                              context.push('/chat/${chat.id}');
                            }
                          },
                          onLongPress: () => _showChatContextMenu(context, chat),
                        ),
                      ),
                    ),
                  );

                  if (_isInitialLoaded) {
                    return RepaintBoundary(child: item);
                  }

                  final int delayMs = (index < 6) ? index * 35 : 0;
                  return RepaintBoundary(child: item)
                      .animate()
                      .fade(duration: 250.ms, delay: delayMs.ms, curve: Curves.easeOutCubic)
                      .slideY(
                        begin: 0.06,
                        end: 0,
                        duration: 250.ms,
                        delay: delayMs.ms,
                        curve: Curves.easeOutCubic,
                      );
                },
                childCount: searched.length,
              ),
            ),
          ),
        ];
      },
      loading: () {
        if (chatsAsync.hasValue && chatsAsync.value!.isNotEmpty) {
          return _buildChatSlivers(
            auth,
            AsyncValue.data(chatsAsync.value!),
            compact,
            scheme,
            textTheme,
            searchResult,
          );
        }
        return <Widget>[
          const SliverFillRemaining(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ChatListSkeleton(),
            ),
          ),
        ];
      },
      error: (Object error, StackTrace stack) {
        if (chatsAsync.hasValue && chatsAsync.value!.isNotEmpty) {
          return _buildChatSlivers(
            auth,
            AsyncValue.data(chatsAsync.value!),
            compact,
            scheme,
            textTheme,
            searchResult,
          );
        }
        return <Widget>[
          SliverFillRemaining(
            child: _CenteredNote(
              context.l10n.chatListFailedLoad('$error'),
              icon: Icons.error_outline_rounded,
            ),
          ),
        ];
      },
    );
  }

  IconData _filterIcon(_ChatFilter value) {
    return switch (value) {
      _ChatFilter.all => Icons.inbox_rounded,
      _ChatFilter.unread => Icons.mark_chat_unread_rounded,
      _ChatFilter.groups => Icons.groups_rounded,
      _ChatFilter.channels => Icons.campaign_rounded,
      _ChatFilter.direct => Icons.person_rounded,
      _ChatFilter.bots => Icons.smart_toy_rounded,
    };
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

  Future<void> _handleChatSwipe(
    BuildContext context,
    ApiChatSummary chat,
    DismissDirection direction,
  ) async {
    if (ref.read(uiSettingsProvider).haptics) {
      HapticFeedback.lightImpact();
    }

    final _ChatSwipeAction? action = await _showSwipeActionSheet(
      context,
      <_ChatSwipeAction>[_ChatSwipeAction.delete],
    );
    if (action == null || !context.mounted) {
      return;
    }
    await _performSwipeAction(context, chat, action);
  }

  Future<_ChatSwipeAction?> _showSwipeActionSheet(
    BuildContext context,
    List<_ChatSwipeAction> actions,
  ) {
    final bool isWide = MediaQuery.sizeOf(context).width >= 760;

    Widget buildMenuContent(BuildContext ctx) {
      final ColorScheme scheme = Theme.of(ctx).colorScheme;
      final TextTheme textTheme = Theme.of(ctx).textTheme;

      Widget actionTile(_ChatSwipeAction action) {
        final bool destructive = action == _ChatSwipeAction.delete;
        final Color fg = destructive ? scheme.error : scheme.onSurface;
        return InkWell(
          onTap: () => Navigator.of(ctx).pop(action),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (destructive ? scheme.error : scheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_swipeActionIcon(action), color: fg, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  _swipeActionLabel(action),
                  style: textTheme.titleMedium?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: actions.map(actionTile).toList(growable: false),
            ),
          ),
        ),
      );
    }

    if (isWide) {
      return showDialog<_ChatSwipeAction>(
        context: context,
        builder: (BuildContext ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: SizedBox(
            width: 320,
            child: buildMenuContent(ctx),
          ),
        ),
      );
    }

    return showModalBottomSheet<_ChatSwipeAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: buildMenuContent,
    );
  }

  IconData _swipeActionIcon(_ChatSwipeAction action) {
    return switch (action) {
      _ChatSwipeAction.delete => Icons.delete_outline_rounded,
    };
  }

  String _swipeActionLabel(_ChatSwipeAction action) {
    return switch (action) {
      _ChatSwipeAction.delete => context.l10n.commonDelete,
    };
  }

  Future<void> _performSwipeAction(
    BuildContext context,
    ApiChatSummary chat,
    _ChatSwipeAction action,
  ) async {
    switch (action) {
      case _ChatSwipeAction.delete:
        await _leaveChat(context, chat);
        return;
    }
  }

  Future<void> _leaveChat(BuildContext context, ApiChatSummary chat) async {
    try {
      await ref.read(chatRepositoryProvider).leaveChat(chat.id);
      await ref.read(chatsProvider.notifier).refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.chatListLeft)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.commonFailed('$e'))));
    }
  }

  Future<void> _showCreateMenu(BuildContext context) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        final TextTheme textTheme = Theme.of(ctx).textTheme;

        Widget actionTile({
          required String value,
          required IconData icon,
          required String title,
          required String subtitle,
        }) {
          return InkWell(
            onTap: () => Navigator.of(ctx).pop(value),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: textTheme.titleMedium),
                        Text(
                          subtitle,
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
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  actionTile(
                    value: 'group',
                    icon: Icons.groups_rounded,
                    title: context.l10n.groupNewGroup,
                    subtitle: context.l10n.groupCreateSharedSubtitle,
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: scheme.outlineVariant.withValues(alpha: 0.16),
                  ),
                  actionTile(
                    value: 'channel',
                    icon: Icons.campaign_rounded,
                    title: context.l10n.groupNewChannel,
                    subtitle: context.l10n.groupCreateBroadcastSubtitle,
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: scheme.outlineVariant.withValues(alpha: 0.16),
                  ),
                  actionTile(
                    value: 'join',
                    icon: Icons.link_rounded,
                    title: context.l10n.groupJoinByInvite,
                    subtitle: context.l10n.groupJoinByInviteSubtitle,
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: scheme.outlineVariant.withValues(alpha: 0.16),
                  ),
                  actionTile(
                    value: 'direct',
                    icon: Icons.person_add_alt_1_rounded,
                    title: context.l10n.chatCreatePersonal,
                    subtitle: context.l10n.chatCreatePersonalSubtitle,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (action == null || !context.mounted) return;
    switch (action) {
      case 'group':
        context.push('/chat/create?type=group');
        return;
      case 'channel':
        context.push('/chat/create?type=channel');
        return;
      case 'join':
        context.push('/join');
        return;
      case 'direct':
        _showStartDirectChatDialog(context);
        return;
    }
  }

  void _showStartDirectChatDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final TextEditingController usernameController = TextEditingController();
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            String? errorText;

            void submit() {
              String username = usernameController.text.trim();
              if (username.startsWith('@')) {
                username = username.substring(1);
              }
              if (username.isEmpty) {
                setState(() {
                  errorText = context.l10n.chatCreatePersonalErrorEmpty;
                });
                return;
              }
              Navigator.of(ctx).pop();
              context.push('/chat/dm/$username');
            }

            return AlertDialog(
              title: Text(context.l10n.chatCreatePersonalPrompt),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: usernameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.chatCreatePersonalUsernameLabel,
                      hintText: context.l10n.chatCreatePersonalUsernameHint,
                      errorText: errorText,
                      prefixText: '@',
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(context.l10n.commonCancel),
                ),
                TextButton(
                  onPressed: submit,
                  child: Text(context.l10n.chatCreatePersonalStart),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChatContextMenu(
    BuildContext context,
    ApiChatSummary chat,
  ) async {
    final bool isWide = MediaQuery.sizeOf(context).width >= 760;

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
        : showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            backgroundColor: Colors.transparent,
            builder: buildMenuContent,
          ));

    if (action == null || !context.mounted) return;

    switch (action) {
      case 'read':
        await ref.read(chatMessagesProvider(chat.id).notifier).markRead();
        await ref.read(chatsProvider.notifier).refresh();
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

class _CenteredNote extends StatelessWidget {
  const _CenteredNote(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
            ],
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
