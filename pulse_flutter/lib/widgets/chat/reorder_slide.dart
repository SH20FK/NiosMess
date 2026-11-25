import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart' show SingleMotionController;
import 'package:pulse_flutter/core/motion/m3_motion.dart';

/// Slides a list row from its previous slot into the new one when its [index]
/// changes, e.g. a chat that jumps to the top on a new message.
///
/// Only rows that stay mounted animate. A change of [scope] (another filter
/// or folder) repositions the rows without motion.
class ReorderSlide extends StatefulWidget {
  const ReorderSlide({
    required this.index,
    required this.child,
    this.scope,
    this.gap = 0.0,
    super.key,
  });

  /// Position of the row in its list.
  final int index;
  final Widget child;

  /// Identity of the list the row belongs to.
  final Object? scope;

  /// Space between two neighbouring rows, added to the row height.
  final double gap;

  @override
  State<ReorderSlide> createState() => _ReorderSlideState();
}

class _ReorderSlideState extends State<ReorderSlide>
    with SingleTickerProviderStateMixin {
  /// Vertical offset from the row's slot in logical pixels.
  late final SingleMotionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SingleMotionController(
      motion: M3Motion.spatialDefault,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant ReorderSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _controller.stop(canceled: true);
      _controller.value = 0.0;
      return;
    }
    final int moved = oldWidget.index - widget.index;
    if (moved == 0 || context.reduceMotion) return;
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    // A row never flies in from further than one screen away.
    final double limit = MediaQuery.sizeOf(context).height;
    final double from =
        _controller.value + moved * (box.size.height + widget.gap);
    // Start where the row was drawn a frame ago; a retarget mid-flight keeps
    // the current velocity.
    _controller.value = from.clamp(-limit, limit);
    _controller.springTo(0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => Transform.translate(
        offset: Offset(0.0, _controller.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}
