import 'package:flutter/services.dart';
import 'dart:ui' show Tristate;
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
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/services/settings/settings_registry.dart';
import 'package:pulse_flutter/l10n/app_localizations_ru.dart';
import 'package:pulse_flutter/l10n/app_localizations_en.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
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
