import 'package:flutter/material.dart';

/// LiquidPullRefresh - упрощенный pull-to-refresh с анимацией
/// Фича #1: Liquid Pull-to-Refresh (упрощенная версия)
/// 
/// Использование:
/// ```dart
/// LiquidPullRefresh(
///   onRefresh: () async => await loadData(),
///   child: ListView(...),
/// )
/// ```
class LiquidPullRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? indicatorColor;
  final double indicatorSize;
  final double triggerDistance;

  const LiquidPullRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.indicatorColor,
    this.indicatorSize = 40.0,
    this.triggerDistance = 100.0,
  });

  @override
  State<LiquidPullRefresh> createState() => _LiquidPullRefreshState();
}

class _LiquidPullRefreshState extends State<LiquidPullRefresh>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (_isRefreshing) return;
    _dragOffset = 0.0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isRefreshing) return;
    if (details.delta.dy > 0) {
      setState(() {
        _dragOffset += details.delta.dy;
        _dragOffset = _dragOffset.clamp(0.0, widget.triggerDistance * 1.5);
      });
      
      final progress = (_dragOffset / widget.triggerDistance).clamp(0.0, 1.0);
      _controller.value = progress;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isRefreshing) return;
    
    if (_dragOffset >= widget.triggerDistance) {
      _startRefresh();
    } else {
      _resetPosition();
    }
  }

  void _startRefresh() {
    setState(() => _isRefreshing = true);
    _controller.animateTo(1.0);
    
    widget.onRefresh().then((_) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _resetPosition();
      }
    });
  }

  void _resetPosition() {
    _controller.animateTo(0.0, duration: const Duration(milliseconds: 200));
    setState(() => _dragOffset = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.indicatorColor ?? theme.colorScheme.primary;

    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: -widget.indicatorSize + (_dragOffset * 0.8),
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final scale = 0.5 + (_controller.value * 0.5);
                  final opacity = _controller.value;
                  
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: widget.indicatorSize,
                        height: widget.indicatorSize,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _isRefreshing
                              ? SizedBox(
                                  width: widget.indicatorSize * 0.5,
                                  height: widget.indicatorSize * 0.5,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_downward,
                                  color: color,
                                  size: widget.indicatorSize * 0.4,
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
