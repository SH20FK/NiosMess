import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/m3_organic_background.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Standard max-width token for all authentication and entry flows.
const double kAuthFormMaxWidth = 440.0;

/// Standardized Material 3 Expressive Primary Action Button for Authentication.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isTonal = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isTonal;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final ButtonStyle style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.fullRadius),
      backgroundColor: isTonal
          ? scheme.surfaceContainerHigh.withValues(alpha: 0.65)
          : scheme.primary,
      foregroundColor: isTonal ? scheme.onSurface : scheme.onPrimary,
      disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
      disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
    );

    final Widget child;
    if (isLoading) {
      child = AppLoadingIndicator(
        size: 22,
        color: isTonal ? scheme.primary : scheme.onPrimary,
      );
    } else if (icon != null) {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    } else {
      child = Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: isLoading
            ? null
            : onPressed == null
                ? null
                : () {
                    HapticService.tap();
                    onPressed!();
                  },
        style: style,
        child: child,
      ),
    );
  }
}

/// Unified Material 3 Expressive Auth Scaffold.
///
/// Ensures consistent 440dp centering, responsive padding, M3OrganicBackground,
/// expressive hero badge, and unified layout across the auth funnel.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.children,
    this.header,
    this.badgeIcon,
    this.title,
    this.subtitle,
    this.footer,
    this.showBackButton = false,
    this.showThemeToggle = true,
    this.onBack,
    this.maxWidth = kAuthFormMaxWidth,
    this.isLoadingOverlay = false,
    this.loadingOverlayText,
    super.key,
  });

  final List<Widget> children;
  final Widget? header;
  final IconData? badgeIcon;
  final String? title;
  final String? subtitle;
  final Widget? footer;
  final bool showBackButton;
  final bool showThemeToggle;
  final VoidCallback? onBack;
  final double maxWidth;
  final bool isLoadingOverlay;
  final String? loadingOverlayText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return M3OrganicBackground(
      showBackButton: showBackButton,
      showThemeToggle: showThemeToggle,
      onBack: onBack,
      child: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header Section ─────────────────────────────
                      if (header != null) ...[
                        header!,
                      ] else if (badgeIcon != null || title != null) ...[
                        _buildDefaultHeader(scheme, textTheme),
                      ],
                      const SizedBox(height: 24),

                      // ── Content Form / Actions ─────────────────────
                      ...children,

                      // ── Optional Footer ────────────────────────────
                      if (footer != null) ...[
                        const SizedBox(height: 28),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Loading Transition Overlay ─────────────────────────────
          if (isLoadingOverlay)
            _buildLoadingOverlay(scheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildDefaultHeader(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badgeIcon != null)
          Center(
            child: M3Container(
              Shapes.c9_sided_cookie,
              width: 68,
              height: 68,
              color: scheme.primaryContainer,
              child: Center(
                child: Icon(
                  badgeIcon,
                  size: 32,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: const Duration(milliseconds: 360),
                curve: M3SpringCurves.spatial,
              )
              .fadeIn(duration: const Duration(milliseconds: 280)),
        if (badgeIcon != null) const SizedBox(height: 20),
        if (title != null)
          Text(
            title!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.headline,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ).animate().fadeIn(
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 300),
              ),
        ],
      ],
    );
  }

  Widget _buildLoadingOverlay(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      color: scheme.surface.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadii.lgRadius,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLoadingIndicator(size: 40, color: scheme.primary),
              if (loadingOverlayText != null) ...[
                const SizedBox(height: 16),
                Text(
                  loadingOverlayText!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fade(duration: const Duration(milliseconds: 200));
  }
}
