import 'package:pulse_flutter/features/security/application/app_lock_controller.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/widgets/settings/account_security_section.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show PointerDeviceKind, Tristate;
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/application/settings_anchor_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_save_failure_listener.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/services/settings/settings_registry.dart';
import 'package:pulse_flutter/l10n/app_localizations_ru.dart';
import 'package:pulse_flutter/l10n/app_localizations_en.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/screens/settings_storage_screen.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/widgets/settings/privacy_rule_row.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/widgets/motion/m3_staggered_list.dart';
import 'package:pulse_flutter/widgets/settings/settings_async_switcher.dart';
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

class _Sound extends SoundService {
  final List<SoundEvent> events = <SoundEvent>[];

  @override
  Future<void> playEvent(SoundEvent event, {double? volume}) async {
    events.add(event);
  }
}

class _ForbiddenAppLock extends AppLockNotifier {
  @override
  AppLockState build() =>
      throw StateError('Native biometrics must not initialize in a browser');
}

class _Storage extends StorageSnapshotNotifier {
  @override
  Future<LocalStorageSnapshot> build() async =>
      const LocalStorageSnapshot.empty();
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
                child: AccountSecuritySection(),
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

    testWidgets('a choice ticks once for a new answer and not for the same', (
      tester,
    ) async {
      final sound = _Sound();
      var value = 1;
      await tester.pumpWidget(
        _app(
          ProviderScope(
            overrides: [appSoundProvider.overrideWithValue(sound)],
            child: StatefulBuilder(
              builder: (context, update) => SettingsChoiceButtons<int>(
                segments: const [
                  ButtonSegment<int>(value: 1, label: Text('One')),
                  ButtonSegment<int>(value: 2, label: Text('Two')),
                ],
                selected: {value},
                onSelectionChanged: (picked) =>
                    update(() => value = picked.first),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(value, 2);
      expect(sound.events, [SoundEvent.uiTap]);

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(sound.events, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading gives way to data with a cross-fade', (tester) async {
      Widget form(AsyncValue<int> value) => _app(
        SettingsAsyncSwitcher<int>(
          value: value,
          data: (loaded) => Text('Loaded $loaded'),
          loading: () => const Text('Loading form'),
          error: (_, _) => const Text('Error form'),
        ),
      );
      await tester.pumpWidget(form(const AsyncLoading<int>()));
      expect(find.text('Loading form'), findsOneWidget);

      await tester.pumpWidget(form(const AsyncData<int>(7)));
      await tester.pump(const Duration(milliseconds: 60));
      // Mid-flight both forms are on screen: one leaving, one arriving.
      expect(find.text('Loading form'), findsOneWidget);
      expect(find.text('Loaded 7'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Loading form'), findsNothing);
      expect(find.text('Loaded 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rows of a staggered group rise one after another', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SettingsSection(
            stagger: true,
            children: [
              for (var i = 0; i < 3; i++)
                SettingsListItem.nav(
                  icon: Icons.tune_rounded,
                  title: 'Row $i',
                  onTap: () {},
                ),
            ],
          ),
        ),
      );
      expect(find.byType(M3StaggeredItem), findsNWidgets(3));
      // The third row has not started yet while the first is on its way.
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('Row 2'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        lessThan(1),
      );

      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(find.text('Row $i').hitTestable(), findsOneWidget);
      }
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the open section stands alone with full corners', (
      tester,
    ) async {
      Widget list(int selected) => _app(
        SettingsSection(
          selectedIndex: selected,
          children: [
            for (var i = 0; i < 3; i++)
              SettingsListItem.nav(
                icon: Icons.tune_rounded,
                title: 'Row $i',
                isSelected: i == selected,
                onTap: () {},
              ),
          ],
        ),
      );
      BorderRadius? shapeOf(int row) => tester
          .widget<PressableSurface>(
            find.ancestor(
              of: find.text('Row $row'),
              matching: find.byType(PressableSurface),
            ),
          )
          .borderRadius;
      Color? tileOf(int row) => tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.text('Row $row'),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;

      await tester.pumpWidget(list(1));
      await tester.pumpAndSettle();
      final outer = SettingsSection.outerRadius(
        tester.element(find.text('Row 1')),
      );
      final connectedMiddle = BorderRadius.circular(4);
      expect(shapeOf(1), BorderRadius.circular(outer));
      expect(shapeOf(1), isNot(connectedMiddle));
      expect(
        shapeOf(0),
        BorderRadius.vertical(
          top: Radius.circular(outer),
          bottom: const Radius.circular(4),
        ),
      );
      // No squarer tile shows behind the rounder corners.
      expect(tileOf(1), Colors.transparent);
      expect(tileOf(0), isNot(Colors.transparent));

      // Selection moves on: the old row rejoins the group, the new one leaves.
      await tester.pumpWidget(list(2));
      await tester.pumpAndSettle();
      expect(shapeOf(1), connectedMiddle);
      expect(shapeOf(2), BorderRadius.circular(outer));
      expect(tileOf(1), isNot(Colors.transparent));
      expect(tester.takeException(), isNull);
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
        await prefs.setDouble('ui.soundVolume', 0.4);
        await tester.pumpWidget(
          _app(const SettingsAppearanceScreen(isEmbedded: true), font: 2),
        );
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsAppearanceScreen)),
        );
        // The radii became a page of their own; the row that opens it is the
        // anchor search lands on. Before the request it sits quiet, like the
        // collapsed disclosure it replaced.
        final Finder radiusRow = find.byKey(
          const ValueKey<String>('ui_corner_radius'),
        );
        expect(radiusRow, findsOneWidget);
        Color? rowHighlight() =>
            (tester.widget<AnimatedContainer>(radiusRow).decoration
                as BoxDecoration)
                .color;
        expect(rowHighlight(), Colors.transparent);
        container
            .read(settingsAnchorControllerProvider.notifier)
            .request(route: '/settings/appearance', anchor: 'ui_corner_radius');
        await tester.pumpAndSettle();
        // The row itself answered: highlighted and scrolled into view, with
        // no page pushed over the screen the user was reading.
        expect(rowHighlight(), isNot(Colors.transparent));
        expect(tester.getRect(radiusRow).top, lessThan(844));
        expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        // The highlight expires; the row it brought into view stays.
        expect(rowHighlight(), Colors.transparent);
        expect(radiusRow, findsOneWidget);
        expect(container.read(uiSettingsProvider).messageBubbleRadius, 24);
        expect(container.read(uiSettingsProvider).soundVolume, 0.4);
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

    testWidgets('photos and videos keep their own auto-download switches', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _app(
          ProviderScope(
            overrides: [storageSnapshotProvider.overrideWith(_Storage.new)],
            child: const SettingsStorageScreen(isEmbedded: true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsStorageScreen)),
      );
      Finder switchOf(String anchor) => find.descendant(
        of: find.byKey(ValueKey<String>(anchor)),
        matching: find.byType(Switch),
      );
      bool valueOf(String anchor) =>
          tester.widget<Switch>(switchOf(anchor)).value;

      const List<String> anchors = <String>[
        'auto_download_wifi',
        'auto_download_cellular',
        'auto_download_video_wifi',
        'auto_download_video_cellular',
      ];
      for (final String anchor in anchors) {
        expect(switchOf(anchor), findsOneWidget, reason: anchor);
      }
      expect(valueOf('auto_download_wifi'), isTrue);
      expect(valueOf('auto_download_video_wifi'), isTrue);

      // Turning photos off over Wi-Fi leaves videos alone.
      await tester.ensureVisible(switchOf('auto_download_wifi'));
      await tester.tap(switchOf('auto_download_wifi'));
      await tester.pumpAndSettle();

      final UiSettingsState state = container.read(uiSettingsProvider);
      expect(state.autoDownloadPhotoWifi, isFalse);
      expect(state.autoDownloadVideoWifi, isTrue);
      expect(valueOf('auto_download_wifi'), isFalse);
      expect(valueOf('auto_download_video_wifi'), isTrue);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

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
