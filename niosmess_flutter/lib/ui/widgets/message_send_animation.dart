import 'package:flutter/material.dart';

/// Анимация отправки сообщения
class MessageSendAnimation extends StatefulWidget {
  final Widget child;
  final bool isSent;
  final VoidCallback? onEnd;

  const MessageSendAnimation({
    super.key,
    required this.child,
    this.isSent = false,
    this.onEnd,
  });

  @override
  State<MessageSendAnimation> createState() => _MessageSendAnimationState();
}

class _MessageSendAnimationState extends State<MessageSendAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isSent) {
      _playAnimation();
    }
  }

  @override
  void didUpdateWidget(MessageSendAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isSent && widget.isSent) {
      _playAnimation();
    }
  }

  void _playAnimation() {
    _controller.forward().then((_) {
      if (widget.onEnd != null) {
        widget.onEnd!();
      }
    });
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
        return Transform.scale(
          scale: widget.isSent ? _scaleAnimation.value : 1.0,
          child: Opacity(
            opacity: widget.isSent ? _opacityAnimation.value : 1.0,
            child: widget.child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Виджет индикатора отправки сообщения
class MessageSendIndicator extends StatelessWidget {
  final bool isSending;
  final bool isDelivered;
  final bool isRead;
  final double size;

  const MessageSendIndicator({
    super.key,
    this.isSending = false,
    this.isDelivered = false,
    this.isRead = false,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    
    if (isSending) {
      color = Theme.of(context).colorScheme.primary.withOpacity(0.7);
    } else if (isRead) {
      color = Theme.of(context).colorScheme.primary;
    } else if (isDelivered) {
      color = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    IconData icon = Icons.access_time; // Отправка
    if (isDelivered && !isRead) {
      icon = Icons.done; // Доставлено
    } else if (isRead) {
      icon = Icons.done_all; // Прочитано
    }

    return Icon(
      icon,
      size: size,
      color: color,
    );
  }
}

/// Анимированный чек для статуса сообщения
class AnimatedMessageStatus extends StatefulWidget {
  final bool isSent;
  final bool isDelivered;
  final bool isRead;
  final Duration duration;

  const AnimatedMessageStatus({
    super.key,
    this.isSent = false,
    this.isDelivered = false,
    this.isRead = false,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedMessageStatus> createState() => _AnimatedMessageStatusState();
}

class _AnimatedMessageStatusState extends State<AnimatedMessageStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedMessageStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.isSent != widget.isSent ||
        oldWidget.isDelivered != widget.isDelivered ||
        oldWidget.isRead != widget.isRead) &&
        _controller.isCompleted) {
      _controller.reset();
      _controller.forward();
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
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: MessageSendIndicator(
            isSending: !widget.isSent,
            isDelivered: widget.isDelivered,
            isRead: widget.isRead,
          ),
        );
      },
    );
  }
}