import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
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

  // Language & TimeZone state (merged from SetupOnboardingScreen)
  String? _selectedLanguageCode;
  AppTimeZoneMode _timeZoneMode = AppTimeZoneMode.auto;
  String _selectedTimeZoneId = 'Europe/Moscow';
  late String _deviceTzName;
  late String _deviceOffsetLabel;

  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  static const int _totalSlides = 4;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    final UiSettingsState settings = ref.read(uiSettingsProvider);
    _selectedLanguageCode = settings.localeCode;
    _timeZoneMode = settings.timeZoneMode;

    final DateTime deviceNow = DateTime.now();
    _deviceTzName = deviceNow.timeZoneName;
    final Duration offset = deviceNow.timeZoneOffset;
    _deviceOffsetLabel =
        '${offset.isNegative ? '-' : '+'}${offset.inHours.abs().toString().padLeft(2, '0')}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}';

    if (settings.timeZoneId != null) {
      _selectedTimeZoneId = settings.timeZoneId!;
    } else {
      _selectedTimeZoneId = _findClosestZone(deviceNow.timeZoneOffset);
    }
  }

  String _findClosestZone(Duration deviceOffset) {
    for (final AppTimeZoneOption option in appTimeZoneOptions) {
      if (option.id.toLowerCase().contains(_deviceTzName.toLowerCase())) {
        return option.id;
      }
    }
    return 'Europe/Moscow';
  }

  void _startClockTimerIfNeeded() {
    if (_index == 3 && _clockTimer == null) {
      _now = DateTime.now();
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _index == 3) {
          setState(() => _now = DateTime.now());
        }
      });
    } else if (_index != 3 && _clockTimer != null) {
      _clockTimer?.cancel();
      _clockTimer = null;
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
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
      context.go('/login');
    }
  }

  void _handleSkip() {
    HapticService.selection();
    if (_index < 3) {
      _pageController.animateToPage(
        3,
        duration: const Duration(milliseconds: 350),
        curve: M3SpringCurves.spatial,
      );
    } else {
      _handleGetStarted();
    }
  }

  void _handleNext() {
    HapticService.selection();
    if (_index < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: M3SpringCurves.spatial,
      );
    } else {
      _handleGetStarted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

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
                Hero(
                  tag: 'app_brand_logo',
                  child: const AppLogoMark(size: 72),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1),
                      curve: M3SpringCurves.spatial,
                      duration: const Duration(milliseconds: 400),
                    )
                    .fade(duration: const Duration(milliseconds: 300)),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.appName,
                      style: TextStyle(
                        fontFamily: AppFonts.headline,
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
                ).animate().fade(
                      delay: const Duration(milliseconds: 150),
                      duration: const Duration(milliseconds: 300),
                    ),
              ],
            );

            final Widget carouselSection = PageView.builder(
              controller: _pageController,
              onPageChanged: (int index) {
                if (ref.read(uiSettingsProvider).haptics) {
                  HapticService.tap();
                }
                setState(() => _index = index);
                _startClockTimerIfNeeded();
              },
              itemCount: _totalSlides,
              itemBuilder: (BuildContext context, int index) {
                if (index == 3) {
                  return _buildRegionAndLanguageSlide(scheme, textTheme);
                }
                return _buildLottieSlide(index, scheme, textTheme);
              },
            );

            final Widget indicatorSection = Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: context.l10n.commonBack,
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  onPressed: _index > 0
                      ? () {
                          HapticFeedback.selectionClick();
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: M3SpringCurves.spatial,
                          );
                        }
                      : null,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(_totalSlides, (int dotIndex) {
                    final bool active = dotIndex == _index;
                    return Semantics(
                      button: true,
                      selected: active,
                      label: '${dotIndex + 1} / $_totalSlides',
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _pageController.animateToPage(
                            dotIndex,
                            duration: const Duration(milliseconds: 320),
                            curve: M3SpringCurves.spatial,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: M3SpringCurves.spatial,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 26 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: active
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: 0.5),
                            borderRadius: AppRadii.fullRadius,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                IconButton(
                  tooltip: context.l10n.commonContinue,
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  onPressed: _index < _totalSlides - 1
                      ? () {
                          HapticFeedback.selectionClick();
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: M3SpringCurves.spatial,
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
                constraints: const BoxConstraints(maxWidth: 440),
                child: Row(
                  children: [
                    if (_index < 3)
                      Expanded(
                        child: TextButton(
                          onPressed: _handleSkip,
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadii.fullRadius,
                            ),
                          ),
                          child: Text(
                            context.l10n.commonSkip,
                            style: textTheme.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (_index < 3) const SizedBox(width: 12),
                    Expanded(
                      flex: _index < 3 ? 1 : 2,
                      child: SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _handleNext,
                          icon: Icon(
                            _index == 3
                                ? Icons.arrow_forward_rounded
                                : Icons.arrow_forward_rounded,
                            size: 20,
                            color: scheme.onPrimary,
                          ),
                          label: Text(
                            _index == 3
                                ? context.l10n.setupStartMessaging
                                : context.l10n.commonContinue,
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
                              borderRadius: AppRadii.fullRadius,
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (bounded) {
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Expanded(flex: 4, child: headerSection),
                  Expanded(flex: 7, child: carouselSection),
                  indicatorSection,
                  const SizedBox(height: 18),
                  actionButtonsSection,
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                headerSection,
                const SizedBox(height: 20),
                SizedBox(height: 320, child: carouselSection),
                indicatorSection,
                const SizedBox(height: 20),
                actionButtonsSection,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLottieSlide(int index, ColorScheme scheme, TextTheme textTheme) {
    late final String title;
    late final String description;
    late final String lottiePath;

    switch (index) {
      case 0:
        title = context.l10n.onboardingSlide1Title;
        description = context.l10n.onboardingSlide1Desc;
        lottiePath = 'assets/lottie/onboarding_calls.json';
        break;
      case 1:
        title = context.l10n.onboardingSlide2Title;
        description = context.l10n.onboardingSlide2Desc;
        lottiePath = 'assets/lottie/onboarding_chat.json';
        break;
      case 2:
      default:
        title = context.l10n.onboardingSlide3Title;
        description = context.l10n.onboardingSlide3Desc;
        lottiePath = 'assets/lottie/onboarding_speed.json';
        break;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              lottiePath,
              width: 140,
              height: 140,
              fit: BoxFit.contain,
              repeat: true,
              frameRate: FrameRate.max,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: AppRadii.lgRadius,
                ),
                child: Icon(
                  index == 0
                      ? Icons.call_rounded
                      : index == 1
                          ? Icons.chat_bubble_rounded
                          : Icons.bolt_rounded,
                  size: 48,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
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
  }

  Widget _buildRegionAndLanguageSlide(ColorScheme scheme, TextTheme textTheme) {
    final List<({String? code, String name, String subtitle})> langOptions = [
      (
        code: null,
        name: context.l10n.languageRegionUseSystemLanguage,
        subtitle: Localizations.localeOf(context).languageCode == 'ru'
            ? context.l10n.languageRussian
            : context.l10n.languageEnglish,
      ),
      (code: 'en', name: context.l10n.languageEnglish, subtitle: 'English'),
      (code: 'ru', name: context.l10n.languageRussian, subtitle: 'Русский'),
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.setupLanguageTitle,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.setupTimezoneUseDevice,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Language Chips / Buttons
              Row(
                children: langOptions.map((lang) {
                  final bool selected = _selectedLanguageCode == lang.code ||
                      (_selectedLanguageCode == null && lang.code == null);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Material(
                        color: selected
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerLow,
                        borderRadius: AppRadii.mdRadius,
                        child: InkWell(
                          onTap: () {
                            HapticService.selection();
                            setState(() => _selectedLanguageCode = lang.code);
                            ref
                                .read(uiSettingsProvider.notifier)
                                .setLocaleCode(lang.code);
                          },
                          borderRadius: AppRadii.mdRadius,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              children: [
                                Text(
                                  lang.name,
                                  style: textTheme.labelLarge?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurface,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Timezone Card
              Material(
                color: _timeZoneMode == AppTimeZoneMode.auto
                    ? scheme.primaryContainer.withValues(alpha: 0.72)
                    : scheme.surfaceContainerLow,
                borderRadius: AppRadii.lgRadius,
                child: InkWell(
                  onTap: () {
                    HapticService.selection();
                    setState(() => _timeZoneMode = AppTimeZoneMode.auto);
                    ref
                        .read(uiSettingsProvider.notifier)
                        .useAutomaticTimeZone();
                  },
                  borderRadius: AppRadii.lgRadius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 22,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.commonAutomatic,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _timeZoneMode == AppTimeZoneMode.auto
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface,
                                ),
                              ),
                              Text(
                                '$_deviceTzName (UTC$_deviceOffsetLabel)',
                                style: textTheme.bodySmall?.copyWith(
                                  color: _timeZoneMode == AppTimeZoneMode.auto
                                      ? scheme.onPrimaryContainer
                                          .withValues(alpha: 0.75)
                                      : scheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_timeZoneMode == AppTimeZoneMode.auto)
                          Icon(
                            Icons.check_circle_rounded,
                            color: scheme.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Manual Timezone Card
              Material(
                color: _timeZoneMode == AppTimeZoneMode.manual
                    ? scheme.primaryContainer.withValues(alpha: 0.72)
                    : scheme.surfaceContainerLow,
                borderRadius: AppRadii.lgRadius,
                child: InkWell(
                  onTap: () async {
                    HapticService.selection();
                    setState(() => _timeZoneMode = AppTimeZoneMode.manual);
                    ref
                        .read(uiSettingsProvider.notifier)
                        .setTimeZoneMode(AppTimeZoneMode.manual);
                    await _showTimeZonePicker();
                  },
                  borderRadius: AppRadii.lgRadius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.public_rounded,
                          size: 22,
                          color: scheme.secondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.commonManual,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _timeZoneMode == AppTimeZoneMode.manual
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface,
                                ),
                              ),
                              Text(
                                _selectedTimeZoneId,
                                style: textTheme.bodySmall?.copyWith(
                                  color: _timeZoneMode == AppTimeZoneMode.manual
                                      ? scheme.onPrimaryContainer
                                          .withValues(alpha: 0.75)
                                      : scheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _timeZoneMode == AppTimeZoneMode.manual
                              ? Icons.check_circle_rounded
                              : Icons.chevron_right_rounded,
                          color: _timeZoneMode == AppTimeZoneMode.manual
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Live Time Preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
                  borderRadius: AppRadii.mdRadius,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${context.l10n.languageRegionCurrentTime}: ',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatFullDateTime(_now),
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTimeZonePicker() async {
    final TextEditingController searchController = TextEditingController();
    String query = '';

    await AppBottomSheets.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final ColorScheme scheme = Theme.of(sheetContext).colorScheme;
        final TextTheme textTheme = Theme.of(sheetContext).textTheme;

        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final List<AppTimeZoneOption> filteredZones = appTimeZoneOptions
                .where((AppTimeZoneOption option) {
                  final String hay =
                      '${option.label} ${option.id}'.toLowerCase();
                  return hay.contains(query.toLowerCase());
                })
                .toList(growable: false);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: context.l10n.languageRegionSearchTimeZones,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (String val) {
                      setModalState(() => query = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredZones.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (BuildContext _, int idx) {
                        final AppTimeZoneOption option = filteredZones[idx];
                        final bool selected = option.id == _selectedTimeZoneId;
                        return Material(
                          color: selected
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerLow,
                          borderRadius: AppRadii.mdRadius,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTimeZoneId = option.id;
                                _timeZoneMode = AppTimeZoneMode.manual;
                              });
                              ref
                                  .read(uiSettingsProvider.notifier)
                                  .useManualTimeZone(option.id);
                              Navigator.of(sheetContext).pop();
                            },
                            borderRadius: AppRadii.mdRadius,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? scheme.onPrimaryContainer
                                            : scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    option.currentOffsetLabel(),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (selected) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: scheme.primary,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
