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

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final double percent = usage.usedPercent.clamp(0.0, 100.0);
    final String percentLabel = percent.toStringAsFixed(
      percent.truncateToDouble() == percent ? 0 : 1,
    );
    final String resetFormatted = _formatResetDate(context, usage.resetsAt);

    final String resetPart =
        resetFormatted.isNotEmpty ? ' · обновится $resetFormatted' : '';
    final String subtitleText = 'Использовано $percentLabel%$resetPart';

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
                      'AI-лимит',
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
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent / 100.0,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 90
                    ? scheme.error
                    : (percent > 70 ? scheme.tertiary : scheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
