import 'package:flutter/material.dart';

/// DynamicIsland - уведомления в стиле iPhone Dynamic Island
/// Фича #10: Dynamic Island Notifications
/// 
/// Анимации: Expand, Contract, Bounce
class DynamicIsland extends StatefulWidget {
  final Widget child;
  final DynamicIslandState state;
  final Duration animationDuration;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const DynamicIsland({
    super.key,
    required this.child,
    this.state = DynamicIslandState.compact,
    this.animationDuration = const Duration(milliseconds: 300),
    this.onTap,
    this.onDismiss,
  });

  @override
  State<DynamicIsland> createState() => _DynamicIslandState();
}

class _DynamicIslandState extends State<DynamicIsland>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _updateState();
  }

  @override
  void didUpdateWidget(DynamicIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateState();
    }
  }

  void _updateState() {
    switch (widget.state) {
      case DynamicIslandState.compact:
        _controller.animateTo(0.0);
        break;
      case DynamicIslandState.expanded:
        _controller.animateTo(1.0);
        break;
      case DynamicIslandState.minimal:
        _controller.animateTo(0.3);
        break;
    }
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
      builder: (context, child) {
        final width = 120.0 + (_controller.value * 200);
        final height = 36.0 + (_controller.value * 80);
        final borderRadius = 18.0 + (_controller.value * 12);

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

enum DynamicIslandState {
  minimal,   // Минимальный размер (только индикатор)
  compact,   // Компактный (стандартный)
  expanded,  // Развернутый (с контентом)
}

/// DynamicIslandNotification - готовый виджет уведомления
class DynamicIslandNotification extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final DynamicIslandState state;
  final VoidCallback? onTap;

  const DynamicIslandNotification({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.state = DynamicIslandState.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DynamicIsland(
      state: state,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            if (title != null)
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
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

/// DynamicIslandController - контроллер для управления уведомлениями
class DynamicIslandController extends ChangeNotifier {
  DynamicIslandState _state = DynamicIslandState.compact;
  Widget? _content;

  DynamicIslandState get state => _state;
  Widget? get content => _content;

  void showCompact(Widget content) {
    _content = content;
    _state = DynamicIslandState.compact;
    notifyListeners();
  }

  void expand() {
    _state = DynamicIslandState.expanded;
    notifyListeners();
  }

  void compact() {
    _state = DynamicIslandState.compact;
    notifyListeners();
  }

  void minimize() {
    _state = DynamicIslandState.minimal;
    notifyListeners();
  }

  void hide() {
    _content = null;
    _state = DynamicIslandState.compact;
    notifyListeners();
  }
}
