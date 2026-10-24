import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/utils/noto_emoji.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/chat/noto_message_emoji.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';

class _Performance extends AdaptivePerformanceNotifier {
  @override
  AdaptivePerformanceState build() => const AdaptivePerformanceState(
    mode: PerformanceMode.flagship,
    targetFps: 60,
    targetFrameBudgetMs: 16.67,
    recentJankRatio: 0,
    isDegraded: false,
  );

  @override
  void setMode(PerformanceMode mode) => state = state.copyWith(mode: mode);
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults();

  @override
  void setAnimateEmoji(bool value) =>
      state = state.copyWith(animateEmoji: value);
}

class _MissingAnimationBundle extends CachingAssetBundle {
  var attempts = 0;

  @override
  Future<ByteData> load(String key) async {
    attempts++;
    throw FlutterError('Missing fixture asset');
  }
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    uiSettingsProvider.overrideWith(_Settings.new),
    adaptivePerformanceProvider.overrideWith(_Performance.new),
  ],
);

Widget _app(
  ProviderContainer container,
  Widget child, {
  bool reducedMotion = false,
  GlobalKey<NavigatorState>? navigatorKey,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    navigatorKey: navigatorKey,
    theme: ThemeData(useMaterial3: true),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);

Future<LottieComposition> _preloadRealEmoji(
  WidgetTester tester,
  String unicode,
) async {
  return (await tester.runAsync(
    () => AssetLottie(
      NotoEmoji.fromMessage(unicode)!.animationAsset!,
      bundle: rootBundle,
      decoder: LottieComposition.decodeGZip,
    ).load(),
  ))!;
}

Future<void> _pumpReady(WidgetTester tester) async {
  for (var index = 0; index < 5; index++) {
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader(NotoEmoji.fontFamily)
      ..addFont(
        rootBundle.load('assets/fonts/noto_color_emoji/NotoColorEmoji.ttf'),
      );
    await loader.load();
  });

  test(
    'real Google gzip compositions decode smiles, hearts, tones and ZWJ',
    () async {
      for (final unicode in ['😀', '❤️', '👍🏽', '🙂‍↕️']) {
        final bytes = await rootBundle.load(
          NotoEmoji.fromMessage(unicode)!.animationAsset!,
        );
        final composition = await LottieComposition.decodeGZip(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        expect(composition, isNotNull, reason: unicode);
        expect(
          composition!.duration,
          greaterThan(Duration.zero),
          reason: unicode,
        );
        expect(composition.bounds.width, greaterThan(0), reason: unicode);
        expect(composition.layers, isNotEmpty, reason: unicode);
      }
    },
  );

  testWidgets(
    'a missing animation keeps the exact Unicode visible without retry loops',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      final bundle = _MissingAnimationBundle();
      await tester.pumpWidget(
        _app(
          container,
          DefaultAssetBundle(
            bundle: bundle,
            child: Center(
              child: NotoMessageEmoji(emoji: NotoEmoji.fromMessage('❤️')!),
            ),
          ),
        ),
      );
      await _pumpReady(tester);
      expect(find.text('❤️'), findsOneWidget);
      expect(find.byType(Lottie), findsNothing);
      expect(bundle.attempts, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(bundle.attempts, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'large static Noto remains visible with emoji animation disabled',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      (container.read(uiSettingsProvider.notifier) as _Settings)
          .setAnimateEmoji(false);
      await tester.pumpWidget(
        _app(
          container,
          Center(
            child: NotoMessageEmoji(emoji: NotoEmoji.fromMessage('👍🏽')!),
          ),
        ),
      );
      await _pumpReady(tester);
      expect(find.text('👍🏽'), findsOneWidget);
      expect(find.byType(Lottie), findsNothing);
      final text = tester.widget<Text>(find.text('👍🏽'));
      expect(text.style!.fontFamily, NotoEmoji.fontFamily);
      expect(
        tester.getSize(find.byType(NotoMessageEmoji)),
        const Size(112, 112),
      );
      await tester.tap(find.byType(NotoMessageEmoji));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Lottie), findsNothing);
    },
  );

  testWidgets(
    'autoplay holds its final vector frame, a tap replays, parent gestures keep ownership',
    (tester) async {
      final composition = await _preloadRealEmoji(tester, '😀');
      final container = _container();
      addTearDown(container.dispose);
      var doubleTaps = 0;
      var longPresses = 0;
      await tester.pumpWidget(
        _app(
          container,
          Center(
            child: GestureDetector(
              onDoubleTap: () => doubleTaps++,
              onLongPress: () => longPresses++,
              child: NotoMessageEmoji(emoji: NotoEmoji.fromMessage('😀')!),
            ),
          ),
        ),
      );
      await _pumpReady(tester);
      expect(find.byType(Lottie), findsOneWidget);
      await tester.pump(
        composition.duration + const Duration(milliseconds: 100),
      );
      await tester.pump();
      expect(find.byType(Lottie), findsOneWidget);
      expect(find.text('😀'), findsNothing);
      expect(tester.widget<Lottie>(find.byType(Lottie)).controller!.value, 1);
      expect((tester.widget<Lottie>(find.byType(Lottie)).controller! as AnimationController).isAnimating, false);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Lottie), findsOneWidget);

      final settings = container.read(uiSettingsProvider.notifier) as _Settings;
      settings.setAnimateEmoji(false);
      await tester.pump();
      expect(find.byType(Lottie), findsOneWidget);
      expect(tester.widget<Lottie>(find.byType(Lottie)).controller!.value, 1);
      expect(find.text('😀'), findsNothing);
      settings.setAnimateEmoji(true);
      await tester.pump();

      await tester.tap(find.byType(NotoMessageEmoji));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(Lottie), findsOneWidget);
      await tester.pump(
        composition.duration + const Duration(milliseconds: 100),
      );
      await tester.pump();
      await tester.tap(find.byType(NotoMessageEmoji));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byType(NotoMessageEmoji));
      await tester.pump(const Duration(milliseconds: 350));
      expect(doubleTaps, 1);
      expect(find.byType(Lottie), findsOneWidget);
      await tester.longPress(find.byType(NotoMessageEmoji));
      await tester.pump();
      expect(longPresses, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'vector playback budget follows performance tiers and reduced motion',
    (tester) async {
      await _preloadRealEmoji(tester, '😀');
      final container = _container();
      addTearDown(container.dispose);
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 3; index++)
            NotoMessageEmoji(emoji: NotoEmoji.fromMessage('😀')!),
        ],
      );
      await tester.pumpWidget(_app(container, Center(child: row)));
      await _pumpReady(tester);
      expect(find.byType(Lottie), findsNWidgets(2));
      final performance =
          container.read(adaptivePerformanceProvider.notifier) as _Performance;
      performance.setMode(PerformanceMode.balanced);
      await _pumpReady(tester);
      expect(find.byWidgetPredicate((w) => w is Lottie && (w.controller! as AnimationController).isAnimating), findsOneWidget);
      performance.setMode(PerformanceMode.powerSaver);
      await _pumpReady(tester);
      expect(find.byType(Lottie), findsNothing);
      expect(find.text('😀'), findsNWidgets(3));
      performance.setMode(PerformanceMode.flagship);
      await tester.pumpWidget(
        _app(container, Center(child: row), reducedMotion: true),
      );
      await _pumpReady(tester);
      expect(find.byType(Lottie), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'any scrolling, hidden routes and app background stop animation',
    (tester) async {
      await _preloadRealEmoji(tester, '😀');
      final container = _container();
      addTearDown(container.dispose);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _app(
          container,
          ScrollNotificationObserver(
            child: ListView(
              controller: scroll,
              children: [
                NotoMessageEmoji(emoji: NotoEmoji.fromMessage('😀')!),
                const SizedBox(height: 1600),
              ],
            ),
          ),
          navigatorKey: navigator,
        ),
      );
      await _pumpReady(tester);
      expect(find.byType(Lottie), findsOneWidget);
      final gesture = await tester.startGesture(const Offset(50, 90));
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      expect(scroll.position.isScrollingNotifier.value, isTrue);
      expect(find.byType(Lottie), findsOneWidget);
      expect((tester.widget<Lottie>(find.byType(Lottie)).controller! as AnimationController).isAnimating, false);
      await gesture.up();
      await tester.pumpAndSettle();
      // Start a fresh finite replay before checking each pause condition.
      await tester.tap(find.byType(NotoMessageEmoji));
      await tester.pump(const Duration(milliseconds: 350));
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Cover')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Lottie, skipOffstage: false), findsNothing);
      navigator.currentState!.pop();
      await _pumpReady(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byType(Lottie), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only a single emoji-only message leaves the rich text path', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    (container.read(uiSettingsProvider.notifier) as _Settings).setAnimateEmoji(
      false,
    );
    Widget bubble(String text, {String? mediaUrl}) => MessageBubble(
      text: text,
      formattedTime: '12:00',
      isMine: true,
      chatId: 1,
      mediaUrl: mediaUrl,
    );
    await tester.pumpWidget(_app(container, bubble('❤️')));
    await _pumpReady(tester);
    expect(find.byType(NotoMessageEmoji), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    await tester.pumpWidget(
      _app(container, bubble('**bold** ❤️ https://ni-os.ru')),
    );
    await _pumpReady(tester);
    expect(find.byType(NotoMessageEmoji), findsNothing);
    expect(find.byType(InteractiveMessageText), findsOneWidget);
    await tester.pumpWidget(_app(container, bubble('❤️❤️')));
    await _pumpReady(tester);
    expect(find.byType(NotoMessageEmoji), findsNothing);
  });
}
