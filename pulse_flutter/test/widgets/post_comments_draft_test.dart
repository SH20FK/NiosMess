import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/custom_emoji_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/post_comments_repository.dart';
import 'package:pulse_flutter/screens/post_comments_screen.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

const _emoji = ApiCustomEmoji(
  id: 1,
  setId: 1,
  shortcode: 'star',
  url: 'https://fixture.invalid/star.png',
);

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'fixture',
      displayName: 'Fixture',
    ),
  );
}

class _Ng extends NiosgramNotifier {
  @override
  Future<NiosgramState> build() async => NiosgramState(
    posts: [
      NgPost(
        id: 3,
        content: 'Test discussion',
        author: const ApiProfile(
          id: 2,
          username: 'fixture',
          displayName: 'Test author',
          bio: '',
        ),
        createdAt: DateTime(2026, 10, 26),
        likesCount: 0,
        dislikesCount: 0,
        commentsCount: 0,
      ),
    ],
  );
  @override
  Future<void> refresh() async {}
}

class _EmojiSets extends CustomEmojiSets {
  @override
  Future<List<ApiCustomEmojiSet>> build() async => const [
    ApiCustomEmojiSet(
      id: 1,
      name: 'fixture',
      title: 'Fixture emoji',
      emojis: [_emoji],
    ),
  ];
}

class _Catalog extends CustomEmojiCatalog {
  @override
  Map<String, ApiCustomEmoji> build() => const {'star': _emoji};
}

class _Repository extends PostCommentsRepository {
  _Repository(super.ref);
  final sent = Completer<ApiMessage>();
  String? submitted;
  @override
  Future<CommentsPage> page(
    int channelId,
    int postId, {
    int afterId = 0,
  }) async => const CommentsPage([], false, 0);
  @override
  Future<ApiMessage> send(
    int channelId,
    int postId,
    String content,
    int? replyToId,
  ) {
    submitted = content;
    return sent.future;
  }
}

void main() {
  group('comment composer draft preservation', () {
    testWidgets(
      'emoji inserted while Send awaits its acknowledgement is not erased',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = Platform.environment['NIOS_AUDIT_CAPTURE'];
        if (capture != null) {
          for (final font in <String, String>{
            'Onest': 'assets/fonts/onest/Onest-Variable.ttf',
            'BricolageGrotesque':
                'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
            'GolosText': 'assets/fonts/golos_text/GolosText-Variable.ttf',
            'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
          }.entries) {
            await (FontLoader(
              font.key,
            )..addFont(rootBundle.load(font.value))).load();
          }
        }
        final key = GlobalKey();
        late _Repository repository;
        final socket = WebSocketClient(
          baseUrl: 'https://fixture.invalid',
          readToken: () => null,
        );
        addTearDown(socket.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_Auth.new),
              niosgramProvider.overrideWith(_Ng.new),
              feedPostByIdProvider(3).overrideWith(
                (ref) async => NgPost(
                  id: 3,
                  content: 'Test discussion',
                  author: const ApiProfile(
                    id: 2,
                    username: 'fixture',
                    displayName: 'Test author',
                    bio: '',
                  ),
                  createdAt: DateTime(2026, 10, 26),
                  likesCount: 0,
                  dislikesCount: 0,
                  commentsCount: 0,
                ),
              ),
              customEmojiSetsProvider.overrideWith(_EmojiSets.new),
              customEmojiCatalogProvider.overrideWith(_Catalog.new),
              webSocketClientProvider.overrideWithValue(socket),
              postCommentsRepositoryProvider.overrideWith(
                (ref) => repository = _Repository(ref),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.themed(
                const VisualThemeSettings(
                  seedColor: Color(0xff006c5b),
                  themeMode: ThemeMode.dark,
                  useSystemDynamic: false,
                  predictiveBackEnabled: false,
                ),
                Brightness.dark,
              ),
              home: RepaintBoundary(
                key: key,
                child: const PostCommentsScreen(channelId: 0, postId: 3),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (capture != null) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            await File(
              'F:/Niosmess V2/output/full-audit-2026-10-26/$capture-comments-fixture.png',
            ).writeAsBytes(data!.buffer.asUint8List());
          });
        }
        final pinnedAvatar = tester.widget<PulseAvatar>(
          find.byType(PulseAvatar).first,
        );
        final thread = tester.widget<ListView>(find.byType(ListView));
        await tester.enterText(find.byType(TextField), 'Original');
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'Original comment');
        await tester.pump();
        expect(
          identical(
            tester.widget<PulseAvatar>(find.byType(PulseAvatar).first),
            pinnedAvatar,
          ),
          isTrue,
          reason: 'Typing must not rebuild the pinned post and its media',
        );
        expect(
          identical(tester.widget<ListView>(find.byType(ListView)), thread),
          isTrue,
          reason: 'Typing and selection must not rebuild the comment thread',
        );
        await tester.tap(find.byTooltip(RegExp('Отправить|Send comment')));
        await tester.pump();
        expect(repository.submitted, 'Original comment');
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        await tester.tap(find.byType(CustomEmojiComposerButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        await tester.tap(
          find
              .ancestor(
                of: find
                    .descendant(
                      of: find.byType(GridView),
                      matching: find.byType(CustomEmojiImage),
                    )
                    .first,
                matching: find.byType(InkWell),
              )
              .first,
        );
        await tester.pump();
        Navigator.of(tester.element(find.byType(CustomEmojiPicker))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        final draft = tester
            .widget<TextField>(find.byType(TextField))
            .controller!;
        final current = draft.text;
        expect(current, contains(':star:'));
        repository.sent.complete(
          ApiMessage.fromJson({
            'id': 101,
            'sender_id': 1,
            'content': 'Original comment',
          }),
        );
        await tester.pumpAndSettle();
        expect(
          draft.text,
          current,
          reason:
              'A server acknowledgement must not erase a draft changed through the emoji picker',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
