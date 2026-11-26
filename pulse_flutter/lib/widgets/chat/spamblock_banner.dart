import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';

/// Mirrors server-side spam-block scope (`chat_handler.py` / `public_antifraud.py`):
/// - @Support and Saved Messages are never restricted.
/// - Private groups and secret chats are never restricted.
/// - Public groups and channels are restricted.
/// - Direct chats are restricted only until the partner has replied.
bool isChatRestrictedBySpamBlock({
  required bool isAccountSpamBlocked,
  required ApiChatSummary? chat,
  required int? myUserId,
  bool hasPartnerReply = false,
}) {
  if (!isAccountSpamBlocked || chat == null) return false;
  if (chat.isSaved) return false;
  final String? uname = chat.username?.trim().toLowerCase();
  if (uname == 'support' || chat.name.trim().toLowerCase() == 'support') {
    return false;
  }
  if (chat.chatType == 'channel') {
    return true;
  }
  if (chat.chatType == 'group') {
    return !chat.isPrivate && !chat.isSecret;
  }
  if (chat.chatType == 'direct') {
    if (chat.isSecret) return false;
    if (hasPartnerReply) return false;
    final int? lastSenderId = chat.lastMessage?.senderId;
    if (lastSenderId != null && myUserId != null && lastSenderId != myUserId) {
      return false;
    }
    return true;
  }
  return false;
}

class SpamBlockBanner extends StatefulWidget {
  const SpamBlockBanner({
    super.key,
    this.until,
    this.reason,
    this.onContactSupport,
  });

  final DateTime? until;
  final String? reason;
  final VoidCallback? onContactSupport;

  @override
  State<SpamBlockBanner> createState() => _SpamBlockBannerState();
}

class _SpamBlockBannerState extends State<SpamBlockBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.until != null) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTiming() {
    if (widget.until == null) return 'Бессрочно';
    final DateTime local = widget.until!.toLocal();
    final String untilText = DateFormat('dd.MM, HH:mm').format(local);
    final Duration diff = widget.until!.difference(DateTime.now());
    if (diff.isNegative) return 'Срок истёк';
    final String remaining;
    if (diff.inDays > 0) {
      remaining = '${diff.inDays} д ${diff.inHours % 24} ч';
    } else if (diff.inHours > 0) {
      remaining = '${diff.inHours} ч ${diff.inMinutes % 60} мин';
    } else {
      remaining = '${diff.inMinutes} мин';
    }
    return 'До $untilText ($remaining)';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String reasonText =
        (widget.reason != null && widget.reason!.trim().isNotEmpty)
        ? widget.reason!.trim()
        : 'Нарушение правил платформы';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.lock_clock_rounded,
                  color: scheme.error,
                  size: 18,
                  semanticLabel: 'Ограничение аккаунта',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ограничение на отправку',
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatTiming(),
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Text(
                    reasonText,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.onContactSupport != null) ...<Widget>[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: widget.onContactSupport,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Оспорить',
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
