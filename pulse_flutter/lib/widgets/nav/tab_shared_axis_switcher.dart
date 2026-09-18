import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/nav/m3_tab_page_switcher.dart';

export 'package:pulse_flutter/widgets/nav/m3_tab_page_switcher.dart';

/// Legacy alias for [M3TabPageSwitcher].
class TabSharedAxisSwitcher extends StatelessWidget {
  const TabSharedAxisSwitcher({
    required this.index,
    required this.children,
    required this.controller,
    this.animate = true,
    this.shift = 0.14,
    this.duration = M3Durations.medium1,
    super.key,
  });

  final int index;
  final List<Widget> children;
  final TabTransitionController controller;
  final bool animate;
  final double shift;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return M3TabPageSwitcher(
      index: index,
      controller: controller,
      animate: animate,
      duration: duration,
      children: children,
    );
  }
}
