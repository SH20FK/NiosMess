import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';

import 'app_logo_mark.dart';
import 'm3_organic_background.dart';

class M3ResponsiveAuthLayout extends StatelessWidget {
  const M3ResponsiveAuthLayout({
    super.key,
    required this.child,
    this.heroIcon = Icons.lock_outline_rounded,
    this.heroTitle,
    this.heroSubtitle,
    this.heroIllustration,
    this.showBackButton = true,
    this.showThemeToggle = true,
    this.onBack,
    this.maxWidth = 480,
  });

  final Widget child;
  final IconData heroIcon;
  final String? heroTitle;
  final String? heroSubtitle;
  final Widget? heroIllustration;
  final bool showBackButton;
  final bool showThemeToggle;
  final VoidCallback? onBack;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Size size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 840;

    return M3OrganicBackground(
      showBackButton: showBackButton,
      showThemeToggle: showThemeToggle,
      onBack: onBack,
      child: SafeArea(
        child: isDesktop
            ? _buildDesktopSplitLayout(context, scheme, textTheme)
            : _buildMobileLayout(context, scheme),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, ColorScheme scheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSplitLayout(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final String title = heroTitle ?? 'NiosMess';
    final String subtitle = heroSubtitle ??
        'Быстрый, безопасный и красивый мессенджер нового поколения.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Row(
          children: <Widget>[
            // ── Left Side: Hero Branding & Illustration ─────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(right: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const AppLogoMark(size: 64)
                            .animate()
                            .scale(
                              begin: const Offset(0.8, 0.8),
                              curve: Curves.easeOutBack,
                              duration: 500.ms,
                            ),
                        const SizedBox(width: 16),
                        Text(
                          'NiosMess',
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(width: 10),
                        M3Container.c9SidedCookie(
                          width: 28,
                          height: 28,
                          color: scheme.primaryContainer,
                          child: Center(
                            child: Icon(
                              Icons.bolt_rounded,
                              size: 17,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    if (heroIllustration != null)
                      heroIllustration!
                    else
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.3),
                            width: 2.0,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.15),
                              blurRadius: 32,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            heroIcon,
                            size: 72,
                            color: scheme.primary,
                          ),
                        ),
                      ).animate().fade(duration: 400.ms),

                    const SizedBox(height: 28),

                    Text(
                      title,
                      style: textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      subtitle,
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Right Side: Floating Form Card Container ─────────────
            Expanded(
              flex: 6,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.40),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.12),
                          blurRadius: 36,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
