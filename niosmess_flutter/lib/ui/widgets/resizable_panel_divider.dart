import 'package:flutter/material.dart';

/// A draggable 6px vertical divider that allows resizing two adjacent panels.
/// Provides a resize cursor and visual hover highlight.
class ResizablePanelDivider extends StatefulWidget {
  final void Function(double delta) onResize;
  final VoidCallback? onResizeEnd;

  const ResizablePanelDivider({
    super.key,
    required this.onResize,
    this.onResizeEnd,
  });

  @override
  State<ResizablePanelDivider> createState() => _ResizablePanelDividerState();
}

class _ResizablePanelDividerState extends State<ResizablePanelDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = _isHovered || _isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          widget.onResize(details.delta.dx);
        },
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          widget.onResizeEnd?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 6,
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
