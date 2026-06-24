import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/session_provider.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  static const List<_SlideData> _slides = <_SlideData>[
    _SlideData(
      title: 'Fast calls with less friction',
      description:
          'Call teammates in one tap and switch between voice and video without leaving the flow.',
      icon: Icons.call_rounded,
    ),
    _SlideData(
      title: 'Organized conversations',
      description:
          'Keep your chats, calls, and contacts in one focused workspace that stays easy to scan.',
      icon: Icons.chat_bubble_rounded,
    ),
    _SlideData(
      title: 'Designed for daily rhythm',
      description:
          'Smooth transitions and clear hierarchy keep communication calm even on a busy day.',
      icon: Icons.bolt_rounded,
    ),
  ];

  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_index < _slides.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    await ref.read(sessionProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: AppTheme.heroGradient(scheme)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenHorizontalPadding,
              vertical: 14,
            ),
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      await ref
                          .read(sessionProvider.notifier)
                          .completeOnboarding();
                      if (!context.mounted) {
                        return;
                      }
                      context.go('/login');
                    },
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (int index) =>
                        setState(() => _index = index),
                    itemCount: _slides.length,
                    itemBuilder: (BuildContext context, int index) {
                      final _SlideData slide = _slides[index];

                      return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(38),
                                ),
                                child: Icon(
                                  slide.icon,
                                  size: 62,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                slide.description,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          )
                          .animate(key: ValueKey<int>(index))
                          .fade(duration: 320.ms)
                          .slideY(
                            begin: 0.06,
                            end: 0,
                            curve: Curves.easeOutCubic,
                            duration: 360.ms,
                          );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(_slides.length, (
                    int dotIndex,
                  ) {
                    final bool active = dotIndex == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 26 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: active
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                PulseButton(
                  label: _index == _slides.length - 1 ? 'Get started' : 'Next',
                  onPressed: _goNext,
                ),
                const SizedBox(height: 6),
              ],
            ),
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
  });

  final String title;
  final String description;
  final IconData icon;
}
