import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/models/api/ai_quota_model.dart';

class AiUsageIndicatorCard extends StatelessWidget {
  const AiUsageIndicatorCard({required this.usage, super.key});

  final AiQuota usage;

  static String _formatResetDate(BuildContext context, DateTime? dt) {
    if (dt == null) return '';
    final DateTime local = dt.toLocal();
    final bool isRu = Localizations.localeOf(context).languageCode == 'ru';
    if (isRu) {
      const List<String> months = <String>[
        '',
        'января',
        'февраля',
        'марта',
        'апреля',
        'мая',
        'июня',
        'июля',
        'августа',
        'сентября',
        'октября',
        'ноября',
        'декабря',
      ];
      final String month = (local.month >= 1 && local.month <= 12)
          ? months[local.month]
          : '';
      final String hour = local.hour.toString().padLeft(2, '0');
      final String min = local.minute.toString().padLeft(2, '0');
      return '${local.day} $month в $hour:$min';
    } else {
      const List<String> months = <String>[
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final String month = (local.month >= 1 && local.month <= 12)
          ? months[local.month]
          : '';
      final String hour = local.hour.toString().padLeft(2, '0');
      final String min = local.minute.toString().padLeft(2, '0');
      return '$month ${local.day} at $hour:$min';
    }
  }

  static String _formatNumber(int count) {
    final String s = count.toString();
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        sb.write('\u00A0');
      }
      sb.write(s[i]);
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    if (!usage.isAvailable) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadii.lgRadius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'AI-символы',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Лимит не установлен',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final double remainingPercent = usage.remainingPercent;
    final String remainingPercentLabel = remainingPercent.toStringAsFixed(
      remainingPercent.truncateToDouble() == remainingPercent ? 0 : 1,
    );

    final int effectiveRemaining = usage.remainingChars > 0
        ? usage.remainingChars
        : (usage.limitChars * (remainingPercent / 100.0)).round();
    final String remainingCharsStr = _formatNumber(effectiveRemaining);
    final String limitCharsStr = _formatNumber(usage.limitChars);

    final String resetFormatted = _formatResetDate(context, usage.resetsAt);
    final String resetPart =
        resetFormatted.isNotEmpty ? ' · сброс $resetFormatted' : '';
    final String subtitleText =
        '$remainingCharsStr из $limitCharsStr символов$resetPart';

    final Color statusColor = remainingPercent < 15
        ? scheme.error
        : (remainingPercent < 40 ? scheme.tertiary : scheme.primary);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgRadius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'AI-символы',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (remainingPercent < 15
                          ? scheme.errorContainer
                          : (remainingPercent < 40
                              ? scheme.tertiaryContainer
                              : scheme.primaryContainer))
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$remainingPercentLabel%',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: remainingPercent < 15
                        ? scheme.onErrorContainer
                        : (remainingPercent < 40
                            ? scheme.onTertiaryContainer
                            : scheme.onPrimaryContainer),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _M3QuotaMeter(
            progress: remainingPercent / 100.0,
            color: statusColor,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

/// Static expressive Material 3 Quota Meter (replaces legacy LinearProgressIndicator)
class _M3QuotaMeter extends StatelessWidget {
  const _M3QuotaMeter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final double clamped = progress.clamp(0.0, 1.0);
    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadii.fullRadius,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: 8,
              width: constraints.maxWidth * clamped,
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppRadii.fullRadius,
              ),
            ),
          );
        },
      ),
    );
  }
}
