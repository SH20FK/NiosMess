import 'dart:async';
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
  Future<void> dispose(int id) async {
    disposals++;
  }

  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
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
