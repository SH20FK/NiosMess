// Tests for `lib/screens/chat_detail/chat_media_controller.dart`.
//
// The controller took `_openMedia` / `_showMediaActions` out of
// `_ChatDetailScreenState`. These tests freeze the invariants the split had to
// keep:
//   1. The playlist follows message order and the viewer's `initialIndex` is
//      found by message id, never by list position.
//   2. Messages without a usable `mediaUrl` are skipped; a playlist with
//      nothing left is `null`, not an empty list.
//   3. `e2eeFileKey` / `mediaName` reach the viewer item unchanged, and the
//      hero tag is the one the bubble preview uses.
//   4. `buildMediaPlaylist` is pure вЂ” no widgets, no providers, no context.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_media_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_presenter.dart';
import 'package:pulse_flutter/screens/media_viewer_screen.dart';
import 'package:pulse_flutter/widgets/media/media_hero.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('ru'));
final ChatMessagePresenter _presenter = ChatMessagePresenter(_l10n);

const int _chatId = 7;

ApiMessage _message({
  required int id,
  String? mediaUrl,
  String? mediaName,
  String? mediaType,
  String? e2eeFileKey,
  String content = '',
  String msgType = 'media',
}) => ApiMessage(
  id: id,
  chatId: _chatId,
  senderId: 1,
  senderUsername: 'me',
  senderDisplayName: 'РЇ',
  senderBadges: const [],
  content: content,
  msgType: msgType,
  replyToId: null,
  mediaUrl: mediaUrl,
  mediaType: mediaType,
  mediaName: mediaName,
  mediaSize: 1024,
  mediaDuration: null,
  commentsCount: 0,
  reactions: const <String, int>{},
  sentAt: DateTime.utc(2026, 11, 28, 10),
  editedAt: null,
  isDeleted: false,
  e2eeFileKey: e2eeFileKey,
);

List<ApiMessage> _chatRows() => <ApiMessage>[
  _message(
    id: 10,
    mediaUrl: 'https://cdn.test/a/one.jpg',
    mediaName: 'one.jpg',
  ),
  _message(id: 11, content: 'РїСЂРѕСЃС‚Рѕ С‚РµРєСЃС‚', msgType: 'text'),
  _message(
    id: 12,
    mediaUrl: 'https://cdn.test/b/two.mp4',
    mediaType: 'video/mp4',
  ),
  _message(
    id: 13,
    mediaUrl: 'https://cdn.test/c/report.pdf',
    mediaName: 'report.pdf',
    mediaType: 'application/pdf',
    msgType: 'document',
  ),
  // A media message whose URL never arrived (failed upload / redacted key).
  _message(id: 14, mediaUrl: '   ', mediaName: 'broken.jpg'),
  _message(id: 15, mediaUrl: 'https://cdn.test/d/three.png'),
];

void main() {
  group('buildMediaPlaylist', () {
    test('follows message order and finds the target id in the middle', () {
      final List<ApiMessage> rows = _chatRows();
      final ChatMediaPlaylist playlist = buildMediaPlaylist(
        rows,
        rows[2],
        presenter: _presenter,
      )!;

      expect(
        playlist.items.map((MediaViewerItem item) => item.url).toList(),
        <String>[
          'https://cdn.test/a/one.jpg',
          'https://cdn.test/b/two.mp4',
          'https://cdn.test/d/three.png',
        ],
      );
      expect(playlist.initialIndex, 1);
      expect(
        playlist.items[playlist.initialIndex].url,
        'https://cdn.test/b/two.mp4',
      );
      expect(playlist.items[1].mediaType, MediaType.video);
      expect(playlist.items[0].mediaType, MediaType.image);
    });

    test('the first and the last media messages still resolve by id', () {
      final List<ApiMessage> rows = _chatRows();

      expect(
        buildMediaPlaylist(rows, rows[0], presenter: _presenter)!.initialIndex,
        0,
      );
      expect(
        buildMediaPlaylist(rows, rows[5], presenter: _presenter)!.initialIndex,
        2,
      );
    });

    test('skips messages without a usable mediaUrl and non-media files', () {
      final List<ApiMessage> rows = _chatRows();
      final ChatMediaPlaylist playlist = buildMediaPlaylist(
        rows,
        rows[0],
        presenter: _presenter,
      )!;

      final Set<String> names = playlist.items
          .map((MediaViewerItem item) => item.url)
          .map((String url) => Uri.parse(url).pathSegments.last)
          .toSet();
      expect(names, <String>{'one.jpg', 'two.mp4', 'three.png'});
      expect(names, isNot(contains('report.pdf')));
      expect(names, isNot(contains('broken.jpg')));
      expect(playlist.items, hasLength(3));
    });

    test('returns null when nothing is left to swipe through', () {
      final List<ApiMessage> textOnly = <ApiMessage>[
        _message(id: 1, content: 'a', msgType: 'text'),
        _message(id: 2, mediaUrl: '', mediaName: 'x.jpg'),
        _message(id: 3, mediaUrl: '  '),
        _message(
          id: 4,
          mediaUrl: 'https://cdn.test/doc.pdf',
          mediaType: 'application/pdf',
          msgType: 'document',
        ),
      ];

      expect(
        buildMediaPlaylist(textOnly, textOnly[0], presenter: _presenter),
        isNull,
      );
    });

    test('passes e2eeFileKey and mediaName through untouched', () {
      final ApiMessage secret = _message(
        id: 20,
        mediaUrl: 'nios-stream://7/abc',
        mediaName: 'secret.jpg',
        e2eeFileKey: 'base64-key',
        mediaType: 'image/jpeg',
      );
      final List<ApiMessage> rows = <ApiMessage>[
        _message(id: 19, mediaUrl: 'https://cdn.test/plain.jpg'),
        secret,
      ];

      final MediaViewerItem item = buildMediaPlaylist(
        rows,
        secret,
        presenter: _presenter,
      )!.items[1];

      expect(item.e2eeFileKey, 'base64-key');
      expect(item.mediaName, 'secret.jpg');
      expect(item.filePath, 'nios-stream://7/abc');
      expect(item.url, 'nios-stream://7/abc');
      expect(item.title, 'secret.jpg');
    });

    test('the hero tag is the bubble preview tag, per chat and message', () {
      final List<ApiMessage> rows = _chatRows();
      final ChatMediaPlaylist playlist = buildMediaPlaylist(
        rows,
        rows[0],
        presenter: _presenter,
      )!;

      expect(
        playlist.items.map((MediaViewerItem item) => item.heroTag).toList(),
        <String>[
          chatMediaHeroTag(_chatId, 10),
          chatMediaHeroTag(_chatId, 12),
          chatMediaHeroTag(_chatId, 15),
        ],
      );
      expect(playlist.items[0].heroTag, isNot(playlist.items[1].heroTag));
    });
  });

  group('ChatMediaController.openMedia', () {
    ChatMediaController controller({
      required List<ApiMessage> Function() messages,
      required List<(String, Object?)> pushes,
      required List<ApiMessage> forwarded,
      required List<ApiMessage> deleted,
    }) => ChatMediaController(
      l10n: () => _l10n,
      messages: messages,
      push: (String location, {Object? extra}) => pushes.add((location, extra)),
      forward: (ApiMessage message) async => forwarded.add(message),
      delete: deleted.add,
      wsClient: () => throw UnimplementedError(),
    );

    testWidgets('pushes the viewer with the playlist and the id-based index', (
      tester,
    ) async {
      final List<(String, Object?)> pushes = <(String, Object?)>[];
      final List<ApiMessage> rows = _chatRows();
      final ChatMediaController media = controller(
        messages: () => rows,
        pushes: pushes,
        forwarded: <ApiMessage>[],
        deleted: <ApiMessage>[],
      );

      final ApiMessage target = rows[2].copyWith(e2eeFileKey: 'video-key');
      late BuildContext screenContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              screenContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      media.openMedia(screenContext, target);

      expect(pushes, hasLength(1));
      final (String location, Object? extra) = pushes.single;
      expect(location, startsWith('/media-viewer?url='));
      expect(location, contains('type=video'));

      final Map<String, dynamic> args = extra! as Map<String, dynamic>;
      expect(args['heroTag'], chatMediaHeroTag(_chatId, 12));
      expect(args['e2eeKey'], 'video-key');
      expect(args['initialIndex'], 1);
      final List<MediaViewerItem> playlist =
          args['playlist']! as List<MediaViewerItem>;
      expect(playlist, hasLength(3));
      expect(playlist[1].url, 'https://cdn.test/b/two.mp4');
    });

    testWidgets(
      'keeps a single-item playlist when the target is the only media',
      (tester) async {
        final List<(String, Object?)> pushes = <(String, Object?)>[];
        final ApiMessage target = _message(
          id: 30,
          mediaUrl: 'https://cdn.test/latest.jpg',
          mediaName: 'latest.jpg',
        );
        final ChatMediaController media = controller(
          messages: () => <ApiMessage>[target],
          pushes: pushes,
          forwarded: <ApiMessage>[],
          deleted: <ApiMessage>[],
        );

        late BuildContext screenContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                screenContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        media.openMedia(screenContext, target);

        final Map<String, dynamic> args =
            pushes.single.$2! as Map<String, dynamic>;
        expect(args['playlist'], isNotNull);
        expect((args['playlist']! as List<MediaViewerItem>), hasLength(1));

        // An image whose URL never arrived opens nothing at all.
        media.openMedia(screenContext, _message(id: 31, mediaUrl: '  '));
        expect(pushes, hasLength(1));
      },
    );

    testWidgets('an image with no cached messages passes no playlist', (
      tester,
    ) async {
      final List<(String, Object?)> pushes = <(String, Object?)>[];
      final ApiMessage target = _message(
        id: 40,
        mediaUrl: 'https://cdn.test/only.jpg',
      );
      final ChatMediaController media = controller(
        messages: () => const <ApiMessage>[],
        pushes: pushes,
        forwarded: <ApiMessage>[],
        deleted: <ApiMessage>[],
      );

      late BuildContext screenContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              screenContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      media.openMedia(screenContext, target);

      final Map<String, dynamic> args =
          pushes.single.$2! as Map<String, dynamic>;
      expect(args['playlist'], isNull);
      expect(args['initialIndex'], 0);
    });
  });
}
