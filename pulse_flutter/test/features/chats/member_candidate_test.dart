import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/features/chats/domain/member_candidate.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';

void main() {
  group('MemberCandidate Identity Guard', () {
    test('candidateFromDirectChat uses partnerUserId and never chatId', () {
      final directChat = ApiChatSummary(
        id: 100, // Chat ID
        name: 'Alice',
        chatType: 'direct',
        unreadCount: 0,
        membersCount: 2,
        partnerUserId: 7, // Real User ID
        username: 'alice',
      );

      final candidate = candidateFromDirectChat(directChat);
      expect(candidate, isNotNull);
      expect(candidate!.userId, equals(7),
          reason: 'Must use partnerUserId=7, not chat.id=100');
      expect(candidate.displayName, equals('Alice'));
      expect(candidate.username, equals('alice'));
      expect(candidate.source, equals(MemberCandidateSource.recentDirect));
    });

    test('candidateFromDirectChat returns null for group or missing partnerUserId', () {
      final groupChat = ApiChatSummary(
        id: 200,
        name: 'Product Team',
        chatType: 'group',
        unreadCount: 0,
        membersCount: 15,
        partnerUserId: null,
      );

      expect(candidateFromDirectChat(groupChat), isNull);

      final brokenDirectChat = ApiChatSummary(
        id: 300,
        name: 'Nobody',
        chatType: 'direct',
        unreadCount: 0,
        membersCount: 2,
        partnerUserId: 0, // Invalid ID
      );

      expect(candidateFromDirectChat(brokenDirectChat), isNull);
    });

    test('MemberCandidate.fromSearchUser prevents id=0 as resolved user', () {
      final validUser = ApiSearchUser(
        id: 42,
        username: 'valid',
        displayName: 'Valid User',
        bio: 'Hello world',
        badges: const [],
      );
      final candidate = MemberCandidate.fromSearchUser(validUser);
      expect(candidate.isResolved, isTrue);
      expect(candidate.userId, equals(42));

      final zeroUser = ApiSearchUser(
        id: 0,
        username: 'unresolved',
        displayName: '@unresolved',
        bio: '',
        badges: const [],
      );
      final zeroCandidate = MemberCandidate.fromSearchUser(zeroUser);
      expect(zeroCandidate.isResolved, isFalse);
    });
  });
}
