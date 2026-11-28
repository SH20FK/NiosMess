import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:pulse_flutter/models/live_location.dart';

/// Pure presentation helpers for the chat message list: media type detection,
/// captions, reply snippets and date separators.
///
/// A plain class, like `ChatScrollCoordinator`: the screen constructs it with
/// the current localization and passes in the values it used to read from
/// providers (`chatName`, `myUserId`), so no `ref` or `BuildContext` leaks here.
class ChatMessagePresenter {
  const ChatMessagePresenter(this.l10n);

  final AppLocalizations l10n;

  String dateSeparatorLabel(DateTime resolvedDate, DateTime now) {
    final bool sameDay =
        resolvedDate.year == now.year &&
        resolvedDate.month == now.month &&
        resolvedDate.day == now.day;
    if (sameDay) return l10n.chatToday;
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (resolvedDate.year == yesterday.year &&
        resolvedDate.month == yesterday.month &&
        resolvedDate.day == yesterday.day) {
      return l10n.chatYesterday;
    }
    return formatFullDateTime(resolvedDate);
  }

  bool isVideoMedia(ApiMessage message, String mediaUrl) {
    final String mediaType = (message.mediaType ?? '').toLowerCase();
    if (mediaType.startsWith('video/')) {
      return true;
    }

    final String lower = mediaUrl.toLowerCase();
    final String fileName = (message.mediaName ?? '').toLowerCase();
    bool isVideoExt(String s) =>
        s.endsWith('.mp4') ||
        s.endsWith('.mov') ||
        s.endsWith('.mkv') ||
        s.endsWith('.webm') ||
        s.endsWith('.3gp') ||
        s.endsWith('.avi');
    return isVideoExt(lower) || (fileName.isNotEmpty && isVideoExt(fileName));
  }

  String displayText(ApiMessage message) =>
      LiveLocation.parse(message.content)?.preview ??
      InteractiveMessage.parse(message.content)?.preview ??
      message.content;

  String mediaLabel(ApiMessage message, String mediaUrl) {
    final String explicit = (message.mediaName ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final Uri? uri = Uri.tryParse(mediaUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final String last = uri.pathSegments.last.trim();
      if (last.isNotEmpty) {
        return last;
      }
    }
    return l10n.chatAttachment;
  }

  String? extractUrlFromText(String text) {
    final RegExp rx = RegExp(r'https?://[^\s]+');
    final Match? match = rx.firstMatch(text);
    if (match == null) {
      return null;
    }
    return match.group(0);
  }

  String? mediaUrlFor(ApiMessage message) {
    final String direct = (message.mediaUrl ?? '').trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    if (message.msgType == 'media') {
      return extractUrlFromText(message.content.trim());
    }
    return null;
  }

  bool isImageMedia(ApiMessage message, String mediaUrl) {
    final String mediaType = (message.mediaType ?? '').toLowerCase();
    if (mediaType.startsWith('image/')) {
      return true;
    }

    final String lower = mediaUrl.toLowerCase();
    final String fileName = (message.mediaName ?? '').toLowerCase();
    bool isImageExt(String s) =>
        s.endsWith('.jpg') ||
        s.endsWith('.jpeg') ||
        s.endsWith('.png') ||
        s.endsWith('.webp') ||
        s.endsWith('.gif') ||
        s.endsWith('.bmp') ||
        s.endsWith('.svg');
    return isImageExt(lower) || (fileName.isNotEmpty && isImageExt(fileName));
  }

  String resolveReplySnippet(ApiMessage message) {
    if (message.isSticker) {
      final String emoji = message.sticker?.emoji.trim() ?? '';
      return emoji.isNotEmpty
          ? l10n.chatPreviewStickerWithEmoji(emoji)
          : l10n.chatPreviewSticker;
    }

    if (message.msgType == 'voice' ||
        (message.mediaType ?? '').toLowerCase().startsWith('audio/')) {
      final int? duration = message.mediaDuration;
      if (duration != null && duration > 0) {
        final int minutes = duration ~/ 60;
        final int seconds = duration % 60;
        final String formatted =
            '$minutes:${seconds.toString().padLeft(2, '0')}';
        return l10n.chatPreviewVoiceWithDuration(formatted);
      }
      return l10n.chatPreviewVoice;
    }

    if (message.msgType == 'circle' ||
        message.msgType == 'circle_video' ||
        message.msgType == 'video_note' ||
        message.msgType == 'round_video') {
      return l10n.chatPreviewVideoNote;
    }

    final String? mediaUrl = mediaUrlFor(message);
    if (mediaUrl != null && mediaUrl.trim().isNotEmpty) {
      final String caption = message.content.trim();
      if (isImageMedia(message, mediaUrl)) {
        return caption.isNotEmpty ? '📷 $caption' : l10n.chatPreviewPhoto;
      }
      if (isVideoMedia(message, mediaUrl)) {
        return caption.isNotEmpty ? '🎥 $caption' : l10n.chatPreviewVideo;
      }
      final String name = (message.mediaName ?? '').trim();
      final String label = name.isNotEmpty
          ? name
          : mediaLabel(message, mediaUrl);
      return caption.isNotEmpty ? '📎 $label • $caption' : '📎 $label';
    }

    if (message.isCallEvent) {
      return l10n.chatPreviewCall;
    }

    final String text = displayText(message).trim();
    if (text.isNotEmpty) {
      return text;
    }

    if (message.hasMedia) {
      return l10n.chatPreviewAttachment;
    }

    return l10n.chatPreviewMessage;
  }

  String resolveReplyAuthor(
    ApiMessage message, {
    required int myUserId,
    required String chatName,
  }) {
    if (message.senderId == myUserId) {
      return l10n.chatSenderYou;
    }
    final String name = message.senderDisplayName.trim();
    if (name.isNotEmpty && name.toLowerCase() != 'unknown') {
      return name;
    }
    final String username = message.senderUsername.trim();
    if (username.isNotEmpty && username.toLowerCase() != 'unknown') {
      return username.startsWith('@') ? username : '@$username';
    }
    final String resolvedChatName = chatName.trim();
    if (resolvedChatName.isNotEmpty) {
      return resolvedChatName;
    }
    return l10n.chatSenderPartner;
  }

  String? replyPreviewFor(
    ApiMessage message,
    Map<int, ApiMessage> byId, {
    required int myUserId,
    required String chatName,
  }) {
    final int? replyToId = message.replyToId;
    if (replyToId == null) {
      return null;
    }
    final ApiMessage? target = byId[replyToId];
    if (target == null) {
      return l10n.chatReplyToId(replyToId);
    }
    final String author = resolveReplyAuthor(
      target,
      myUserId: myUserId,
      chatName: chatName,
    );
    final String snippet = resolveReplySnippet(target);
    final String text = '$author: $snippet';
    return text.length > 64 ? '${text.substring(0, 64)}...' : text;
  }
}
