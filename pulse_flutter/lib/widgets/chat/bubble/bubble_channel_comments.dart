import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

class ChannelCommentsBar extends StatelessWidget {
  const ChannelCommentsBar({
    required this.commentsCount,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
    this.borderRadius = 8.0,
    super.key,
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
              color: scheme.outlineVariant,
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

