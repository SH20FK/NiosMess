import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/services/desktop_pasteboard_service.dart';

/// Wraps chat content with desktop drag-and-drop file target and expressive visual cue.
class DesktopDragDropArea extends StatefulWidget {
  const DesktopDragDropArea({
    super.key,
    required this.child,
    required this.onFilesDropped,
  });

  final Widget child;
  final ValueChanged<List<String>> onFilesDropped;

  @override
  State<DesktopDragDropArea> createState() => _DesktopDragDropAreaState();
}

class _DesktopDragDropAreaState extends State<DesktopDragDropArea> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (!DesktopPasteboardService.isDesktop) {
      return widget.child;
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (DropEventDetails details) {
        setState(() => _isDragging = true);
      },
      onDragExited: (DropEventDetails details) {
        setState(() => _isDragging = false);
      },
      onDragDone: (DropDoneDetails details) {
        setState(() => _isDragging = false);
        final List<String> paths = details.files
            .map((DropItem file) => file.path)
            .where((String path) => path.isNotEmpty)
            .toList();
        if (paths.isNotEmpty) {
          widget.onFilesDropped(paths);
        }
      },
      child: Stack(
        children: <Widget>[
          widget.child,
          if (_isDragging)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: M3Durations.short4,
                  curve: M3SpringCurves.expressiveStandard,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: scheme.primary,
                      width: 2.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_upload_rounded,
                            size: 38,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Перетащите файлы сюда для отправки',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Файлы будут отправлены без сжатия',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
