import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/settings/pressable_surface.dart';
import 'package:pulse_flutter/widgets/settings/settings_group_scope.dart';

/// Release notes of the installed build on the «Что нового» tab.
///
/// Short notes render as they are. Notes taller than [_collapseThreshold]
/// are clipped to a [_previewLines]-line preview that fades into the card,
/// with a «show in full» row below; the tap opens the whole text on the
/// fast spatial spring. The fade is paint-only: it neither catches taps
/// nor shadows the text from a screen reader.
class AboutChangelogExpander extends StatefulWidget {
  const AboutChangelogExpander({required this.changes, super.key});

  final List<String> changes;

  @override
  State<AboutChangelogExpander> createState() => _AboutChangelogExpanderState();
}

class _AboutChangelogExpanderState extends State<AboutChangelogExpander> {
  /// Taller than this (~8 lines of body text plus row gaps) and the notes
  /// collapse into the preview; shorter ones never grow chrome they do not
  /// need.
  static const double _collapseThreshold = 200.0;

  /// Lines left visible in the collapsed preview; the fade sits on the last
  /// one, so three read clean and the fourth dissolves.
  static const int _previewLines = 4;

  /// Height of the gradient that dissolves the preview into the card.
  static const double _fadeHeight = 24.0;

  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle style =
        text.bodyMedium?.copyWith(height: 1.45) ??
        const TextStyle(height: 1.45);

    Widget notes() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final change in widget.changes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(change, style: style),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure instead of guessing: the same text, style, width and
        // scaler the real paragraphs get, so the threshold and the preview
        // window land exactly where the render does.
        final TextDirection direction = Directionality.of(context);
        final TextScaler scaler = MediaQuery.textScalerOf(context);
        double fullHeight = 0;
        double lineHeight = 0;
        for (final change in widget.changes) {
          final TextPainter painter = TextPainter(
            text: TextSpan(text: change, style: style),
            textDirection: direction,
            textScaler: scaler,
          )..layout(maxWidth: constraints.maxWidth);
          lineHeight = painter.preferredLineHeight;
          fullHeight += painter.height + AppSpacing.sm;
          // TextPainter holds native paragraph handles; free them before the
          // next one is built instead of leaking them per rebuild.
          painter.dispose();
        }
        if (fullHeight <= _collapseThreshold) return notes();

        final double previewHeight = lineHeight * _previewLines;
        final Duration duration = context.motionDuration(
          M3Durations.spatialFast,
        );
        final Color cardColor =
            SettingsGroupScope.maybeOf(context)?.color ??
            scheme.surfaceContainerLow;
        final String label = _expanded
            ? context.l10n.aboutChangelogShowLess
            : context.l10n.aboutChangelogShowMore;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AnimatedSize(
                  duration: duration,
                  curve: M3SpringCurves.spatialFast,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? SizedBox(
                          width: double.infinity,
                          child: notes(),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: previewHeight,
                          // The full text keeps its layout; only the window
                          // over it is small, so expanding is a reveal, not
                          // a reflow.
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight: 0,
                              maxHeight: double.infinity,
                              child: notes(),
                            ),
                          ),
                        ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _fadeHeight,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: AnimatedOpacity(
                        opacity: _expanded ? 0.0 : 1.0,
                        duration: context.motionDuration(
                          M3Durations.effectsFast,
                        ),
                        curve: M3SpringCurves.expressiveDecel,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                cardColor.withValues(alpha: 0),
                                cardColor,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              container: true,
              button: true,
              expanded: _expanded,
              label: label,
              onTap: _toggle,
              child: ExcludeSemantics(
                child: PressableSurface(
                  onTap: _toggle,
                  borderRadius: AppRadii.of(context).fullRadius,
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: ConstrainedBox(
                    // The text row is short; the box lifts the tap target to
                    // the 48 dp the surface promises.
                    constraints: const BoxConstraints(minHeight: 32),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: text.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: duration,
                          curve: M3SpringCurves.spatialFast,
                          child: Icon(
                            Icons.expand_more_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
