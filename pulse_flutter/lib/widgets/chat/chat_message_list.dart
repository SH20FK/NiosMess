import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
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
  final Map<int, GlobalKey> _messageKeys = <int, GlobalKey>{};
  int? _highlightedMessageId;

  void _scrollToMessage(int messageId) {
    final GlobalKey? key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      setState(() => _highlightedMessageId = messageId);
      Scrollable.ensureVisible(
        key.currentContext!,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.messages, _cachedMessages)) {
      _cachedMessages = widget.messages;
      _layoutCache = _precomputeLayout(widget.messages);
      _byIdCache = <int, ApiMessage>{
        for (final ApiMessage m in widget.messages) m.id: m,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ApiMessage> messages = widget.messages;
    final List<_MessageLayoutData> layout =
        _layoutCache ?? _precomputeLayout(messages);
    if (_layoutCache == null) {
      _layoutCache = layout;
      _cachedMessages = messages;
      _byIdCache = <int, ApiMessage>{
        for (final ApiMessage m in messages) m.id: m,
      };
    }

    final Map<int, ApiMessage> byId =
        _byIdCache ?? <int, ApiMessage>{
          for (final ApiMessage message in messages) message.id: message,
        };

    final DateTime now = AppTimeSettings.now();

    return ListView.builder(
      controller: widget.scrollController,
      reverse: true,
      // ignore: deprecated_member_use
      cacheExtent: 600,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      addAutomaticKeepAlives: false,
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
        final int? mediaDuration = message.mediaDuration;
        final bool isLocalSending = message.isSending && message.id < 0;

        final String rawText = widget.displayTextBuilder(message);
        final bool isCallMessage = message.msgType == 'call' ||
            rawText.startsWith('📹') ||
            rawText.startsWith('📞') ||
            rawText.contains('Видеозвонок') ||
            rawText.contains('Голосовой звонок');

        if (isCallMessage) {
          final Widget callPill = _CallEventPill(
            text: rawText,
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

        Widget buildBubble({double? progress}) {
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
            mediaUrl: mediaUrl,
            mediaIsImage: isImageMedia,
            mediaLabel: mediaLabel,
            isVoice: isVoice,
            isCircleVideo: isCircleVideo,
            mediaDuration: mediaDuration,
            senderBadges: message.senderBadges,
            senderDisplayName: message.senderDisplayName,
            animate: now.difference(message.resolvedSentAt).inSeconds < 4,
            isSending: isLocalSending,
            isFailed: message.isFailed,
            onRetrySend: () => widget.onRetrySend(message),
            uploadProgress: progress,
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
            animateHighlight: message.id == _highlightedMessageId,
          );
        }

        final Widget bubble = RepaintBoundary(
          child: isLocalSending
              ? Consumer(
                  builder: (context, ref, _) {
                    final uploadTask = ref.watch(
                      uploadTaskProvider(message.id.toString()),
                    );
                    return buildBubble(progress: uploadTask?.progress ?? 0.0);
                  },
                )
              : buildBubble(progress: null),
        );

        final bool isNewest = index == 0;

        _messageKeys.putIfAbsent(message.id, () => GlobalKey());

        final Widget animatedBubble = InkWell(
          onLongPress: () => widget.onLongPress(
              message, isMine, widget.isChannel, widget.amAdminOrOwner),
          child: Container(
            key: _messageKeys[message.id],
            child: widget.animatedMessageBuilder(
              messageId: message.id,
              animate: isNewest,
              isMine: isMine,
              child: bubble,
            ),
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
                    if (message.isSending)
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
                  if (!data.isNextSame) ...[
                    Hero(
                      tag: 'sender-avatar-${message.senderId}',
                      child: GestureDetector(
                        onTap: () {},
                        child: message.senderAvatarUrl != null
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: ApiConstants.resolve(message.senderAvatarUrl),
                                  httpHeaders: cachedAuthHeaders(),
                                  memCacheWidth: 56,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.person, size: 16),
                                  ),
                                  errorWidget: (context, url, error) => CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.person, size: 16),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                radius: 14,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Text(
                                  message.senderDisplayName.isNotEmpty
                                      ? message.senderDisplayName[0]
                                      : '?',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const SizedBox(width: 36),
                  Flexible(child: animatedBubble),
                ],
              ),
            ],
          ),
        );
      },
      findChildIndexCallback: (Key key) {
        if (key is! ValueKey<int>) return null;
        final int id = key.value;
        final int index = messages.indexWhere((ApiMessage m) => m.id == id);
        if (index < 0) return null;
        return messages.length - 1 - index;
      },
    );
  }
}

class _CallEventPill extends StatelessWidget {
  const _CallEventPill({
    required this.text,
    required this.formattedTime,
    required this.isMine,
  });

  final String text;
  final String formattedTime;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isVideo = text.contains('Видеозвонок') || text.startsWith('📹');
    final bool isMissed =
        text.toLowerCase().contains('пропущен') || text.toLowerCase().contains('отклон');

    final IconData icon = isVideo
        ? Icons.videocam_rounded
        : (isMissed ? Icons.phone_missed_rounded : Icons.phone_rounded);
    final Color iconColor = isMissed ? scheme.error : scheme.primary;

    String cleanText = text;
    if (cleanText.startsWith('📹') || cleanText.startsWith('📞')) {
      cleanText = cleanText.substring(2).trim();
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
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
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

