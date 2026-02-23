import 'package:flutter/material.dart';

/// Кастомные анимированные переходы между экранами
class AnimatedPageRoute {
  /// Fade Through transition (Material Design)
  static Route fadeThrough({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.easeInOut;

        final opacityTween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: curve));
        final scaleTween = Tween(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: curve));

        return FadeTransition(
          opacity: animation.drive(opacityTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Slide from right (iOS style)
  static Route slideFromRight({
    required Widget page,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Slide from bottom (Material style for modals)
  static Route slideFromBottom({
    required Widget page,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutQuart;

        final slideTween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: curve));
        final opacityTween = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(opacityTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Scale transition (for dialogs)
  static Route scale({
    required Widget page,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      opaque: false,
      barrierColor: Colors.black54,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutBack;

        final scaleTween = Tween(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: curve));
        final opacityTween = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn));

        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(
            opacity: animation.drive(opacityTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Rotation transition (creative effect)
  static Route rotation({
    required Widget page,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;

        final rotationTween = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: curve));
        final scaleTween = Tween(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: curve));

        return RotationTransition(
          turns: animation.drive(rotationTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Shared Axis (horizontal) - Material Design
  static Route sharedAxisHorizontal({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOut;

        // Входящая страница
        final incomingSlide = Tween(
          begin: const Offset(0.3, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: curve));

        final incomingFade = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: curve));

        // Исходящая страница
        final outgoingSlide = Tween(
          begin: Offset.zero,
          end: const Offset(-0.3, 0.0),
        ).chain(CurveTween(curve: curve));

        final outgoingFade = Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: curve));

        return Stack(
          children: [
            SlideTransition(
              position: secondaryAnimation.drive(outgoingSlide),
              child: FadeTransition(
                opacity: secondaryAnimation.drive(outgoingFade),
                child: Container(),
              ),
            ),
            SlideTransition(
              position: animation.drive(incomingSlide),
              child: FadeTransition(
                opacity: animation.drive(incomingFade),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Fade + Slide (elegant transition)
  static Route fadeSlide({
    required Widget page,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutQuart;

        final slideTween = Tween(
          begin: const Offset(0.0, 0.05),
          end: Offset.zero,
        ).chain(CurveTween(curve: curve));

        final opacityTween = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(opacityTween),
            child: child,
          ),
        );
      },
    );
  }
}

/// Extension для удобного использования
extension NavigatorAnimation on BuildContext {
  /// Навигация с fade through
  Future<T?> pushFadeThrough<T>(Widget page) {
    return Navigator.of(this).push(
      AnimatedPageRoute.fadeThrough(page: page),
    );
  }

  /// Навигация с slide from right
  Future<T?> pushSlideRight<T>(Widget page) {
    return Navigator.of(this).push(
      AnimatedPageRoute.slideFromRight(page: page),
    );
  }

  /// Навигация с slide from bottom
  Future<T?> pushSlideBottom<T>(Widget page) {
    return Navigator.of(this).push(
      AnimatedPageRoute.slideFromBottom(page: page),
    );
  }

  /// Навигация с scale
  Future<T?> pushScale<T>(Widget page) {
    return Navigator.of(this).push(
      AnimatedPageRoute.scale(page: page),
    );
  }

  /// Навигация с fade slide
  Future<T?> pushFadeSlide<T>(Widget page) {
    return Navigator.of(this).push(
      AnimatedPageRoute.fadeSlide(page: page),
    );
  }
}
