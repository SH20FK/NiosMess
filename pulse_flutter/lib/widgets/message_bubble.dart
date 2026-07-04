import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    required this.text,
    required this.formattedTime,
    required this.isMine,
    this.isDeleted = false,
    this.isEdited = false,
    this.isRead = false,
    this.replyPreview,
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
    super.key,
  });

  final String text;
  final String formattedTime;
  final bool isMine;
  final bool isDeleted;
  final bool isEdited;
  final bool isRead;
  final bool isE2ee;
  final String? replyPreview;
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
                            Container(
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
                            ),
                          if (hasMedia && hasText) const SizedBox(height: 6),
                          if (hasText)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: 12,
                                right: hasMedia ? 0 : 36,
                              ),
                              child: Text(
                                displayText,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: textColor,
                                  fontStyle: isDeleted
                                      ? FontStyle.italic
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
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

    if (onSwipeToReply != null) {
      content = Dismissible(
        key: ValueKey<String>('msg_dismiss_${text.hashCode}_$formattedTime'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (DismissDirection direction) async {
          onSwipeToReply!();
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.reply_rounded, color: scheme.primary, size: 20),
          ),
        ),
        child: content,
      );
    }

    final bool optimize = ref.read(uiSettingsProvider).optimizeForWeakDevices;
    if (optimize || !animate) {
      return content;
    }

    return RepaintBoundary(
      child: content
          .animate()
          .fade(duration: 180.ms, curve: Curves.easeOutCubic)
          .slideY(
            begin: 0.04,
            end: 0,
            duration: 180.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }

  Widget _mediaPreview(
    BuildContext context, {
    required ColorScheme scheme,
    required TextTheme textTheme,
    required Color textColor,
  }) {
    if (mediaIsImage) {
      return InkWell(
        onTap: onOpenMedia,
        onLongPress: onLongPressMedia,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: mediaUrl!,
            cacheKey: '${mediaUrl}_preview',
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
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
                imageUrl: senderAvatarUrl!,
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
