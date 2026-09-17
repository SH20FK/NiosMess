import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/chat/inline_keyboard_view.dart';
import 'package:pulse_flutter/widgets/chat/sticker_set_modal.dart';
import 'package:video_player/video_player.dart';
import 'package:pulse_flutter/widgets/voice_message_player.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/widgets/chat/ws_cached_image.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/utils/message_formatter.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';

final RegExp _interactiveTokenRegExp = RegExp(
  r"""((?:https?:\/\/|niosmess:\/\/|tg:\/\/)[^\s<>"'\)]+|\b(?:t\.me|telegram\.me|ni-os\.ru)\/[^\s<>"'\)]+|@([a-zA-Z0-9_]{3,32}))""",
  caseSensitive: false,
);

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    required this.text,
    required this.formattedTime,
    required this.isMine,
    required this.chatId,
    this.isDeleted = false,
    this.isEdited = false,
    this.isRead = false,
    this.replyPreview,
    this.replyToId,
    this.onReplyTap,
    this.reactions = const <String, int>{},
    this.onLongPress,
    this.mediaUrl,
    this.mediaLabel,
    this.mediaIsImage = false,
    this.onOpenMedia,
    this.onLongPressMedia,
    this.senderBadges = const <ApiBadge>[],
    this.senderDisplayName,
    this.senderAvatarUrl,
    this.onSwipeToReply,
    this.onReactionTap,
    this.replyMarkup,
    this.onCallbackQuery,
    this.isPrevSame = false,
    this.isNextSame = false,
    this.animate = false,
    this.isE2ee = false,
    this.e2eeFileKey,
    this.isVoice = false,
    this.isCircleVideo = false,
    this.isSticker = false,
    this.sticker,
    this.onStickerTap,
    this.mediaDuration,
    this.animateHighlight = false,
    this.hideFooter = false,
    this.isSending = false,
    this.isFailed = false,
    this.onRetrySend,
    this.uploadProgress,
    this.uploadBytesSent,
    this.uploadTotalBytes,
    this.mediaSize,
    this.localId,
    this.isChannel = false,
    this.commentsCount = 0,
    this.onOpenComments,
    super.key,
  });

  final String text;
  final String formattedTime;
  final bool isMine;
  final int chatId;
  final bool isDeleted;
  final bool isEdited;
  final bool isRead;
  final bool isE2ee;

  /// Base64 per-file AES key from the E2EE envelope (secret chats).
  final String? e2eeFileKey;
  final String? replyPreview;
  final int? replyToId;
  final VoidCallback? onReplyTap;
  final Map<String, int> reactions;
  final VoidCallback? onLongPress;
  final String? mediaUrl;
  final String? mediaLabel;
  final bool mediaIsImage;
  final VoidCallback? onOpenMedia;
  final VoidCallback? onLongPressMedia;
  final List<ApiBadge> senderBadges;
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  final VoidCallback? onSwipeToReply;
  final ValueChanged<String>? onReactionTap;
  final InlineKeyboardMarkup? replyMarkup;
  final ValueChanged<String>? onCallbackQuery;
  final bool isPrevSame;
  final bool isNextSame;
  final bool animate;
  final bool isVoice;
  final bool isCircleVideo;
  final bool isSticker;
  final ApiSticker? sticker;
  final VoidCallback? onStickerTap;
  final int? mediaDuration;
  final bool animateHighlight;
  final bool hideFooter;
  final bool isSending;
  final bool isFailed;
  final VoidCallback? onRetrySend;
  final double? uploadProgress;
  final int? uploadBytesSent;
  final int? uploadTotalBytes;
  final int? mediaSize;
  final String? localId;
  final bool isChannel;
  final int commentsCount;
  final VoidCallback? onOpenComments;

  List<String> get mediaUrls {
    if (mediaUrl == null || mediaUrl!.trim().isEmpty) return [];
    return mediaUrl!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  static BorderRadius _getBubbleRadius(
    bool isMine,
    bool isPrevSame,
    bool isNextSame, [
    double outer = AppRadii.md,
  ]) {
    final MessageBubblePosition position;
    if (!isPrevSame && !isNextSame) {
      position = MessageBubblePosition.single;
    } else if (!isPrevSame && isNextSame) {
      position = MessageBubblePosition.top;
    } else if (isPrevSame && isNextSame) {
      position = MessageBubblePosition.middle;
    } else {
      position = MessageBubblePosition.bottom;
    }
    return getBubbleRadius(
      isOutgoing: isMine,
      position: position,
      baseRadius: outer,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final _ForwardedPayload? forwarded = _parseForwarded(text);
    final List<ApiBadge> visibleBadges = senderBadges
        .take(2)
        .toList(growable: false);
    final int hiddenBadgeCount = senderBadges.length - visibleBadges.length;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bubbleColor = isDeleted
        ? scheme.surfaceContainerHighest
        : (isMine
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh);
    final Color textColor = isDeleted
        ? scheme.onSurfaceVariant
        : (isMine
            ? scheme.onPrimaryContainer
            : scheme.onSurface);
    final Border? bubbleBorder = (!isMine && !isDark)
        ? Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            width: 0.8,
          )
        : null;
    final bool hasMedia = (mediaUrl ?? '').trim().isNotEmpty;
    final String displayText = forwarded != null ? forwarded.body : text;
    final bool hasText = displayText.trim().isNotEmpty;

    final Map<String, String> headers = cachedAuthHeaders();

    final double messageRadius = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.messageBubbleRadius),
    );
    final double innerRadius = (messageRadius * 0.5).clamp(4.0, 16.0);
    final double mediaRadius = (messageRadius * 0.75).clamp(6.0, 20.0);

    final BorderRadius bubbleRadius = _getBubbleRadius(
      isMine,
      isPrevSame,
      isNextSame,
      messageRadius,
    );

    Widget content = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: <Widget>[
            if (isSticker && (sticker != null || hasMedia)) ...<Widget>[
              if ((replyPreview ?? '').trim().isNotEmpty)
                GestureDetector(
                  onTap: onReplyTap,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(innerRadius),
                      border: Border(
                        left: BorderSide(
                          color: isMine ? scheme.primary : scheme.secondary,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      replyPreview!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              _buildStickerContent(context, scheme, textTheme, radius: mediaRadius),
            ]
            else if (isCircleVideo && hasMedia)
              _buildCircleVideoContent(context, scheme, textTheme,
                ref: ref,
                chatId: chatId,
                wsClient: ref.watch(webSocketClientProvider),
                e2eeService: ref.watch(e2eeServiceProvider),
              )
            else
            InkWell(
              borderRadius: bubbleRadius,
              onDoubleTap: onReactionTap != null
                  ? () {
                      final String emoji =
                          ref.read(uiSettingsProvider).doubleTapReactionEmoji;
                      if (emoji.isNotEmpty) {
                        TriSync.reaction(context: context);
                        onReactionTap!(emoji);
                      }
                    }
                  : null,
              onLongPress: onLongPress != null
                  ? () {
                      HapticService.confirm();
                      onLongPress!();
                    }
                  : null,
              onSecondaryTapUp: (_) {
                if (onLongPress != null) {
                  HapticService.confirm();
                  onLongPress!();
                }
              },
              child: Container(
                constraints: BoxConstraints(
                  minWidth: 76,
                  maxWidth: MediaQuery.sizeOf(context).width > 600
                      ? 520.0
                      : MediaQuery.sizeOf(context).width * 0.78,
                ),
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: bubbleRadius,
                  border: bubbleBorder,
                ),
                child: Semantics(
                  label: isMine
                      ? context.l10n.messageSentByMe
                      : (senderDisplayName ?? context.l10n.messageSemantics),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _MessageBubbleHeader(
                        isMine: isMine,
                        senderDisplayName: senderDisplayName,
                        senderAvatarUrl: senderAvatarUrl,
                        visibleBadges: visibleBadges,
                        hiddenBadgeCount: hiddenBadgeCount,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                      if ((replyPreview ?? '').trim().isNotEmpty)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: onReplyTap,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (isMine ? scheme.primary : scheme.secondary)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(innerRadius),
                                  bottomRight: Radius.circular(innerRadius),
                                ),
                                border: Border(
                                  left: BorderSide(
                                    color: isMine
                                        ? scheme.primary
                                        : scheme.secondary,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                replyPreview!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelSmall?.copyWith(
                                  color: isMine
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (forwarded != null) ...<Widget>[
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(innerRadius),
                            border: Border(
                              left: BorderSide(
                                color: scheme.outlineVariant,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.forward_rounded,
                                    size: 14,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.l10n.chatForwardedCard,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              if (forwarded.sender.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  context.l10n.chatForwardedFrom(
                                    forwarded.sender,
                                  ),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (hasMedia)
                        _mediaPreview(
                          context,
                          ref: ref,
                          scheme: scheme,
                          textTheme: textTheme,
                          textColor: textColor,
                          headers: headers,
                          chatId: chatId,
                          wsClient: ref.watch(webSocketClientProvider),
                          e2eeService: ref.watch(e2eeServiceProvider),
                          radius: mediaRadius,
                        ),
                      if (hasMedia && hasText) const SizedBox(height: 6),
                      if (hasText)
                        _buildMessageTextAndFooter(
                          context: context,
                          text: displayText,
                          textColor: textColor,
                          isDeleted: isDeleted,
                          isMine: isMine,
                          scheme: scheme,
                          textTheme: textTheme,
                          hideFooter: hideFooter,
                          footer: _MessageBubbleFooter(
                            isMine: isMine,
                            isE2ee: isE2ee,
                            isEdited: isEdited,
                            isDeleted: isDeleted,
                            isRead: isRead,
                            isSending: isSending,
                            isFailed: isFailed,
                            onRetrySend: onRetrySend,
                            formattedTime: formattedTime,
                            scheme: scheme,
                            textTheme: textTheme,
                          ),
                        )
                      else if (!hideFooter)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: _MessageBubbleFooter(
                            isMine: isMine,
                            isE2ee: isE2ee,
                            isEdited: isEdited,
                            isDeleted: isDeleted,
                            isRead: isRead,
                            isSending: isSending,
                            isFailed: isFailed,
                            onRetrySend: onRetrySend,
                            formattedTime: formattedTime,
                            scheme: scheme,
                            textTheme: textTheme,
                          ),
                        ),
                      if (isChannel && onOpenComments != null) ...<Widget>[
                        const SizedBox(height: 6),
                        _ChannelCommentsBar(
                          commentsCount: commentsCount,
                          scheme: scheme,
                          textTheme: textTheme,
                          onTap: onOpenComments!,
                          borderRadius: innerRadius,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (replyMarkup != null && replyMarkup!.inlineKeyboard.isNotEmpty)
              _buildInlineKeyboard(scheme, textTheme),
            if (reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                  children: reactions.entries
                      .map((MapEntry<String, int> item) {
                        return TweenAnimationBuilder<double>(
                          key: ValueKey<String>('react_${item.key}_${item.value}'),
                          tween: Tween<double>(begin: 0.65, end: 1.0),
                          duration: M3Durations.medium1,
                          curve: M3SpringCurves.bouncy,
                          builder: (BuildContext context, double scale, Widget? child) {
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: TouchContainer(
                            borderRadius: AppRadii.fullRadius,
                            scaleDown: 0.90,
                            releaseCurve: M3SpringCurves.bouncy,
                            onTap: onReactionTap != null
                                ? () {
                                    TriSync.reaction(context: context);
                                    onReactionTap!(item.key);
                                  }
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: AppRadii.fullRadius,
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(alpha: 0.25),
                                  width: 0.75,
                                ),
                              ),
                              child: Text(
                                '${normalizeReactionEmoji(item.key)} ${item.value}',
                                style: textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );

    if (animateHighlight) {
      content = TweenAnimationBuilder<Color?>(
        tween: ColorTween(
          begin: scheme.secondaryContainer.withValues(alpha: 0.4),
          end: Colors.transparent,
        ),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeOut,
        builder: (BuildContext context, Color? color, Widget? child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: bubbleRadius,
              color: color,
            ),
            child: child,
          );
        },
        child: content,
      );
    }

      if (onSwipeToReply != null) {
        content = _SwipeToReply(
          onReply: onSwipeToReply!,
          scheme: scheme,
          child: content,
        );
      }

    return content;
  }

  Widget _buildStickerContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme, {
    double radius = 16.0,
  }) {
    final String stickerUrl = sticker?.resolvedUrl.trim() ?? '';
    final String mediaResolved = (mediaUrl ?? '').trim().isNotEmpty
        ? ApiConstants.resolve(mediaUrl!.trim())
        : '';
    final String url = stickerUrl.isNotEmpty ? stickerUrl : mediaResolved;
    final bool isAnimated = sticker?.isAnimated == true ||
        (sticker?.mediaType ?? '').contains('video') ||
        (sticker?.mediaType ?? '').contains('webm') ||
        url.endsWith('.webm') ||
        url.endsWith('.mp4');

    return Semantics(
      label: 'Стикер',
      child: InkWell(
        onTap: () {
          HapticService.tap();
          if (onStickerTap != null) {
            onStickerTap!();
          } else if (sticker?.setId != null) {
            StickerSetModal.show(context, setId: sticker!.setId);
          }
        },
        onDoubleTap: onReactionTap != null
            ? () {
                TriSync.reaction(context: context);
                onReactionTap!('❤️');
              }
            : null,
        onLongPress: onLongPress != null
            ? () {
                HapticService.confirm();
                onLongPress!();
              }
            : null,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          // Borderless with transparent background (no container box, no border, no outline)
          color: Colors.transparent,
          constraints: const BoxConstraints(
            maxWidth: 190,
            maxHeight: 190,
            minWidth: 100,
            minHeight: 100,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Sticker media content
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: url.isEmpty
                    ? Center(
                        child: Text(
                          sticker?.emoji.isNotEmpty == true
                              ? sticker!.emoji
                              : '🖼️',
                          style: const TextStyle(fontSize: 48),
                        ),
                      )
                    : isAnimated
                        ? _StickerVideoPlayer(url: url)
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.contain,
                            memCacheWidth: 400,
                            memCacheHeight: 400,
                            placeholder: (_, _) => AppLoadingIndicator(
                              size: 24,
                              color: scheme.primary.withValues(alpha: 0.4),
                            ),
                            errorWidget: (_, _, _) => Center(
                              child: Text(
                                sticker?.emoji.isNotEmpty == true
                                    ? sticker!.emoji
                                    : '🖼️',
                                style: const TextStyle(fontSize: 48),
                              ),
                            ),
                          ),
              ),

              // Floating translucent time badge
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.scrim.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        formattedTime,
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMine) ...<Widget>[
                        const SizedBox(width: 3),
                        Icon(
                          isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 12,
                          color: scheme.onPrimary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Sending spinner
              if (isSending)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AppLoadingIndicator(
                      size: 28,
                      color: scheme.primary,
                    ),
                  ),
                ),

              // Failed icon
              if (isFailed)
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton(
                    onPressed: onRetrySend,
                    icon: Icon(Icons.refresh_rounded, color: scheme.error),
                    tooltip: 'Повторить отправку',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleVideoContent(BuildContext context, ColorScheme scheme, TextTheme textTheme, {
    required WidgetRef ref,
    required int chatId,
    required WebSocketClient wsClient,
    required E2eeService e2eeService,
  }) {
    const double circleSize = 180;
    return Semantics(
      label: context.l10n.chatCircleVideo,
      child: SizedBox(
        width: circleSize,
        height: circleSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _CircleVideoInlinePlayer(
              videoUrl: mediaUrl!,
              durationSeconds: mediaDuration ?? 0,
              isMine: isMine,
              isE2ee: isE2ee,
              isEdited: isEdited,
              isDeleted: isDeleted,
              isRead: isRead,
              formattedTime: formattedTime,
              scheme: scheme,
              textTheme: textTheme,
              chatId: chatId,
              wsClient: wsClient,
              e2eeFileKey: e2eeFileKey,
              onLongPress: onLongPressMedia,
            ),
            if (isSending)
              Positioned.fill(
                child: ClipOval(
                  child: _UploadProgressOverlay(
                    progress: uploadProgress,
                    bytesSent: uploadBytesSent,
                    totalBytes: uploadTotalBytes ?? mediaSize,
                    isMine: isMine,
                    scheme: scheme,
                    onCancel: isMine && localId != null
                        ? () {
                            HapticService.destructive();
                            ref.read(uploadQueueProvider.notifier).cancel(localId!);
                          }
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }



  Widget _mediaPreview(
    BuildContext context, {
    required WidgetRef ref,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required Color textColor,
    required Map<String, String> headers,
    required int chatId,
    required WebSocketClient wsClient,
    required E2eeService e2eeService,
    double radius = 12.0,
  }) {
    if (isVoice && mediaUrl != null && mediaUrl!.trim().isNotEmpty) {
      return InkWell(
        onTap: onOpenMedia,
        onLongPress: onLongPressMedia,
        borderRadius: BorderRadius.circular(radius),
        child: VoiceMessagePlayer(
          e2eeFileKey: e2eeFileKey,
          audioUrl: mediaUrl!,
          durationSeconds: mediaDuration ?? 0,
          isMine: isMine,
          scheme: scheme,
          chatId: chatId,
          wsClient: wsClient,
        ),
      );
    }

    if (mediaIsImage) {
      final urls = mediaUrls;
      if (urls.length > 1) {
        return _MediaCarousel(
          urls: urls,
          scheme: scheme,
          textStyle: textTheme.bodySmall?.copyWith(color: textColor) ?? const TextStyle(),
          isMine: isMine,
          chatId: chatId,
          isE2ee: isE2ee,
          e2eeFileKey: e2eeFileKey,
          onOpenMedia: onOpenMedia,
          onLongPressMedia: onLongPressMedia,
          radius: radius,
        );
      }
      return Stack(
        children: [
          InkWell(
            onTap: onOpenMedia,
            onLongPress: onLongPressMedia,
            borderRadius: BorderRadius.circular(radius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Hero(
                tag: 'media_${urls.first}',
                child: WsCachedImage(
                  e2eeFileKey: e2eeFileKey,
                  mediaUrl: urls.first,
                  chatId: chatId,
                  isE2ee: isE2ee,
                  width: 220,
                  height: 180,
                  fit: BoxFit.cover,
                  placeholder: (BuildContext context) => SizedBox(
                    width: 220,
                    height: 180,
                    child: Center(
                      child: AppLoadingIndicator(
                        color: isMine ? scheme.onPrimary : scheme.primary,
                      ),
                    ),
                  ),
                  errorWidget: (BuildContext context, Object error) {
                    return Container(
                      width: 220,
                      height: 180,
                      alignment: Alignment.center,
                      color: isMine
                          ? scheme.onPrimary.withValues(alpha: 0.12)
                          : scheme.surfaceContainerHigh,
                      child: Semantics(
                        label: context.l10n.chatImageUnavailable,
                        child: Text(
                          context.l10n.chatImageUnavailable,
                          style: textTheme.bodySmall?.copyWith(color: textColor),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (isSending)
            _UploadProgressOverlay(
              progress: uploadProgress,
              bytesSent: uploadBytesSent,
              totalBytes: uploadTotalBytes ?? mediaSize,
              isMine: isMine,
              scheme: scheme,
              onCancel: isMine && localId != null
                  ? () {
                      HapticService.destructive();
                      ref.read(uploadQueueProvider.notifier).cancel(localId!);
                    }
                  : null,
            ),
        ],
      );
    }

    final FileTypeInfo typeInfo = FileTypeDetector.detect(
      fileName: mediaLabel ?? 'file',
    );

    final double p = (uploadProgress ?? 0.0).clamp(0.0, 1.0);
    final int percent = (p * 100).toInt();

    final int? total = uploadTotalBytes ?? mediaSize;
    final int? sent = uploadBytesSent;

    final String progressSubtitle;
    if (total != null && total > 0) {
      if (sent != null && sent > 0) {
        progressSubtitle = '$percent% • ${FileTypeDetector.formatFileSize(sent)} из ${FileTypeDetector.formatFileSize(total)}';
      } else {
        progressSubtitle = '$percent% из ${FileTypeDetector.formatFileSize(total)}';
      }
    } else {
      progressSubtitle = '$percent% • Загрузка...';
    }

    final String normalSubtitle;
    if (mediaSize != null && mediaSize! > 0) {
      normalSubtitle = '${typeInfo.label} • ${FileTypeDetector.formatFileSize(mediaSize!)}';
    } else {
      normalSubtitle = '${typeInfo.label} • ${context.l10n.chatTapToPreview}';
    }

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isMine
            ? scheme.onPrimary.withValues(alpha: 0.15)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (isSending)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: p > 0.01 ? p : null,
                        strokeWidth: 3.0,
                        strokeCap: StrokeCap.round,
                        color: isMine ? scheme.onPrimary : scheme.primary,
                        backgroundColor: (isMine ? scheme.onPrimary : scheme.primary)
                            .withValues(alpha: 0.2),
                      ),
                      if (isMine && localId != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              HapticService.destructive();
                              ref.read(uploadQueueProvider.notifier).cancel(localId!);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                color: isMine ? scheme.onPrimary : scheme.primary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: onOpenMedia,
                  onLongPress: onLongPressMedia,
                  borderRadius: BorderRadius.circular((radius * 0.8).clamp(4.0, 14.0)),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isMine ? scheme.onPrimary : scheme.primary).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular((radius * 0.8).clamp(4.0, 14.0)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      getIconDataByName(
                        FileTypeDetector.detect(fileName: mediaLabel ?? '').icon,
                      ),
                      color: isMine ? scheme.onPrimary : scheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: isSending ? null : onOpenMedia,
                  onLongPress: isSending ? null : onLongPressMedia,
                  borderRadius: BorderRadius.circular(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        (mediaLabel ?? context.l10n.chatOpenAttachment).trim().isEmpty
                            ? context.l10n.chatOpenAttachment
                            : mediaLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isSending ? progressSubtitle : normalSubtitle,
                        style: textTheme.labelSmall?.copyWith(
                          color: isMine
                              ? scheme.onPrimary.withValues(alpha: 0.82)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isSending) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: isMine ? scheme.onPrimary : scheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: onOpenMedia,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          if (isSending) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p > 0.01 ? p : null,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: (isMine ? scheme.onPrimary : scheme.primary)
                    .withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isMine ? scheme.onPrimary : scheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _ForwardedPayload? _parseForwarded(String rawText) {
    final String trimmed = rawText.trim();
    final Match? result = MessageFormatter.fwdRegExp.firstMatch(trimmed);
    if (result == null) return null;
    final String sender = (result.group(1) ?? '').trim();
    final String body = (result.group(2) ?? '').trim();
    if (sender.isEmpty) return null;
    return _ForwardedPayload(sender: sender, body: body);
  }

  Widget _buildInlineKeyboard(ColorScheme scheme, TextTheme textTheme) {
    return InlineKeyboardView(
      replyMarkup: replyMarkup!,
      isMine: isMine,
      onCallbackQuery: onCallbackQuery,
    );
  }
  Widget _buildMessageTextAndFooter({
    required BuildContext context,
    required String text,
    required Color textColor,
    required bool isDeleted,
    required bool isMine,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required bool hideFooter,
    required Widget footer,
  }) {
    final Widget textWidget = _InteractiveMessageText(
      text: text,
      baseStyle: textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontSize: 15,
        height: 1.35,
        fontStyle: isDeleted ? FontStyle.italic : null,
      ) ?? const TextStyle(fontSize: 15, height: 1.35),
      isMine: isMine,
      scheme: scheme,
    );

    if (hideFooter) {
      return textWidget;
    }

    final bool isSingleLineShort = !text.contains('\n') && text.trim().length <= 26;

    if (isSingleLineShort) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Flexible(child: textWidget),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: footer,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Align(
          alignment: Alignment.topLeft,
          child: textWidget,
        ),
        const SizedBox(height: 3),
        footer,
      ],
    );
  }
}

class _ParsedTextToken {
  const _ParsedTextToken({
    required this.prefix,
    required this.token,
    required this.trailing,
    required this.isMention,
    required this.isLink,
    required this.target,
  });

  final String prefix;
  final String token;
  final String trailing;
  final bool isMention;
  final bool isLink;
  final String target;
}

class _InteractiveMessageText extends StatefulWidget {
  const _InteractiveMessageText({
    required this.text,
    required this.baseStyle,
    required this.isMine,
    required this.scheme,
  });

  final String text;
  final TextStyle baseStyle;
  final bool isMine;
  final ColorScheme scheme;

  @override
  State<_InteractiveMessageText> createState() => _InteractiveMessageTextState();
}

class _InteractiveMessageTextState extends State<_InteractiveMessageText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  final List<_ParsedTextToken> _tokens = <_ParsedTextToken>[];
  String _trailingText = '';
  late TextSpan _cachedSpan;

  @override
  void initState() {
    super.initState();
    _parseTokens();
    _updateSpans();
  }

  @override
  void didUpdateWidget(covariant _InteractiveMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
      _parseTokens();
      _updateSpans();
    } else if (oldWidget.baseStyle != widget.baseStyle ||
        oldWidget.isMine != widget.isMine ||
        oldWidget.scheme != widget.scheme) {
      _updateSpans();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _parseTokens() {
    _tokens.clear();
    final String text = widget.text;
    final int lastMatch = text.length;
    int lastEnd = 0;

    for (final RegExpMatch match in _interactiveTokenRegExp.allMatches(text)) {
      final String prefix = match.start > lastEnd ? text.substring(lastEnd, match.start) : '';
      final String rawToken = match.group(0)!;
      String token = rawToken;
      String trailingPunctuation = '';

      while (token.isNotEmpty &&
          (token.endsWith('.') ||
              token.endsWith(',') ||
              token.endsWith('!') ||
              token.endsWith('?') ||
              token.endsWith(';') ||
              token.endsWith(':') ||
              token.endsWith(')') ||
              token.endsWith(']'))) {
        trailingPunctuation = token[token.length - 1] + trailingPunctuation;
        token = token.substring(0, token.length - 1);
      }

      final bool isMention = token.startsWith('@');
      final String target = isMention ? token.substring(1) : token;

      final TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (mounted) {
            AppUrlLauncher.openUrl(context, isMention ? '/g/$target' : target);
          }
        };
      _recognizers.add(recognizer);

      _tokens.add(_ParsedTextToken(
        prefix: prefix,
        token: token,
        trailing: trailingPunctuation,
        isMention: isMention,
        isLink: !isMention,
        target: target,
      ));

      lastEnd = match.end;
    }

    _trailingText = lastEnd < lastMatch ? text.substring(lastEnd) : '';
  }

  void _updateSpans() {
    final Color linkColor = widget.isMine
        ? widget.scheme.onPrimaryContainer
        : widget.scheme.primary;

    final List<TextSpan> spans = <TextSpan>[];

    for (int i = 0; i < _tokens.length; i++) {
      final _ParsedTextToken t = _tokens[i];
      if (t.prefix.isNotEmpty) {
        spans.add(TextSpan(text: t.prefix));
      }
      final TapGestureRecognizer recognizer = _recognizers[i];
      if (t.isMention) {
        spans.add(TextSpan(
          text: t.token,
          style: widget.baseStyle.copyWith(
            color: linkColor,
            fontWeight: FontWeight.w600,
          ),
          recognizer: recognizer,
        ));
      } else {
        spans.add(TextSpan(
          text: t.token,
          style: widget.baseStyle.copyWith(
            color: linkColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: linkColor.withValues(alpha: 0.4),
          ),
          recognizer: recognizer,
        ));
      }
      if (t.trailing.isNotEmpty) {
        spans.add(TextSpan(text: t.trailing));
      }
    }

    if (_trailingText.isNotEmpty) {
      spans.add(TextSpan(text: _trailingText));
    }

    _cachedSpan = TextSpan(
      style: widget.baseStyle,
      children: spans,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(_cachedSpan);
  }
}

class _ForwardedPayload {
  const _ForwardedPayload({required this.sender, required this.body});

  final String sender;
  final String body;
}

class _MessageBubbleHeader extends StatelessWidget {
  const _MessageBubbleHeader({
    required this.isMine,
    required this.senderDisplayName,
    required this.senderAvatarUrl,
    required this.visibleBadges,
    required this.hiddenBadgeCount,
    required this.scheme,
    required this.textTheme,
  });

  final bool isMine;
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  final List<ApiBadge> visibleBadges;
  final int hiddenBadgeCount;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (isMine ||
        ((senderDisplayName ?? '').trim().isEmpty && visibleBadges.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[
          if (senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: ApiConstants.resolve(senderAvatarUrl),
                httpHeaders: cachedAuthHeaders(),
                width: 16,
                height: 16,
                memCacheWidth: 32,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if ((senderDisplayName ?? '').trim().isNotEmpty)
            Text(
              senderDisplayName!,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.avatarColorFor(
                  senderDisplayName!,
                  scheme,
                ),
              ),
            ),
          ...visibleBadges.map(
            (ApiBadge badge) => BadgeChip(
              id: badge.id,
              name: badge.name,
              icon: badge.icon,
              color: badge.color,
              interactive: false,
            ),
          ),
          if (hiddenBadgeCount > 0) BadgeOverflowChip(count: hiddenBadgeCount),
        ],
      ),
    );
  }
}

class _ChannelCommentsBar extends StatelessWidget {
  const _ChannelCommentsBar({
    required this.commentsCount,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
    this.borderRadius = 8.0,
  });

  final int commentsCount;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final String label = commentsCount > 0
        ? context.l10n.commentsCount(commentsCount)
        : context.l10n.commentsHint;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.tap();
          onTap();
        },
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.primary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubbleFooter extends StatelessWidget {
  const _MessageBubbleFooter({
    required this.isMine,
    required this.isE2ee,
    required this.isEdited,
    required this.isDeleted,
    required this.isRead,
    required this.formattedTime,
    required this.scheme,
    required this.textTheme,
    this.isSending = false,
    this.isFailed = false,
    this.onRetrySend,
  });

  final bool isMine;
  final bool isE2ee;
  final bool isEdited;
  final bool isDeleted;
  final bool isRead;
  final String formattedTime;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool isSending;
  final bool isFailed;
  final VoidCallback? onRetrySend;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color footerTextColor = isMine
        ? scheme.onPrimaryContainer.withValues(alpha: 0.70)
        : scheme.onSurfaceVariant.withValues(alpha: 0.75);

    final Color statusIconColor = isMine
        ? (isSending
            ? scheme.onPrimaryContainer.withValues(alpha: 0.60)
            : (isDark ? scheme.primary : scheme.onPrimaryContainer.withValues(alpha: 0.85)))
        : scheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isE2ee) ...[
          Icon(
            Icons.lock_rounded,
            size: 11,
            color: scheme.tertiary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 3),
        ],
        if (isEdited)
          Text(
            context.l10n.chatEdited,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: footerTextColor,
            ),
          ),
        if (isEdited) const SizedBox(width: 4),
        Text(
          formattedTime,
          style: textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: footerTextColor,
          ),
        ),
        if (isMine && !isDeleted) ...<Widget>[
          const SizedBox(width: 3),
          if (isFailed)
            GestureDetector(
              onTap: onRetrySend,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: scheme.error,
                ),
              ),
            )
          else if (isSending)
            Icon(
              Icons.access_time_rounded,
              size: 12,
              color: statusIconColor,
            )
          else
            Icon(
              isRead ? Icons.done_all_rounded : Icons.check_rounded,
              size: 13,
              color: statusIconColor,
            ),
        ],
      ],
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({
    required this.onReply,
    required this.scheme,
    required this.child,
  });

  final VoidCallback onReply;
  final ColorScheme scheme;
  final Widget child;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final ValueNotifier<double> _dragNotifier = ValueNotifier<double>(0.0);
  static const double _maxDrag = 64;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.addListener(() {
      _dragNotifier.value = _animation.value;
    });
  }

  @override
  void dispose() {
    _dragNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _controller.stop();
        _triggered = false;
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        double delta = details.delta.dx;
        // Apply friction if pulled past the threshold
        if (_dragNotifier.value < -_maxDrag && delta < 0) {
          delta *= 0.3;
        }

        final double next = (_dragNotifier.value + delta).clamp(-_maxDrag * 1.2, 0.0);
        _dragNotifier.value = next;

        if (next <= -_maxDrag && !_triggered) {
          _triggered = true;
          HapticService.reaction(); // Pop when threshold met
        } else if (next > -_maxDrag + 12.0 && _triggered) {
          _triggered = false; // Reset with hysteresis, without chatter vibration
        }
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        final double current = _dragNotifier.value;
        if (current <= -_maxDrag) {
          HapticService.tap();
          widget.onReply();
        }

        // Snap back without overshooting past 0
        _animation = Tween<double>(
          begin: current,
          end: 0,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

        _controller.forward(from: 0);
      },
      child: ValueListenableBuilder<double>(
        valueListenable: _dragNotifier,
        builder: (BuildContext context, double dragX, Widget? cachedChild) {
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Transform.translate(
                offset: Offset(dragX, 0),
                child: cachedChild,
              ),
              if (dragX < -8)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Transform.scale(
                    scale: (dragX.abs() / _maxDrag).clamp(0.0, 1.0),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: widget.scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.reply_rounded, color: widget.scheme.primary, size: 20),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _CircleVideoInlinePlayer extends StatefulWidget {
  const _CircleVideoInlinePlayer({
    required this.videoUrl,
    required this.durationSeconds,
    required this.isMine,
    required this.isE2ee,
    required this.isEdited,
    required this.isDeleted,
    required this.isRead,
    required this.formattedTime,
    required this.scheme,
    required this.textTheme,
    required this.chatId,
    required this.wsClient,
    this.e2eeFileKey,
    this.onLongPress,
  });

  final String videoUrl;
  final int durationSeconds;
  final bool isMine;
  final bool isE2ee;
  final bool isEdited;
  final bool isDeleted;
  final bool isRead;
  final String formattedTime;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final int chatId;
  final WebSocketClient wsClient;
  final String? e2eeFileKey;
  final VoidCallback? onLongPress;

  @override
  State<_CircleVideoInlinePlayer> createState() => _CircleVideoInlinePlayerState();
}

class _CircleVideoInlinePlayerState extends State<_CircleVideoInlinePlayer> {
  VideoPlayerController? _videoController;
  bool _initialized = false;
  bool _playing = false;
  bool _showThumbnail = true;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isTickerActive = TickerMode.valuesOf(context).enabled;
    if (!isTickerActive && _videoController != null && _playing) {
      _videoController!.pause();
    }
  }

  Future<void> _initVideo() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      Uint8List? fileKey;
      if (widget.e2eeFileKey != null && widget.e2eeFileKey!.isNotEmpty) {
        fileKey = base64Decode(widget.e2eeFileKey!);
      }
      final localPath = await WsMediaFetcher.fetchToLocalFile(
        filePath: widget.videoUrl,
        wsClient: widget.wsClient,
        e2eeFileKey: fileKey,
      );
      if (!mounted) return;
      _videoController = VideoPlayerController.file(
        File(localPath),
      );
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      _videoController!.addListener(_onVideoStateChange);
      if (mounted) {
        setState(() {
          _initialized = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initialized = false;
          _isLoading = false;
        });
      }
    }
  }

  void _onVideoStateChange() {
    if (!mounted) return;
    final bool wasPlaying = _playing;
    final bool nowPlaying = _videoController?.value.isPlaying ?? false;
    if (wasPlaying != nowPlaying) setState(() => _playing = nowPlaying);
  }

  Future<void> _togglePlay() async {
    if (_videoController == null && !_isLoading) {
      await _initVideo();
      if (!mounted || _videoController == null) return;
      setState(() => _showThumbnail = false);
      _videoController!.play();
      return;
    }
    if (!_initialized || _videoController == null) return;
    if (_showThumbnail) {
      setState(() => _showThumbnail = false);
      _videoController!.play();
    } else if (_playing) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoStateChange);
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double circleSize = 180;

    return GestureDetector(
      onTap: _togglePlay,
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: circleSize,
        height: circleSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail or video
            if (_showThumbnail || !_initialized)
              _circleThumbnail(circleSize)
            else
              ClipOval(
                child: SizedBox(
                  width: circleSize,
                  height: circleSize,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width > 0
                          ? _videoController!.value.size.width
                          : circleSize,
                      height: _videoController!.value.size.height > 0
                          ? _videoController!.value.size.height
                          : circleSize,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                ),
              ),
            // Play/pause overlay
            if (_showThumbnail || !_playing)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _showThumbnail 
                      ? widget.scheme.surface.withValues(alpha: 0.3) 
                      : widget.scheme.surface.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _showThumbnail ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: widget.scheme.onSurface,
                  size: 28,
                ),
              ),
            // Duration badge
            if (_showThumbnail && widget.durationSeconds > 0)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDuration(widget.durationSeconds),
                    style: TextStyle(color: widget.scheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            // Footer overlay
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.scheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _MessageBubbleFooter(
                  isMine: widget.isMine,
                  isE2ee: widget.isE2ee,
                  isEdited: widget.isEdited,
                  isDeleted: widget.isDeleted,
                  isRead: widget.isRead,
                  formattedTime: widget.formattedTime,
                  scheme: widget.scheme,
                  textTheme: widget.textTheme,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleThumbnail(double circleSize) {
    return Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        color: widget.isMine
            ? widget.scheme.onPrimary.withValues(alpha: 0.12)
            : widget.scheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.videocam_rounded, size: 32),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _MediaCarousel extends StatefulWidget {
  const _MediaCarousel({
    required this.urls,
    required this.scheme,
    required this.textStyle,
    required this.isMine,
    required this.onOpenMedia,
    required this.onLongPressMedia,
    required this.chatId,
    required this.isE2ee,
    this.e2eeFileKey,
    this.radius = 12.0,
  });

  final List<String> urls;
  final ColorScheme scheme;
  final TextStyle textStyle;
  final bool isMine;
  final VoidCallback? onOpenMedia;
  final VoidCallback? onLongPressMedia;
  final int chatId;
  final bool isE2ee;
  final String? e2eeFileKey;
  final double radius;

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  final PageController _controller = PageController(viewportFraction: 1.0);
  final ValueNotifier<int> _pageNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _controller.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double rad = widget.radius;
    return InkWell(
      onTap: widget.onOpenMedia,
      onLongPress: widget.onLongPressMedia,
      borderRadius: BorderRadius.circular(rad),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rad),
        child: SizedBox(
          width: 240,
          height: 190,
          child: Stack(
            children: <Widget>[
              PageView.builder(
                controller: _controller,
                itemCount: widget.urls.length,
                onPageChanged: (int index) => _pageNotifier.value = index,
                itemBuilder: (BuildContext context, int index) {
                  return WsCachedImage(
                    e2eeFileKey: widget.e2eeFileKey,
                    mediaUrl: widget.urls[index],
                    chatId: widget.chatId,
                    isE2ee: widget.isE2ee,
                    width: 240,
                    height: 190,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context) => SizedBox(
                      width: 240,
                      height: 190,
                      child: Center(
                        child: AppLoadingIndicator(
                          color: widget.isMine
                              ? widget.scheme.onPrimary
                              : widget.scheme.primary,
                        ),
                      ),
                    ),
                    errorWidget: (BuildContext context, Object error) => Container(
                      width: 240,
                      height: 190,
                      alignment: Alignment.center,
                      color: widget.isMine
                          ? widget.scheme.onPrimary.withValues(alpha: 0.12)
                          : widget.scheme.surfaceContainerHigh,
                      child: Semantics(
                        label: context.l10n.chatImageUnavailable,
                        child: Text(
                          context.l10n.chatImageUnavailable,
                          style: widget.textStyle,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.urls.length > 1)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _pageNotifier,
                    builder: (BuildContext context, int page, Widget? _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${page + 1}/${widget.urls.length}',
                          style: TextStyle(
                            color: widget.scheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadProgressOverlay extends StatelessWidget {
  const _UploadProgressOverlay({
    required this.progress,
    this.bytesSent,
    this.totalBytes,
    required this.isMine,
    required this.scheme,
    this.onCancel,
  });

  final double? progress;
  final int? bytesSent;
  final int? totalBytes;
  final bool isMine;
  final ColorScheme scheme;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final double p = (progress ?? 0.0).clamp(0.0, 1.0);
    final int percent = (p * 100).toInt();

    final String progressLabel;
    if (totalBytes != null && totalBytes! > 0) {
      if (bytesSent != null && bytesSent! > 0) {
        progressLabel = '$percent% • ${FileTypeDetector.formatFileSize(bytesSent!)} / ${FileTypeDetector.formatFileSize(totalBytes!)}';
      } else {
        progressLabel = '$percent% • ${FileTypeDetector.formatFileSize(totalBytes!)}';
      }
    } else {
      progressLabel = '$percent%';
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: p > 0.01 ? p : null,
                      strokeWidth: 3.2,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                  ),
                  if (onCancel != null)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.close_rounded, color: scheme.onSurface, size: 22),
                      onPressed: onCancel,
                      tooltip: 'Отменить',
                    )
                  else
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                progressLabel,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickerVideoPlayer extends StatefulWidget {
  const _StickerVideoPlayer({required this.url});
  final String url;

  @override
  State<_StickerVideoPlayer> createState() => _StickerVideoPlayerState();
}

class _StickerVideoPlayerState extends State<_StickerVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isTickerActive = TickerMode.valuesOf(context).enabled;
    if (!isTickerActive && _controller != null && _controller!.value.isPlaying) {
      _controller!.pause();
    } else if (isTickerActive && _controller != null && _isInit && !_controller!.value.isPlaying) {
      _controller!.play();
    }
  }

  Future<void> _initVideo() async {
    try {
      final Uri uri = Uri.parse(widget.url);
      _controller = VideoPlayerController.networkUrl(uri);
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.setVolume(0.0);
      if (mounted && TickerMode.valuesOf(context).enabled) {
        await _controller!.play();
      }
      if (mounted) setState(() => _isInit = true);
    } catch (_) {
      // Graceful fallback to static thumbnail
    }
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null && _isInit && _controller!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.contain,
      memCacheWidth: 400,
      memCacheHeight: 400,
      placeholder: (_, _) => const AppLoadingIndicator(size: 24),
      errorWidget: (_, _, _) => const Icon(Icons.sticky_note_2_outlined),
    );
  }
}
