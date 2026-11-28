import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/navigation/direct_chat_navigator.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';

ApiChatSummary _direct({
  required int id,
  required String username,
  bool isSecret = false,
}) {
  return ApiChatSummary(
    id: id,
    chatType: 'direct',
    name: username,
    username: username,
    unreadCount: 0,
    membersCount: 2,
    isSecret: isSecret,
  );
}

void main() {
  group('findDirectChatWithUser', () {
    test('prefers the regular chat when both regular and secret exist', () {
      final ApiChatSummary? picked = findDirectChatWithUser(
        <ApiChatSummary>[
          _direct(id: 1, username: 'alice', isSecret: true),
          _direct(id: 2, username: 'alice'),
        ],
        'alice',
      );

      expect(picked?.id, 2);
      expect(picked?.isSecret, isFalse);
    });

    test('opens the only secret chat instead of creating a duplicate', () {
      final ApiChatSummary? picked = findDirectChatWithUser(
        <ApiChatSummary>[
          _direct(id: 7, username: 'Alice', isSecret: true),
        ],
        'alice',
      );

      expect(picked?.id, 7);
      expect(picked?.isSecret, isTrue);
    });

    test('returns null when there is no direct chat (regular one is created)',
        () {
      final ApiChatSummary? picked = findDirectChatWithUser(
        <ApiChatSummary>[
          ApiChatSummary(
            id: 3,
            chatType: 'group',
            name: 'Devs',
            username: 'devs',
            unreadCount: 0,
            membersCount: 5,
          ),
          _direct(id: 4, username: 'bob'),
        ],
        'alice',
      );

      expect(picked, isNull);
    });
  });
}
