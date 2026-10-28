import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/screens/niosgram_video_screen.dart';
import 'package:pulse_flutter/widgets/post_card.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player/video_player.dart';
import 'package:pulse_flutter/widgets/media/m3_video_controls.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
  );
}

class _Video extends VideoPlayerPlatform {
  int creates = 0, plays = 0, disposals = 0;
  Duration? lastSeek;
  double speed = 1;
  double volume = 1;
  DataSource? source;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    creates++;
    source = options.dataSource;
    return 1;
  }

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
  Future<void> pause(int id) async {}
  @override
  Future<void> seekTo(int id, Duration position) async {
    lastSeek = position;
  }

  @override
  Future<void> dispose(int id) async {
    disposals++;
  }

  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {
    volume = value;
  }

  @override
  Future<void> setPlaybackSpeed(int id, double value) async {
    speed = value;
  }

  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  testWidgets(
    'feed photo opens without closing on a tap and has a close action',
    (tester) async {
      final post = NgPost(
        id: 91,
        content: 'photo fixture',
        author: const ApiProfile(
          id: 2,
          username: 'two',
          displayName: 'Two',
          bio: '',
        ),
        createdAt: DateTime.utc(2026),
        likesCount: 0,
        dislikesCount: 0,
        commentsCount: 0,
        mediaUrls: const ['https://example.invalid/photo.jpg'],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(_Auth.new)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: PostCard(post: post)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('post-media-open-91')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Close'), findsOneWidget);
      await tester.tapAt(const Offset(400, 450));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('Close').hitTestable(), findsNothing);
      await tester.tapAt(const Offset(400, 450));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('Close'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Close'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('gallery controls keep Chewie fullscreen available', (
    tester,
  ) async {
    final old = VideoPlayerPlatform.instance;
    final video = _Video();
    VideoPlayerPlatform.instance = video;
    addTearDown(() => VideoPlayerPlatform.instance = old);
    final player = VideoPlayerController.networkUrl(
      Uri.parse('https://example.com/fixture.mp4'),
    );
    await player.initialize();
    bool? visible;
    final chewie = ChewieController(
      videoPlayerController: player,
      customControls: M3VideoOverlayControls(
        controller: player,
        onVisibilityChanged: (value) => visible = value,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Chewie(controller: chewie)),
      ),
    );
    await tester.pump();
    final videoArea = find.byType(M3VideoOverlayControls);
    final videoTap = tester.getTopLeft(videoArea) + const Offset(30, 30);
    await tester.tapAt(videoTap);
    await tester.pump(const Duration(milliseconds: 300));
    expect(visible, isFalse);
    expect(find.byTooltip('Full screen').hitTestable(), findsNothing);
    await tester.tapAt(videoTap);
    await tester.pump(const Duration(milliseconds: 300));
    expect(visible, isTrue);
    expect(find.byTooltip('Full screen'), findsOneWidget);
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
    expect(chewie.isFullScreen, isTrue);
    chewie.exitFullScreen();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    chewie.dispose();
    unawaited(player.dispose());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    expect(video.disposals, 1);
  });
  testWidgets('video controls fit large text and seek on a narrow screen', (
    tester,
  ) async {
    final old = VideoPlayerPlatform.instance;
    final video = _Video();
    VideoPlayerPlatform.instance = video;
    addTearDown(() => VideoPlayerPlatform.instance = old);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse('https://example.com/fixture.mp4'),
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(body: M3VideoPlaybackBar(controller: controller)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(video.plays, 1);
    await tester.tapAt(tester.getCenter(find.byType(Slider)));
    await tester.pump();
    expect(video.lastSeek, isNotNull);
    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5×'));
    await tester.pump();
    expect(video.speed, 1.5);
    await tester.tap(find.byTooltip('Mute'));
    await tester.pump();
    expect(video.volume, 0);
    await tester.tap(find.byTooltip('Unmute'));
    await tester.pump();
    expect(video.volume, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(controller.dispose());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    expect(video.disposals, 1);
  });
  test('shared web-client link resolves to the selected post in the app', () {
    final uri = Uri.parse(niosgramPostShareUrl(42));
    expect(uri.path, '/web/');
    expect(AppUrlLauncher.resolveInternalAppRoute(uri), '/niosgram/post/42');
  });
  testWidgets('feed video starts only on tap and disposes on exit', (
    tester,
  ) async {
    final old = VideoPlayerPlatform.instance;
    final video = _Video();
    VideoPlayerPlatform.instance = video;
    addTearDown(() => VideoPlayerPlatform.instance = old);
    final post = NgPost(
      id: 7,
      content: 'fixture',
      author: const ApiProfile(
        id: 2,
        username: 'two',
        displayName: 'Two',
        bio: '',
      ),
      createdAt: DateTime.utc(2026),
      likesCount: 0,
      dislikesCount: 0,
      commentsCount: 0,
      mediaType: 'video',
      mediaUrls: const ['https://example.com/fixture.mp4'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_Auth.new)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: PostCard(post: post)),
          ),
        ),
      ),
    );
    expect(video.creates, 0);
    await tester.tap(find.text('Open video'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(video.creates, 1);
    expect(video.plays, 0);
    expect(video.source?.httpHeaders, isEmpty);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(video.plays, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(NiosgramVideoScreen), findsNothing);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    expect(video.disposals, 1);
  });
}
