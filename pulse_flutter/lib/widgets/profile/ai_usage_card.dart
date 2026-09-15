import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';

class AiUsageIndicatorCard extends StatelessWidget {
  const AiUsageIndicatorCard({required this.usage, super.key});

  final ApiAiUsage usage;

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

  static String _formatTokens(int count) {
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

    final double usedPercent = usage.usedPercent.clamp(0.0, 100.0);
    final double remainingPercent = (100.0 - usedPercent).clamp(0.0, 100.0);
    final String remainingPercentLabel = remainingPercent.toStringAsFixed(
      remainingPercent.truncateToDouble() == remainingPercent ? 0 : 1,
    );

    final int effectiveRemaining = usage.remainingTokens > 0
        ? usage.remainingTokens
        : (usage.limitTokens * (remainingPercent / 100.0)).round();
    final String remainingTokensStr = _formatTokens(effectiveRemaining);
    final String limitTokensStr = _formatTokens(usage.limitTokens);

    final String resetFormatted = _formatResetDate(context, usage.resetsAt);
    final String resetPart =
        resetFormatted.isNotEmpty ? ' · обновится $resetFormatted' : '';
    final String subtitleText =
        '$remainingTokensStr из $limitTokensStr токенов$resetPart';

    final Color statusColor = remainingPercent < 15
        ? scheme.error
        : (remainingPercent < 40 ? scheme.tertiary : scheme.primary);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
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
                      'AI-токены',
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
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: remainingPercent / 100.0,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
