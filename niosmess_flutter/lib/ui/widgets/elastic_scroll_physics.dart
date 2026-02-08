import 'package:flutter/material.dart';

/// ElasticScrollPhysics - пружинная физика прокрутки
/// Фича #8: Elastic List Physics
/// 
/// Использование:
/// ```dart
/// ListView.builder(
///   physics: const ElasticScrollPhysics(),
///   itemBuilder: ...
/// )
/// ```
class ElasticScrollPhysics extends BouncingScrollPhysics {
  const ElasticScrollPhysics({super.parent});
  
  /// Коэффициент упругости (0.0 - 1.0)
  /// Чем меньше значение, тем сильнее "пружинит"
  final double elasticity = 0.65;
  
  /// Максимальное растяжение при overscroll
  final double maxOverscroll = 120.0;

  @override
  ElasticScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ElasticScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double frictionFactor(double overscrollFraction) {
    // Усиленное трение для более выраженного эффекта
    return 0.25 * overscrollFraction * (1.0 / elasticity);
  }

  @override
  SpringDescription get spring {
    // Кастомная пружина для эффекта "отскока"
    return SpringDescription.withDampingRatio(
      mass: 0.4,
      stiffness: 180.0,
      ratio: 0.7, // damping ratio
    );
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

/// ElasticScrollBehavior - применяет ElasticScrollPhysics ко всем скроллам
/// 
/// Использование:
/// ```dart
/// MaterialApp(
///   scrollBehavior: ElasticScrollBehavior(),
///   ...
/// )
/// ```
class ElasticScrollBehavior extends ScrollBehavior {
  const ElasticScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ElasticScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Убираем стандартный glow эффект для чистого elastic эффекта
    return child;
  }
}
