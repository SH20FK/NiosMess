import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/providers/support_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class _MockSupportWs extends WebSocketClient {
  _MockSupportWs()
      : super(baseUrl: 'wss://test', readToken: () => 'test_token');

  final List<String> actions = <String>[];
  bool failTickets = false;

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    actions.add(action);
    if (action == 'list_support_tickets') {
      if (failTickets) throw Exception('offline');
      return <String, dynamic>{
        'tickets': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 7,
            'subject': 'Help',
            'body': 'Body',
            'status': 'open',
          },
        ],
      };
    }
    if (action == 'support_get_status') {
      return <String, dynamic>{
        'spam_block': <String, dynamic>{
          'is_blocked': true,
          'reason': 'spam rush',
        },
      };
    }
    return <String, dynamic>{'status': 'ok'};
  }
}

void main() {
  group('SupportCenterNotifier', () {
    late _MockSupportWs ws;
    late ProviderContainer container;
    late ProviderSubscription<AsyncValue<SupportCenterData>> subscription;

    setUp(() {
      ws = _MockSupportWs();
      container = ProviderContainer(
        overrides: [webSocketClientProvider.overrideWithValue(ws)],
      );
      subscription = container.listen(supportCenterProvider, (_, _) {});
    });

    tearDown(() {
      subscription.close();
      container.dispose();
    });

    test('initial build loads tickets and falls back to getStatus', () async {
      final SupportCenterData data = await container.read(
        supportCenterProvider.future,
      );

      expect(data.tickets, hasLength(1));
      expect(data.tickets.single.id, 7);
      expect(data.spamBlock?.isBlocked, isTrue);
      expect(data.spamBlock?.reason, 'spam rush');
      expect(
        ws.actions,
        containsAllInOrder(<String>['list_support_tickets', 'support_get_status']),
      );
    });

    test('silent refresh failure keeps previous data and sets error', () async {
      await container.read(supportCenterProvider.future);

      ws.failTickets = true;
      await container.read(supportCenterProvider.notifier).refresh(
        silent: true,
      );

      final SupportCenterData data = container.read(supportCenterProvider).value!;
      expect(data.tickets, hasLength(1));
      expect(data.spamBlock?.isBlocked, isTrue);
      expect(data.error, contains('offline'));
      expect(data.loading, isFalse);
    });

    test('non-silent refresh flags loading and clears the error', () async {
      await container.read(supportCenterProvider.future);
      ws.failTickets = true;
      await container.read(supportCenterProvider.notifier).refresh(
        silent: true,
      );

      ws.failTickets = false;
      final Future<void> refresh = container
          .read(supportCenterProvider.notifier)
          .refresh();
      expect(container.read(supportCenterProvider).value?.loading, isTrue);
      expect(container.read(supportCenterProvider).value?.error, isNull);

      await refresh;
      final SupportCenterData data = container.read(supportCenterProvider).value!;
      expect(data.loading, isFalse);
      expect(data.error, isNull);
      expect(data.tickets, hasLength(1));
    });
  });
}
