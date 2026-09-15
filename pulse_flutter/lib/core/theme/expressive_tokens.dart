import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Centralized Material 3 Expressive corner radii tokens (7-step canonical scale).
abstract final class AppRadii {
  /// Zero radius (0.0 dp)
  static const double none = 0.0;

  /// Extra small radius (4.0 dp)
  static const double xs = 4.0;

  /// Small radius (8.0 dp): small badges, inline chips, tags.
  static const double sm = 8.0;

  /// Medium radius (12.0 dp): message bubbles, inputs, small cards.
  static const double md = 12.0;

  /// Large radius (16.0 dp): cards, settings tiles, dialogs, bottom sheets.
  static const double lg = 16.0;

  /// Extra large radius (28.0 dp): NiosGram post cards, modal hero sheets.
  static const double xl = 28.0;

  /// Full pill radius (999.0 dp): action buttons, search bars, pill inputs.
  static const double full = 999.0;

  // BorderRadius helpers
  static const BorderRadius noneRadius = BorderRadius.zero;
  static const BorderRadius xsRadius = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullRadius = BorderRadius.all(Radius.circular(full));

  // RoundedSuperellipseBorder helpers
  static RoundedSuperellipseBorder superellipse(
    double radius, {
    BorderSide side = BorderSide.none,
  }) =>
      RoundedSuperellipseBorder(
        side: side,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      );

  static RoundedSuperellipseBorder xsSuperellipse({BorderSide side = BorderSide.none}) =>
      superellipse(xs, side: side);
  static RoundedSuperellipseBorder smSuperellipse({BorderSide side = BorderSide.none}) =>
      superellipse(sm, side: side);
  static RoundedSuperellipseBorder mdSuperellipse({BorderSide side = BorderSide.none}) =>
      superellipse(md, side: side);
  static RoundedSuperellipseBorder lgSuperellipse({BorderSide side = BorderSide.none}) =>
      superellipse(lg, side: side);
  static RoundedSuperellipseBorder xlSuperellipse({BorderSide side = BorderSide.none}) =>
      superellipse(xl, side: side);

  /// Dynamically resolved radii based on theme extension / user setting.
  static AppRadiiTheme of(BuildContext context) {
    return Theme.of(context).extension<AppRadiiTheme>() ??
        const AppRadiiTheme(xs: xs, sm: sm, md: md, lg: lg, xl: xl, full: full);
  }
}

/// Theme extension to propagate dynamic [uiCornerRadius] throughout widget tree.
@immutable
class AppRadiiTheme extends ThemeExtension<AppRadiiTheme> {
  const AppRadiiTheme({
    this.xs = 4.0,
    required this.sm,
    required this.md,
    required this.lg,
    this.xl = 28.0,
    required this.full,
  });

  factory AppRadiiTheme.fromCornerRadius(double cornerRadius) {
    final double factor = (cornerRadius / 20.0).clamp(0.4, 1.4);
    return AppRadiiTheme(
      xs: (4.0 * factor).clamp(2.0, 6.0),
      sm: (8.0 * factor).clamp(4.0, 12.0),
      md: (12.0 * factor).clamp(8.0, 18.0),
      lg: cornerRadius,
      xl: (28.0 * factor).clamp(18.0, 36.0),
      full: 999.0,
    );
  }

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  BorderRadius get xsRadius => BorderRadius.all(Radius.circular(xs));
  BorderRadius get smRadius => BorderRadius.all(Radius.circular(sm));
  BorderRadius get mdRadius => BorderRadius.all(Radius.circular(md));
  BorderRadius get lgRadius => BorderRadius.all(Radius.circular(lg));
  BorderRadius get xlRadius => BorderRadius.all(Radius.circular(xl));
  BorderRadius get fullRadius => const BorderRadius.all(Radius.circular(999.0));

  RoundedSuperellipseBorder get mdSuperellipse =>
      RoundedSuperellipseBorder(borderRadius: mdRadius);
  RoundedSuperellipseBorder get lgSuperellipse =>
      RoundedSuperellipseBorder(borderRadius: lgRadius);
  RoundedSuperellipseBorder get xlSuperellipse =>
      RoundedSuperellipseBorder(borderRadius: xlRadius);

  @override
  AppRadiiTheme copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? full,
  }) {
    return AppRadiiTheme(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      full: full ?? this.full,
    );
  }

  @override
  AppRadiiTheme lerp(ThemeExtension<AppRadiiTheme>? other, double t) {
    if (other is! AppRadiiTheme) return this;
    return AppRadiiTheme(
      xs: lerpDouble(xs, other.xs, t) ?? xs,
      sm: lerpDouble(sm, other.sm, t) ?? sm,
      md: lerpDouble(md, other.md, t) ?? md,
      lg: lerpDouble(lg, other.lg, t) ?? lg,
      xl: lerpDouble(xl, other.xl, t) ?? xl,
      full: 999.0,
    );
  }
}

/// Canonical Material 3 responsive layout breakpoints.
abstract final class Breakpoints {
  /// Phone in portrait: bottom navigation bar (< 600 dp).
  static const double compact = 600.0;

  /// Foldable, tablet in portrait: compact navigation rail (600..839 dp).
  static const double medium = 840.0;

  /// Tablet in landscape, desktop window: navigation rail + list-detail panes (840..1199 dp).
  static const double expanded = 1200.0;

  /// Large desktop, 4K canvas: expanded rail with permanent drawer (>= 1600 dp).
  static const double large = 1600.0;
}

/// Standardized component heights across the app.
abstract final class AppHeights {
  static const double sm = 40.0;
  static const double md = 48.0;
  static const double lg = 56.0;
  static const double xl = 64.0;
}

/// Centralized motion tokens, springs, and press feedback parameters.
abstract final class AppMotion {
  /// Default spring curve for user-facing transitions and touches.
  static const Curve spring = M3SpringCurves.spatial;

  /// Expressive spatial curve from M3 specifications.
  static const Curve spatial = M3SpringCurves.spatial;

  /// Emphasized curve for prominent reveals and hero elements.
  static const Curve emphasized = M3SpringCurves.emphasized;

  /// Snappy curve for quick tactile responses.
  static const Curve snappy = M3SpringCurves.snappy;

  /// Bouncy curve for playful feedback (badges, switches, reactions).
  static const Curve bouncy = M3SpringCurves.bouncy;

  /// Tactile press scale down factor.
  static const double scalePressed = 0.975;

  /// Delay before triggering press scale to prevent accidental activations during scroll gestures.
  static const Duration pressTimeout = Duration(milliseconds: 90);

  /// Standard duration for press scale animations.
  static const Duration durationPress = Duration(milliseconds: 140);

  /// Standard duration for release spring animations.
  static const Duration durationRelease = Duration(milliseconds: 240);
}

/// Position of a message within a message cluster/group.
enum MessageBubblePosition {
  /// Standalone single message.
  single,

  /// First message in a consecutive group from the same sender.
  top,

  /// Middle message in a consecutive group.
  middle,

  /// Last message in a consecutive group (has speech bubble tail).
  bottom,
}

/// Deterministic, clean bubble radius calculation based on sender side and cluster position.
BorderRadius getBubbleRadius({
  required bool isOutgoing,
  required MessageBubblePosition position,
  double baseRadius = AppRadii.md,
}) {
  final Radius rLg = Radius.circular(baseRadius);
  final Radius rSm = Radius.circular((baseRadius * 0.6).clamp(8.0, 16.0));
  const Radius rXs = Radius.circular(6.0); // cluster tight chain link

  if (isOutgoing) {
    return BorderRadius.only(
      topLeft: rLg,
      bottomLeft: rLg,
      topRight: (position == MessageBubblePosition.middle ||
              position == MessageBubblePosition.bottom)
          ? rXs
          : rLg,
      bottomRight: (position == MessageBubblePosition.single ||
              position == MessageBubblePosition.bottom)
          ? rSm
          : rXs,
    );
  } else {
    return BorderRadius.only(
      topRight: rLg,
      bottomRight: rLg,
      topLeft: (position == MessageBubblePosition.middle ||
              position == MessageBubblePosition.bottom)
          ? rXs
          : rLg,
      bottomLeft: (position == MessageBubblePosition.single ||
              position == MessageBubblePosition.bottom)
          ? rSm
          : rXs,
    );
  }
}
