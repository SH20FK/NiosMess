import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/report_repository.dart';
import 'package:pulse_flutter/repositories/support_repository.dart';
import 'package:pulse_flutter/widgets/chat/spamblock_banner.dart';

class _MockWsClient extends WebSocketClient {
  _MockWsClient()
      : super(baseUrl: 'wss://test', readToken: () => 'test_token');

  String? lastAction;
  Map<String, dynamic>? lastPayload;
  dynamic mockResponse;

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    lastAction = action;
    lastPayload = payload;
    return mockResponse ?? <String, dynamic>{'status': 'ok'};
  }
}

void main() {
  group('Milestone 5: Profile Spamblock Model', () {
    test('isRestrictedBySpamBlock handles spamBlock flag and expiration dates', () {
      final unrestricted = ApiProfile(
        id: 10,
        username: 'good_user',
        displayName: 'Good User',
        bio: '',
        spamBlock: false,
      );
      expect(unrestricted.isRestrictedBySpamBlock, isFalse);

      final permBlocked = ApiProfile(
        id: 11,
        username: 'blocked_user',
        displayName: 'Blocked User',
        bio: '',
        spamBlock: true,
        spamBlockReason: 'Спам рассылка',
      );
      expect(permBlocked.isRestrictedBySpamBlock, isTrue);
      expect(permBlocked.spamBlockReason, 'Спам рассылка');

      final tempActive = ApiProfile(
        id: 12,
        username: 'temp_user',
        displayName: 'Temp User',
        bio: '',
        spamBlock: false,
        spamBlockUntil: DateTime.now().add(const Duration(hours: 2)),
        spamBlockReason: 'Подозрительная активность',
      );
      expect(tempActive.isRestrictedBySpamBlock, isTrue);

      final tempExpired = ApiProfile(
        id: 13,
        username: 'expired_user',
        displayName: 'Expired User',
        bio: '',
        spamBlock: false,
        spamBlockUntil: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(tempExpired.isRestrictedBySpamBlock, isFalse);
    });

    test('ApiProfile serialization preserves spamBlockUntil and spamBlockReason', () {
      final until = DateTime.utc(2026, 12, 31, 23, 59, 59);
      final json = {
        'id': 100,
        'username': 'john',
        'display_name': 'John',
        'bio': 'Hi',
        'spam_block': true,
        'spam_block_until': until.toIso8601String(),
        'spam_block_reason': 'Doxing violation',
      };

      final profile = ApiProfile.fromJson(json);
      expect(profile.id, 100);
      expect(profile.spamBlock, isTrue);
      expect(profile.spamBlockUntil, until);
      expect(profile.spamBlockReason, 'Doxing violation');

      final serialized = profile.toJson();
      expect(serialized['spam_block'], isTrue);
      expect(serialized['spam_block_until'], until.toIso8601String());
      expect(serialized['spam_block_reason'], 'Doxing violation');
    });
  });

  group('Milestone 5: Support & Report Repositories', () {
    late _MockWsClient mockWs;
    late ProviderContainer container;

    setUp(() {
      mockWs = _MockWsClient();
      container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(mockWs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('ReportRepository sends report with new reasons (copyright, doxing, swatting)', () async {
      final repo = container.read(reportRepositoryProvider);

      await repo.report(
        chatId: 5,
        reportedUserId: 42,
        reason: 'copyright',
        messageIds: [101],
      );
      expect(mockWs.lastAction, 'report');
      expect(mockWs.lastPayload?['reason'], 'copyright');
      expect(mockWs.lastPayload?['reported_user_id'], 42);

      await repo.report(
        chatId: 5,
        reportedUserId: 43,
        reason: 'doxing',
      );
      expect(mockWs.lastPayload?['reason'], 'doxing');

      await repo.report(
        chatId: 5,
        reportedUserId: 44,
        reason: 'swatting',
      );
      expect(mockWs.lastPayload?['reason'], 'swatting');
    });

    test('SupportRepository creates support and copyright tickets', () async {
      final repo = container.read(supportRepositoryProvider);

      mockWs.mockResponse = {
        'id': 1,
        'ticket_type': 'copyright',
        'subject': 'Авторские права',
        'body': 'Несанкционированное использование видео',
        'status': 'open',
      };

      final ticket = await repo.createTicket(
        ticketType: 'copyright',
        subject: 'Авторские права',
        body: 'Несанкционированное использование видео',
      );

      expect(mockWs.lastAction, 'create_support_ticket');
      expect(mockWs.lastPayload?['ticket_type'], 'copyright');
      expect(ticket?.id, 1);
      expect(ticket?.isCopyright, isTrue);
    });

    test('SupportRepository listTickets parses ticket collection', () async {
      final repo = container.read(supportRepositoryProvider);

      mockWs.mockResponse = {
        'tickets': [
          {
            'id': 10,
            'ticket_type': 'support',
            'subject': 'Помощь с входом',
            'body': 'Не могу войти',
            'status': 'closed',
          },
          {
            'id': 11,
            'ticket_type': 'copyright',
            'subject': 'DMCA',
            'body': 'Удалите мой контент',
            'status': 'open',
          },
        ],
      };

      final tickets = await repo.listTickets();
      expect(mockWs.lastAction, 'list_support_tickets');
      expect(tickets.length, 2);
      expect(tickets[0].ticketType, 'support');
      expect(tickets[1].ticketType, 'copyright');
    });
  });

  group('Milestone 5: SpamBlockBanner Widget', () {
    testWidgets('Renders restriction title, reason, and countdown in local timezone', (tester) async {
      final futureTime = DateTime.now().add(const Duration(hours: 3));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpamBlockBanner(
              until: futureTime,
              reason: 'Нарушение правил авторского права',
            ),
          ),
        ),
      );

      expect(find.text('Аккаунт временно ограничен (Спамблок)'), findsOneWidget);
      expect(find.textContaining('Нарушение правил авторского права'), findsOneWidget);
      expect(find.text('Отправка сообщений заблокирована'), findsOneWidget);
      expect(find.byIcon(Icons.lock_clock_rounded), findsOneWidget);
    });
  });
}
