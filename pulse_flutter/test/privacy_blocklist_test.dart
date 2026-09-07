import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

import 'package:pulse_flutter/repositories/privacy_repository.dart';
import 'package:pulse_flutter/screens/blocked_users_screen.dart';
import 'package:pulse_flutter/screens/privacy_rule_detail_screen.dart';

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

void main() {
  group('Privacy Models', () {
    test('PrivacyPolicy enum and conversions', () {
      expect(PrivacyPolicy.fromString('everyone'), PrivacyPolicy.everyone);
      expect(PrivacyPolicy.fromString('contacts'), PrivacyPolicy.contacts);
      expect(PrivacyPolicy.fromString('nobody'), PrivacyPolicy.nobody);
      expect(PrivacyPolicy.everyone.apiValue, 'everyone');
      expect(PrivacyPolicy.contacts.localizedTitle, 'Мои контакты');
    });

    test('PrivacyRule serialization and localized names', () {
      expect(PrivacyRule.allKeys.length, 12);
      expect(PrivacyRule.localizedKeyName('calls'), 'Звонки');

      final PrivacyRule rule = PrivacyRule.fromJson(<String, dynamic>{
        'key': 'calls',
        'default_policy': 'contacts',
        'always_allow': <dynamic>[12, 13],
        'never_allow': <dynamic>[34],
      });

      expect(rule.key, 'calls');
      expect(rule.policy, PrivacyPolicy.contacts);
      expect(rule.alwaysAllow, <int>[12, 13]);
      expect(rule.neverAllow, <int>[34]);

      final Map<String, dynamic> json = rule.toJson();
      expect(json['key'], 'calls');
      expect(json['default_policy'], 'contacts');
      expect(json['always_allow'], <int>[12, 13]);
      expect(json['never_allow'], <int>[34]);
    });

    test('BlockedUser model serialization', () {
      final BlockedUser user = BlockedUser.fromJson(<String, dynamic>{
        'id': 42,
        'username': 'spammer',
        'display_name': 'Spam Bot',
        'avatar_url': 'https://example.com/avatar.jpg',
      });

      expect(user.id, 42);
      expect(user.username, 'spammer');
      expect(user.displayName, 'Spam Bot');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
    });
  });

  group('PrivacyRepository Gateway Actions', () {
    late ProviderContainer container;
    late _FakeWebSocketClient fakeWs;
    late PrivacyRepository repository;

    setUp(() {
      fakeWs = _FakeWebSocketClient();
      container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(fakeWs),
        ],
      );
      repository = container.read(privacyRepositoryProvider);
    });

    tearDown(() => container.dispose());

    test('getPrivacy returns all 12 rules', () async {
      fakeWs.nextResponse = <String, dynamic>{
        'calls': <String, dynamic>{
          'default_policy': 'contacts',
          'always_allow': <dynamic>[12],
          'never_allow': <dynamic>[34],
        },
      };

      final Map<String, PrivacyRule> rules = await repository.getPrivacy();
      expect(rules.length, 12);
      expect(rules['calls']?.policy, PrivacyPolicy.contacts);
      expect(rules['calls']?.alwaysAllow, <int>[12]);
      expect(fakeWs.requests.last['action'], 'get_privacy');
    });

    test('setPrivacy sends payload with key, policy and exceptions', () async {
      fakeWs.nextResponse = <String, dynamic>{'success': true};

      final PrivacyRule result = await repository.setPrivacy(
        key: 'calls',
        policy: PrivacyPolicy.nobody,
        alwaysAllow: <int>[1],
        neverAllow: <int>[2],
      );

      expect(result.key, 'calls');
      expect(result.policy, PrivacyPolicy.nobody);
      expect(fakeWs.requests.last['action'], 'set_privacy');
      final Map<String, dynamic> payload = fakeWs.requests.last['payload'] as Map<String, dynamic>;
      expect(payload['key'], 'calls');
      expect(payload['default_policy'], 'nobody');
      expect(payload['always_allow'], <int>[1]);
      expect(payload['never_allow'], <int>[2]);
    });

    test('block_user and unblock_user actions', () async {
      fakeWs.nextResponse = <String, dynamic>{'success': true};
      final bool blocked = await repository.blockUser(42);
      expect(blocked, true);
      expect(fakeWs.requests.last['action'], 'block_user');
      expect(fakeWs.requests.last['payload'], <String, dynamic>{'user_id': 42});

      final bool unblocked = await repository.unblockUser(42);
      expect(unblocked, true);
      expect(fakeWs.requests.last['action'], 'unblock_user');
      expect(fakeWs.requests.last['payload'], <String, dynamic>{'user_id': 42});
    });

    test('listBlockedUsers parses list', () async {
      fakeWs.nextResponse = <String, dynamic>{
        'blocked_users': <dynamic>[
          <String, dynamic>{'id': 10, 'username': 'user10', 'display_name': 'User Ten'},
        ],
      };

      final List<BlockedUser> list = await repository.listBlockedUsers();
      expect(list.length, 1);
      expect(list.first.username, 'user10');
      expect(fakeWs.requests.last['action'], 'list_blocked_users');
    });
  });

  group('UI Widgets: Privacy Screens', () {
    testWidgets('PrivacyRuleDetailScreen renders radio options', (WidgetTester tester) async {
      final _FakeWebSocketClient fakeWs = _FakeWebSocketClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            webSocketClientProvider.overrideWithValue(fakeWs),
          ],
          child: const MaterialApp(
            home: PrivacyRuleDetailScreen(ruleKey: 'calls'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Звонки'), findsOneWidget);
      expect(find.text('Все'), findsOneWidget);
      expect(find.text('Мои контакты'), findsOneWidget);
      expect(find.text('Никто'), findsOneWidget);
      expect(find.text('Исключения'), findsOneWidget);
    });

    testWidgets('BlockedUsersScreen renders search bar and empty state', (WidgetTester tester) async {
      final _FakeWebSocketClient fakeWs = _FakeWebSocketClient();
      fakeWs.nextResponse = <String, dynamic>{'blocked_users': <dynamic>[]};

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            webSocketClientProvider.overrideWithValue(fakeWs),
          ],
          child: const MaterialApp(
            home: BlockedUsersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Заблокированные пользователи'), findsOneWidget);
      expect(find.text('Черный список пуст'), findsOneWidget);
    });
  });
}
