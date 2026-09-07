import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/inline_query_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/inline_query_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/bot_repository.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_app_bar.dart';
import 'package:pulse_flutter/widgets/chat/inline_keyboard_view.dart';
import 'package:pulse_flutter/widgets/chat/inline_query_overlay.dart';

class _FakeWebSocketClient extends WebSocketClient {
  _FakeWebSocketClient()
      : super(baseUrl: 'wss://test', readToken: () => 'test_token');

  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];
  dynamic nextResponse;

  @override
  bool get isConnected => true;

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    requests.add(<String, dynamic>{'action': action, 'payload': payload});
    return nextResponse ?? <String, dynamic>{};
  }
}

Widget _wrap(Widget child, [List<dynamic> overrides = const <dynamic>[]]) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Milestone 1: Bot & Inline Models', () {
    test('InlineQueryResult json serialization and deserialization', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 'res_1',
        'type': 'article',
        'title': 'Test Article',
        'description': 'Description text',
        'message_text': 'Full article message content',
        'thumb_url': 'https://example.com/thumb.png',
        'url': 'https://example.com/article',
      };

      final InlineQueryResult model = InlineQueryResult.fromJson(json);
      expect(model.id, 'res_1');
      expect(model.type, 'article');
      expect(model.title, 'Test Article');
      expect(model.description, 'Description text');
      expect(model.messageText, 'Full article message content');
      expect(model.thumbUrl, 'https://example.com/thumb.png');
      expect(model.url, 'https://example.com/article');

      final Map<String, dynamic> serialized = model.toJson();
      expect(serialized['id'], 'res_1');
      expect(serialized['message_text'], 'Full article message content');
    });

    test('InlineQueryResponse parses results array and query id', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'inline_query_id': 'iq_123',
        'expires_in': 300,
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '1',
            'type': 'article',
            'title': 'Result 1',
            'message_text': 'Text 1',
          },
          <String, dynamic>{
            'id': '2',
            'type': 'photo',
            'title': 'Result 2',
            'message_text': 'Text 2',
          },
        ],
      };

      final InlineQueryResponse response = InlineQueryResponse.fromJson(json);
      expect(response.inlineQueryId, 'iq_123');
      expect(response.expiresIn, 300);
      expect(response.results.length, 2);
      expect(response.results[0].title, 'Result 1');
      expect(response.results[1].type, 'photo');
    });

    test('InlineKeyboardButton supports 5 M3 styles and mutual exclusivity', () {
      final InlineKeyboardButton btnDefault = InlineKeyboardButton.fromJson(
        <String, dynamic>{'text': 'Normal', 'callback_data': 'cb_normal'},
      );
      expect(btnDefault.buttonStyle, InlineKeyboardButtonStyle.defaultStyle);
      expect(btnDefault.isCallback, isTrue);
      expect(btnDefault.isUrl, isFalse);

      final InlineKeyboardButton btnPrimary = InlineKeyboardButton.fromJson(
        <String, dynamic>{
          'text': 'Primary',
          'url': 'https://ni-os.ru',
          'style': 'primary',
        },
      );
      expect(btnPrimary.buttonStyle, InlineKeyboardButtonStyle.primary);
      expect(btnPrimary.isUrl, isTrue);
      expect(btnPrimary.isCallback, isFalse);

      final InlineKeyboardButton btnSuccess = InlineKeyboardButton.fromJson(
        <String, dynamic>{'text': 'Success', 'style': 'success'},
      );
      expect(btnSuccess.buttonStyle, InlineKeyboardButtonStyle.success);

      final InlineKeyboardButton btnWarning = InlineKeyboardButton.fromJson(
        <String, dynamic>{'text': 'Warning', 'style': 'warning'},
      );
      expect(btnWarning.buttonStyle, InlineKeyboardButtonStyle.warning);

      final InlineKeyboardButton btnDanger = InlineKeyboardButton.fromJson(
        <String, dynamic>{'text': 'Danger', 'style': 'danger'},
      );
      expect(btnDanger.buttonStyle, InlineKeyboardButtonStyle.danger);

      // Mutual exclusivity: if both url and callback_data provided, url takes precedence
      final InlineKeyboardButton btnBoth = InlineKeyboardButton.fromJson(
        <String, dynamic>{
          'text': 'Both',
          'url': 'https://ni-os.ru',
          'callback_data': 'ignore_me',
        },
      );
      expect(btnBoth.isUrl, isTrue);
      expect(btnBoth.callbackData, isNull);
    });
  });

  group('Milestone 1: BotRepository & InlineQueryProvider', () {
    test('BotRepository sends inline_query action with payload', () async {
      final _FakeWebSocketClient fakeWs = _FakeWebSocketClient();
      fakeWs.nextResponse = <String, dynamic>{
        'inline_query_id': 'query_abc',
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'res_a',
            'title': 'Alpha',
            'message_text': 'Alpha text',
          },
        ],
      };

      final ProviderContainer container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(fakeWs),
        ],
      );
      addTearDown(container.dispose);

      final BotRepository repo = container.read(botRepositoryProvider);
      final InlineQueryResponse res = await repo.sendInlineQuery(
        chatId: 42,
        botUsername: 'testbot',
        query: 'hello world',
      );

      expect(res.inlineQueryId, 'query_abc');
      expect(res.results.length, 1);
      expect(fakeWs.requests.length, 1);
      expect(fakeWs.requests.first['action'], 'inline_query');
      expect(fakeWs.requests.first['payload']['chat_id'], 42);
      expect(fakeWs.requests.first['payload']['bot_username'], 'testbot');
      expect(fakeWs.requests.first['payload']['query'], 'hello world');
    });

    test('InlineQueryNotifier detects @bot query and clears on non-matching', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final InlineQueryNotifier notifier =
          container.read(inlineQueryProvider.notifier);

      // Non matching
      notifier.onInputChanged(chatId: 10, text: 'regular message');
      expect(container.read(inlineQueryProvider).isActive, isFalse);

      // Matching @bot query
      notifier.onInputChanged(chatId: 10, text: '@gif search term');
      final InlineQueryState state = container.read(inlineQueryProvider);
      expect(state.isActive, isTrue);
      expect(state.botUsername, 'gif');
      expect(state.query, 'search term');
      expect(state.chatId, 10);

      // Clears
      notifier.onInputChanged(chatId: 10, text: 'hello again');
      expect(container.read(inlineQueryProvider).isActive, isFalse);
    });
  });

  group('Milestone 1: UI Widgets & Restrictions', () {
    testWidgets('InlineKeyboardView renders buttons and handles callback and URL',
        (WidgetTester tester) async {
      String? tappedCallback;
      final InlineKeyboardMarkup markup = InlineKeyboardMarkup(
        inlineKeyboard: <List<InlineKeyboardButton>>[
          <InlineKeyboardButton>[
            const InlineKeyboardButton(
              text: 'Primary Action',
              style: 'primary',
              callbackData: 'act_1',
            ),
            const InlineKeyboardButton(
              text: 'Danger Action',
              style: 'danger',
              callbackData: 'act_2',
            ),
          ],
        ],
      );

      await tester.pumpWidget(
        _wrap(
          InlineKeyboardView(
            replyMarkup: markup,
            onCallbackQuery: (String cb) => tappedCallback = cb,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Primary Action'), findsOneWidget);
      expect(find.text('Danger Action'), findsOneWidget);

      await tester.tap(find.text('Primary Action'));
      await tester.pump();
      expect(tappedCallback, 'act_1');

      await tester.tap(find.text('Danger Action'));
      await tester.pump();
      expect(tappedCallback, 'act_2');
    });

    testWidgets('InlineQueryOverlay displays results and triggers onSelectResult',
        (WidgetTester tester) async {
      InlineQueryResult? selected;
      bool closed = false;

      const InlineQueryState state = InlineQueryState(
        isActive: true,
        botUsername: 'gifbot',
        query: 'cats',
        results: <InlineQueryResult>[
          InlineQueryResult(
            id: 'c1',
            type: 'gif',
            title: 'Funny Cat',
            description: 'A dancing cat gif',
            messageText: 'https://gif.url/cat1',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          InlineQueryOverlay(
            state: state,
            onSelectResult: (InlineQueryResult r) => selected = r,
            onClose: () => closed = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('@gifbot'), findsOneWidget);
      expect(find.text('Funny Cat'), findsOneWidget);
      expect(find.text('A dancing cat gif'), findsOneWidget);

      await tester.tap(find.text('Funny Cat'));
      await tester.pump();
      expect(selected?.id, 'c1');
      expect(selected?.messageText, 'https://gif.url/cat1');

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('ChatDetailAppBar hides voice and video call buttons for bots',
        (WidgetTester tester) async {
      // Normal user chat: call buttons shown
      await tester.pumpWidget(
        _wrap(
          ChatDetailAppBar(
            chatId: 10,
            isDesktopSplit: false,
            title: 'Alice',
            headerIcon: Icons.person_rounded,
            typingSubtitle: const SizedBox.shrink(),
            isBot: false,
            onBack: () {},
            onVoiceCall: () {},
            onVideoCall: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);

      // Bot chat: isBot = true suppresses call buttons completely
      await tester.pumpWidget(
        _wrap(
          ChatDetailAppBar(
            chatId: 11,
            isDesktopSplit: false,
            title: 'HelperBot',
            headerIcon: Icons.smart_toy_rounded,
            typingSubtitle: const SizedBox.shrink(),
            isBot: true,
            onBack: () {},
            onVoiceCall: () {},
            onVideoCall: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.phone_rounded), findsNothing);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
    });
  });
}
