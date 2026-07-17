import 'package:flutter/material.dart';

class ThreeDLongPressHandler extends StatefulWidget {
  const ThreeDLongPressHandler({
    required this.child,
    required this.onLongPress,
    this.onReply,
    this.onCopy,
    this.onForward,
    super.key,
  });

  final Widget child;
  final VoidCallback onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onCopy;
  final VoidCallback? onForward;

  @override
  State<ThreeDLongPressHandler> createState() => _ThreeDLongPressHandlerState();
}

class _ThreeDLongPressHandlerState extends State<ThreeDLongPressHandler>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _blur;
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _blur = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLongPress() {
    widget.onLongPress();
    setState(() => _showActions = true);
    _controller.forward();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) setState(() => _showActions = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: _onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001 * _scale.value)
                  ..scale(_scale.value, _scale.value, 1),
                child: child,
              );
            },
            child: widget.child,
          ),
          if (_showActions)
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismiss,
                child: AnimatedBuilder(
                  animation: _blur,
                  builder: (context, child) {
                    if (_blur.value <= 0) return const SizedBox.shrink();
                    return BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: _blur.value,
                        sigmaY: _blur.value,
                      ),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_showActions)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ActionBar(
                scheme: scheme,
                onReply: widget.onReply,
                onCopy: widget.onCopy,
                onForward: widget.onForward,
                onDismiss: _dismiss,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.scheme,
    this.onReply,
    this.onCopy,
    this.onForward,
    required this.onDismiss,
  });

  final ColorScheme scheme;
  final VoidCallback? onReply;
  final VoidCallback? onCopy;
  final VoidCallback? onForward;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (onReply != null)
            _ActionButton(
              icon: Icons.reply_rounded,
              label: 'Reply',
              color: scheme.primary,
              onTap: () { onDismiss(); onReply!(); },
            ),
          if (onCopy != null)
            _ActionButton(
              icon: Icons.copy_rounded,
              label: 'Copy',
              color: scheme.secondary,
              onTap: () { onDismiss(); onCopy!(); },
            ),
          if (onForward != null)
            _ActionButton(
              icon: Icons.forward_rounded,
              label: 'Forward',
              color: scheme.tertiary,
              onTap: () { onDismiss(); onForward!(); },
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
