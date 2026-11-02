import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';
import 'package:pulse_flutter/providers/feed_poll_vote_provider.dart';
import 'package:pulse_flutter/widgets/feed_poll_card.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/screens/post_comments_screen.dart';
import 'package:universal_io/io.dart';

const _poll = <String, dynamic>{
  'kind': 'quiz',
  'title': 'Question',
  'items': ['One', 'Two'],
  'my_choices': <int>[],
  'counts': [0, 0],
  'total_voters': 0,
};
Map<String, dynamic> _confirmed() => {
  ..._poll,
  'my_choices': [0],
  'counts': [1, 0],
  'total_voters': 1,
  'correct': 1,
  'explanation': 'Confirmed only',
};

class _Auth extends AuthNotifier {
  bool loggingOut = false;
  @override
  bool get isLoggingOut => loggingOut;
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'test-only-a',
      userId: 1,
      username: 'a',
      displayName: 'A',
    ),
  );
  void clearAccount() => state = const AuthState.initial();
  void switchAccount() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'test-only-b',
      userId: 2,
      username: 'b',
      displayName: 'B',
    ),
  );
}

class _EmptyFeed extends NiosgramNotifier {
  @override
  Future<NiosgramState> build() async => const NiosgramState();
  @override
  Future<void> refresh() async {}
}

class _EmptyComments extends PostCommentsNotifier {
  _EmptyComments(super.args);
  @override
  Future<List<ApiMessage>> build() async => [];
}

void main() {
  test(
    'logout and unauthenticated session reject selection and vote before any request',
    () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          customEmojiRequestProvider.overrideWithValue((_, _) async {
            calls++;
            return {'poll': _confirmed()};
          }),
        ],
      );
      addTearDown(container.dispose);
      final auth = container.read(authProvider.notifier) as _Auth;
      final votes = container.read(feedPollVotesProvider.notifier);
      auth.loggingOut = true;
      votes.select(42, _poll, {0});
      await votes.vote(42, _poll, {0});
      expect(calls, 0);
      expect(container.read(feedPollVotesProvider), isEmpty);
      auth.loggingOut = false;
      auth.clearAccount();
      final guestVotes = container.read(feedPollVotesProvider.notifier);
      guestVotes.select(42, _poll, {0});
      await guestVotes.vote(42, _poll, {0});
      expect(calls, 0);
      expect(container.read(feedPollVotesProvider), isEmpty);
    },
  );
  for (final malformed in [
    <String, dynamic>{
      'items': [1, 2],
    },
    {'correct': 'bad'},
    {
      'counts': [double.nan, 0],
    },
  ]) {
    test(
      'malformed typed poll response keeps safe source and selection: $malformed',
      () async {
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            customEmojiRequestProvider.overrideWithValue(
              (_, _) async => {
                'poll': {..._confirmed(), ...malformed},
              },
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(feedPollVotesProvider.notifier).vote(42, _poll, {
          0,
        });
        final state = container.read(feedPollVotesProvider)[42]!;
        expect(state.failed, isTrue);
        expect(state.poll, _poll);
        expect(state.choices, {0});
      },
    );
  }
  testWidgets(
    'comments hide previous account quiz while next account detail is loading',
    (tester) async {
      final next = Completer<NgPost>();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          niosgramProvider.overrideWith(_EmptyFeed.new),
          postCommentsProvider(
            const PostCommentsArgs(channelId: 0, postId: 42),
          ).overrideWith(
            () => _EmptyComments(
              const PostCommentsArgs(channelId: 0, postId: 42),
            ),
          ),
          feedPostByIdProvider.overrideWith((ref, id) {
            final account = ref.watch(
              authProvider.select((a) => a.session?.userId),
            );
            return account == 1
                ? Future.value(
                    NgPost.fromJson({
                      'id': 42,
                      'content': 'Account A quiz',
                      'poll': _confirmed(),
                    }),
                  )
                : next.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PostCommentsScreen(channelId: 0, postId: 42),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('Confirmed only'), findsOneWidget);
      (container.read(authProvider.notifier) as _Auth).switchAccount();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Confirmed only'), findsNothing);
      expect(find.byType(FeedPollCard), findsNothing);
      next.complete(NgPost.fromJson({'id': 42, 'poll': _poll}));
      await tester.pumpAndSettle();
    },
  );
  test(
    'out-of-order fetches and fetch started during a vote cannot replace newer ballot',
    () async {
      final response = Completer<Map<String, dynamic>>();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          customEmojiRequestProvider.overrideWithValue(
            (_, _) => response.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final votes = container.read(feedPollVotesProvider.notifier);
      final sending = votes.vote(42, _poll, {0});
      final duringVote = votes.revisions;
      response.complete({'poll': _confirmed()});
      await sending;
      votes.reconcile(duringVote, [
        NgPost.fromJson({'id': 42, 'poll': _poll}),
      ]);
      expect(container.read(feedPollVotesProvider)[42]!.poll!['my_choices'], [
        0,
      ]);
      final older = votes.revisions;
      final newer = votes.revisions;
      votes.reconcile(newer, [
        NgPost.fromJson({
          'id': 42,
          'poll': {..._confirmed(), 'total_voters': 10},
        }),
      ]);
      votes.reconcile(older, [
        NgPost.fromJson({'id': 42, 'poll': _confirmed()}),
      ]);
      expect(
        container.read(feedPollVotesProvider)[42]!.poll!['total_voters'],
        10,
      );
    },
  );
  if (Platform.environment['NIOSGRAM_CAPTURE_DIR'] != null) {
    setUpAll(() async {
      for (final entry in {
        'GolosText': 'assets/fonts/golos_text/GolosText-Variable.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    });
  }
  for (final brightness in Brightness.values) {
    for (final locale in ['ru', 'en']) {
      testWidgets(
        'poll pending/confirmed fits 320dp at 200% $brightness $locale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final response = Completer<Map<String, dynamic>>();
          final capture = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(_Auth.new),
                customEmojiRequestProvider.overrideWithValue(
                  (_, _) => response.future,
                ),
              ],
              child: MaterialApp(
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: brightness,
                  fontFamily: 'GolosText',
                ),
                locale: Locale(locale),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(
                  body: RepaintBoundary(
                    key: capture,
                    child: const Material(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: FeedPollCard(postId: 42, poll: _poll),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('One'));
          await tester.pump();
          expect(
            find.text(locale == 'ru' ? 'Отправка…' : 'Sending…'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          response.complete({'poll': _confirmed()});
          await tester.pumpAndSettle();
          expect(find.text('100%'), findsOneWidget);
          expect(tester.takeException(), isNull);
          final output = Platform.environment['NIOSGRAM_CAPTURE_DIR'];
          if (output != null) {
            await tester.runAsync(() async {
              final image =
                  await (capture.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(output).create(recursive: true);
                await File(
                  '$output/poll-${brightness.name}-$locale.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
        },
      );
    }
  }
  testWidgets(
    'two poll screens share pending and confirmed ballot without leaking quiz answer',
    (tester) async {
      final response = Completer<Map<String, dynamic>>();
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            customEmojiRequestProvider.overrideWithValue((_, payload) {
              calls++;
              return response.future;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  FeedPollCard(postId: 42, poll: _poll),
                  FeedPollCard(postId: 42, poll: _poll),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('One').first);
      await tester.pump();
      expect(find.text('Отправка…'), findsNWidgets(2));
      expect(find.text('Confirmed only'), findsNothing);
      await tester.tap(find.text('Two').last);
      expect(calls, 1);
      response.complete({'poll': _confirmed()});
      await tester.pumpAndSettle();
      expect(find.text('Confirmed only'), findsNWidgets(2));
      expect(find.text('100%'), findsNWidgets(2));
    },
  );

  test(
    'account switch fences a delayed vote and clears selected answers',
    () async {
      final response = Completer<Map<String, dynamic>>();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          customEmojiRequestProvider.overrideWithValue(
            (_, _) => response.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final votes = container.read(feedPollVotesProvider.notifier);
      final pending = votes.vote(42, _poll, {0});
      expect(container.read(feedPollVotesProvider)[42]!.pending, isTrue);
      (container.read(authProvider.notifier) as _Auth).switchAccount();
      expect(container.read(feedPollVotesProvider), isEmpty);
      response.complete({'poll': _confirmed()});
      await pending;
      expect(container.read(feedPollVotesProvider), isEmpty);
    },
  );

  test(
    'failed and malformed responses retain choice; retry and stale fetch cannot erase confirmed vote',
    () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          customEmojiRequestProvider.overrideWithValue((_, _) async {
            calls++;
            return calls == 1 ? {'poll': {}} : {'poll': _confirmed()};
          }),
        ],
      );
      addTearDown(container.dispose);
      final votes = container.read(feedPollVotesProvider.notifier);
      final before = votes.revisions;
      await votes.vote(42, _poll, {0});
      expect(container.read(feedPollVotesProvider)[42]!.choices, {0});
      expect(container.read(feedPollVotesProvider)[42]!.failed, isTrue);
      await votes.vote(42, _poll, {0});
      votes.reconcile(before, [
        NgPost.fromJson({'id': 42, 'poll': _poll}),
      ]);
      expect(container.read(feedPollVotesProvider)[42]!.poll!['my_choices'], [
        0,
      ]);
      expect(container.read(feedPollVotesProvider)[42]!.failed, isFalse);
    },
  );
}
