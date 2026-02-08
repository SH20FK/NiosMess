import 'package:flutter/material.dart';

/// Анимированный элемент списка с staggered появлением
class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 300),
    this.delay = const Duration(milliseconds: 50),
  });

  final Widget child;
  final int index;
  final Duration duration;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Анимированный ripple эффект для списка чатов (Telegram-style)
class ChatListItem extends StatelessWidget {
  const ChatListItem({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 16.0,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
        child: child,
      ),
    );
  }
}

/// Hero-анимация для аватаров
class HeroAvatar extends StatelessWidget {
  const HeroAvatar({
    super.key,
    required this.heroTag,
    required this.child,
    this.size = 46,
  });

  final String heroTag;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      transitionOnUserGestures: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: child),
      ),
    );
  }
}

/// Slide-переход между экранами (Telegram-style)
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  SlidePageRoute({
    required this.builder,
    this.direction = AxisDirection.right,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
        );

  final WidgetBuilder builder;
  final AxisDirection direction;
}

/// Fade-переход для модальных экранов
class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 200),
        );

  final WidgetBuilder builder;
}
