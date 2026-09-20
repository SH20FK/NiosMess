import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/widgets/chat/sticker_set_details_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';


class MessageLayoutData {
  const MessageLayoutData({
    required this.showDateSep,
    required this.isPrevSame,
    required this.isNextSame,
  });

  final bool showDateSep;
  final bool isPrevSame;
  final bool isNextSame;
}

/// Incremental message layout store to eliminate O(n) layout recomputations on each message update.
class MessageLayoutStore {
  final List<ApiMessage> messages = <ApiMessage>[];
  final List<MessageLayoutData> layout = <MessageLayoutData>[];
  final Map<int, ApiMessage> byId = <int, ApiMessage>{};
  final Map<int, int> idToIndex = <int, int>{};

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  MessageLayoutData _computeSingle(int i, List<ApiMessage> list) {
    final ApiMessage msg = list[i];
    final bool showDateSep = (i == 0)
        ? true
        : !_isSameDay(msg.resolvedSentAt, list[i - 1].resolvedSentAt);

    final bool isPrevSame = (i > 0 && !showDateSep)
        ? (list[i - 1].senderId == msg.senderId && !list[i - 1].isDeleted)
        : false;

    final bool isNextSame = (i < list.length - 1)
        ? (_isSameDay(list[i + 1].resolvedSentAt, msg.resolvedSentAt) &&
            list[i + 1].senderId == msg.senderId &&
            !list[i + 1].isDeleted)
        : false;

    return MessageLayoutData(
      showDateSep: showDateSep,
      isPrevSame: isPrevSame,
      isNextSame: isNextSame,
    );
  }

  void reset(List<ApiMessage> newMessages) {
    messages.clear();
    layout.clear();
    byId.clear();
    idToIndex.clear();

    messages.addAll(newMessages);
    final int len = newMessages.length;
    for (int i = 0; i < len; i++) {
      layout.add(_computeSingle(i, newMessages));
      final ApiMessage m = newMessages[i];
      byId[m.id] = m;
      idToIndex[m.id] = len - 1 - i;
    }
  }

  /// Synchronizes current state with updated list [nextMessages] using O(1)/O(k) fast-paths.
  void sync(List<ApiMessage> nextMessages) {
    if (messages.isEmpty || nextMessages.isEmpty) {
      reset(nextMessages);
      return;
    }

    final int oldLen = messages.length;
    final int newLen = nextMessages.length;

    // 1. O(1) Fast-path: Single message append at the end (new incoming message)
    if (newLen == oldLen + 1 && nextMessages[0].id == messages[0].id) {
      if (nextMessages[oldLen - 1].id == messages[oldLen - 1].id) {
        final ApiMessage newMsg = nextMessages[newLen - 1];
        messages.add(newMsg);

        final int prevIdx = oldLen - 1;
        layout[prevIdx] = _computeSingle(prevIdx, messages);
        layout.add(_computeSingle(oldLen, messages));

        byId[newMsg.id] = newMsg;
        for (int i = 0; i < newLen; i++) {
          idToIndex[messages[i].id] = newLen - 1 - i;
        }
        return;
      }
    }

    // 2. O(k) Fast-path: Prepend older history at the beginning (pagination)
    if (newLen > oldLen && nextMessages[newLen - 1].id == messages[oldLen - 1].id) {
      final int prependedCount = newLen - oldLen;
      if (nextMessages[prependedCount].id == messages[0].id) {
        final List<ApiMessage> prepended = nextMessages.sublist(0, prependedCount);
        messages.insertAll(0, prepended);

        final List<MessageLayoutData> prependedLayout = <MessageLayoutData>[];
        for (int i = 0; i < prependedCount; i++) {
          prependedLayout.add(_computeSingle(i, messages));
        }
        layout.insertAll(0, prependedLayout);
        layout[prependedCount] = _computeSingle(prependedCount, messages);

        byId.clear();
        idToIndex.clear();
        for (int i = 0; i < newLen; i++) {
          final ApiMessage m = messages[i];
          byId[m.id] = m;
          idToIndex[m.id] = newLen - 1 - i;
        }
        return;
      }
    }

    // 3. O(1) Fast-path: Single in-place update (edited, read status, reactions)
    if (newLen == oldLen) {
      int diffIndex = -1;
      int diffCount = 0;
      for (int i = 0; i < oldLen; i++) {
        if (!identical(messages[i], nextMessages[i])) {
          diffCount++;
          diffIndex = i;
          if (diffCount > 1) break;
        }
      }
      if (diffCount == 1) {
        final ApiMessage oldMsg = messages[diffIndex];
        final ApiMessage updatedMsg = nextMessages[diffIndex];
        messages[diffIndex] = updatedMsg;
        byId.remove(oldMsg.id);
        byId[updatedMsg.id] = updatedMsg;
        if (oldMsg.id != updatedMsg.id) {
          idToIndex.remove(oldMsg.id);
          idToIndex[updatedMsg.id] = newLen - 1 - diffIndex;
        }

        if (diffIndex > 0) {
          layout[diffIndex - 1] = _computeSingle(diffIndex - 1, messages);
        }
        layout[diffIndex] = _computeSingle(diffIndex, messages);
        if (diffIndex < newLen - 1) {
          layout[diffIndex + 1] = _computeSingle(diffIndex + 1, messages);
        }
        return;
      }
    }

    // Fallback: full reset
    reset(nextMessages);
  }
}

class ChatMessageList extends ConsumerStatefulWidget {
  const ChatMessageList({
    required this.messages,
    required this.scrollController,
    required this.authUserId,
    required this.amAdminOrOwner,
    required this.isChannel,
    this.isGroup = false,
    this.bottomPadding = 56.0,
    this.topPadding = 48.0,
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
  final double bottomPadding;
  final double topPadding;
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
  final MessageLayoutStore _store = MessageLayoutStore();
  Map<int, int>? get _idToIndexCache => _store.idToIndex;
  GlobalKey? _activeTargetKey;
  int? _activeTargetMessageId;
  final Set<int> _animatedMessageIds = <int>{};
  Timer? _highlightTimer;
  final ValueNotifier<int?> _highlightedIdNotifier = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    _store.reset(widget.messages);
    _animatedMessageIds.addAll(widget.messages.map((ApiMessage m) => m.id));
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.messages, oldWidget.messages)) {
      _store.sync(widget.messages);
    }
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
    _activeTargetMessageId = messageId;
    _activeTargetKey = GlobalKey(debugLabel: 'target_msg_$messageId');
    if (mounted) setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final GlobalKey? key = _activeTargetKey;
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          alignment: 0.3,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      } else {
        final int? builderIndex = _idToIndexCache?[messageId];
        final List<ApiMessage> messages = _store.messages;
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
              final GlobalKey? updatedKey = _activeTargetKey;
              if (updatedKey != null && updatedKey.currentContext != null) {
                final RenderBox? box = updatedKey.currentContext!.findRenderObject() as RenderBox?;
                if (box != null && mounted) {
                  final Offset pos = box.localToGlobal(Offset.zero);
                  final double screenHeight = MediaQuery.sizeOf(context).height;
                  // Single coordinator check: only correct if misaligned outside visible bounds
                  if (pos.dy < 48 || pos.dy > screenHeight - 120) {
                    Scrollable.ensureVisible(
                      updatedKey.currentContext!,
                      alignment: 0.3,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                }
              }
            });
          });
        }
      }
    });

    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && _highlightedIdNotifier.value == messageId) {
        _highlightedIdNotifier.value = null;
        _activeTargetMessageId = null;
        _activeTargetKey = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ApiMessage> messages = _store.messages;
    final List<MessageLayoutData> layout = _store.layout;
    final Map<int, ApiMessage> byId = _store.byId;

    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((s) => s.tier),
    );
    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final double cacheExtent = switch (tier) {
      PerformanceTier.tierC => 250.0,
      PerformanceTier.tierB => isWindows ? 350.0 : 500.0,
      PerformanceTier.tierA => isWindows ? 350.0 : 750.0,
    };

    final DateTime now = AppTimeSettings.now();

    return RepaintBoundary(
      child: ListView.builder(
        controller: widget.scrollController,
        reverse: true,
        // ignore: deprecated_member_use
        cacheExtent: cacheExtent,
        padding: EdgeInsets.fromLTRB(16, widget.topPadding, 16, widget.bottomPadding),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        final int reversedIndex = messages.length - 1 - index;
        final ApiMessage message = messages[reversedIndex];
        final MessageLayoutData data = layout[reversedIndex];

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
          UploadTask? uploadTask,
          int? queuePosition,
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
              final int? stickerId = message.sticker?.id;
              if (stickerId != null && stickerId > 0) {
                StickerSetDetailsSheet.showForSticker(
                  context,
                  stickerId: stickerId,
                  knownSetId: message.resolvedStickerSetId ?? message.sticker?.setId,
                );
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
            uploadTask: uploadTask,
            uploadQueuePosition: queuePosition,
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

        final Key itemKey = (message.id == _activeTargetMessageId)
            ? (_activeTargetKey ??= GlobalKey(debugLabel: 'target_msg_${message.id}'))
            : ValueKey<int>(message.id);

        final Widget bubble = ValueListenableBuilder<int?>(
          valueListenable: _highlightedIdNotifier,
          builder: (BuildContext context, int? highlightedId, Widget? _) {
            final bool isHighlighted = message.id == highlightedId;
            return isLocalSending
                ? Consumer(
                    builder: (context, ref, _) {
                      final String localIdStr = message.id.toString();
                      final uploadTask = ref.watch(
                        uploadTaskProvider(localIdStr),
                      );
                      final int queuePosition = ref.watch(
                        uploadQueuePositionProvider(localIdStr),
                      );
                      return buildBubble(
                        progress: uploadTask?.progress ?? 0.0,
                        bytesSent: uploadTask?.bytesSent,
                        totalBytes: uploadTask != null && uploadTask.fileSize > 0
                            ? uploadTask.fileSize
                            : message.mediaSize,
                        uploadTask: uploadTask,
                        queuePosition: queuePosition,
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

