import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

/// Comprehensive vector illustration library for NiosMess.
///
/// Provides responsive, theme-tintable, and animated vector components for empty states,
/// media viewport placeholders, error fallbacks, and settings domain badges.

// ── 1. Empty Feed Illustration ─────────────────────────────────────────

/// A rich, multi-layered vector illustration displayed when feeds or lists are empty.
class EmptyFeedIllustration extends StatelessWidget {
  const EmptyFeedIllustration({
    super.key,
    this.size = 180,
    this.primaryColor,
    this.accentColor,
    this.animate = true,
  });

  /// Overall square dimension of the illustration.
  final double size;

  /// Primary tint color for the card and foreground elements. Defaults to [ColorScheme.primary].
  final Color? primaryColor;

  /// Accent tint color for background glow and highlights. Defaults to [ColorScheme.secondary].
  final Color? accentColor;

  /// Whether to play a gentle breathing float animation.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color primary = primaryColor ?? scheme.primary;
    final Color accent = accentColor ?? scheme.secondary;

    final Widget svgGraphic = SvgPicture.asset(
      'assets/svg/illustration_empty_feed.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(primary, BlendMode.srcIn),
    );

    if (!animate) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            _RadialBackdrop(
              size: size * 0.95,
              primary: primary,
              accent: accent,
            ),
            svgGraphic,
          ],
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _RadialBackdrop(
            size: size * 0.95,
            primary: primary,
            accent: accent,
          ),
          svgGraphic
              .animate(onPlay: (AnimationController c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 0.98,
                end: 1.02,
                duration: const Duration(milliseconds: 2400),
                curve: Curves.easeInOut,
              )
              .moveY(
                begin: 0,
                end: -4,
                duration: const Duration(milliseconds: 2400),
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }
}

class _RadialBackdrop extends StatelessWidget {
  const _RadialBackdrop({
    required this.size,
    required this.primary,
    required this.accent,
  });

  final double size;
  final Color primary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            primary.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.6, 1.0],
        ),
      ),
    );
  }
}

// ── 2. Media Placeholder Illustration ──────────────────────────────────

/// A shimmering vector placeholder for loading media cards and post viewports.
class MediaPlaceholderIllustration extends StatelessWidget {
  const MediaPlaceholderIllustration({
    super.key,
    this.width = double.infinity,
    this.height = 240,
    this.tintColor,
    this.animate = true,
    this.borderRadius,
  });

  final double width;
  final double height;
  final Color? tintColor;
  final bool animate;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color effectiveColor = tintColor ?? scheme.onSurfaceVariant;
    final BorderRadius radius = borderRadius ?? BorderRadius.circular(16);

    final Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'assets/svg/illustration_media_placeholder.svg',
        width: 80,
        height: 64,
        colorFilter: ColorFilter.mode(
          effectiveColor.withValues(alpha: 0.45),
          BlendMode.srcIn,
        ),
      ),
    );

    if (!animate) return content;

    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      highlightColor: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
      child: content,
    );
  }
}

// ── 3. Media Error Illustration ────────────────────────────────────────

/// A vector error indicator for broken or failed media downloads with an optional retry action.
class MediaErrorIllustration extends StatelessWidget {
  const MediaErrorIllustration({
    super.key,
    this.width = double.infinity,
    this.height = 200,
    this.message,
    this.onRetry,
    this.tintColor,
    this.borderRadius,
  });

  final double width;
  final double height;
  final String? message;
  final VoidCallback? onRetry;
  final Color? tintColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color effectiveTint = tintColor ?? scheme.outline;
    final BorderRadius radius = borderRadius ?? BorderRadius.circular(16);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: radius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SvgPicture.asset(
            'assets/svg/illustration_media_error.svg',
            width: 56,
            height: 48,
            colorFilter: ColorFilter.mode(
              effectiveTint.withValues(alpha: 0.7),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message ?? 'Не удалось загрузить медиа',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Повторить'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: scheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 4. Settings Categories & Header Illustration ───────────────────────

/// Enumerates the 9 primary settings domain categories.
enum SettingsIllustrationCategory {
  account,
  appearance,
  privacy,
  storage,
  languageRegion,
  preferences,
  about,
  e2ee,
  sessions,
}

/// A crisp, squircle-wrapped vector badge representing a settings category.
class SettingsHeaderIllustration extends StatelessWidget {
  const SettingsHeaderIllustration({
    super.key,
    required this.category,
    this.size = 52,
    this.accentColor,
    this.compact = false,
  });

  final SettingsIllustrationCategory category;
  final double size;
  final Color? accentColor;
  final bool compact;

  String get _svgAsset {
    switch (category) {
      case SettingsIllustrationCategory.account:
        return 'assets/svg/settings_account.svg';
      case SettingsIllustrationCategory.appearance:
        return 'assets/svg/settings_appearance.svg';
      case SettingsIllustrationCategory.privacy:
        return 'assets/svg/settings_privacy.svg';
      case SettingsIllustrationCategory.storage:
        return 'assets/svg/settings_storage.svg';
      case SettingsIllustrationCategory.languageRegion:
        return 'assets/svg/settings_language.svg';
      case SettingsIllustrationCategory.preferences:
        return 'assets/svg/settings_preferences.svg';
      case SettingsIllustrationCategory.about:
        return 'assets/svg/settings_about.svg';
      case SettingsIllustrationCategory.e2ee:
        return 'assets/svg/settings_e2ee.svg';
      case SettingsIllustrationCategory.sessions:
        return 'assets/svg/settings_sessions.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = accentColor ?? _defaultColor(category, scheme);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.35),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        _svgAsset,
        width: size * 0.54,
        height: size * 0.54,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }

  static Color _defaultColor(
    SettingsIllustrationCategory cat,
    ColorScheme scheme,
  ) {
    switch (cat) {
      case SettingsIllustrationCategory.account:
      case SettingsIllustrationCategory.appearance:
        return scheme.primary;
      case SettingsIllustrationCategory.privacy:
      case SettingsIllustrationCategory.preferences:
        return scheme.secondary;
      case SettingsIllustrationCategory.storage:
      case SettingsIllustrationCategory.e2ee:
        return scheme.tertiary;
      case SettingsIllustrationCategory.languageRegion:
      case SettingsIllustrationCategory.about:
      case SettingsIllustrationCategory.sessions:
        return scheme.primary;
    }
  }
}
