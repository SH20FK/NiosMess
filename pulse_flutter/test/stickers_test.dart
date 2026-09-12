import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/chat/create_sticker_set_dialog.dart';
import 'package:pulse_flutter/widgets/chat/sticker_picker_view.dart';
import 'package:pulse_flutter/widgets/chat/sticker_set_modal.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';
import 'package:universal_io/io.dart';

class FakeWebSocketClient extends WebSocketClient {
  FakeWebSocketClient()
      : super(baseUrl: 'wss://test', readToken: () => 'test_token');

  final List<Map<String, dynamic>> recordedRequests = <Map<String, dynamic>>[];
  dynamic responseToReturn;

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    recordedRequests.add(<String, dynamic>{
      'action': action,
      'payload': payload,
    });
    return responseToReturn;
  }
}

Widget _wrapWidget({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late Directory _hiveDir;

  setUp(() async {
    _hiveDir = await Directory.systemTemp.createTemp('stickers_test_hive_');
    Hive.init(_hiveDir.path);
  });

  tearDown(() async {
    try {
      await Hive.close();
      if (_hiveDir.existsSync()) await _hiveDir.delete(recursive: true);
    } catch (_) {}
  });

  group('ApiSticker & ApiStickerSet Models', () {
    test('ApiSticker serialization and isAnimated detection', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 45,
        'set_id': 1,
        'url': '/uploads/stickers/1/cat.webm',
        'emoji': '🐱',
        'media_type': 'video/webm',
        'duration_seconds': 7,
        'width': 512,
        'height': 512,
        'file_size': 245000,
      };

      final ApiSticker sticker = ApiSticker.fromJson(json);
      expect(sticker.id, 45);
      expect(sticker.setId, 1);
      expect(sticker.url, '/uploads/stickers/1/cat.webm');
      expect(sticker.emoji, '🐱');
      expect(sticker.mediaType, 'video/webm');
      expect(sticker.durationSeconds, 7);
      expect(sticker.width, 512);
      expect(sticker.height, 512);
      expect(sticker.fileSize, 245000);
      expect(sticker.isAnimated, isTrue);

      final Map<String, dynamic> serialized = sticker.toJson();
      expect(serialized['id'], 45);
      expect(serialized['set_id'], 1);
      expect(serialized['url'], '/uploads/stickers/1/cat.webm');
      expect(serialized['duration_seconds'], 7);

      final ApiSticker staticSticker = ApiSticker(
        id: 46,
        url: '/uploads/stickers/1/cat.webp',
        mediaType: 'image/webp',
        durationSeconds: null,
      );
      expect(staticSticker.isAnimated, isFalse);

      final ApiSticker copied = sticker.copyWith(emoji: '🐶');
      expect(copied.id, 45);
      expect(copied.emoji, '🐶');
      expect(copied.url, sticker.url);
    });

    test('ApiStickerSet serialization and coverSticker getter', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 1,
        'name': 'cats',
        'title': 'Коты',
        'is_public': true,
        'author_id': 99,
        'stickers': [
          <String, dynamic>{
            'id': 45,
            'set_id': 1,
            'url': '/uploads/stickers/1/cover.webp',
            'emoji': '🐱',
            'media_type': 'image/webp',
          },
          <String, dynamic>{
            'id': 46,
            'set_id': 1,
            'url': '/uploads/stickers/1/second.webp',
            'emoji': '😺',
            'media_type': 'image/webp',
          },
        ],
      };

      final ApiStickerSet set = ApiStickerSet.fromJson(json);
      expect(set.id, 1);
      expect(set.name, 'cats');
      expect(set.title, 'Коты');
      expect(set.isPublic, isTrue);
      expect(set.authorId, 99);
      expect(set.stickers.length, 2);

      // First sticker acts as cover
      expect(set.coverSticker, isNotNull);
      expect(set.coverSticker!.id, 45);
      expect(set.coverSticker!.url, '/uploads/stickers/1/cover.webp');

      final Map<String, dynamic> serialized = set.toJson();
      expect(serialized['id'], 1);
      expect(serialized['name'], 'cats');
      expect((serialized['stickers'] as List).length, 2);
    });

    test('ApiMessage sticker integration and isSticker getter', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 1024,
        'chat_id': 12,
        'sender_id': 99,
        'sender_username': 'author',
        'sender_display_name': 'Author',
        'msg_type': 'sticker',
        'sticker': <String, dynamic>{
          'id': 45,
          'url': '/uploads/stickers/1/cat.webm',
          'emoji': '🐱',
          'media_type': 'video/webm',
        },
        'sent_at': '2026-09-07T10:15:00.000Z',
      };

      final ApiMessage message = ApiMessage.fromJson(json);
      expect(message.id, 1024);
      expect(message.msgType, 'sticker');
      expect(message.sticker, isNotNull);
      expect(message.sticker!.id, 45);
      expect(message.isSticker, isTrue);

      final Map<String, dynamic> serialized = message.toJson();
      expect(serialized['msg_type'], 'sticker');
      expect(serialized['sticker'], isNotNull);
      expect((serialized['sticker'] as Map)['id'], 45);

      final ApiMessage textMessage = ApiMessage(
        id: 1025,
        chatId: 12,
        senderId: 99,
        senderUsername: 'author',
        senderDisplayName: 'Author',
        senderBadges: const [],
        content: 'Hello',
        msgType: 'text',
        replyToId: null,
        mediaUrl: null,
        mediaType: null,
        mediaName: null,
        mediaSize: null,
        mediaDuration: null,
        commentsCount: 0,
        reactions: const {},
        sentAt: DateTime.now(),
        editedAt: null,
        isDeleted: false,
      );
      expect(textMessage.isSticker, isFalse);
    });
  });

  group('StickerRepository & ChatRepository Gateway Actions', () {
    late FakeWebSocketClient fakeWs;
    late ProviderContainer container;

    setUp(() {
      fakeWs = FakeWebSocketClient();
      container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(fakeWs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('listStickerSets sends action list_sticker_sets', () async {
      fakeWs.responseToReturn = <String, dynamic>{
        'sets': [
          <String, dynamic>{
            'id': 1,
            'name': 'cats',
            'title': 'Коты',
            'is_public': true,
            'stickers': [
              <String, dynamic>{
                'id': 45,
                'url': '/uploads/stickers/1/cat.webp',
                'emoji': '🐱',
                'media_type': 'image/webp',
              },
            ],
          },
        ],
      };

      final repo = container.read(stickerRepositoryProvider);
      final sets = await repo.listStickerSets();

      expect(fakeWs.recordedRequests.length, 1);
      expect(fakeWs.recordedRequests.first['action'], 'list_sticker_sets');
      expect(sets.length, 1);
      expect(sets.first.id, 1);
      expect(sets.first.name, 'cats');
      expect(sets.first.stickers.length, 1);
    });

    test('createStickerSet sends action create_sticker_set', () async {
      fakeWs.responseToReturn = <String, dynamic>{
        'id': 10,
        'name': 'dogs',
        'title': 'Собаки',
        'is_public': true,
        'stickers': <dynamic>[],
      };

      final repo = container.read(stickerRepositoryProvider);
      final set = await repo.createStickerSet(
        name: 'dogs',
        title: 'Собаки',
        isPublic: true,
      );

      expect(fakeWs.recordedRequests.length, 1);
      expect(fakeWs.recordedRequests.first['action'], 'create_sticker_set');
      expect(fakeWs.recordedRequests.first['payload'], {
        'name': 'dogs',
        'title': 'Собаки',
        'is_public': true,
      });
      expect(set.id, 10);
      expect(set.name, 'dogs');
    });

    test('addSticker sends action add_sticker with payload', () async {
      fakeWs.responseToReturn = <String, dynamic>{
        'id': 99,
        'set_id': 10,
        'url': '/uploads/stickers/10/dog.webp',
        'emoji': '🐶',
        'media_type': 'image/webp',
        'width': 512,
        'height': 512,
      };

      final repo = container.read(stickerRepositoryProvider);
      final sticker = await repo.addSticker(
        setId: 10,
        filename: 'dog.webp',
        dataBase64: 'AAAA',
        width: 512,
        height: 512,
        emoji: '🐶',
      );

      expect(fakeWs.recordedRequests.length, 1);
      expect(fakeWs.recordedRequests.first['action'], 'add_sticker');
      final payload = fakeWs.recordedRequests.first['payload'] as Map;
      expect(payload['set_id'], 10);
      expect(payload['filename'], 'dog.webp');
      expect(payload['data_base64'], 'AAAA');
      expect(payload['emoji'], '🐶');
      expect(sticker.id, 99);
    });

    test('saveStickerSet sends action save_sticker_set', () async {
      fakeWs.responseToReturn = <String, dynamic>{'status': 'success'};

      final repo = container.read(stickerRepositoryProvider);
      await repo.saveStickerSet(1);

      expect(fakeWs.recordedRequests.length, 1);
      expect(fakeWs.recordedRequests.first['action'], 'save_sticker_set');
      expect(fakeWs.recordedRequests.first['payload'], {'set_id': 1});
    });

    test('removeStickerSet sends action remove_sticker_set', () async {
      fakeWs.responseToReturn = <String, dynamic>{'status': 'success'};

      final repo = container.read(stickerRepositoryProvider);
      await repo.removeStickerSet(1, deletePermanently: false);

      expect(fakeWs.recordedRequests.length, 1);
      expect(fakeWs.recordedRequests.first['action'], 'remove_sticker_set');
      expect(fakeWs.recordedRequests.first['payload'], {'set_id': 1});

      await repo.removeStickerSet(1, deletePermanently: true);
      expect(fakeWs.recordedRequests.last['payload'], {
        'set_id': 1,
        'delete_permanently': true,
      });
    });

    test('deleteSticker sends action delete_sticker', () async {
      fakeWs.responseToReturn = <String, dynamic>{'status': 'success'};

      final repo = container.read(stickerRepositoryProvider);
      await repo.deleteSticker(45);

      expect(fakeWs.recordedRequests.length, 1);
      expect(fakeWs.recordedRequests.first['action'], 'delete_sticker');
      expect(fakeWs.recordedRequests.first['payload'], {'sticker_id': 45});
    });

    test('ChatRepository.sendSticker sends send_sticker action and parses message', () async {
      fakeWs.responseToReturn = <String, dynamic>{
        'id': 100,
        'chat_id': 12,
        'sender_id': 5,
        'sender_username': 'tester',
        'sender_display_name': 'Tester',
        'msg_type': 'sticker',
        'sticker': <String, dynamic>{
          'id': 45,
          'url': '/uploads/stickers/1/cat.webp',
          'emoji': '🐱',
          'media_type': 'image/webp',
        },
        'sent_at': '2026-09-07T12:00:00.000Z',
      };

      final chatRepo = container.read(chatRepositoryProvider);
      final message = await chatRepo.sendSticker(12, 45);

      expect(fakeWs.recordedRequests.length, 1);
      expect(fakeWs.recordedRequests.first['action'], 'send_sticker');
      expect(fakeWs.recordedRequests.first['payload'], {
        'chat_id': 12,
        'sticker_id': 45,
      });
      expect(message.id, 100);
      expect(message.isSticker, isTrue);
      expect(message.sticker?.id, 45);
    });
  });

  group('StickerSetsNotifier Riverpod State', () {
    test('StickerSetsNotifier loads and mutates sticker sets', () async {
      final fakeWs = FakeWebSocketClient();
      fakeWs.responseToReturn = <String, dynamic>{
        'sets': [
          <String, dynamic>{
            'id': 1,
            'name': 'pack1',
            'title': 'Pack 1',
            'is_public': true,
            'stickers': <dynamic>[],
          },
        ],
      };

      final container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(fakeWs),
        ],
      );
      addTearDown(container.dispose);

      // Initial load
      final initial = await container.read(stickerSetsProvider.future);
      expect(initial.length, 1);
      expect(initial.first.id, 1);

      // Create new set
      fakeWs.responseToReturn = <String, dynamic>{
        'id': 2,
        'name': 'pack2',
        'title': 'Pack 2',
        'is_public': true,
        'stickers': <dynamic>[],
      };
      await container
          .read(stickerSetsProvider.notifier)
          .createStickerSet(name: 'pack2', title: 'Pack 2');

      final afterCreate = container.read(stickerSetsProvider).value!;
      expect(afterCreate.length, 2);
      expect(afterCreate.any((s) => s.id == 2), isTrue);

      // Add sticker to set 2
      fakeWs.responseToReturn = <String, dynamic>{
        'id': 50,
        'set_id': 2,
        'url': '/url.webp',
        'emoji': '🔥',
        'media_type': 'image/webp',
      };
      await container.read(stickerSetsProvider.notifier).addSticker(
            setId: 2,
            filename: 'fire.webp',
            dataBase64: '...',
            emoji: '🔥',
          );

      final afterAddSticker = container.read(stickerSetsProvider).value!;
      final set2 = afterAddSticker.firstWhere((s) => s.id == 2);
      expect(set2.stickers.length, 1);
      expect(set2.stickers.first.emoji, '🔥');

      // Remove set 1
      fakeWs.responseToReturn = <String, dynamic>{'status': 'success'};
      await container.read(stickerSetsProvider.notifier).removeStickerSet(1);

      final afterRemove = container.read(stickerSetsProvider).value!;
      expect(afterRemove.length, 1);
      expect(afterRemove.first.id, 2);
    });
  });

  group('Widget Tests: Stickers Suite UI', () {
    testWidgets('MessageBubble renders borderless for isSticker: true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWidget(
          child: MessageBubble(
            text: '',
            formattedTime: '15:30',
            isMine: true,
            chatId: 1,
            isSticker: true,
            sticker: const ApiSticker(
              id: 1,
              url: 'https://test.com/sticker.webp',
              emoji: '🐱',
            ),
          ),
        ),
      );

      // Confirm time badge is visible
      expect(find.text('15:30'), findsOneWidget);
      // CachedNetworkImage is rendered for the sticker
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('StickerSetModal renders pack info and Add/Remove button', (
      WidgetTester tester,
    ) async {
      final fakeWs = FakeWebSocketClient();
      fakeWs.responseToReturn = <String, dynamic>{'sets': <dynamic>[]};

      const testSet = ApiStickerSet(
        id: 77,
        name: 'super_pack',
        title: 'Super Pack',
        isPublic: true,
        stickers: [
          ApiSticker(id: 1, url: 'https://test.com/1.webp', emoji: '🌟'),
          ApiSticker(id: 2, url: 'https://test.com/2.webp', emoji: '🚀'),
        ],
      );

      await tester.pumpWidget(
        _wrapWidget(
          overrides: [
            webSocketClientProvider.overrideWithValue(fakeWs),
          ],
          child: const StickerSetModal(
            stickerSet: testSet,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Super Pack'), findsOneWidget);
      expect(find.text('2 стикеров • @super_pack'), findsOneWidget);
      // Not installed by default in empty provider -> shows "В коллекцию" and "Добавить стикеры"
      expect(find.text('В коллекцию'), findsOneWidget);
      expect(find.text('Добавить стикеры'), findsOneWidget);
    });

    testWidgets('CreateStickerSetDialog renders form fields and create button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWidget(
          child: const CreateStickerSetDialog(),
        ),
      );

      expect(find.text('Новый стикерпак'), findsOneWidget);
      expect(find.text('Название набора'), findsOneWidget);
      expect(find.text('Короткое имя (slug)'), findsOneWidget);
      expect(find.text('Публичный набор'), findsOneWidget);
      expect(find.text('Создать набор'), findsOneWidget);
    });

    testWidgets('StickerPickerView renders empty state when no packs installed', (
      WidgetTester tester,
    ) async {
      final fakeWs = FakeWebSocketClient();
      fakeWs.responseToReturn = <String, dynamic>{'sets': <dynamic>[]};

      await tester.pumpWidget(
        _wrapWidget(
          overrides: [
            webSocketClientProvider.overrideWithValue(fakeWs),
          ],
          child: const StickerPickerView(chatId: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('У вас пока нет стикерпаков'), findsOneWidget);
      expect(find.text('Создать стикерпак'), findsOneWidget);
    });

    testWidgets('StickerPickerView renders empty pack state with add stickers button', (
      WidgetTester tester,
    ) async {
      final fakeWs = FakeWebSocketClient();
      fakeWs.responseToReturn = <String, dynamic>{
        'sets': [
          <String, dynamic>{
            'id': 101,
            'name': 'empty_pack',
            'title': 'Пустой пак',
            'is_public': true,
            'stickers': <dynamic>[],
          },
        ],
      };

      await tester.pumpWidget(
        _wrapWidget(
          overrides: [
            webSocketClientProvider.overrideWithValue(fakeWs),
          ],
          child: const StickerPickerView(chatId: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Пустой пак'), findsOneWidget);
      expect(find.text('В этом наборе пока нет стикеров'), findsOneWidget);
      expect(find.text('Добавить стикеры'), findsOneWidget);
    });
  });
}
