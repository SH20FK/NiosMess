import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/rendering.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
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
import 'package:pulse_flutter/widgets/centered_note.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_filter_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_header.dart';
import 'package:pulse_flutter/widgets/chat/chat_search_field.dart';


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


  bool _isInitialLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatsProvider.notifier).refresh();
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _isInitialLoaded = true);
        }
      });
    });
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
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool compact = settings.compactMode;
    final AuthState auth = ref.watch(authProvider);
    final AsyncValue<List<ApiChatSummary>> chatsAsync = ref.watch(
      chatsProvider,
    );
    final AsyncValue<ApiSearchResult> searchAsync = ref.watch(chatListSearchProvider);
    final filter = ref.watch(chatFilterProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: ChatListHeader(
        onJoinTap: () => context.push('/join'),
        onDirectTap: () => _showStartDirectChatDialog(context),
      ),
      floatingActionButton: _CreateFab(
        onGroupTap: () => context.push('/chat/create?type=group'),
        onChannelTap: () => context.push('/chat/create?type=channel'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticService.confirm();
          await ref.read(chatsProvider.notifier).refresh();
        },
        displacement: 40,
        child: NotificationListener<UserScrollNotification>(
          onNotification: _handleUserScroll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      const ChatSearchField(),
                      const SizedBox(height: 10),
                      const ChatListFilterBar(),
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
                filter,
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

  List<Widget> _buildChatSlivers(
    AuthState auth,
    AsyncValue<List<ApiChatSummary>> chatsAsync,
    bool compact,
    ColorScheme scheme,
    TextTheme textTheme,
    ApiSearchResult? searchResult,
    ChatFilter filter,
  ) {
    if (!auth.isAuthenticated) {
      return <Widget>[
        SliverFillRemaining(
          child: CenteredNote(
            context.l10n.chatListNotAuthenticated,
            icon: Icons.lock_outline_rounded,
          ),
        ),
      ];
    }

    return chatsAsync.when(
      data: (List<ApiChatSummary> chats) {
        final List<ApiChatSummary> filtered = _applyFilter(chats, filter);
        final Set<int> resultChatIds = <int>{
          ...?searchResult?.chats.map((ApiSearchChat chat) => chat.id),
          ...?searchResult?.messages.map(
            (ApiSearchMessage message) => message.chatId,
          ),
        };
        final bool isSearchActive = searchResult != null && searchResult.messages.isNotEmpty;
        final List<ApiChatSummary> searched = filtered
            .where((ApiChatSummary chat) {
              if (!isSearchActive) return true;
              return resultChatIds.contains(chat.id);
            })
            .toList(growable: false);

        if (searched.isEmpty) {
          return <Widget>[
            SliverFillRemaining(
              child: CenteredNote(
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
                          isSecret: chat.isSecret,
                          partnerBadges: chat.partnerBadges,
                          chatId: chat.id,
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
            filter,
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
            filter,
          );
        }
        return <Widget>[
          SliverFillRemaining(
            child: CenteredNote(
              context.l10n.chatListFailedLoad('$error'),
              icon: Icons.error_outline_rounded,
            ),
          ),
        ];
      },
    );
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
      HapticService.tap();
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

  void _showStartDirectChatDialog(BuildContext context) {
    showAppDialog<void>(
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
              this.context.push('/chat/dm/$username');
            }

            return AppDialog(
              title: context.l10n.chatCreatePersonalPrompt,
              actions: <AppDialogAction>[
                AppDialogAction(
                  label: context.l10n.commonCancel,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                AppDialogAction(
                  label: context.l10n.chatCreatePersonalStart,
                  isPrimary: true,
                  onPressed: submit,
                ),
              ],
              child: TextField(
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

class _CreateFab extends StatefulWidget {
  const _CreateFab({
    required this.onGroupTap,
    required this.onChannelTap,
  });

  final VoidCallback onGroupTap;
  final VoidCallback onChannelTap;

  @override
  State<_CreateFab> createState() => _CreateFabState();
}

class _CreateFabState extends State<_CreateFab>
    with SingleTickerProviderStateMixin {
  bool _open = false;

  void _toggle() {
    HapticService.confirm();
    setState(() => _open = !_open);
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (_open) ...[
          _FabAction(
            icon: Icons.groups_rounded,
            label: l10n.groupNewGroup,
            scheme: scheme,
            textTheme: textTheme,
            onTap: () {
              _close();
              widget.onGroupTap();
            },
          ),
          const SizedBox(height: 12),
          _FabAction(
            icon: Icons.campaign_rounded,
            label: l10n.groupNewChannel,
            scheme: scheme,
            textTheme: textTheme,
            onTap: () {
              _close();
              widget.onChannelTap();
            },
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          onPressed: _toggle,
          heroTag: 'chat_create_fab',
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 250),
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _FabAction extends StatelessWidget {
  const _FabAction({
    required this.icon,
    required this.label,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: AnimatedScale(
            scale: 1,
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(label, style: textTheme.labelLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
