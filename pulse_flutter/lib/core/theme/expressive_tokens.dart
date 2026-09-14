import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// Centralized Material 3 Expressive corner radii tokens.
abstract final class AppRadii {
  /// Small radius (12.0 dp): small badges, inline chips, tags, inner media previews.
  static const double sm = 12.0;

  /// Medium radius (20.0 dp): message bubbles, settings cards, input fields, modals.
  static const double md = 20.0;

  /// Large radius (28.0 dp): NiosGram post cards, dialogs, bottom sheets, hero containers.
  static const double lg = 28.0;

  /// Full pill radius (999.0 dp): action buttons, search bars, pill inputs, filter chips.
  static const double full = 999.0;

  // BorderRadius helpers
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius fullRadius = BorderRadius.all(Radius.circular(full));

  /// Dynamically resolved radii based on theme extension / user setting.
  static AppRadiiTheme of(BuildContext context) {
    return Theme.of(context).extension<AppRadiiTheme>() ??
        const AppRadiiTheme(sm: sm, md: md, lg: lg, full: full);
  }
}

/// Theme extension to propagate dynamic [uiCornerRadius] throughout widget tree.
@immutable
class AppRadiiTheme extends ThemeExtension<AppRadiiTheme> {
  const AppRadiiTheme({
    required this.sm,
    required this.md,
    required this.lg,
    required this.full,
  });

  factory AppRadiiTheme.fromCornerRadius(double cornerRadius) {
    final double factor = (cornerRadius / 20.0).clamp(0.4, 1.4);
    return AppRadiiTheme(
      sm: (12.0 * factor).clamp(6.0, 18.0),
      md: cornerRadius,
      lg: (28.0 * factor).clamp(16.0, 36.0),
      full: 999.0,
    );
  }

  final double sm;
  final double md;
  final double lg;
  final double full;

  BorderRadius get smRadius => BorderRadius.all(Radius.circular(sm));
  BorderRadius get mdRadius => BorderRadius.all(Radius.circular(md));
  BorderRadius get lgRadius => BorderRadius.all(Radius.circular(lg));
  BorderRadius get fullRadius => const BorderRadius.all(Radius.circular(999.0));

  @override
  AppRadiiTheme copyWith({double? sm, double? md, double? lg, double? full}) {
    return AppRadiiTheme(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      full: full ?? this.full,
    );
  }

  @override
  AppRadiiTheme lerp(ThemeExtension<AppRadiiTheme>? other, double t) {
    if (other is! AppRadiiTheme) return this;
    return AppRadiiTheme(
      sm: lerpDouble(sm, other.sm, t) ?? sm,
      md: lerpDouble(md, other.md, t) ?? md,
      lg: lerpDouble(lg, other.lg, t) ?? lg,
      full: 999.0,
    );
  }
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
