import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/localization/secret_chat_l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/ai_quota_model.dart';
import 'package:pulse_flutter/widgets/profile/ai_usage_card.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_chats_screen.dart';
import 'package:pulse_flutter/screens/settings_energy_saving_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/screens/settings_plus_screen.dart';
import 'package:pulse_flutter/screens/settings_preferences_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sound extends SoundService {
  final events = <SoundEvent>[];
  @override
  Future<void> playEvent(SoundEvent event, {double? volume}) async {
    events.add(event);
  }
}

class _Notifications extends NotificationPreferencesNotifier {
  @override
  Future<NotificationPreferences> build() async =>
      const NotificationPreferences();
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'isolated-a',
      userId: 1,
      username: 'a',
      displayName: 'A',
    ),
  );
  void switchAccount() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'isolated-b',
      userId: 2,
      username: 'b',
      displayName: 'B',
    ),
  );
}

class _Socket extends WebSocketClient {
  _Socket() : super(baseUrl: 'wss://isolated.invalid', readToken: () => null);
  final pendingLimits = <Completer<dynamic>>[];
  final pendingTrials = <Completer<dynamic>>[];
  final trialRetryLimits = <int>[];
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) {
    if (action == 'get_my_limits') {
      final pending = Completer<dynamic>();
      pendingLimits.add(pending);
      return pending.future;
    }
    if (action == 'claim_nios_plus_trial') {
      final pending = Completer<dynamic>();
      pendingTrials.add(pending);
      trialRetryLimits.add(maxRetries);
      return pending.future;
    }
    return Future.value(<String, dynamic>{});
  }
}

Widget _app(
  Widget screen, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  double scale = 1,
  ProviderContainer? container,
}) {
  final content = MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: brightness),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: screen,
  );
  return container == null
      ? ProviderScope(
          overrides: [appSoundProvider.overrideWithValue(_Sound())],
          child: content,
        )
      : UncontrolledProviderScope(container: container, child: content);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'ui.optimizeWeak': true});
    final previous = UiSettingsNotifier.cachedPrefs;
    UiSettingsNotifier.cachedPrefs = await SharedPreferences.getInstance();
    addTearDown(() => UiSettingsNotifier.cachedPrefs = previous);
  });

  for (final brightness in Brightness.values) {
    for (final locale in [const Locale('en'), const Locale('ru')]) {
      testWidgets(
        'personalization is readable at 320dp / 200% $brightness $locale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (final screen in const [
            SettingsAppearanceScreen(),
            SettingsChatsScreen(),
            SettingsLanguageRegionScreen(),
            SettingsEnergySavingScreen(),
          ]) {
            await tester.pumpWidget(
              _app(screen, brightness: brightness, locale: locale, scale: 2),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(
              tester.takeException(),
              isNull,
              reason: screen.runtimeType.toString(),
            );
            await tester.drag(
              find.byType(CustomScrollView).first,
              const Offset(0, -900),
            );
            await tester.pump(const Duration(milliseconds: 400));
            expect(
              tester.takeException(),
              isNull,
              reason: screen.runtimeType.toString(),
            );
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }
        },
      );
    }
  }

  for (final brightness in Brightness.values) {
    for (final locale in [const Locale('ru'), const Locale('en')]) {
      testWidgets(
        'AI quota keeps server units and reset at 320dp / 200% $brightness $locale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final usage = AiQuota(
            limitChars: 12000,
            usedChars: 3000,
            remainingChars: 9000,
            usedPercent: 25,
            windowHours: 72,
            resetsAt: DateTime.utc(2032, 3, 4, 10),
          );
          await tester.pumpWidget(
            _app(
              Scaffold(
                body: SingleChildScrollView(
                  child: AiUsageIndicatorCard(usage: usage),
                ),
              ),
              locale: locale,
              brightness: brightness,
              scale: 2,
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(AiUsageIndicatorCard)),
          )!;
          expect(find.text(l10n.settingsAiUsagePercent('75')), findsOneWidget);
          expect(find.textContaining('2032'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(tester.binding.transientCallbackCount, 0);
          await tester.pumpWidget(
            _app(
              Scaffold(
                body: SingleChildScrollView(
                  child: AiUsageIndicatorCard(
                    usage: usage.copyWith(remainingChars: 0, usedPercent: 100),
                  ),
                ),
              ),
              locale: locale,
              brightness: brightness,
              scale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(l10n.settingsAiUsagePercent('0')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('quick reaction uses selectable controls and retains selection', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SettingsChatsScreen()));
    await tester.pumpAndSettle();
    final fire = find.byKey(const ValueKey('settings-quick-reaction-🔥'));
    await tester.ensureVisible(fire);
    await tester.tap(fire);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(fire).selected, isTrue);
    final scope = ProviderScope.containerOf(tester.element(fire));
    expect(scope.read(uiSettingsProvider).doubleTapReactionEmoji, '🔥');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'time-zone picker cancellation preserves automatic mode and search recovers',
    (tester) async {
      await tester.pumpWidget(_app(const SettingsLanguageRegionScreen()));
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(SettingsLanguageRegionScreen)),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Manual'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('settings-time-zone-search'));
      expect(search, findsOneWidget);
      await tester.enterText(search, 'no-such-isolated-time-zone');
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
      await tester.tap(find.byTooltip('Close').first);
      await tester.pumpAndSettle();
      expect(scope.read(uiSettingsProvider).timeZoneMode, AppTimeZoneMode.auto);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Manual'));
      await tester.pumpAndSettle();
      await tester.enterText(search, 'Yekaterinburg');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yekaterinburg', findRichText: false).last);
      await tester.pumpAndSettle();
      expect(
        scope.read(uiSettingsProvider).timeZoneMode,
        AppTimeZoneMode.manual,
      );
      expect(scope.read(uiSettingsProvider).timeZoneId, 'Asia/Yekaterinburg');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('time-zone sheet fits 320dp / 200% with keyboard $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        _app(
          const SettingsLanguageRegionScreen(),
          scale: 2,
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      final manual = find.widgetWithText(ChoiceChip, 'Manual');
      await tester.ensureVisible(manual);
      await tester.pumpAndSettle();
      await tester.tap(manual);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('settings-time-zone-search')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets(
    'sound preview ignores repeated taps and stops on mute or dispose',
    (tester) async {
      final sound = _Sound();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          notificationPreferencesProvider.overrideWith(_Notifications.new),
          appSoundProvider.overrideWithValue(sound),
        ],
      );
      addTearDown(container.dispose);
      container.read(uiSettingsProvider.notifier).setSoundEffects(true);
      Widget app(bool active) => _app(
        TickerMode(enabled: active, child: const SettingsPreferencesScreen()),
        container: container,
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      final preview = find.byKey(const ValueKey('settings-sound-preview'));
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      sound.events.clear();
      await tester.tap(preview);
      await tester.pump();
      await tester.tap(preview);
      await tester.pump();
      expect(
        sound.events.where((event) => event == SoundEvent.uiTap),
        hasLength(1),
      );
      container.read(uiSettingsProvider.notifier).setSoundEffects(false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(
        sound.events.where((event) => event == SoundEvent.messageReceive),
        isEmpty,
      );
      container.read(uiSettingsProvider.notifier).setSoundEffects(true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pump();
      final beforePause = tester.state(find.byType(SettingsPreferencesScreen));
      await tester.pumpWidget(app(false));
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.state(find.byType(SettingsPreferencesScreen)),
        same(beforePause),
      );
      expect(
        sound.events.where((event) => event == SoundEvent.messageReceive),
        isEmpty,
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(
        sound.events.where((event) => event == SoundEvent.messageReceive),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Plus trial coalesces taps and uncertain failure requires explicit retry',
    (tester) async {
      final socket = _Socket();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          webSocketClientProvider.overrideWithValue(socket),
          appSoundProvider.overrideWithValue(_Sound()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _app(const SettingsPlusScreen(), container: container),
      );
      await tester.pump();
      socket.pendingLimits.single.complete({
        'is_nios_plus': false,
        'nios_plus_trial_used': false,
      });
      await tester.pumpAndSettle();
      final trial = find.widgetWithText(FilledButton, 'Try free for 1 day');
      await tester.ensureVisible(trial);
      await tester.pumpAndSettle();
      await tester.tap(trial);
      await tester.pump();
      final pending = find.widgetWithText(FilledButton, 'Activating…');
      expect(tester.widget<FilledButton>(pending).onPressed, isNull);
      await tester.tap(pending);
      await tester.pump();
      expect(socket.pendingTrials, hasLength(1));
      expect(socket.trialRetryLimits, [0]);
      socket.pendingTrials.single.completeError(TimeoutException('isolated'));
      await tester.pump();
      expect(socket.pendingLimits, hasLength(2));
      socket.pendingLimits.last.complete({
        'is_nios_plus': false,
        'nios_plus_trial_used': false,
      });
      await tester.pumpAndSettle();
      expect(socket.pendingTrials, hasLength(1));
      expect(trial, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid Plus status shows retry and cannot offer a trial', (
    tester,
  ) async {
    final socket = _Socket();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        webSocketClientProvider.overrideWithValue(socket),
        appSoundProvider.overrideWithValue(_Sound()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _app(const SettingsPlusScreen(), container: container),
    );
    await tester.pump();
    socket.pendingLimits.single.complete({'unrelated': true});
    await tester.pumpAndSettle();
    expect(find.text('Try free for 1 day'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(socket.pendingTrials, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late Plus status from previous account never replaces current account',
    (tester) async {
      final socket = _Socket();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          webSocketClientProvider.overrideWithValue(socket),
          appSoundProvider.overrideWithValue(_Sound()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _app(const SettingsPlusScreen(), container: container),
      );
      await tester.pump();
      expect(socket.pendingLimits, hasLength(1));
      (container.read(authProvider.notifier) as _Auth).switchAccount();
      await tester.pump();
      expect(socket.pendingLimits, hasLength(2));
      socket.pendingLimits.last.complete({
        'is_nios_plus': true,
        'nios_plus_expires_at': '2032-03-04T10:00:00Z',
      });
      await tester.pump();
      socket.pendingLimits.first.complete({
        'is_nios_plus': true,
        'nios_plus_expires_at': '2041-01-02T10:00:00Z',
      });
      await tester.pump();
      expect(find.textContaining('2032'), findsOneWidget);
      expect(find.textContaining('2041'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
