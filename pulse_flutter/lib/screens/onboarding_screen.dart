import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool bounded = constraints.hasBoundedHeight;

            final Widget headerSection = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogoMark(size: 80)
                    .animate()
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                      duration: 480.ms,
                    )
                    .fade(duration: 400.ms),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.appName,
                      style: GoogleFonts.unbounded(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    M3Container(
                      Shapes.c9_sided_cookie,
                      width: 22,
                      height: 22,
                      color: scheme.primaryContainer,
                      child: Center(
                        child: Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ).animate().fade(delay: 150.ms, duration: 400.ms),
              ],
            );

            final Widget carouselSection = PageView.builder(
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Lottie.asset(
                          slide.lottiePath,
                          width: 140,
                          height: 140,
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
            );

            final Widget indicatorSection = Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  onPressed: _index > 0
                      ? () {
                          HapticFeedback.selectionClick();
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                          );
                        }
                      : null,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(slides.length, (int dotIndex) {
                    final bool active = dotIndex == _index;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _pageController.animateToPage(
                          dotIndex,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: active
                              ? scheme.primary
                              : scheme.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    );
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  onPressed: _index < slides.length - 1
                      ? () {
                          HapticFeedback.selectionClick();
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                          );
                        }
                      : null,
                ),
              ],
            );

            final Widget actionButtonsSection = Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: bottomInset > 0 ? bottomInset + 12 : 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _handleGetStarted,
                    icon: Icon(Icons.arrow_forward_rounded, size: 20, color: scheme.onPrimary),
                    label: Text(
                      context.l10n.onboardingGetStarted,
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            );

            if (bounded) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Expanded(flex: 5, child: headerSection),
                  Expanded(flex: 6, child: carouselSection),
                  indicatorSection,
                  const SizedBox(height: 24),
                  actionButtonsSection,
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                headerSection,
                const SizedBox(height: 24),
                SizedBox(height: 280, child: carouselSection),
                indicatorSection,
                const SizedBox(height: 24),
                actionButtonsSection,
              ],
            );
          },
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
