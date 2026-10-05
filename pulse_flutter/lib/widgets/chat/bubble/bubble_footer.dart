import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class MessageBubbleFooter extends StatelessWidget {
  const MessageBubbleFooter({
    required this.isMine,
    required this.isE2ee,
    required this.isEdited,
    required this.isDeleted,
    required this.isRead,
    required this.formattedTime,
    required this.scheme,
    required this.textTheme,
    this.expiresAt,
    this.isSending = false,
    this.isFailed = false,
    this.onRetrySend,
    super.key,
  });

  final bool isMine;
  final bool isE2ee;
  final bool isEdited;
  final bool isDeleted;
  final bool isRead;
  final String formattedTime;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final DateTime? expiresAt;
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
        if (expiresAt != null) ...[
          SelfDestructCountdownPill(
            expiresAt: expiresAt!,
            color: footerTextColor,
          ),
          const SizedBox(width: 4),
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

class SelfDestructCountdownPill extends StatefulWidget {
  const SelfDestructCountdownPill({
    required this.expiresAt,
    required this.color,
    super.key,
  });

  final DateTime expiresAt;
  final Color color;

  @override
  State<SelfDestructCountdownPill> createState() =>
      SelfDestructCountdownPillState();
}

class SelfDestructCountdownPillState
    extends State<SelfDestructCountdownPill> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant SelfDestructCountdownPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(Duration diff) {
    if (diff.isNegative) return '0с';
    final int secs = diff.inSeconds;
    if (secs < 60) return '$secsс';
    if (secs < 3600) return '${(secs / 60).ceil()}м';
    return '${(secs / 3600).ceil()}ч';
  }

  @override
  Widget build(BuildContext context) {
    final Duration diff = widget.expiresAt.difference(DateTime.now().toUtc());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.local_fire_department_rounded,
          size: 11,
          color: widget.color,
        ),
        const SizedBox(width: 2),
        Text(
          _formatRemaining(diff),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: widget.color,
          ),
        ),
      ],
    );
  }
}

