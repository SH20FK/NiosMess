import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

/// Placeholder rows for a settings group that is still loading.
///
/// The blocks sit exactly where the real rows land — a squircle icon tile and
/// two label lines — so the group does not jump when data arrives. One
/// controller drives every block, so they breathe together; under reduced
/// motion the pulse is dropped and the blocks stay fully opaque.
///
/// ```dart
/// SettingsAsyncSwitcher(
///   value: form,
///   loading: () => const SettingsSkeleton(rows: 3),
///   data: (data) => _Form(data),
///   error: (_, _) => SettingsErrorSection(...),
/// )
/// ```
class SettingsSkeleton extends StatefulWidget {
  const SettingsSkeleton({
    this.rows = 3,
    this.showLeading = true,
    this.animate = true,
    this.label,
    super.key,
  });

  /// Number of placeholder rows. Keep it to the height of the loaded group.
  final int rows;

  /// Draw the squircle icon tile of each row.
  final bool showLeading;

  /// Breathe. Ignored under reduced motion, where the blocks stay at rest.
  final bool animate;

  /// What a screen reader announces instead of the blocks. Defaults to the
  /// shared loading string.
  final String? label;

  @override
  State<SettingsSkeleton> createState() => _SettingsSkeletonState();
}

class _SettingsSkeletonState extends State<SettingsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..addStatusListener(_onStatus);

  late final Animation<double> _opacity = Tween<double>(
    begin: 1.0,
    end: 0.55,
  ).animate(CurvedAnimation(parent: _pulse, curve: M3SpringCurves.effectsDefault));

  bool _reduceMotion = false;

  void _onStatus(AnimationStatus status) {
    if (_reduceMotion || !mounted || !widget.animate) return;
    if (status == AnimationStatus.completed) {
      _pulse.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _pulse.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = context.reduceMotion || !widget.animate;
    if (_reduceMotion) {
      // No ticking decoration when there is nothing to animate: the rows are
      // still legible at rest.
      _pulse.stop();
      _pulse.value = 0.0;
    } else if (!_pulse.isAnimating) {
      _pulse.forward();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color block = scheme.surfaceContainerHighest;
    final double radius = AppRadii.of(context).md;
    return Semantics(
      container: true,
      label: widget.label ?? context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _opacity,
            builder: (BuildContext context, Widget? child) => Opacity(
              opacity: _reduceMotion ? 1.0 : _opacity.value,
              child: child,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var row = 0; row < widget.rows; row++) ...<Widget>[
                  if (row != 0) const SizedBox(height: 2),
                  _SkeletonRow(
                    block: block,
                    radius: radius,
                    showLeading: widget.showLeading,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({
    required this.block,
    required this.radius,
    required this.showLeading,
  });

  final Color block;
  final double radius;
  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => DecoratedBox(
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.all(Radius.circular(radius / 2)),
      ),
      child: SizedBox(width: width, height: height),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppHeights.rowCompact),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            if (showLeading) ...[
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: block,
                  shape: AppRadii.superellipse(radius),
                ),
                child: SizedBox.square(dimension: AppHeights.sm),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: .52,
                    child: bar(double.infinity, 14),
                  ),
                  const SizedBox(height: 6),
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: .78,
                    child: bar(double.infinity, 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
