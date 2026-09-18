import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/widgets/chat/sticker_set_modal.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';


class _MessageLayoutData {
  const _MessageLayoutData({
    required this.showDateSep,
    required this.isPrevSame,
    required this.isNextSame,
  });

  final bool showDateSep;
  final bool isPrevSame;
  final bool isNextSame;
}

List<_MessageLayoutData> _precomputeLayout(List<ApiMessage> messages) {
  final int len = messages.length;
  final List<_MessageLayoutData> layout = List<_MessageLayoutData>.filled(
    len,
    const _MessageLayoutData(showDateSep: false, isPrevSame: false, isNextSame: false),
  );

  for (int i = 0; i < len; i++) {
    final ApiMessage message = messages[i];
    bool showDateSep = false;
    bool isPrevSame = false;
    bool isNextSame = false;

    if (i == 0) {
      showDateSep = true;
    } else {
      final ApiMessage prev = messages[i - 1];
      final DateTime messageDate = message.resolvedSentAt;
      final DateTime prevDate = prev.resolvedSentAt;
      showDateSep =
          messageDate.day != prevDate.day ||
          messageDate.month != prevDate.month ||
          messageDate.year != prevDate.year;
    }

    if (i > 0 && !showDateSep) {
      final ApiMessage prev = messages[i - 1];
      isPrevSame =
          prev.senderId == message.senderId && !prev.isDeleted;
    }

    if (i < len - 1) {
      final ApiMessage next = messages[i + 1];
      isNextSame =
          next.resolvedSentAt.day == message.resolvedSentAt.day &&
          next.resolvedSentAt.month == message.resolvedSentAt.month &&
          next.resolvedSentAt.year == message.resolvedSentAt.year &&
          next.senderId == message.senderId &&
          !next.isDeleted;
    }

    layout[i] = _MessageLayoutData(
      showDateSep: showDateSep,
      isPrevSame: isPrevSame,
      isNextSame: isNextSame,
    );
  }

  return layout;
}

class ChatMessageList extends ConsumerStatefulWidget {
  const ChatMessageList({
    required this.messages,
    required this.scrollController,
    required this.authUserId,
    required this.amAdminOrOwner,
    required this.isChannel,
    this.isGroup = false,
    this.onOpenComments,
    this.onReactionTap,
    required this.onOpenMedia,
    required this.onLongPressMedia,
    required this.onLongPress,
    required this.onSwipeToReply,
    required this.onCallbackQuery,
    required this.onRetrySend,
    required this.displayTextBuilder,
    required this.mediaUrlBuilder,
    required this.isImageMediaBuilder,
    required this.mediaLabelBuilder,
    required this.replyPreviewBuilder,
    required this.dateSeparatorBuilder,
    required this.animatedMessageBuilder,
    super.key,
  });

  final List<ApiMessage> messages;
  final ScrollController scrollController;
  final int authUserId;
  final bool amAdminOrOwner;
  final bool isChannel;
  final bool isGroup;
  final void Function(ApiMessage message, String emoji)? onReactionTap;
  final void Function(ApiMessage)? onOpenComments;
  final void Function(ApiMessage) onOpenMedia;
  final void Function(ApiMessage, bool isMine, bool amAdminOrOwner)
      onLongPressMedia;
  final void Function(
    ApiMessage,
    bool isMine,
    bool isChannel,
    bool amAdminOrOwner,
  )
      onLongPress;
  final void Function(ApiMessage) onSwipeToReply;
  final void Function(ApiMessage, String data) onCallbackQuery;
  final void Function(ApiMessage) onRetrySend;
  final String Function(ApiMessage) displayTextBuilder;
  final String? Function(ApiMessage) mediaUrlBuilder;
  final bool Function(ApiMessage, String url) isImageMediaBuilder;
  final String? Function(ApiMessage, String url) mediaLabelBuilder;
  final String? Function(ApiMessage, Map<int, ApiMessage> byId)
      replyPreviewBuilder;
  final Widget Function(DateTime date, DateTime now) dateSeparatorBuilder;
  final Widget Function({
    required int messageId,
    required bool animate,
    required bool isMine,
    required Widget child,
  })
      animatedMessageBuilder;

  @override
  ConsumerState<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends ConsumerState<ChatMessageList> {
  List<_MessageLayoutData>? _layoutCache;
  List<ApiMessage>? _cachedMessages;
  Map<int, ApiMessage>? _byIdCache;
  Map<int, int>? _idToIndexCache;
  final Map<int, GlobalKey> _messageKeys = <int, GlobalKey>{};
  final Set<int> _animatedMessageIds = <int>{};
  Timer? _highlightTimer;
  final ValueNotifier<int?> _highlightedIdNotifier = ValueNotifier<int?>(null);

  void _syncCaches(List<ApiMessage> messages) {
    if (identical(messages, _cachedMessages)) return;
    _cachedMessages = messages;
    _layoutCache = _precomputeLayout(messages);
    final Map<int, ApiMessage> byId = <int, ApiMessage>{};
    final Map<int, int> idToIndex = <int, int>{};
    final int len = messages.length;
    for (int i = 0; i < len; i++) {
      final ApiMessage m = messages[i];
      byId[m.id] = m;
      idToIndex[m.id] = len - 1 - i;
    }
    _byIdCache = byId;
    _idToIndexCache = idToIndex;
    _messageKeys.removeWhere((int id, _) => !byId.containsKey(id));
  }

  @override
  void initState() {
    super.initState();
    _syncCaches(widget.messages);
    _animatedMessageIds.addAll(widget.messages.map((ApiMessage m) => m.id));
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCaches(widget.messages);
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _highlightedIdNotifier.dispose();
    super.dispose();
  }

  void _scrollToMessage(int messageId) {
    _highlightTimer?.cancel();
    _highlightedIdNotifier.value = messageId;

    final GlobalKey? key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      final int? builderIndex = _idToIndexCache?[messageId];
      final List<ApiMessage> messages = widget.messages;
      if (builderIndex != null && widget.scrollController.hasClients && messages.isNotEmpty) {
        final double maxScroll = widget.scrollController.position.maxScrollExtent;
        final double estimatedItemHeight = (maxScroll / messages.length).clamp(50.0, 300.0);
        final double targetOffset = (builderIndex * estimatedItemHeight).clamp(
          0.0,
          maxScroll,
        );
        widget.scrollController
            .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        )
            .then((_) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final GlobalKey? updatedKey = _messageKeys[messageId];
            if (updatedKey != null && updatedKey.currentContext != null) {
              Scrollable.ensureVisible(
                updatedKey.currentContext!,
                alignment: 0.3,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
              );
            }
          });
        });
      }
    }

    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && _highlightedIdNotifier.value == messageId) {
        _highlightedIdNotifier.value = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ApiMessage> messages = widget.messages;
    final List<_MessageLayoutData> layout = _layoutCache!;
    final Map<int, ApiMessage> byId = _byIdCache!;

    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((s) => s.tier),
    );
    final double cacheExtent = switch (tier) {
      PerformanceTier.tierC => 250.0,
      PerformanceTier.tierB => 500.0,
      PerformanceTier.tierA => 750.0,
    };

    final DateTime now = AppTimeSettings.now();

    return RepaintBoundary(
      child: ListView.builder(
        controller: widget.scrollController,
        reverse: true,
        // ignore: deprecated_member_use
        cacheExtent: cacheExtent,
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 56),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        final int reversedIndex = messages.length - 1 - index;
        final ApiMessage message = messages[reversedIndex];
        final _MessageLayoutData data = layout[reversedIndex];

        final bool isMine = message.senderId == widget.authUserId;

        final String? mediaUrl = widget.mediaUrlBuilder(message);
        final bool hasMedia = mediaUrl != null && mediaUrl.trim().isNotEmpty;
        final bool isImageMedia =
            hasMedia ? widget.isImageMediaBuilder(message, mediaUrl) : false;
        final String? mediaLabel =
            hasMedia ? widget.mediaLabelBuilder(message, mediaUrl) : null;

        final bool isVoice = message.msgType == 'voice' ||
            (message.mediaType ?? '').toLowerCase().startsWith('audio/');
        final bool isCircleVideo = message.msgType == 'circle' ||
            message.msgType == 'circle_video' ||
            message.msgType == 'video_note' ||
            message.msgType == 'round_video';
        final bool isSticker = message.isSticker;
        final int? mediaDuration = message.mediaDuration;
        final bool isLocalSending = message.isSending && message.id < 0;

        final String rawText = widget.displayTextBuilder(message);
        final bool isCallMessage = message.isCallEvent ||
            rawText.startsWith('📹') ||
            rawText.startsWith('📞');

        if (isCallMessage) {
          final Widget callPill = _CallEventPill(
            message: message,
            formattedTime: formatMessageTime(message.sentAt),
            isMine: isMine,
          );
          return RepaintBoundary(
            key: ValueKey<int>(message.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (data.showDateSep)
                  widget.dateSeparatorBuilder(message.resolvedSentAt, now),
                callPill,
              ],
            ),
          );
        }

        if (message.isSystemEvent) {
          final Widget systemPill = _SystemEventPill(
            message: message,
            formattedTime: formatMessageTime(message.sentAt),
          );
          return RepaintBoundary(
            key: ValueKey<int>(message.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (data.showDateSep)
                  widget.dateSeparatorBuilder(message.resolvedSentAt, now),
                systemPill,
              ],
            ),
          );
        }

        final bool shouldAnimate =
            index == 0 &&
            !_animatedMessageIds.contains(message.id) &&
            now.difference(message.resolvedSentAt).inSeconds < 4;
        if (shouldAnimate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _animatedMessageIds.add(message.id);
          });
        }

        Widget buildBubble({
          double? progress,
          int? bytesSent,
          int? totalBytes,
          required bool animateHighlight,
        }) {
          return MessageBubble(
            key: ValueKey<int>(message.id),
            chatId: message.chatId,
            text: rawText,
            isMine: isMine,
            isE2ee: message.isE2ee,
            e2eeFileKey: message.e2eeFileKey,
            isPrevSame: data.isPrevSame,
            isNextSame: data.isNextSame,
            formattedTime: formatMessageTime(message.sentAt),
            isEdited: message.isEdited,
            isDeleted: message.isDeleted,
            isRead: message.isRead,
            replyPreview: widget.replyPreviewBuilder(message, byId),
            replyToId: message.replyToId,
            onReplyTap: message.replyToId != null
                ? () {
                    _scrollToMessage(message.replyToId!);
                  }
                : null,
            reactions: message.reactions,
            onReactionTap: widget.onReactionTap != null
                ? (String emoji) => widget.onReactionTap!(message, emoji)
                : null,
            mediaUrl: mediaUrl,
            mediaIsImage: isImageMedia,
            mediaLabel: mediaLabel,
            mediaSize: totalBytes ?? message.mediaSize,
            isVoice: isVoice,
            isCircleVideo: isCircleVideo,
            isSticker: isSticker,
            sticker: message.sticker,
            onStickerTap: () {
              final int? targetSetId =
                  message.resolvedStickerSetId ?? message.sticker?.setId;
              final int? stickerId = message.sticker?.id;
              if (targetSetId != null && targetSetId > 0) {
                StickerSetModal.show(context, setId: targetSetId, stickerId: stickerId);
              } else if (stickerId != null && stickerId > 0) {
                final List<ApiStickerSet> sets =
                    ref.read(stickerSetsProvider).value ??
                        const <ApiStickerSet>[];
                for (final ApiStickerSet s in sets) {
                  if (s.stickers.any((ApiSticker st) => st.id == stickerId)) {
                    StickerSetModal.show(
                      context,
                      stickerSet: s,
                      setId: s.id,
                      stickerId: stickerId,
                    );
                    return;
                  }
                }
                // Fallback: look up by sticker ID directly on server
                StickerSetModal.show(context, stickerId: stickerId);
              } else {
                AppToast.showError(context, 'Стикерпак не найден');
              }
            },
            mediaDuration: mediaDuration,
            senderBadges: message.senderBadges,
            senderDisplayName:
                widget.isGroup ? message.senderDisplayName : null,
            isChannel: widget.isChannel,
            commentsCount: message.commentsCount,
            onOpenComments: widget.onOpenComments != null
                ? () => widget.onOpenComments!(message)
                : null,
            animate: shouldAnimate,
            isSending: isLocalSending,
            isFailed: message.isFailed,
            onRetrySend: () => widget.onRetrySend(message),
            uploadProgress: progress,
            uploadBytesSent: bytesSent,
            uploadTotalBytes: totalBytes,
            localId: isLocalSending ? message.id.toString() : null,
            onOpenMedia: hasMedia ? () => widget.onOpenMedia(message) : null,
            onLongPressMedia: hasMedia
                ? () => widget.onLongPressMedia(
                    message, isMine, widget.amAdminOrOwner)
                : null,
            onLongPress: () => widget.onLongPress(
                message, isMine, widget.isChannel, widget.amAdminOrOwner),
            onSwipeToReply: () => widget.onSwipeToReply(message),
            replyMarkup: message.replyMarkup,
            onCallbackQuery: (String data) =>
                widget.onCallbackQuery(message, data),
            animateHighlight: animateHighlight,
          );
        }

        final Key itemKey = _messageKeys.putIfAbsent(message.id, GlobalKey.new);

        final Widget bubble = ValueListenableBuilder<int?>(
          valueListenable: _highlightedIdNotifier,
          builder: (BuildContext context, int? highlightedId, Widget? _) {
            final bool isHighlighted = message.id == highlightedId;
            return isLocalSending
                ? Consumer(
                    builder: (context, ref, _) {
                      final uploadTask = ref.watch(
                        uploadTaskProvider(message.id.toString()),
                      );
                      return buildBubble(
                        progress: uploadTask?.progress ?? 0.0,
                        bytesSent: uploadTask?.bytesSent,
                        totalBytes: uploadTask != null && uploadTask.fileSize > 0
                            ? uploadTask.fileSize
                            : message.mediaSize,
                        animateHighlight: isHighlighted,
                      );
                    },
                  )
                : buildBubble(
                    progress: null,
                    animateHighlight: isHighlighted,
                  );
          },
        );

        final Widget animatedBubble = KeyedSubtree(
          key: itemKey,
          child: widget.animatedMessageBuilder(
            messageId: message.id,
            animate: shouldAnimate,
            isMine: isMine,
            child: bubble,
          ),
        );

        if (isMine) {
          return RepaintBoundary(
            key: ValueKey<int>(message.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (data.showDateSep)
                  widget.dateSeparatorBuilder(message.resolvedSentAt, now),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (message.isSending && !hasMedia && !isVoice && !isCircleVideo && !isSticker)
                      const Padding(
                        padding: EdgeInsets.only(right: 8, bottom: 12),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: AppLoadingIndicator(size: 14),
                        ),
                      ),
                    if (message.isFailed)
                      Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 4),
                        child: IconButton(
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: Theme.of(context).colorScheme.error,
                            size: 22,
                          ),
                          onPressed: () => widget.onRetrySend(message),
                        ),
                      ),
                    Flexible(child: animatedBubble),
                  ],
                ),
              ],
            ),
          );
        }

        return RepaintBoundary(
          key: ValueKey<int>(message.id),
          child: Column(
            children: <Widget>[
              if (data.showDateSep)
                widget.dateSeparatorBuilder(message.resolvedSentAt, now),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (widget.isGroup) ...<Widget>[
                    if (!data.isNextSame) ...[
                      GestureDetector(
                        onTap: () {
                          final String username = message.senderUsername.trim();
                          if (username.isNotEmpty) {
                            context.push('/profile/$username');
                          } else if (message.senderId > 0) {
                            context.push('/profile/${message.senderId}');
                          }
                        },
                        child: message.senderAvatarUrl != null
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: ApiConstants.resolve(
                                    message.senderAvatarUrl,
                                  ),
                                  httpHeaders: cachedAuthHeaders(),
                                  memCacheWidth: 56,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: const Icon(Icons.person, size: 16),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: const Icon(Icons.person, size: 16),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                radius: 14,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: Text(
                                  message.senderDisplayName.isNotEmpty
                                      ? message.senderDisplayName[0]
                                      : '?',
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                    ] else
                      const SizedBox(width: 36),
                  ],
                  Flexible(child: animatedBubble),
                ],
              ),
            ],
          ),
        );
      },
      findChildIndexCallback: (Key key) {
        if (key is! ValueKey<int>) return null;
        return _idToIndexCache?[key.value];
      },
    ),
  );
}
}

class _CallEventPill extends StatelessWidget {
  const _CallEventPill({
    required this.message,
    required this.formattedTime,
    required this.isMine,
  });

  final ApiMessage message;
  final String formattedTime;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isVideo = message.isCallVideo;
    final bool isMissed = message.isCallMissed;

    final IconData icon = isVideo
        ? Icons.videocam_rounded
        : (isMissed ? Icons.phone_missed_rounded : Icons.phone_rounded);
    final Color iconColor = isMissed ? scheme.error : scheme.primary;

    String cleanText = message.content.trim();
    if (cleanText.startsWith('📹') || cleanText.startsWith('📞')) {
      cleanText = cleanText.substring(2).trim();
    }
    if (cleanText.isEmpty) {
      if (isVideo) {
        cleanText = isMissed ? 'Пропущенный видеозвонок' : 'Видеозвонок';
      } else {
        cleanText = isMissed ? 'Пропущенный звонок' : 'Голосовой звонок';
      }
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isMissed
              ? scheme.errorContainer.withValues(alpha: isDark ? 0.40 : 0.60)
              : (isDark
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.60)
                  : scheme.surfaceContainerHigh.withValues(alpha: 0.80)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMissed
                ? scheme.error.withValues(alpha: 0.25)
                : scheme.outlineVariant.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              cleanText,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isMissed ? scheme.onErrorContainer : scheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formattedTime,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: isMissed
                    ? scheme.onErrorContainer.withValues(alpha: 0.70)
                    : scheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemEventPill extends StatelessWidget {
  const _SystemEventPill({
    required this.message,
    required this.formattedTime,
  });

  final ApiMessage message;
  final String formattedTime;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final String text = message.content.isNotEmpty
        ? message.content
        : 'Системное уведомление';

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.60)
              : scheme.surfaceContainerHigh.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formattedTime,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

