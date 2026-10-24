@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_web/video_player_web.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:web/web.dart' as web;
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/media/browser_playback_web.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/widgets/chat/video_message_preview.dart';
import '../fixtures/browser_video_fixture.dart';
import 'package:pulse_flutter/screens/onboarding_screen.dart';
import 'package:pulse_flutter/widgets/app_logo_mark.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

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

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() =>
      const UiSettingsState.defaults().copyWith(haptics: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    releaseBrowserPlayback();
    AnimatedMediaControllerPool.instance.reset();
    WsMediaFetcher.clearMemoryCache();
  });
  test(
    'encrypted media reaches a real browser decoder and Blob URLs are revoked',
    () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final bytes = base64Decode(browserVideoBase64);
      final encrypted = await E2eeFileCrypto.encrypt(bytes, key);
      final oldLoader = WsMediaFetcher.secretLocalLoader;
      WsMediaFetcher.secretLocalLoader = (_) async => encrypted;
      addTearDown(() => WsMediaFetcher.secretLocalLoader = oldLoader);
      final socket = WebSocketClient(
        baseUrl: 'https://fixture.invalid',
        readToken: () => null,
      );
      addTearDown(socket.close);
      final source = await WsMediaFetcher.acquirePlaybackSource(
        filePath: 'secret-local://preview.mp4',
        wsClient: socket,
        e2eeFileKey: key,
      );
      expect(source.filePath, isNull);
      expect(source.uri!.scheme, 'blob');
      final video = web.HTMLVideoElement()
        ..muted = true
        ..playsInline = true
        ..preload = 'auto';
      // loadeddata only promises available media data. On a busy/headless
      // browser the compositor may still have no drawable frame at that point.
      // Attach and play the muted fixture, then wait for an actual presented
      // frame instead of sampling a timing-dependent black canvas.
      video.style
        ..position = 'fixed'
        ..top = '0'
        ..left = '0'
        ..zIndex = '100000'
        ..width = '96px'
        ..height = '64px'
        ..pointerEvents = 'none';
      web.document.body!.append(video);
      final frame = Completer<void>();
      final frameRequest = video.requestVideoFrameCallback(
        ((double now, JSObject metadata) {
          if (!frame.isCompleted) frame.complete();
        }).toJS,
      );
      addTearDown(() {
        video.cancelVideoFrameCallback(frameRequest);
        video.pause();
        video.removeAttribute('src');
        video.load();
        video.remove();
      });
      final loaded = Completer<void>();
      video.addEventListener(
        'loadeddata',
        ((web.Event e) {
          if (!loaded.isCompleted) loaded.complete();
        }).toJS,
      );
      video.addEventListener(
        'error',
        ((web.Event e) {
          if (!loaded.isCompleted) {
            loaded.completeError(StateError('Decoder rejected fixture'));
          }
        }).toJS,
      );
      video.src = source.uri.toString();
      await loaded.future.timeout(const Duration(seconds: 10));
      await video.play().toDart;
      await frame.future.timeout(const Duration(seconds: 10));
      video.pause();
      expect(video.videoWidth, 96);
      expect(video.videoHeight, 64);
      expect(video.duration, closeTo(2, .1));
      final canvas = web.HTMLCanvasElement()
        ..width = 96
        ..height = 64;
      final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
      ctx.drawImage(video, 0, 0);
      final pixels = ctx.getImageData(0, 0, 96, 64).data.toDart;
      expect(
        pixels[0],
        isNot(pixels[95 * 4]),
        reason: 'The decoded first frame must contain the actual color bars',
      );
      video.src = '';
      final url = source.uri.toString();
      await source.close();
      await source.close();
      await expectLater(web.window.fetch(url.toJS).toDart, throwsA(anything));
      final other = browserPlayback(bytes, 'video/mp4');
      releaseBrowserPlayback();
      await expectLater(
        web.window.fetch(other.uri.toString().toJS).toDart,
        throwsA(anything),
      );
    },
  );

  testWidgets(
    'actual video preview decodes without autoplay and releases its decoder on removal',
    (tester) async {
      VideoPlayerPlatform.instance = VideoPlayerPlugin();
      const url = 'https://fixture.invalid/frame.mp4';
      WsMediaFetcher.putMemoryCachedBytes(
        filePath: url,
        bytes: base64Decode(browserVideoBase64),
      );
      var opens = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adaptivePerformanceProvider.overrideWith(_Performance.new),
            autoDownloadAllowedProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: VideoMessagePreview(
                    url: url,
                    name: 'frame.mp4',
                    duration: 2,
                    onOpen: () => opens++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (
        var i = 0;
        i < 375 && find.byType(VideoPlayer).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
      expect(find.byType(VideoPlayer), findsOneWidget);
      final controller = tester
          .widget<VideoPlayer>(find.byType(VideoPlayer))
          .controller;
      expect(controller.value.isInitialized, true);
      expect(controller.value.isPlaying, false);
      expect(controller.value.volume, 0);
      expect(find.text('00:02'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      expect(opens, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
      expect(AnimatedMediaControllerPool.instance.initializedCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a late failed attachment cannot release the replacement video decoder',
    (tester) async {
      VideoPlayerPlatform.instance = VideoPlayerPlugin();
      final key = Uint8List.fromList(List.generate(32, (i) => i));

      final encrypted = (await tester.runAsync(
        () => E2eeFileCrypto.encrypt(base64Decode(browserVideoBase64), key),
      ))!;
      final pending = Completer<Uint8List>();
      final started = Completer<void>();
      final oldLoader = WsMediaFetcher.secretLocalLoader;
      WsMediaFetcher.secretLocalLoader = (id) {
        if (id.contains('pending')) {
          started.complete();
          return pending.future;
        }
        return Future.value(encrypted);
      };
      addTearDown(() => WsMediaFetcher.secretLocalLoader = oldLoader);

      var url = 'secret-local://pending.mp4';
      late StateSetter update;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adaptivePerformanceProvider.overrideWith(_Performance.new),
            autoDownloadAllowedProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: StatefulBuilder(
                    builder: (_, setState) {
                      update = setState;
                      return VideoMessagePreview(
                        url: url,
                        fileKey: base64Encode(key),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 375 && !started.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
      expect(started.isCompleted, true);

      update(() => url = 'secret-local://replacement.mp4');
      await tester.pump();
      for (
        var i = 0;
        i < 375 && find.byType(VideoPlayer).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
      expect(find.byType(VideoPlayer), findsOneWidget);

      pending.completeError(
        StateError('Old attachment failed after replacement'),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(AnimatedMediaControllerPool.instance.initializedCount, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(AnimatedMediaControllerPool.instance.initializedCount, 0);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'real browser onboarding switches between columns and a compact flow; $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [uiSettingsProvider.overrideWith(_Settings.new)],
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true, brightness: brightness),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const OnboardingScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          tester.getRect(find.byType(AppLogoMark)).right,
          lessThan(tester.getRect(find.byType(PageView)).left),
        );
        expect(find.text('Continue'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.physicalSize = const Size(390, 844);
        await tester.pump();
        expect(
          tester.getRect(find.byType(AppLogoMark)).bottom,
          lessThan(tester.getRect(find.byType(PageView)).top),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
