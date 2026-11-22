import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Pull-to-refresh that shows the M3 Expressive loading indicator instead of
/// the Material circular spinner.
///
/// [RefreshIndicator.noSpinner] keeps the gesture logic; this widget only
/// draws the indicator. It follows the pull, holds while the refresh runs and
/// fades out when it ends.
class AppRefreshIndicator extends StatefulWidget {
  const AppRefreshIndicator({
    required this.onRefresh,
    required this.child,
    this.displacement = 24.0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    super.key,
  });

  final RefreshCallback onRefresh;
  final Widget child;

  /// Distance from the top edge at which the indicator rests.
  final double displacement;
  final ScrollNotificationPredicate notificationPredicate;

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator>
    with SingleTickerProviderStateMixin {
  static const double _size = 40.0;

  RefreshIndicatorStatus? _status;

  /// Pull distance, counted the way [RefreshIndicator] counts it.
  double _distance = 0.0;

  /// How far the indicator is revealed, from 0 to 1. It follows the pull
  /// during a drag and is animated otherwise. At 0 the indicator is not
  /// built, so nothing ticks at rest.
  late final AnimationController _reveal;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this);
    _scale = _reveal.drive(Tween<double>(begin: 0.6, end: 1.0));
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  // RefreshIndicator does not report the switch to `refresh` or the final
  // reset to null, so `snap` holds the indicator until `done`.
  void _onStatus(RefreshIndicatorStatus? status) {
    if (!mounted) return;
    _status = status;
    final bool reduceMotion = context.reduceMotion;
    switch (status) {
      case RefreshIndicatorStatus.drag:
        _distance = 0.0;
        _reveal.value = 0.0;
      case RefreshIndicatorStatus.armed:
      case RefreshIndicatorStatus.snap:
      case RefreshIndicatorStatus.refresh:
        _reveal.animateTo(
          1.0,
          duration: reduceMotion ? Duration.zero : M3Durations.effectsFast,
          curve: M3SpringCurves.effectsFast,
        );
      case RefreshIndicatorStatus.done:
      case RefreshIndicatorStatus.canceled:
      case null:
        _reveal.animateBack(
          0.0,
          duration: reduceMotion ? Duration.zero : M3Durations.effectsDefault,
          curve: M3SpringCurves.effectsDefault,
        );
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) return false;
    // Once armed the indicator is held open and stops following the finger.
    if (_status != RefreshIndicatorStatus.drag) return false;
    final double delta;
    if (notification is ScrollUpdateNotification) {
      delta = notification.scrollDelta ?? 0.0;
    } else if (notification is OverscrollNotification) {
      delta = notification.overscroll;
    } else {
      return false;
    }
    final ScrollMetrics metrics = notification.metrics;
    _distance += metrics.axisDirection == AxisDirection.up ? delta : -delta;
    // RefreshIndicator arms after a sixth of the viewport.
    final double armDistance = metrics.viewportDimension / 6.0;
    _reveal.value = armDistance <= 0.0
        ? 0.0
        : (_distance / armDistance).clamp(0.0, 1.0);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Stack(
      children: <Widget>[
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: RefreshIndicator.noSpinner(
            onRefresh: widget.onRefresh,
            onStatusChange: _onStatus,
            notificationPredicate: widget.notificationPredicate,
            child: widget.child,
          ),
        ),
        Positioned(
          top: widget.displacement,
          left: 0.0,
          right: 0.0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (BuildContext context, Widget? child) =>
                  _reveal.value <= 0.0 ? const SizedBox.shrink() : child!,
              child: FadeTransition(
                opacity: _reveal,
                child: ScaleTransition(
                  scale: _scale,
                  child: Center(
                    child: Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: AppLoadingIndicator(
                        size: 28.0,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
