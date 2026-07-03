import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';

class ChatMessageList extends StatelessWidget {
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
  final void Function(ApiMessage, bool isMine, bool amAdminOrOwner) onLongPressMedia;
  final void Function(ApiMessage, bool isMine, bool isChannel, bool amAdminOrOwner) onLongPress;
  final void Function(ApiMessage) onSwipeToReply;
  final void Function(ApiMessage, String data) onCallbackQuery;
  final void Function(ApiMessage) onRetrySend;
  final String Function(ApiMessage) displayTextBuilder;
  final String? Function(ApiMessage) mediaUrlBuilder;
  final bool Function(ApiMessage, String url) isImageMediaBuilder;
  final String? Function(ApiMessage, String url) mediaLabelBuilder;
  final String? Function(ApiMessage, Map<int, ApiMessage> byId) replyPreviewBuilder;
  final Widget Function(DateTime date, DateTime now) dateSeparatorBuilder;
  final Widget Function({required int messageId, required bool animate, required bool isMine, required Widget child}) animatedMessageBuilder;

  @override
  Widget build(BuildContext context) {
    final Map<int, ApiMessage> byId = <int, ApiMessage>{
      for (final ApiMessage message in messages) message.id: message,
    };

    final DateTime now = AppTimeSettings.now();

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        final int reversedIndex = messages.length - 1 - index;
        final ApiMessage message = messages[reversedIndex];

        final bool showDateSep;
        if (reversedIndex == 0) {
          showDateSep = true;
        } else {
          final ApiMessage prev = messages[reversedIndex - 1];
          final DateTime messageDate = message.resolvedSentAt;
          final DateTime prevDate = prev.resolvedSentAt;
          showDateSep =
              messageDate.day != prevDate.day ||
              messageDate.month != prevDate.month ||
              messageDate.year != prevDate.year;
        }

        final bool isMine = message.senderId == authUserId;

        final bool isPrevSame = reversedIndex > 0 &&
            !showDateSep &&
            messages[reversedIndex - 1].senderId == message.senderId &&
            !messages[reversedIndex - 1].isDeleted;

        final bool isNextSame = reversedIndex < messages.length - 1 &&
            messages[reversedIndex + 1].resolvedSentAt.day == message.resolvedSentAt.day &&
            messages[reversedIndex + 1].resolvedSentAt.month == message.resolvedSentAt.month &&
            messages[reversedIndex + 1].resolvedSentAt.year == message.resolvedSentAt.year &&
            messages[reversedIndex + 1].senderId == message.senderId &&
            !messages[reversedIndex + 1].isDeleted;

        final String? mediaUrl = mediaUrlBuilder(message);
        final bool hasMedia = mediaUrl != null && mediaUrl.trim().isNotEmpty;
        final bool isImageMedia = hasMedia ? isImageMediaBuilder(message, mediaUrl) : false;
        final String? mediaLabel = hasMedia ? mediaLabelBuilder(message, mediaUrl) : null;

        final Widget bubble = RepaintBoundary(
          child: MessageBubble(
            key: ValueKey<int>(message.id),
            text: displayTextBuilder(message),
            isMine: isMine,
            isE2ee: message.isE2ee,
            isPrevSame: isPrevSame,
            isNextSame: isNextSame,
            formattedTime: formatMessageTime(message.sentAt),
            isEdited: message.isEdited,
            isDeleted: message.isDeleted,
            isRead: message.isRead,
            replyPreview: replyPreviewBuilder(message, byId),
            reactions: message.reactions,
            mediaUrl: mediaUrl,
            mediaIsImage: isImageMedia,
            mediaLabel: mediaLabel,
            senderBadges: message.senderBadges,
            senderDisplayName: message.senderDisplayName,
            animate: now.difference(message.resolvedSentAt).inSeconds < 4,
            onOpenMedia: hasMedia ? () => onOpenMedia(message) : null,
            onLongPressMedia: hasMedia
                ? () => onLongPressMedia(message, isMine, amAdminOrOwner)
                : null,
            onLongPress: () => onLongPress(
              message,
              isMine,
              isChannel,
              amAdminOrOwner,
            ),
            onSwipeToReply: () => onSwipeToReply(message),
            replyMarkup: message.replyMarkup,
            onCallbackQuery: (String data) => onCallbackQuery(message, data),
          ),
        );

        final bool isNewest = index == 0;

        final Widget animatedBubble = animatedMessageBuilder(
          messageId: message.id,
          animate: isNewest,
          isMine: isMine,
          child: bubble,
        );

        if (isMine) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (showDateSep) dateSeparatorBuilder(message.resolvedSentAt, now),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (message.isFailed)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.red, size: 22),
                        onPressed: () => onRetrySend(message),
                      ),
                    ),
                  Flexible(child: animatedBubble),
                ],
              ),
            ],
          );
        }

        return Column(
          children: <Widget>[
            if (showDateSep) dateSeparatorBuilder(message.resolvedSentAt, now),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                GestureDetector(
                  onTap: () {}, // Handled in detail screen resolver
                  child: CircleAvatar(
                    radius: 14,
                    backgroundImage: message.senderAvatarUrl != null
                        ? NetworkImage(message.senderAvatarUrl!)
                        : null,
                    child: message.senderAvatarUrl == null
                        ? Text(message.senderDisplayName.isNotEmpty ? message.senderDisplayName[0] : '?')
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: animatedBubble),
              ],
            ),
          ],
        );
      },
    );
  }
}
