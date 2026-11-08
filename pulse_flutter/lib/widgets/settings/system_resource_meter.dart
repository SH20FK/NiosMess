import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// A capacity measurement, not loading. The fill animates; labels stay truthful.
class SystemResourceMeter extends StatelessWidget {
  const SystemResourceMeter({
    required this.icon,
    required this.title,
    required this.used,
    required this.total,
    required this.unit,
    required this.subtitle,
    required this.unavailableLabel,
    super.key,
  });
  final IconData icon;
  final String title;
  final double? used;
  final double total;
  final String unit;
  final String subtitle;
  final String unavailableLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final available = total.isFinite && total > 0;
    final usageKnown = available && used != null && used!.isFinite;
    final ratio = usageKnown ? (used! / total).clamp(0.0, 1.0) : 0.0;
    final totalLabel =
        '${total.toStringAsFixed(total == total.roundToDouble() ? 0 : 1)} $unit';
    final label = !available
        ? unavailableLabel
        : usageKnown
        ? '${used!.clamp(0, total).toStringAsFixed(1)} / $totalLabel · ${(ratio * 100).round()}%'
        : totalLabel;
    return Semantics(
      label: title,
      value: '$label. $subtitle',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: text.titleSmall)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (usageKnown)
              RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : M3Durations.medium4,
                  curve: M3SpringCurves.expressiveDecel,
                  builder: (context, value, _) => SizedBox(
                    height: 8,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                          widthFactor: value,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (usageKnown) const SizedBox(height: 8),
            Text(
              subtitle,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
