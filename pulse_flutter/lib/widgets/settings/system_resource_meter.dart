import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// A capacity measurement, not loading. The fill animates; labels stay truthful.
///
/// The row is tonal from end to end: the glyph sits in a `surfaceContainerHighest`
/// squircle, the track is the same tone and the fill takes `primary`. No shadow
/// and no outline, so it sits inside a settings group without a second
/// elevation step. The bar is always drawn — an unknown capacity shows an empty
/// track instead of a missing one, so the row does not change height when the
/// reading arrives late.
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppRadiiTheme radii = AppRadii.of(context);
    final bool available = total.isFinite && total > 0;
    final bool usageKnown = available && used != null && used!.isFinite;
    final double ratio = usageKnown ? (used! / total).clamp(0.0, 1.0) : 0.0;
    final int percent = (ratio * 100).round();
    final String totalLabel =
        '${total.toStringAsFixed(total == total.roundToDouble() ? 0 : 1)} $unit';
    final String label = !available
        ? unavailableLabel
        : usageKnown
        ? '${used!.clamp(0, total).toStringAsFixed(1)} / $totalLabel · $percent%'
        : totalLabel;
    // The caller passes the same fallback for the label and the hint when the
    // capacity is unknown; printing it twice would read as a stutter.
    final bool showSubtitle =
        subtitle.trim().isNotEmpty && subtitle.trim() != label.trim();
    final Radius barRadius = Radius.circular(radii.xs.clamp(4.0, 8.0));

    return Semantics(
      label: title,
      value: showSubtitle ? '$label. $subtitle' : label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: AppRadii.superellipse(radii.sm),
                  ),
                  child: SizedBox.square(
                    dimension: AppHeights.controlCompact,
                    child: Center(
                      child: Icon(
                        icon,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: text.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Only a measured capacity animates. An unknown one gets the same
            // empty track without a ticker, so the row keeps its height and
            // the figure never counts up from a placeholder.
            RepaintBoundary(
              child: SizedBox(
                height: 10,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.all(barRadius),
                  ),
                  child: usageKnown
                      ? TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: ratio),
                          duration: context.reduceMotion
                              ? Duration.zero
                              : M3Durations.medium4,
                          curve: M3SpringCurves.expressiveDecel,
                          builder:
                              (BuildContext context, double value, Widget? _) {
                                return Align(
                                  // The fill grows from the reading edge, so the
                                  // meter reads with the surrounding text.
                                  alignment: AlignmentDirectional.centerStart,
                                  child: FractionallySizedBox(
                                    widthFactor: value,
                                    heightFactor: 1,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        borderRadius: BorderRadius.all(
                                          barRadius,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                        )
                      : null,
                ),
              ),
            ),
            if (showSubtitle) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
