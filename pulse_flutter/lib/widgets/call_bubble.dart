import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';

class CallBubble extends StatelessWidget {
  const CallBubble({
    required this.isMine,
    required this.formattedTime,
    this.callStatus = 'ended',
    this.callDuration,
    this.isVideo = false,
    this.onTap,
    super.key,
  });

  final bool isMine;
  final String formattedTime;
  final String callStatus;
  final int? callDuration;
  final bool isVideo;
  final VoidCallback? onTap;

  IconData get _icon {
    if (callStatus == 'missed') return Icons.call_missed_rounded;
    if (callStatus == 'cancelled') return Icons.call_made_rounded;
    if (isVideo) return Icons.videocam_rounded;
    return Icons.call_received_rounded;
  }

  Color _iconColor(ColorScheme scheme) {
    if (callStatus == 'missed') return scheme.error;
    if (callStatus == 'cancelled' || callStatus == 'no_answer') {
      return scheme.tertiary;
    }
    return scheme.primary;
  }

  String _label(BuildContext context) {
    final String type = isVideo
        ? context.l10n.chatVideoCall
        : context.l10n.chatVoiceCall;
    switch (callStatus) {
      case 'missed':
        return '$type • ${context.l10n.activeCallMissed}';
      case 'cancelled':
        return '$type • ${context.l10n.activeCallDeclined}';
      case 'no_answer':
        return '$type • ${context.l10n.activeCallRinging}';
      default:
        if (callDuration != null && callDuration! > 0) {
          return '$type • ${formatCallDuration(Duration(seconds: callDuration!))}';
        }
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color bgColor = isMine
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final Color fgColor = isMine ? scheme.onPrimaryContainer : scheme.onSurface;
    final Color iconColor = _iconColor(scheme);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Card.filled(
          color: bgColor,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMine ? 20 : 6),
              bottomRight: Radius.circular(isMine ? 6 : 20),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Badge(
                      backgroundColor: iconColor.withValues(alpha: 0.16),
                      largeSize: 36,
                      label: Icon(_icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _label(context),
                            style: textTheme.bodyMedium?.copyWith(
                              color: fgColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedTime,
                            style: textTheme.labelSmall?.copyWith(
                              color: fgColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
