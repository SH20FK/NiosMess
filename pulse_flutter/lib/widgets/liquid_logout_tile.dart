import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

class LiquidLogoutTile extends StatefulWidget {
  const LiquidLogoutTile({
    required this.onLogout,
    required this.label,
    super.key,
  });

  final VoidCallback onLogout;
  final String label;

  @override
  State<LiquidLogoutTile> createState() => _LiquidLogoutTileState();
}

class _LiquidLogoutTileState extends State<LiquidLogoutTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown() {
    HapticService.tap();
    _controller.forward();
  }

  void _onPointerUp() {
    if (_controller.status == AnimationStatus.forward || _controller.status == AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final errorColor = scheme.error;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _onPointerDown(),
        onTapUp: (_) {
          _onPointerUp();
          widget.onLogout();
        },
        onTapCancel: _onPointerUp,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final fillPercent = Curves.easeOutCubic.transform(_controller.value);
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: _isHovered ? errorColor.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: errorColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Liquid Fill Background
                    if (fillPercent > 0)
                      Positioned(
                        left: -50,
                        top: -50,
                        bottom: -50,
                        child: Container(
                          width: MediaQuery.sizeOf(context).width * fillPercent * 1.5,
                          decoration: BoxDecoration(
                            color: errorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    // Content
                    Row(
                      children: [
                        Icon(
                          _controller.value > 0.5 ? Icons.door_front_door_rounded : Icons.meeting_room_rounded,
                          color: fillPercent > 0.5 ? scheme.onError : errorColor,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          widget.label,
                          style: textTheme.titleMedium?.copyWith(
                            color: fillPercent > 0.5 ? scheme.onError : errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
