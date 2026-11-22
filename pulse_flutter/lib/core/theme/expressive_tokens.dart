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

/// Centralized Material 3 Expressive semantic component shapes.
abstract final class AppShape {
  /// Controls: buttons, input fields, segmented buttons (12.0 dp).
  static const double control = 12.0;

  /// Text fields, dropdowns, chips (16.0 dp).
  static const double field = 16.0;

  /// Cards, list groups, settings sections (20.0 dp).
  static const double card = 20.0;

  /// Dialogs and bottom sheet modals (24.0 dp).
  static const double dialog = 24.0;

  /// Media previews: thumbnails, image viewports, video tiles (16.0 dp).
  static const double media = 16.0;

  /// Message bubbles (20.0 dp).
  static const double bubble = 20.0;

  /// Pill: reserved strictly for chips, compact filter tags, and capsule status tags.
  static const StadiumBorder pill = StadiumBorder();

  static RoundedSuperellipseBorder controlBorder({BorderSide side = BorderSide.none}) =>
      AppRadii.superellipse(control, side: side);

  static RoundedSuperellipseBorder cardBorder({BorderSide side = BorderSide.none}) =>
      AppRadii.superellipse(card, side: side);

  static RoundedSuperellipseBorder dialogBorder({BorderSide side = BorderSide.none}) =>
      AppRadii.superellipse(dialog, side: side);

  static RoundedSuperellipseBorder mediaBorder({BorderSide side = BorderSide.none}) =>
      AppRadii.superellipse(media, side: side);
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

  double get card => lg;
  double get button => full;

  BorderRadius get xsRadius => BorderRadius.all(Radius.circular(xs));
  BorderRadius get smRadius => BorderRadius.all(Radius.circular(sm));
  BorderRadius get mdRadius => BorderRadius.all(Radius.circular(md));
  BorderRadius get lgRadius => BorderRadius.all(Radius.circular(lg));
  BorderRadius get xlRadius => BorderRadius.all(Radius.circular(xl));
  BorderRadius get fullRadius => const BorderRadius.all(Radius.circular(999.0));
  BorderRadius get cardRadius => lgRadius;
  BorderRadius get buttonRadius => fullRadius;

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

  /// Lowest window that still gets the list–detail split. A phone on its side
  /// is wide enough for two panes but too low to read either of them.
  static const double twoPaneMinHeight = 480.0;

  /// Whether a window of [size] shows the chat list and the open chat side by
  /// side. Every place that chooses between selecting a chat in the pane and
  /// pushing its route asks this, so they cannot disagree.
  static bool twoPane(Size size) =>
      size.width >= medium && size.height >= twoPaneMinHeight;

  /// Narrowest list of settings sections beside an open section.
  static const double settingsNavMinWidth = 300.0;

  /// Narrowest open settings section beside the list. Below this its forms
  /// are tighter than on a phone.
  static const double settingsDetailMinWidth = 560.0;

  /// Whether settings laid out in [area] show the section list and the open
  /// section side by side. [area] is what the settings get, with the app rail
  /// already taken out. One rule for Windows and the web.
  static bool settingsTwoPane(Size area) =>
      area.width >= settingsNavMinWidth + settingsDetailMinWidth &&
      area.height >= twoPaneMinHeight;
}

/// Canonical 4dp spacing scale. Use these instead of magic padding numbers so
/// every column (header, list rows, sheets) shares one rhythm.
abstract final class AppSpacing {
  /// 4.0 dp — hairline gap between an icon and its label.
  static const double xs = 4.0;

  /// 8.0 dp — gap between tightly related controls.
  static const double sm = 8.0;

  /// 12.0 dp — inner padding of compact rows and tiles.
  static const double md = 12.0;

  /// 16.0 dp — screen gutter, group padding.
  static const double lg = 16.0;

  /// 24.0 dp — section separation.
  static const double xl = 24.0;

  /// 32.0 dp — page-level breathing room.
  static const double xxl = 32.0;
}

/// Standardized component heights across the app.
abstract final class AppHeights {
  static const double sm = 40.0;
  static const double md = 48.0;
  static const double lg = 56.0;
  static const double xl = 64.0;

  /// Compact top app bar (single title line, dense toolbars): 56.0 dp.
  static const double appBarCompact = lg;

  /// Standard top app bar (M3 small app bar): 64.0 dp.
  static const double appBar = xl;

  /// Chat / inbox list row: 48dp avatar + 2×14dp vertical padding = 76.0 dp.
  static const double row = 76.0;

  /// Compact list row (dense desktop / small windows): 64.0 dp.
  static const double rowCompact = 64.0;

  /// Standard interactive control height (buttons, chips, search field): 40.0 dp.
  static const double control = sm;

  /// Compact interactive control used in dense toolbars: 36.0 dp.
  static const double controlCompact = 36.0;
}

/// Centralized motion tokens, springs, and press feedback parameters.
abstract final class AppMotion {
  /// Default spring curve for user-facing transitions and touches.
  static const Curve spring = M3SpringCurves.spatialFast;

  /// Tactile press scale down factor.
  static const double scalePressed = 0.975;

  /// Delay before triggering press scale to prevent accidental activations during scroll gestures.
  static const Duration pressTimeout = Duration(milliseconds: 90);

  /// Standard duration for press scale animations.
  static const Duration durationPress = M3Durations.effectsFast;

  /// Curve of the press-down compression; never overshoots.
  static const Curve pressCurve = M3SpringCurves.effectsFast;

  /// Standard duration for release spring animations.
  static const Duration durationRelease = M3Durations.spatialFast;
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
