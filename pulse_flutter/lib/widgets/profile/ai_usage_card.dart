import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/ai_quota_model.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// Displays the server character quota without changing its units or limits.
class AiUsageIndicatorCard extends StatelessWidget {
  const AiUsageIndicatorCard({required this.usage, super.key});
  final AiQuota usage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final numbers = NumberFormat.decimalPattern(locale);
    final remainingPercent = usage.isAvailable ? usage.remainingPercent : 0.0;
    final remaining = usage.remainingChars > 0
        ? usage.remainingChars
        : (usage.limitChars * (remainingPercent / 100)).round();
    final percent = NumberFormat('0.#', locale).format(remainingPercent);
    final percentLabel = l10n.settingsAiUsagePercent(percent);
    final statusColor = remainingPercent < 15
        ? scheme.error
        : remainingPercent < 40
        ? scheme.tertiary
        : scheme.primary;
    return SettingsSection(
      title: l10n.settingsAiUsageTitle,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                usage.isAvailable
                    ? l10n.settingsAiUsageRemaining(
                        numbers.format(remaining),
                        numbers.format(usage.limitChars),
                      )
                    : l10n.settingsAiUsageUnavailable,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (usage.isAvailable) ...[
                const SizedBox(height: 8),
                Text(
                  percentLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: statusColor),
                ),
                const SizedBox(height: 12),
                ExcludeSemantics(
                  child: _M3QuotaMeter(
                    progress: remainingPercent / 100,
                    color: statusColor,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                if (usage.resetsAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.settingsAiUsageReset(
                      formatFullDateTime(usage.resetsAt!),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A determinate data meter: it animates only when the server quota changes.
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
  Widget build(BuildContext context) => SizedBox(
    height: 12,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0.0, 1.0)),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : M3Durations.medium2,
        curve: M3SpringCurves.expressiveStandard,
        builder: (context, progress, _) => FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: progress,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ),
  );
}
