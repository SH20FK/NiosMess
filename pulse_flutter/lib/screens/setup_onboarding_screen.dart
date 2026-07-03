import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/providers/session_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';

class SetupOnboardingScreen extends ConsumerStatefulWidget {
  const SetupOnboardingScreen({super.key});

  @override
  ConsumerState<SetupOnboardingScreen> createState() =>
      _SetupOnboardingScreenState();
}

class _SetupOnboardingScreenState extends ConsumerState<SetupOnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;
  bool _loading = false;

  String? _selectedLanguageCode;
  AppTimeZoneMode _timeZoneMode = AppTimeZoneMode.auto;
  String _selectedTimeZoneId = 'Europe/Moscow';

  // Live clock — updated once per second, NOT in build()
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  // Cached device tz info — computed once in initState
  late String _deviceTzName;
  late String _deviceOffsetLabel;

  @override
  void initState() {
    super.initState();
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    _selectedLanguageCode = settings.localeCode;
    _timeZoneMode = settings.timeZoneMode;

    // Determine device timezone and use as default for manual selection
    final DateTime deviceNow = DateTime.now();
    _deviceTzName = deviceNow.timeZoneName;
    final Duration offset = deviceNow.timeZoneOffset;
    _deviceOffsetLabel =
        '${offset.isNegative ? '-' : '+'}${offset.inHours.abs().toString().padLeft(2, '0')}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}';

    // Prefer stored manual tz; if none, pick the closest match from the list
    if (settings.timeZoneId != null) {
      _selectedTimeZoneId = settings.timeZoneId!;
    } else {
      // Try to find device tz name in our list; fall back to 'Europe/Moscow'
      final String deviceTzId = _findClosestZone(deviceNow.timeZoneOffset);
      _selectedTimeZoneId = deviceTzId;
    }

    // Start a 1-second ticker to update the clock preview
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  /// Find the zone in appTimeZoneOptions whose offset best matches [deviceOffset].
  String _findClosestZone(Duration deviceOffset) {
    for (final AppTimeZoneOption option in appTimeZoneOptions) {
      // currentOffsetLabel is like '+03:00' — compare raw offset instead
      // We check id contains the device tz name as a substring (e.g. 'Moscow')
      if (option.id.toLowerCase().contains(_deviceTzName.toLowerCase())) {
        return option.id;
      }
    }
    // No name match — fall back to Europe/Moscow
    return 'Europe/Moscow';
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index < 2) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _finish();
  }

  Future<void> _skip() async {
    if (_loading) return;
    setState(() => _loading = true);
    ref.read(uiSettingsProvider.notifier).setLocaleCode(null);
    ref.read(uiSettingsProvider.notifier).useAutomaticTimeZone();
    await _finish();
  }

  Future<void> _finish() async {
    if (!mounted) return;
    setState(() => _loading = true);
    ref.read(uiSettingsProvider.notifier).setLocaleCode(_selectedLanguageCode);
    if (_timeZoneMode == AppTimeZoneMode.auto) {
      ref.read(uiSettingsProvider.notifier).useAutomaticTimeZone();
    } else {
      ref
          .read(uiSettingsProvider.notifier)
          .useManualTimeZone(_selectedTimeZoneId);
    }
    await ref.read(sessionProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go('/main/chats');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
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
                    onPressed: _loading ? null : _skip,
                    child: Text(
                      context.l10n.commonSkip,
                      style: textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    onPageChanged: (int i) => setState(() => _index = i),
                    itemBuilder: (BuildContext context, int page) {
                      switch (page) {
                        case 0:
                          return _welcomePage(scheme, textTheme);
                        case 1:
                          return _languagePage(scheme, textTheme);
                        case 2:
                          return _timezonePage(scheme, textTheme);
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(3, (int dotIndex) {
                    final bool active = dotIndex == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
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
                  label: _index == 2
                      ? context.l10n.setupStartMessaging
                      : context.l10n.commonContinue,
                  onPressed: _loading ? null : _next,
                  isLoading: _loading && _index == 2,
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _welcomePage(ColorScheme scheme, TextTheme textTheme) {
    return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.20),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.waving_hand_rounded,
                    color: scheme.onPrimary,
                    size: 56,
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.06, 1.06),
                  duration: 1100.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 28),
            Text(
              context.l10n.setupWelcomeTitle,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.setupWelcomeBody,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        )
        .animate(key: const ValueKey<String>('welcome'))
        .fade(duration: 320.ms)
        .slideY(begin: 0.06, end: 0, duration: 360.ms);
  }

  Widget _languagePage(ColorScheme scheme, TextTheme textTheme) {
    final List<({String? code, String name, String subtitle})> options =
        <({String? code, String name, String subtitle})>[
          (
            code: null,
            name: context.l10n.languageRegionUseSystemLanguage,
            subtitle:
                WidgetsBinding.instance.platformDispatcher.locale.languageCode
                    .startsWith('ru')
                ? context.l10n.languageRussian
                : context.l10n.languageEnglish,
          ),
          (code: 'en', name: context.l10n.languageEnglish, subtitle: context.l10n.languageEnglish),
          (
            code: 'ru',
            name: context.l10n.languageRussian,
            subtitle: context.l10n.languageRussianNative,
          ),
        ];

    return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.language_rounded,
                size: 44,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.setupLanguageTitle,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ...options.map((
              ({String? code, String name, String subtitle}) lang,
            ) {
              final bool selected =
                  _selectedLanguageCode == lang.code ||
                  (_selectedLanguageCode == null && lang.code == null);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: selected
                      ? scheme.primaryContainer.withValues(alpha: 0.72)
                      : scheme.surfaceContainerLow.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedLanguageCode = lang.code);
                      ref
                          .read(uiSettingsProvider.notifier)
                          .setLocaleCode(lang.code);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  lang.name,
                                  style: textTheme.titleMedium?.copyWith(
                                    color: selected
                                        ? scheme.onPrimaryContainer
                                        : null,
                                  ),
                                ),
                                Text(
                                  lang.subtitle,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: selected
                                        ? scheme.onPrimaryContainer.withValues(
                                            alpha: 0.7,
                                          )
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: scheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        )
        .animate(key: const ValueKey<String>('language'))
        .fade(duration: 320.ms)
        .slideY(begin: 0.06, end: 0, duration: 360.ms);
  }

  Widget _timezonePage(ColorScheme scheme, TextTheme textTheme) {
    // _now and _deviceTzName/_deviceOffsetLabel are updated by Timer — NOT computed here
    return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.schedule_rounded,
                size: 44,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.setupTimezoneTitle,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Material(
              color: _timeZoneMode == AppTimeZoneMode.auto
                  ? scheme.primaryContainer.withValues(alpha: 0.72)
                  : scheme.surfaceContainerLow.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () {
                  setState(() => _timeZoneMode = AppTimeZoneMode.auto);
                  ref.read(uiSettingsProvider.notifier).useAutomaticTimeZone();
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.commonAutomatic,
                              style: textTheme.titleMedium?.copyWith(
                                color: _timeZoneMode == AppTimeZoneMode.auto
                                    ? scheme.onPrimaryContainer
                                    : null,
                              ),
                            ),
                            Text(
                              '$_deviceTzName (UTC$_deviceOffsetLabel)',
                              style: textTheme.bodySmall?.copyWith(
                                color: _timeZoneMode == AppTimeZoneMode.auto
                                    ? scheme.onPrimaryContainer.withValues(
                                        alpha: 0.7,
                                      )
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_timeZoneMode == AppTimeZoneMode.auto)
                        Icon(Icons.check_circle_rounded, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: _timeZoneMode == AppTimeZoneMode.manual
                  ? scheme.primaryContainer.withValues(alpha: 0.72)
                  : scheme.surfaceContainerLow.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () async {
                  setState(() => _timeZoneMode = AppTimeZoneMode.manual);
                  ref
                      .read(uiSettingsProvider.notifier)
                      .setTimeZoneMode(AppTimeZoneMode.manual);
                  await _showTimeZonePicker();
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.commonManual,
                              style: textTheme.titleMedium?.copyWith(
                                color: _timeZoneMode == AppTimeZoneMode.manual
                                    ? scheme.onPrimaryContainer
                                    : null,
                              ),
                            ),
                            Text(
                              _zoneLabel(_selectedTimeZoneId),
                              style: textTheme.bodySmall?.copyWith(
                                color: _timeZoneMode == AppTimeZoneMode.manual
                                    ? scheme.onPrimaryContainer.withValues(
                                        alpha: 0.7,
                                      )
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_timeZoneMode == AppTimeZoneMode.manual)
                        Icon(Icons.check_circle_rounded, color: scheme.primary)
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.setupTimezoneUseDevice,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    context.l10n.languageRegionCurrentTime,
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    // _now is updated by Timer — safe to call formatFullDateTime here
                    formatFullDateTime(_now),
                    style: textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        )
        .animate(key: const ValueKey<String>('timezone'))
        .fade(duration: 320.ms)
        .slideY(begin: 0.06, end: 0, duration: 360.ms);
  }

  Future<void> _showTimeZonePicker() async {
    final TextEditingController controller = TextEditingController();
    String query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final List<AppTimeZoneOption> zones = appTimeZoneOptions
                .where((AppTimeZoneOption option) {
                  final String hay = '${option.label} ${option.id}'
                      .toLowerCase();
                  return hay.contains(query.toLowerCase());
                })
                .toList(growable: false);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: context.l10n.languageRegionSearchTimeZones,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (String value) {
                      setModalState(() => query = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: zones.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final AppTimeZoneOption option = zones[index];
                        final bool selected = option.id == _selectedTimeZoneId;
                        return Material(
                          color: selected
                              ? scheme.primaryContainer.withValues(alpha: 0.72)
                              : scheme.surfaceContainerLow.withValues(
                                  alpha: 0.86,
                                ),
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTimeZoneId = option.id;
                                _timeZoneMode = AppTimeZoneMode.manual;
                              });
                              ref
                                  .read(uiSettingsProvider.notifier)
                                  .useManualTimeZone(option.id);
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          option.label,
                                          style: textTheme.titleMedium,
                                        ),
                                        Text(
                                          '${option.id} • ${option.currentOffsetLabel()}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: scheme.primary,
                                    ),
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

    controller.dispose();
  }

  String _zoneLabel(String zoneId) {
    for (final AppTimeZoneOption option in appTimeZoneOptions) {
      if (option.id == zoneId) {
        return '${option.label} (${option.currentOffsetLabel()})';
      }
    }
    return zoneId;
  }
}
