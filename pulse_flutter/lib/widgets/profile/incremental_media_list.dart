import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A bounded column for a section embedded in an existing scroll view.
/// Only a small prefix is mounted until its end reaches the viewport.
class IncrementalMediaList extends StatefulWidget {
  const IncrementalMediaList({
    required this.itemCount,
    required this.itemBuilder,
    this.batchSize = 8,
    super.key,
  }) : assert(batchSize > 0);

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int batchSize;

  @override
  State<IncrementalMediaList> createState() => _IncrementalMediaListState();
}

class _IncrementalMediaListState extends State<IncrementalMediaList> {
  late int _limit = widget.batchSize;
  final _sentinelKey = GlobalKey();
  ScrollPosition? _position;
  bool _checkScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_scheduleCheck);
      _position = position;
      position?.addListener(_scheduleCheck);
    }
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(covariant IncrementalMediaList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_checkScheduled || _limit >= widget.itemCount) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted ||
          _limit >= widget.itemCount ||
          !TickerMode.valuesOf(context).enabled) {
        return;
      }
      final box = _sentinelKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      var viewport = Offset.zero & MediaQuery.sizeOf(context);
      RenderObject? ancestor = box.parent;
      while (ancestor != null) {
        if (ancestor is RenderOffstage && ancestor.offstage) return;
        if (ancestor is RenderAbstractViewport && ancestor is RenderBox) {
          final viewportBox = ancestor as RenderBox;
          if (viewportBox.hasSize) {
            viewport = viewport.intersect(
              viewportBox.localToGlobal(Offset.zero) & viewportBox.size,
            );
          }
        }
        ancestor = ancestor.parent;
      }
      // Start the next small batch just before the marker reaches the edge;
      // this also avoids rounding and overscroll clipping at the exact boundary.
      const preloadExtent = 96.0;
      if (bounds.right <= viewport.left ||
          bounds.left >= viewport.right ||
          bounds.bottom < viewport.top - preloadExtent ||
          bounds.top > viewport.bottom + preloadExtent) {
        return;
      }
      setState(
        () => _limit = math.min(_limit + widget.batchSize, widget.itemCount),
      );
      _scheduleCheck();
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleCheck);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = math.min(_limit, widget.itemCount);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < visibleCount; index++)
          widget.itemBuilder(context, index),
        if (visibleCount < widget.itemCount)
          SizedBox(key: _sentinelKey, width: double.infinity, height: 4),
      ],
    );
  }
}
