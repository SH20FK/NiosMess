import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/media/media_playback_visibility.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_sticker_player.dart';

class _Performance extends AdaptivePerformanceNotifier {
  @override
  AdaptivePerformanceState build() => const AdaptivePerformanceState(
    mode: PerformanceMode.powerSaver,
    targetFps: 60,
    targetFrameBudgetMs: 16.67,
    recentJankRatio: 0,
    isDegraded: false,
  );
  @override
  void setMode(PerformanceMode mode) => state = state.copyWith(mode: mode);
}

void main() {
  final pool = AnimatedMediaControllerPool.instance;
  setUp(pool.reset);
  tearDown(pool.reset);

  testWidgets(
    'real repeated GIF widgets gate decoding before creation and pause on fling',
    (tester) async {
      final container = ProviderContainer(
        overrides: [adaptivePerformanceProvider.overrideWith(_Performance.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    const SizedBox(
                      width: 100,
                      height: 100,
                      child: StickerVideoPlayer(
                        url: 'https://test.invalid/repeated.gif',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(pool.initializedCount, 0);
      expect(find.byType(CachedNetworkImage), findsNothing);
      final performance =
          container.read(adaptivePerformanceProvider.notifier) as _Performance;
      performance.setMode(PerformanceMode.flagship);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(pool.initializedCount, 2);
      expect(pool.activeCount, 2);
      expect(find.byType(CachedNetworkImage), findsNWidgets(2));
      pool.setFastScrolling(true);
      await tester.pump();
      expect(pool.initializedCount, 0);
      expect(find.byType(CachedNetworkImage), findsNothing);
      pool.setFastScrolling(false);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(pool.initializedCount, 2);
      performance.setMode(PerformanceMode.powerSaver);
      await tester.pump();
      expect(pool.initializedCount, 0);
      expect(find.byType(CachedNetworkImage), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(pool.posterCount, 0);
    },
  );

  test(
    'retained posters obey both count and byte budgets and evict their owners',
    () {
      var evictions = 0;
      for (var i = 0; i < 10; i++) {
        expect(
          pool.retainPoster(
            id: Object(),
            bytes: 100,
            onEvict: () => evictions++,
          ),
          isTrue,
        );
      }
      expect(pool.posterCount, AnimatedMediaControllerPool.maxPosterCount);
      expect(pool.posterBytes, 800);
      expect(evictions, 2);
      pool.reset();
      expect(pool.posterBytes, 0);
      expect(evictions, 10);
      for (var i = 0; i < 3; i++) {
        pool.retainPoster(
          id: Object(),
          bytes: 1024 * 1024,
          onEvict: () => evictions++,
        );
      }
      expect(pool.posterBytes, AnimatedMediaControllerPool.maxPosterBytes);
      expect(pool.posterCount, 2);
      expect(
        pool.retainPoster(id: Object(), bytes: 3 * 1024 * 1024, onEvict: () {}),
        isFalse,
      );
    },
  );

  test(
    'separate instances reserve codecs before playing and release independently',
    () async {
      final tokens = [Object(), Object()];
      var released = 0;
      for (final token in tokens) {
        expect(
          await pool.acquireInitialization(
            id: token,
            tier: PerformanceTier.tierA,
            onRelease: () async {
              released++;
            },
          ),
          isTrue,
        );
        expect(
          pool.requestPlay(
            id: token,
            tier: PerformanceTier.tierA,
            onPause: () {},
            onResume: () {},
          ),
          isTrue,
        );
      }
      expect(pool.initializedCount, 2);
      expect(pool.activeCount, 2);
      await pool.release(tokens.first);
      expect(pool.initializedCount, 1);
      expect(pool.activeCount, 1);
      expect(released, 1);
    },
  );

  test(
    'replacement waits for native disposal and tier C creates no codecs',
    () async {
      final disposal = Completer<void>();
      expect(
        await pool.acquireInitialization(
          id: Object(),
          tier: PerformanceTier.tierB,
          onRelease: () => disposal.future,
        ),
        isTrue,
      );
      var secondGranted = false;
      final second = pool
          .acquireInitialization(
            id: Object(),
            tier: PerformanceTier.tierB,
            onRelease: () async {},
          )
          .then((value) {
            secondGranted = value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(secondGranted, isFalse);
      disposal.complete();
      await second;
      expect(secondGranted, isTrue);
      expect(
        await pool.acquireInitialization(
          id: Object(),
          tier: PerformanceTier.tierC,
          onRelease: () async {},
        ),
        isFalse,
      );
      expect(pool.initializedCount, 1);
    },
  );

  test(
    'scroll sources cannot clear each other and manual playback wins',
    () async {
      final auto = Object();
      final manual = Object();
      var released = false;
      await pool.acquireInitialization(
        id: auto,
        tier: PerformanceTier.tierA,
        onRelease: () async {
          released = true;
        },
      );
      final firstScroll = Object();
      final secondScroll = Object();
      pool.setFastScrolling(true, source: firstScroll);
      pool.setFastScrolling(true, source: secondScroll);
      pool.setFastScrolling(false, source: firstScroll);
      expect(pool.isFastScrolling, isTrue);
      expect(pool.initializedCount, 0);
      expect(released, isTrue);
      expect(
        await pool.acquireInitialization(
          id: manual,
          tier: PerformanceTier.tierC,
          isUserInitiated: true,
          onRelease: () async {},
        ),
        isTrue,
      );
      pool.setFastScrolling(false, source: secondScroll);
      expect(
        await pool.acquireInitialization(
          id: auto,
          tier: PerformanceTier.tierA,
          onRelease: () async {},
        ),
        isFalse,
      );
      expect(pool.initializedCount, 1);
    },
  );

  testWidgets(
    'cached sliver, hidden route and background do not count as visible',
    (tester) async {
      final changes = <bool>[];
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: ScrollNotificationObserver(
            child: ListView(
              controller: scroll,
              scrollCacheExtent: const ScrollCacheExtent.pixels(1000),
              children: [
                const SizedBox(height: 900),
                MediaPlaybackVisibility(
                  onChanged: changes.add,
                  child: const SizedBox(height: 120),
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(changes, isEmpty);
      scroll.jumpTo(800);
      await tester.pump();
      expect(changes.last, isTrue);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('another route')),
        ),
      );
      await tester.pumpAndSettle();
      expect(changes.last, isFalse);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(changes.last, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(changes.last, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(changes.last, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
