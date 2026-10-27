import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

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
    this.meshDeliveryStatus,
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
  final String? meshDeliveryStatus;
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
              : (isDark
                    ? scheme.primary
                    : scheme.onPrimaryContainer.withValues(alpha: 0.85)))
        : scheme.onSurfaceVariant;

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
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
        if (meshDeliveryStatus != null) ...[
          Text(meshDeliveryStatus!, style: textTheme.labelSmall?.copyWith(fontSize: 10, color: footerTextColor)),
          const SizedBox(width: 4),
        ],
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
            onRetrySend == null
                ? Text(
                    context.l10n.inboxSendFailed,
                    style: textTheme.labelSmall?.copyWith(color: scheme.error),
                  )
                : TextButton.icon(
                    onPressed: onRetrySend,
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: scheme.error,
                    ),
                    label: Text(context.l10n.secretRetry),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.error,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  )
          else
            Tooltip(
              excludeFromSemantics: true,
              message: isSending
                  ? context.l10n.inboxWaitingToSend
                  : isRead
                  ? context.l10n.deliveryRead
                  : context.l10n.deliverySent,
              child: Semantics(
                liveRegion: true,
                label: isSending
                    ? context.l10n.inboxWaitingToSend
                    : isRead
                    ? context.l10n.deliveryRead
                    : context.l10n.deliverySent,
                child: SizedBox(
                  key: const ValueKey('delivery-status-slot'),
                  width: 20,
                  height: 20,
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : M3Durations.short3,
                    switchInCurve: M3SpringCurves.expressiveDecel,
                    switchOutCurve: M3SpringCurves.expressiveDecel,
                    child: Icon(
                      isSending
                          ? Icons.access_time_rounded
                          : isRead
                          ? Icons.done_all_rounded
                          : Icons.check_rounded,
                      key: ValueKey((isSending, isRead)),
                      size: 14,
                      color: statusIconColor,
                    ),
                  ),
                ),
              ),
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

class SelfDestructCountdownPillState extends State<SelfDestructCountdownPill> {
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
