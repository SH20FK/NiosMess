import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:pulse_flutter/widgets/voice_message_player.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/widgets/chat/ws_cached_image.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';

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
    this.isVoice = false,
    this.isCircleVideo = false,
    this.mediaDuration,
    this.animateHighlight = false,
    this.hideFooter = false,
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
  final int? mediaDuration;
  final bool animateHighlight;
  final bool hideFooter;

  List<String> get mediaUrls {
    if (mediaUrl == null || mediaUrl!.trim().isEmpty) return [];
    return mediaUrl!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static const BorderRadius _mineRadiusNoneSame = BorderRadius.all(
    Radius.circular(16),
  );
  static const BorderRadius _mineRadiusPrevSame = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    topRight: Radius.circular(4),
    bottomRight: Radius.circular(16),
  );
  static const BorderRadius _mineRadiusNextSame = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    topRight: Radius.circular(16),
    bottomRight: Radius.circular(4),
  );
  static const BorderRadius _mineRadiusPrevSameNextSame = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    topRight: Radius.circular(4),
    bottomRight: Radius.circular(4),
  );

  static const BorderRadius _theirsRadiusNoneSame = BorderRadius.all(
    Radius.circular(16),
  );
  static const BorderRadius _theirsRadiusPrevSame = BorderRadius.only(
    topRight: Radius.circular(16),
    bottomRight: Radius.circular(16),
    topLeft: Radius.circular(4),
    bottomLeft: Radius.circular(16),
  );
  static const BorderRadius _theirsRadiusNextSame = BorderRadius.only(
    topRight: Radius.circular(16),
    bottomRight: Radius.circular(16),
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(4),
  );
  static const BorderRadius _theirsRadiusPrevSameNextSame = BorderRadius.only(
    topRight: Radius.circular(16),
    bottomRight: Radius.circular(16),
    topLeft: Radius.circular(4),
    bottomLeft: Radius.circular(4),
  );

  static BorderRadius _getBubbleRadius(
    bool isMine,
    bool isPrevSame,
    bool isNextSame,
  ) {
    if (isMine) {
      if (isPrevSame && isNextSame) return _mineRadiusPrevSameNextSame;
      if (isPrevSame) return _mineRadiusPrevSame;
      if (isNextSame) return _mineRadiusNextSame;
      return _mineRadiusNoneSame;
    } else {
      if (isPrevSame && isNextSame) return _theirsRadiusPrevSameNextSame;
      if (isPrevSame) return _theirsRadiusPrevSame;
      if (isNextSame) return _theirsRadiusNextSame;
      return _theirsRadiusNoneSame;
    }
  }

  static final RegExp _fwdRegExp = RegExp(r'^_fwd from\s+(.+?):\s*(.*)$');
  static final RegExp _mentionRegExp = RegExp(r'@(\w+)');

  static TextSpan _parseTextWithMentions(
    BuildContext context,
    String text,
    TextStyle baseStyle,
    bool isMine,
    ColorScheme scheme,
  ) {
    final int lastMatch = text.length;
    final List<TextSpan> spans = <TextSpan>[];
    int lastEnd = 0;

    for (final RegExpMatch match in _mentionRegExp.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final String username = match.group(1)!;
      final Color linkColor = isMine
          ? scheme.onPrimaryContainer
          : scheme.primary;
      final String mention = match.group(0)!;
      spans.add(TextSpan(
        text: mention,
        style: baseStyle.copyWith(
          color: linkColor,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => context.go('/g/$username'),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < lastMatch) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return TextSpan(style: baseStyle, children: spans);
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

    final Color bubbleColor = isDeleted
        ? scheme.surfaceContainerHighest
        : (isMine ? scheme.primaryContainer : scheme.surfaceContainerHigh);
    final Color textColor = isDeleted
        ? scheme.onSurfaceVariant
        : (isMine ? scheme.onPrimaryContainer : scheme.onSurface);
    final bool hasMedia = (mediaUrl ?? '').trim().isNotEmpty;
    final String displayText = forwarded?.body ?? text;
    final bool hasText = displayText.trim().isNotEmpty;

    final Map<String, String> headers = cachedAuthHeaders();

    final BorderRadius bubbleRadius = _getBubbleRadius(
      isMine,
      isPrevSame,
      isNextSame,
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
            if (isCircleVideo && hasMedia)
              _buildCircleVideoContent(context, scheme, textTheme)
            else if (isVoice && hasMedia)
              _buildVoiceOnly(context, scheme, textTheme)
            else
            InkWell(
              borderRadius: bubbleRadius,
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
                  maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: bubbleRadius,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Semantics(
                  label: isMine
                      ? context.l10n.messageSentByMe
                      : (senderDisplayName ?? context.l10n.messageSemantics),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            GestureDetector(
                              onTap: onReplyTap,
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: isMine
                                          ? scheme.primary
                                          : scheme.secondary,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  replyPreview!,
                                  maxLines: 1,
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
                          if (forwarded != null) ...<Widget>[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
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
                              ),
                            ),
                          ],
                          if (hasMedia)
                            _mediaPreview(
                              context,
                              scheme: scheme,
                              textTheme: textTheme,
                              textColor: textColor,
                              headers: headers,
                            ),
                          if (hasMedia && hasText) const SizedBox(height: 6),
                          if (hasText)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: 12,
                                right: hasMedia ? 0 : 36,
                              ),
                              child: Text.rich(
                                _parseTextWithMentions(
                                  context,
                                  displayText,
                                  textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                    fontStyle: isDeleted
                                        ? FontStyle.italic
                                        : null,
                                  ) ?? const TextStyle(),
                                  isMine,
                                  scheme,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (!hideFooter)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: _MessageBubbleFooter(
                          isMine: isMine,
                          isE2ee: isE2ee,
                          isEdited: isEdited,
                          isDeleted: isDeleted,
                          isRead: isRead,
                          formattedTime: formattedTime,
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                      ),
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
                        return GestureDetector(
                          onTap: onReactionTap != null
                              ? () {
                                  HapticService.reaction();
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
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${item.key} ${item.value}',
                              style: textTheme.labelSmall,
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

    final bool optimize = ref.read(uiSettingsProvider).optimizeForWeakDevices;
    if (optimize || !animate) {
      return content;
    }

    return _OnceAnimated(
      key: ValueKey<int>(text.hashCode),
      messageId: text.hashCode,
      child: RepaintBoundary(
        child: content
            .animate()
            .fade(duration: 180.ms, curve: Curves.easeOutCubic)
            .slideY(
              begin: 0.04,
              end: 0,
              duration: 180.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }

  Widget _buildCircleVideoContent(BuildContext context, ColorScheme scheme, TextTheme textTheme) {
    const double circleSize = 180;
    return Semantics(
      label: context.l10n.chatCircleVideo,
      child: SizedBox(
        width: circleSize,
        height: circleSize,
        child: _CircleVideoInlinePlayer(
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
          wsClient: ref.read(webSocketClientProvider),
          e2eeService: ref.read(e2eeServiceProvider),
          onLongPress: onLongPressMedia,
        ),
      ),
    );
  }

  Widget _buildVoiceOnly(BuildContext context, ColorScheme scheme, TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if ((replyPreview ?? '').trim().isNotEmpty)
          GestureDetector(
            onTap: onReplyTap,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isMine ? scheme.primary : scheme.secondary,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                replyPreview!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: isMine ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        InkWell(
          onLongPress: onLongPressMedia,
          borderRadius: BorderRadius.circular(16),
          child: VoiceMessagePlayer(
            audioUrl: mediaUrl!,
            durationSeconds: mediaDuration ?? 0,
            isMine: isMine,
            scheme: scheme,
            formattedTime: hideFooter ? null : formattedTime,
            isRead: isRead,
            isE2ee: isE2ee,
            isEdited: isEdited,
            chatId: chatId,
            wsClient: ref.read(webSocketClientProvider),
            e2eeService: ref.read(e2eeServiceProvider),
          ),
        ),
      ],
    );
  }

  Widget _mediaPreview(
    BuildContext context, {
    required ColorScheme scheme,
    required TextTheme textTheme,
    required Color textColor,
    required Map<String, String> headers,
  }) {
    if (isVoice && mediaUrl != null && mediaUrl!.trim().isNotEmpty) {
      return InkWell(
        onTap: onOpenMedia,
        onLongPress: onLongPressMedia,
        borderRadius: BorderRadius.circular(12),
        child: VoiceMessagePlayer(
          audioUrl: mediaUrl!,
          durationSeconds: mediaDuration ?? 0,
          isMine: isMine,
          scheme: scheme,
          chatId: chatId,
          wsClient: ref.read(webSocketClientProvider),
          e2eeService: ref.read(e2eeServiceProvider),
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
          onOpenMedia: onOpenMedia,
          onLongPressMedia: onLongPressMedia,
        );
      }
      return InkWell(
        onTap: onOpenMedia,
        onLongPress: onLongPressMedia,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: urls.first,
            cacheKey: '${urls.first}_preview',
            httpHeaders: headers,
            width: 220,
            height: 180,
            fit: BoxFit.cover,
            memCacheWidth: 440,
            memCacheHeight: 360,
            fadeInDuration: const Duration(milliseconds: 140),
            placeholder: (BuildContext context, String _) => SizedBox(
              width: 220,
              height: 180,
              child: Center(
                child: AppLoadingIndicator(
                  color: isMine ? scheme.onPrimary : scheme.primary,
                ),
              ),
            ),
            errorWidget: (BuildContext context, String _, Object error) {
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
      );
    }

    final FileTypeInfo typeInfo = FileTypeDetector.detect(
      fileName: mediaLabel ?? 'file',
    );

    return InkWell(
      onTap: onOpenMedia,
      onLongPress: onLongPressMedia,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isMine
              ? scheme.onPrimary.withValues(alpha: 0.15)
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (isMine ? scheme.onPrimary : scheme.primary).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(12),
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    (mediaLabel ?? context.l10n.chatOpenAttachment)
                            .trim()
                            .isEmpty
                        ? context.l10n.chatOpenAttachment
                        : mediaLabel!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${typeInfo.label} • ${context.l10n.chatTapToPreview}',
                    style: textTheme.labelSmall?.copyWith(
                      color: isMine
                          ? scheme.onPrimary.withValues(alpha: 0.82)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: isMine ? scheme.onPrimary : scheme.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  _ForwardedPayload? _parseForwarded(String rawText) {
    final String trimmed = rawText.trim();
    final Match? result = _fwdRegExp.firstMatch(trimmed);
    if (result == null) return null;
    final String sender = (result.group(1) ?? '').trim();
    final String body = (result.group(2) ?? '').trim();
    if (sender.isEmpty) return null;
    return _ForwardedPayload(sender: sender, body: body);
  }

  Widget _buildInlineKeyboard(ColorScheme scheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: replyMarkup!.inlineKeyboard
            .map((List<InlineKeyboardButton> row) {
              if (row.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                  children: row
                      .map((InlineKeyboardButton btn) {
                        return OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            if (btn.url != null && btn.url!.trim().isNotEmpty) {
                              final Uri? uri = Uri.tryParse(btn.url!);
                              if (uri != null) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            } else if (btn.callbackData != null &&
                                onCallbackQuery != null) {
                              onCallbackQuery!(btn.callbackData!);
                            }
                          },
                          child: Text(
                            btn.text,
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
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
                color: scheme.primary,
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
  });

  final bool isMine;
  final bool isE2ee;
  final bool isEdited;
  final bool isDeleted;
  final bool isRead;
  final String formattedTime;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isE2ee) ...[
          Icon(
            Icons.lock_rounded,
            size: 11,
            color: Colors.green.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 3),
        ],
        if (isEdited)
          Text(
            context.l10n.chatEdited,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        if (isEdited) const SizedBox(width: 4),
        Text(
          formattedTime,
          style: textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        if (isMine && !isDeleted) ...<Widget>[
          const SizedBox(width: 3),
          Icon(
            isRead ? Icons.done_all_rounded : Icons.check_rounded,
            size: 13,
            color: scheme.primary.withValues(alpha: 0.8),
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
  double _dragX = 0;
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
      setState(() {
        _dragX = _animation.value;
      });
    });
  }

  @override
  void dispose() {
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
        setState(() {
          double delta = details.delta.dx;
          // Apply friction if pulled past the threshold
          if (_dragX < -_maxDrag && delta < 0) {
            delta *= 0.3; 
          }
          
          _dragX = (_dragX + delta).clamp(-_maxDrag * 1.2, 0);

          if (_dragX <= -_maxDrag && !_triggered) {
            _triggered = true;
            HapticService.reaction(); // small pop when threshold met
          } else if (_dragX > -_maxDrag && _triggered) {
            _triggered = false;
            HapticService.reaction(); // small pop when threshold un-met
          }
        });
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        if (_dragX <= -_maxDrag) {
          HapticService.tap();
          widget.onReply();
        }
        
        // Snap back without overshooting past 0
        _animation = Tween<double>(
          begin: _dragX,
          end: 0,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
        
        _controller.forward(from: 0);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: Offset(_dragX, 0),
            child: widget.child,
          ),
          if (_dragX < -8)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Transform.scale(
                scale: (_dragX.abs() / _maxDrag).clamp(0.0, 1.0),
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
    required this.e2eeService,
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
  final E2eeService e2eeService;
  final VoidCallback? onLongPress;

  @override
  State<_CircleVideoInlinePlayer> createState() => _CircleVideoInlinePlayerState();
}

class _CircleVideoInlinePlayerState extends State<_CircleVideoInlinePlayer> {
  VideoPlayerController? _videoController;
  bool _initialized = false;
  bool _playing = false;
  bool _showThumbnail = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final localPath = await WsMediaFetcher.fetchToLocalFile(
        filePath: widget.videoUrl,
        wsClient: widget.wsClient,
        isE2ee: widget.isE2ee,
        chatId: widget.chatId,
        e2eeService: widget.e2eeService,
      );
      _videoController = VideoPlayerController.file(
        File(localPath),
      );
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      _videoController!.addListener(_onVideoStateChange);
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _initialized = false);
    }
  }

  void _onVideoStateChange() {
    if (!mounted) return;
    final bool wasPlaying = _playing;
    final bool nowPlaying = _videoController?.value.isPlaying ?? false;
    if (wasPlaying != nowPlaying) setState(() => _playing = nowPlaying);
  }

  void _togglePlay() {
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
                  child: VideoPlayer(_videoController!),
                ),
              ),
            // Play/pause overlay
            if (_showThumbnail || !_playing)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _showThumbnail ? Colors.black26 : Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _showThumbnail ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: Colors.white,
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
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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
                  color: Colors.black.withValues(alpha: 0.5),
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
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.scheme.shadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: WsCachedImage(
          mediaUrl: widget.videoUrl,
          chatId: widget.chatId,
          isE2ee: widget.isE2ee,
          width: circleSize,
          height: circleSize,
          fit: BoxFit.cover,
          placeholder: (BuildContext context) => Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: widget.isMine
                  ? widget.scheme.onPrimary.withValues(alpha: 0.12)
                  : widget.scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam_rounded, size: 32),
          ),
          errorWidget: (BuildContext context, Object error) {
            return Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: widget.isMine
                    ? widget.scheme.onPrimary.withValues(alpha: 0.12)
                    : widget.scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.broken_image_rounded, size: 32),
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }
}

class _OnceAnimated extends StatefulWidget {
  const _OnceAnimated({
    super.key,
    required this.messageId,
    required this.child,
  });

  final int messageId;
  final Widget child;

  @override
  State<_OnceAnimated> createState() => _OnceAnimatedState();
}

class _OnceAnimatedState extends State<_OnceAnimated> {
  bool _played = false;

  @override
  Widget build(BuildContext context) {
    if (_played) return widget.child;
    _played = true;
    return widget.child;
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
  });

  final List<String> urls;
  final ColorScheme scheme;
  final TextStyle textStyle;
  final bool isMine;
  final VoidCallback? onOpenMedia;
  final VoidCallback? onLongPressMedia;

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onOpenMedia,
      onLongPress: widget.onLongPressMedia,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 220,
        height: 180,
        child: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (int index) =>
                  setState(() => _currentPage = index),
              itemBuilder: (BuildContext context, int index) {
                final double scale =
                    index == _currentPage ? 1.0 : 0.9;
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < widget.urls.length - 1 ? 8 : 0,
                  ),
                  child: AnimatedScale(
                    scale: scale,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: widget.urls[index],
                        cacheKey: '${widget.urls[index]}_preview',
                        httpHeaders: cachedAuthHeaders(),
                        width: 220,
                        height: 180,
                        fit: BoxFit.cover,
                        memCacheWidth: 440,
                        memCacheHeight: 360,
                        fadeInDuration: const Duration(milliseconds: 140),
                        placeholder: (_, _) => SizedBox(
                          width: 220,
                          height: 180,
                          child: Center(
                            child: AppLoadingIndicator(
                              color: widget.isMine
                                  ? widget.scheme.onPrimary
                                  : widget.scheme.primary,
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          width: 220,
                          height: 180,
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${widget.urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
