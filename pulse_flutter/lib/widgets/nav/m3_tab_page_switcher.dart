import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/nav/m3_route_tab_switcher.dart';

export 'package:pulse_flutter/widgets/nav/m3_route_tab_switcher.dart';

/// Legacy adapter for [M3RouteTabSwitcher].
class M3TabPageSwitcher extends StatelessWidget {
  const M3TabPageSwitcher({
    required this.index,
    required this.children,
    this.controller,
    this.animate = true,
    this.slideDistance,
    this.duration,
    this.onTransitionStateChanged,
    super.key,
  });

  final int index;
  final List<Widget> children;
  final TabTransitionController? controller;
  final bool animate;
  final double? slideDistance;
  final Duration? duration;
  final ValueChanged<bool>? onTransitionStateChanged;

  @override
  Widget build(BuildContext context) {
    return M3RouteTabSwitcher(
      index: index,
      controller: controller,
      animate: animate,
      slideDistance: slideDistance,
      duration: duration,
      onTransitionStateChanged: onTransitionStateChanged,
      children: children,
    );
  }
}
