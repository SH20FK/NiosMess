import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/session_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_logo_mark.dart';
import 'package:pulse_flutter/widgets/m3_organic_background.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  int _index = 0;

  List<_SlideData> _slides(BuildContext context) => <_SlideData>[
    _SlideData(
      title: context.l10n.onboardingSlide1Title,
      description: context.l10n.onboardingSlide1Desc,
      icon: Icons.call_rounded,
      lottiePath: 'assets/lottie/onboarding_calls.json',
      tintColor: Theme.of(context).colorScheme.primary,
    ),
    _SlideData(
      title: context.l10n.onboardingSlide2Title,
      description: context.l10n.onboardingSlide2Desc,
      icon: Icons.chat_bubble_rounded,
      lottiePath: 'assets/lottie/onboarding_chat.json',
      tintColor: Theme.of(context).colorScheme.secondary,
    ),
    _SlideData(
      title: context.l10n.onboardingSlide3Title,
      description: context.l10n.onboardingSlide3Desc,
      icon: Icons.bolt_rounded,
      lottiePath: 'assets/lottie/onboarding_speed.json',
      tintColor: Theme.of(context).colorScheme.tertiary,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleGetStarted() async {
    HapticService.tap();
    await ref.read(sessionProvider.notifier).completeOnboarding();
    if (!mounted) return;
    final bool authenticated = ref.read(authProvider).isAuthenticated;
    if (authenticated) {
      context.go('/main/chats');
    } else {
      context.push('/register');
    }
  }

  Future<void> _handleLogin() async {
    HapticService.tap();
    await ref.read(sessionProvider.notifier).completeOnboarding();
    if (!mounted) return;
    final bool authenticated = ref.read(authProvider).isAuthenticated;
    if (authenticated) {
      context.go('/main/chats');
    } else {
      context.push('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<_SlideData> slides = _slides(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return M3OrganicBackground(
      showBackButton: false,
      showThemeToggle: true,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ── Hero Branding Header ─────────────────────────────────
            Expanded(
              flex: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogoMark(size: 88)
                      .animate()
                      .scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1, 1),
                        curve: Curves.easeOutBack,
                        duration: 480.ms,
                      )
                      .fade(duration: 400.ms),
                  const SizedBox(height: 18),

                  // Brand Name with M3 decorative element
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Ni',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: M3Container(
                          Shapes.c9_sided_cookie,
                          width: 22,
                          height: 22,
                          color: scheme.primary,
                          child: Center(
                            child: Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        's Mess',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 150.ms, duration: 400.ms),
                ],
              ),
            ),

            // ── Features PageView Carousel ───────────────────────────
            Expanded(
              flex: 6,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int index) {
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.tap();
                  }
                  setState(() => _index = index);
                },
                itemCount: slides.length,
                itemBuilder: (BuildContext context, int index) {
                  final _SlideData slide = slides[index];

                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Lottie Animated Illustration
                          Lottie.asset(
                            slide.lottiePath,
                            width: 130,
                            height: 130,
                            fit: BoxFit.contain,
                            repeat: true,
                          ),
                          const SizedBox(height: 16),

                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            slide.description,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Slide Indicator Dots ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(slides.length, (int dotIndex) {
                final bool active = dotIndex == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),

            // ── Bottom Action Buttons ────────────────────────────────
            Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: bottomInset > 0 ? bottomInset + 12 : 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Action: "Создать аккаунт"
                    _M3AuthPillButton(
                      label: context.l10n.registerTitle,
                      icon: Icons.arrow_forward_rounded,
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      onTap: _handleGetStarted,
                    ),
                    const SizedBox(height: 12),

                    // Secondary Action: "У меня уже есть аккаунт"
                    _M3AuthPillButton(
                      label: context.l10n.loginTitle,
                      backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
                      foregroundColor: scheme.onSurface,
                      isOutlined: false,
                      onTap: _handleLogin,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _M3AuthPillButton extends StatelessWidget {
  const _M3AuthPillButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.icon,
    this.isOutlined = false,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isOutlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(28),
      elevation: 0,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: isOutlined
                ? Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: foregroundColor),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.title,
    required this.description,
    required this.icon,
    required this.lottiePath,
    required this.tintColor,
  });
  final String title;
  final String description;
  final IconData icon;
  final String lottiePath;
  final Color tintColor;
}
