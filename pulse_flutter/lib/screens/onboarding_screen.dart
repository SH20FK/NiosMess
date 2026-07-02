import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/session_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/glass_card.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';
import 'package:pulse_flutter/widgets/onboarding/call_waves_painter.dart';
import 'package:pulse_flutter/widgets/onboarding/chat_messages_painter.dart';
import 'package:pulse_flutter/widgets/onboarding/bolt_spark_painter.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _floatController;
  int _index = 0;

  static const List<IconData> _slideIcons = <IconData>[
    Icons.call_rounded,
    Icons.chat_bubble_rounded,
    Icons.bolt_rounded,
  ];

  List<_SlideData> _slides(BuildContext context) => <_SlideData>[
    _SlideData(
      title: context.l10n.onboardingSlide1Title,
      description: context.l10n.onboardingSlide1Desc,
      icon: _slideIcons[0],
      painter: CallWavesPainter.new,
      tintIndex: 0,
    ),
    _SlideData(
      title: context.l10n.onboardingSlide2Title,
      description: context.l10n.onboardingSlide2Desc,
      icon: _slideIcons[1],
      painter: ChatMessagesPainter.new,
      tintIndex: 1,
    ),
    _SlideData(
      title: context.l10n.onboardingSlide3Title,
      description: context.l10n.onboardingSlide3Desc,
      icon: _slideIcons[2],
      painter: BoltSparkPainter.new,
      tintIndex: 2,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Color _slideTint(ColorScheme scheme, int tintIndex) {
    switch (tintIndex) {
      case 0: return scheme.primary;
      case 1: return scheme.secondary;
      case 2: return scheme.tertiary;
      default: return scheme.primary;
    }
  }

  Future<void> _goNext() async {
    final slides = _slides(context);
    if (_index < slides.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await ref.read(sessionProvider.notifier).completeOnboarding();
    if (mounted) {
      final bool authenticated = ref.read(authProvider).isAuthenticated;
      context.go(authenticated ? '/main/chats' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<_SlideData> slides = _slides(context);
    final Color tint = _slideTint(scheme, slides[_index].tintIndex);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              tint.withValues(alpha: 0.18),
              tint.withValues(alpha: 0.08),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenHorizontalPadding,
              vertical: 14,
            ),
            child: Column(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: scheme.surfaceContainerHighest,
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (_index + 1) / slides.length,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: <Color>[tint, _slideTint(scheme, (_index + 1) % slides.length)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        await ref.read(sessionProvider.notifier).completeOnboarding();
                        if (!context.mounted) return;
                        final bool authenticated = ref.read(authProvider).isAuthenticated;
                        context.go(authenticated ? '/main/chats' : '/login');
                      },
                      child: Text(context.l10n.commonSkip),
                    ),
                  ],
                ),
                Expanded(
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

                      return AnimatedBuilder(
                        animation: _floatController,
                        builder: (_, Widget? child) {
                          return SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const SizedBox(height: 20),
                                Hero(
                                  tag: 'onboarding_icon_${slide.tintIndex}',
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(6),
                                    child: SizedBox(
                                      width: 140,
                                      height: 140,
                                      child: CustomPaint(
                                        painter: slide.painter(
                                          scheme,
                                          _floatController.value,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: GlassCard(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        children: <Widget>[
                                          Text(
                                            slide.title,
                                            textAlign: TextAlign.center,
                                            style: textTheme.headlineMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            slide.description,
                                            textAlign: TextAlign.center,
                                            style: textTheme.bodyLarge?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                    .animate(key: ValueKey<int>(index))
                                    .fade(duration: 320.ms)
                                    .slideY(
                                      begin: 0.08,
                                      end: 0,
                                      curve: Curves.easeOutCubic,
                                      duration: 360.ms,
                                    ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(slides.length, (int dotIndex) {
                    final bool active = dotIndex == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 28 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: active
                            ? _slideTint(scheme, dotIndex)
                            : scheme.outlineVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                PulseButton(
                  label: _index == slides.length - 1
                      ? context.l10n.onboardingGetStarted
                      : context.l10n.onboardingNext,
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
    required this.painter,
    required this.tintIndex,
  });
  final String title;
  final String description;
  final IconData icon;
  final CustomPainter Function(ColorScheme, double) painter;
  final int tintIndex;
}
