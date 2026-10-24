import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/comment_item.dart';

ApiMessage fixture(
  int id,
  String name,
  String content, {
  int? parent,
  bool edited = false,
  bool deleted = false,
}) => ApiMessage.fromJson({
  'id': id,
  'sender_id': id,
  'sender_username': id == 3 ? 'niosai' : 'user$id',
  'sender_display_name': name,
  'content': content,
  'reply_to_id': parent,
  'sent_at': '2026-10-24T12:30:00Z',
  'edited_at': edited ? '2026-10-24T12:31:00Z' : null,
  'is_deleted': deleted,
  'reactions': {'👍': 3},
});

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('thread fits 320px with theme $brightness and text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preview = Platform.environment['NIOS_COMMENT_PREVIEW'] == '1';
        if (preview) {
          await (FontLoader('GolosText')..addFont(
                rootBundle.load(
                  'assets/fonts/golos_text/GolosText-Variable.ttf',
                ),
              ))
              .load();
        }
        final root = fixture(
          1,
          'Саша',
          'Как лучше снять вечерний город? @ai',
          edited: true,
        );
        final reply = fixture(
          2,
          'Елена',
          'Попробуй дождаться, когда включат фонари.',
          parent: 1,
        );
        final ai = fixture(
          3,
          'NiosAI',
          'Снимай в синий час: небо ещё светлое, а огни уже видны.',
          parent: 2,
        );
        var replied = false;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorSchemeSeed: const Color(0xffbd8bc9),
              brightness: brightness,
              fontFamily: preview ? 'GolosText' : null,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('Комментарии')),
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: boundary,
                  child: Material(
                    child: Column(
                      children: [
                        for (final (index, message) in [
                          root,
                          reply,
                          ai,
                        ].indexed)
                          CommentItem(
                            comment: message,
                            parent: index == 0 ? null : root,
                            depth: index == 2 ? 9000 : index,
                            isMine: index == 0,
                            isPostAuthor: index == 0,
                            replyCount: index == 0 ? 2 : 0,
                            onToggleReplies: () {},
                            onReply: () {
                              replied = true;
                            },
                            onAuthorTap: () {},
                            onReact: (_) {},
                            onEdit: () {},
                            onDelete: () {},
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('изменено'), findsOneWidget);
        expect(find.text('NiosAI'), findsOneWidget);
        expect(find.text('👍'), findsNWidgets(3));
        await tester.tap(find.text('Ответить').first);
        expect(replied, isTrue);
        await tester.pumpAndSettle();
        if (preview && scale == 1) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'E:/NiosIDAndNiosmess/release/feed-comments/comments-${brightness.name}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
  testWidgets('deleted parent stays visible without edit and delete actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentItem(
            comment: fixture(1, 'Автор', '', deleted: true),
            isMine: true,
            replyCount: 1,
            onReply: () {},
            onAuthorTap: () {},
            onReact: (_) {},
            onToggleReplies: () {},
          ),
        ),
      ),
    );
    expect(find.text('Комментарий удалён'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Скрыть ответы (1)'), findsOneWidget);
  });
  testWidgets(
    'reaction menu and counters display emoji and preserve the selected reaction',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentItem(
              comment: fixture(
                1,
                'Автор',
                'Комментарий',
              ).copyWith(reactions: const {'👍': 3, '❤️': 2}),
              isMine: false,
              onReply: () {},
              onAuthorTap: () {},
              onReact: (value) => selected = value,
            ),
          ),
        ),
      );
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byTooltip('Действия с комментарием'));
      await tester.pumpAndSettle();
      expect(find.text('😂'), findsOneWidget);
      await tester.tap(find.text('Люблю'));
      await tester.pumpAndSettle();
      expect(selected, 'heart');
    },
  );
  testWidgets('quality report action is explicit and can be marked sent', (
    tester,
  ) async {
    var reported = false;
    Widget view(bool sent) => MaterialApp(
      home: Scaffold(
        body: CommentItem(
          comment: fixture(3, 'NiosAI', 'Ответ по существу'),
          isMine: false,
          onReply: () {},
          onAuthorTap: () {},
          onReact: (_) {},
          onQualityReport: () => reported = true,
          qualityReported: sent,
        ),
      ),
    );
    await tester.pumpWidget(view(false));
    expect(find.text('Пожаловаться на качество ответа модели'), findsNothing);
    await tester.tap(find.byTooltip('Действия с комментарием'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пожаловаться на качество ответа модели'));
    await tester.pumpAndSettle();
    expect(reported, isTrue);
    await tester.pumpWidget(view(true));
    await tester.tap(find.byTooltip('Действия с комментарием'));
    await tester.pumpAndSettle();
    expect(find.text('Жалоба на качество отправлена'), findsOneWidget);
    expect(find.text('Пожаловаться на качество ответа модели'), findsNothing);
  });
}
