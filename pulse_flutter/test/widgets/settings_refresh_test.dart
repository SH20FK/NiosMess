import 'package:pulse_flutter/features/security/application/app_lock_controller.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/widgets/settings/account_security_section.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show PointerDeviceKind, Tristate;
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/application/settings_anchor_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_save_failure_listener.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/services/settings/settings_registry.dart';
import 'package:pulse_flutter/l10n/app_localizations_ru.dart';
import 'package:pulse_flutter/l10n/app_localizations_en.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/widgets/settings/privacy_rule_row.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_sticker_player.dart';

class _Performance extends AdaptivePerformanceNotifier {
  @override
  AdaptivePerformanceState build() => const AdaptivePerformanceState(
    mode: PerformanceMode.balanced,
    targetFps: 60,
    targetFrameBudgetMs: 16.67,
    recentJankRatio: 0,
    isDegraded: false,
  );
}

class _Privacy extends PrivacyNotifier {
  final List<(String, PrivacyPolicy)> writes = <(String, PrivacyPolicy)>[];
  bool fail = false;

  @override
  PrivacyState build() => const PrivacyState(
    rules: <String, PrivacyRule>{
      'calls': PrivacyRule(key: 'calls', policy: PrivacyPolicy.contacts),
    },
  );

  @override
  Future<void> updateRule({
    required String key,
    required PrivacyPolicy policy,
    List<int>? alwaysAllow,
    List<int>? neverAllow,
  }) async {
    writes.add((key, policy));
    if (fail) throw StateError('synthetic failure');
    state = state.copyWith(
      rules: <String, PrivacyRule>{
        ...state.rules,
        key: PrivacyRule(key: key, policy: policy),
      },
    );
  }
}

class _ForbiddenAppLock extends AppLockNotifier {
  @override
  AppLockState build() =>
      throw StateError('Native biometrics must not initialize in a browser');
}

class _Video extends VideoPlayerPlatform {
  int plays = 0, pauses = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int id) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 2),
      size: const Size(96, 64),
    ),
  );
  @override
  Future<void> play(int id) async {
    plays++;
  }

  @override
  Future<void> pause(int id) async {
    pauses++;
  }

  @override
  Future<void> dispose(int id) async {}
  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Color(0xff987654));
}

Widget _app(
  Widget child, {
  double font = 1,
  Brightness brightness = Brightness.light,
  String lang = 'ru',
}) => ProviderScope(
  overrides: [adaptivePerformanceProvider.overrideWith(_Performance.new)],
  child: MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff006c5b),
        brightness: brightness,
      ),
    ),
    locale: Locale(lang),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(font)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('Settings refresh', () {
    testWidgets(
      'browser security settings do not initialize native biometrics',
      (tester) async {
        await tester.pumpWidget(
          _app(
            ProviderScope(
              overrides: [
                clientCapabilitiesProvider.overrideWithValue(
                  const ClientCapabilities(
                    isWeb: true,
                    platform: TargetPlatform.windows,
                  ),
                ),
                appLockProvider.overrideWith(_ForbiddenAppLock.new),
              ],
              child: const SingleChildScrollView(
                child: AccountSecuritySection(isEmbedded: true),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(Switch), findsNothing);
        // The portal link stays, but it no longer promises 2FA: Nios ID does
        // not ask for a second factor at sign-in.
        expect(find.textContaining('2FA'), findsNothing);
        expect(find.textContaining('Nios ID'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('navigation rows activate with a keyboard', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SettingsListItem.nav(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a loading indicator speaks only when it is given a label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              AppLoadingIndicator(size: 28, semanticsLabel: 'Loading data'),
              AppLoadingIndicator(size: 28),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Loading data'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Loading data'))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('a privacy rule is chosen from a menu on its own row', (
      tester,
    ) async {
      final privacy = _Privacy();
      await tester.pumpWidget(
        _app(
          ProviderScope(
            overrides: [privacyProvider.overrideWith(() => privacy)],
            child: const PrivacyRuleRow(
              ruleKey: 'calls',
              anchor: 'privacy.calls',
              icon: Icons.call_rounded,
              title: 'Calls',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Мои контакты'), findsOneWidget);

      await tester.tap(find.text('Calls'));
      await tester.pumpAndSettle();
      // All three answers, and the way to per-person exceptions.
      expect(find.text('Все'), findsOneWidget);
      expect(find.text('Никто'), findsOneWidget);
      expect(find.text('Исключения'), findsOneWidget);

      await tester.tap(find.text('Никто'));
      await tester.pumpAndSettle();
      expect(privacy.writes, [('calls', PrivacyPolicy.nobody)]);
      expect(find.text('Никто'), findsOneWidget);
      expect(find.text('Мои контакты'), findsNothing);

      // Picking the current answer again writes nothing.
      await tester.tap(find.text('Calls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Никто').last);
      await tester.pumpAndSettle();
      expect(privacy.writes, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refused privacy rule says so and keeps the old answer', (
      tester,
    ) async {
      final privacy = _Privacy()..fail = true;
      await tester.pumpWidget(
        _app(
          ProviderScope(
            overrides: [privacyProvider.overrideWith(() => privacy)],
            child: const PrivacyRuleRow(
              ruleKey: 'calls',
              anchor: 'privacy.calls',
              icon: Icons.call_rounded,
              title: 'Calls',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Calls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Все'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(privacy.writes, [('calls', PrivacyPolicy.everyone)]);
      expect(find.text('Мои контакты'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled row shows its reason in place of the hint', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          SettingsListItem.toggle(
            icon: Icons.volume_up_outlined,
            title: 'Sound',
            subtitle: 'Plays with each message',
            value: true,
            enabled: false,
            disabledReason: 'Turn on notifications first',
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Turn on notifications first'), findsOneWidget);
      expect(find.text('Plays with each message'), findsNothing);
      expect(
        tester
            .getSemantics(find.byType(SettingsListItem))
            .getSemanticsData()
            .label,
        'Sound, Turn on notifications first',
      );
      semantics.dispose();
    });

    testWidgets('a pending row says it is loading', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const SettingsListItem(
            type: SettingsListItemType.value,
            icon: Icons.workspace_premium_rounded,
            title: 'Nios+',
            pending: true,
          ),
        ),
      );
      await tester.pump();
      final label = tester
          .getSemantics(find.byType(SettingsListItem))
          .getSemanticsData()
          .label;
      expect(label, startsWith('Nios+, '));
      expect(label.length, greaterThan('Nios+, '.length));
      semantics.dispose();
    });

    testWidgets('a refused save is announced and can be asked again', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _app(const SettingsSaveFailureListener(child: SizedBox.expand())),
      );
      ProviderScope.containerOf(
            tester.element(find.byType(SettingsSaveFailureListener)),
          )
          .read(settingsSaveFailureProvider.notifier)
          .report(SettingsSaveFailure(() => retries++));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('Не удалось сохранить настройку'),
        findsOneWidget,
      );
      await tester.tap(find.byType(SnackBarAction));
      await tester.pump();
      expect(retries, 1);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'ui.haptics': false,
        'ui.soundEffects': false,
        'ui.optimizeWeak': false,
      });
      UiSettingsNotifier.cachedPrefs = await SharedPreferences.getInstance();
    });
    tearDown(() {
      UiSettingsNotifier.cachedPrefs = null;
      AnimatedMediaControllerPool.instance.reset();
    });

    testWidgets(
      'row and switch expose one toggle and each tap changes it once',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var changes = 0;
        var value = false;
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, update) => SettingsListItem.toggle(
                icon: Icons.notifications_outlined,
                title: 'Notification setting',
                value: value,
                onChanged: (next) => update(() {
                  value = next;
                  changes++;
                }),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Notification setting'));
        await tester.pumpAndSettle();
        expect(changes, 1);
        expect(value, isTrue);
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(changes, 2);
        expect(value, isFalse);
        final nodes = <SemanticsData>[];
        void visit(SemanticsNode node) {
          final data = node.getSemanticsData();
          if (!node.isMergedIntoParent &&
              data.flagsCollection.isToggled != Tristate.none) {
            nodes.add(data);
          }
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        var root = tester.getSemantics(find.byType(SettingsListItem));
        while (root.parent != null) {
          root = root.parent!;
        }
        visit(root);
        expect(nodes, hasLength(1));
        expect(nodes.single.label, 'Notification setting');
        semantics.dispose();
      },
    );

    testWidgets('a switch row is one Tab stop and Space flips it once', (
      tester,
    ) async {
      var changes = 0;
      var taps = 0;
      var value = false;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, update) => Column(
              children: [
                SettingsListItem.toggle(
                  icon: Icons.notifications_outlined,
                  title: 'Notification setting',
                  value: value,
                  onChanged: (next) => update(() {
                    value = next;
                    changes++;
                  }),
                ),
                SettingsListItem.nav(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  onTap: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(value, isTrue);
      // The switch is not a stop of its own: the next Tab is the next row.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(changes, 1);
    });

    testWidgets('a row reads its title, hint and value as one label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          SettingsListItem.nav(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: 'Follows the system',
            value: 'Dark',
            onTap: () {},
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(SettingsListItem))
          .getSemanticsData();
      expect(data.label, 'Theme, Follows the system, Dark');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });

    testWidgets('a row answers the pointer with a hover tone', (tester) async {
      await tester.pumpWidget(
        _app(
          SettingsListItem.nav(
            icon: Icons.palette_outlined,
            title: 'Theme',
            onTap: () {},
          ),
        ),
      );
      Color? fill() =>
          (tester
                      .widget<AnimatedContainer>(
                        find
                            .descendant(
                              of: find.byType(PressableSurface),
                              matching: find.byType(AnimatedContainer),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      expect(fill(), const Color(0x00000000));

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: const Offset(400, 500));
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Theme')));
      await tester.pump();
      expect(fill(), isNot(const Color(0x00000000)));

      await gesture.moveTo(const Offset(400, 500));
      await tester.pump();
      expect(fill(), const Color(0x00000000));
    });

    testWidgets('the shell keeps content clear of the gesture bar and cutout', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(left: 12, bottom: 34),
              ),
              child: const SettingsShell(
                title: 'Section',
                isEmbedded: true,
                children: [SizedBox(height: 10)],
              ),
            ),
          ),
        ),
      );
      final padding =
          tester.widget<SliverPadding>(find.byType(SliverPadding)).padding
              as EdgeInsets;
      expect(padding.left, 16 + 12);
      expect(padding.right, 16);
      expect(padding.bottom, 32 + 34);
    });

    testWidgets(
      'ordinary icons are neutral and selected rows use paired tonal colors',
      (tester) async {
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                SettingsListItem.nav(
                  icon: Icons.palette_outlined,
                  title: 'Theme',
                  isSelected: true,
                  onTap: () {},
                ),
                SettingsRow(
                  leading: const Icon(
                    Icons.storage_outlined,
                    color: Color(0xffff00ff),
                  ),
                  title: 'Storage',
                  control: const ValueControl('128 MB'),
                ),
              ],
            ),
          ),
        );
        final context = tester.element(find.text('Theme'));
        final scheme = Theme.of(context).colorScheme;
        expect(
          tester.widget<Text>(find.text('Theme')).style!.color,
          scheme.onSecondaryContainer,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.storage_outlined)).color,
          scheme.onSurfaceVariant,
        );
      },
    );

    for (final brightness in Brightness.values) {
      for (final lang in ['ru', 'en']) {
        for (final page in ['appearance', 'language']) {
          testWidgets('$page at 360dp and 200% text: $lang / $brightness', (
            tester,
          ) async {
            tester.view.physicalSize = const Size(360, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              _app(
                page == 'appearance'
                    ? const SettingsAppearanceScreen(isEmbedded: true)
                    : const SettingsLanguageRegionScreen(isEmbedded: true),
                font: 2,
                brightness: brightness,
                lang: lang,
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
            expect(tester.takeException(), isNull);
            for (var i = 0; i < 8; i++) {
              await tester.drag(
                find.byType(CustomScrollView).first,
                const Offset(0, -400),
              );
              await tester.pump(const Duration(milliseconds: 400));
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
          });
        }
      }
    }

    testWidgets(
      'search opens advanced controls on the current screen and preserves legacy values',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prefs = UiSettingsNotifier.cachedPrefs!;
        await prefs.setDouble('ui.messageBubbleRadius', 24);
        await prefs.setBool('ui.saveGalleryPrivate', true);
        await tester.pumpWidget(
          _app(const SettingsAppearanceScreen(isEmbedded: true), font: 2),
        );
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsAppearanceScreen)),
        );
        expect(
          tester
              .widget<ExpansionTile>(find.byType(ExpansionTile))
              .controller!
              .isExpanded,
          isFalse,
        );
        container
            .read(settingsAnchorControllerProvider.notifier)
            .request(route: '/settings/appearance', anchor: 'ui_corner_radius');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ExpansionTile>(find.byType(ExpansionTile))
              .controller!
              .isExpanded,
          isTrue,
        );
        expect(tester.getRect(find.byType(ExpansionTile)).top, lessThan(844));
        await tester.pump(const Duration(seconds: 2));
        expect(
          tester
              .widget<ExpansionTile>(find.byType(ExpansionTile))
              .controller!
              .isExpanded,
          isTrue,
        );
        expect(container.read(uiSettingsProvider).messageBubbleRadius, 24);
        expect(container.read(uiSettingsProvider).saveToGalleryPrivate, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    test(
      'moved search destinations resolve in both languages without obsolete flags',
      () {
        for (final l in [AppLocalizationsRu(), AppLocalizationsEn()]) {
          for (final query in ['microphone', 'микрофон']) {
            final result = SettingsRegistry.search(
              query,
              l,
            ).firstWhere((r) => r.node.id == 'chats.callDevices');
            expect(result.targetSectionId, SettingsSectionId.chats);
            expect(result.anchor, 'chats.callDevices');
          }
          final wifi = SettingsRegistry.search(
            'wifi',
            l,
          ).firstWhere((r) => r.node.id == 'auto_download_wifi');
          expect(wifi.targetSectionId, SettingsSectionId.storage);
          expect(
            SettingsRegistry.getAllNodes().any(
              (n) => n.id == 'bubble_radius' || n.id == 'hide_online',
            ),
            isFalse,
          );
        }
      },
    );

    testWidgets(
      'sticker preference pauses and resumes a live video controller',
      (tester) async {
        final previous = VideoPlayerPlatform.instance;
        final platform = _Video();
        VideoPlayerPlatform.instance = platform;
        addTearDown(() => VideoPlayerPlatform.instance = previous);
        await tester.pumpWidget(
          _app(
            const Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: StickerVideoPlayer(
                  url: 'https://fixture.invalid/sticker.webm',
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(platform.plays, greaterThan(0));
        expect(AnimatedMediaControllerPool.instance.activeCount, 1);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(StickerVideoPlayer)),
        );
        final plays = platform.plays;
        container.read(uiSettingsProvider.notifier).setAnimateStickers(false);
        await tester.pump(const Duration(milliseconds: 100));
        expect(platform.pauses, greaterThan(0));
        expect(platform.plays, plays);
        expect(AnimatedMediaControllerPool.instance.activeCount, 0);
        container.read(uiSettingsProvider.notifier).setAnimateStickers(true);
        await tester.pump(const Duration(milliseconds: 100));
        expect(platform.plays, greaterThan(plays));
        expect(AnimatedMediaControllerPool.instance.activeCount, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(AnimatedMediaControllerPool.instance.initializedCount, 0);
      },
    );
  });
}
