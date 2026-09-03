import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';

void main() {
  group('Chat Message Optimistic Sorting Tests', () {
    test('Pending messages with negative IDs sort to the newest position (bottom)', () {
      final now = DateTime.now();

      final confirmedMsg1 = ApiMessage(
        id: 101,
        chatId: 1,
        senderId: 1,
        senderUsername: 'alice',
        senderDisplayName: 'Alice',
        senderBadges: const [],
        content: 'First message',
        msgType: 'text',
        replyToId: null,
        mediaUrl: null,
        mediaType: null,
        mediaName: null,
        mediaSize: null,
        mediaDuration: null,
        commentsCount: 0,
        reactions: const {},
        sentAt: now.subtract(const Duration(minutes: 5)),
        editedAt: null,
        isDeleted: false,
        isSending: false,
        isFailed: false,
      );

      final confirmedMsg2 = ApiMessage(
        id: 102,
        chatId: 1,
        senderId: 2,
        senderUsername: 'bob',
        senderDisplayName: 'Bob',
        senderBadges: const [],
        content: 'Second message',
        msgType: 'text',
        replyToId: null,
        mediaUrl: null,
        mediaType: null,
        mediaName: null,
        mediaSize: null,
        mediaDuration: null,
        commentsCount: 0,
        reactions: const {},
        sentAt: now.subtract(const Duration(minutes: 2)),
        editedAt: null,
        isDeleted: false,
        isSending: false,
        isFailed: false,
      );

      // Pending message with negative ID
      final pendingMsg = ApiMessage(
        id: -1741234567890,
        chatId: 1,
        senderId: 1,
        senderUsername: 'alice',
        senderDisplayName: 'Alice',
        senderBadges: const [],
        content: 's',
        msgType: 'text',
        replyToId: null,
        mediaUrl: null,
        mediaType: null,
        mediaName: null,
        mediaSize: null,
        mediaDuration: null,
        commentsCount: 0,
        reactions: const {},
        sentAt: now,
        editedAt: null,
        isDeleted: false,
        isSending: true,
        isFailed: false,
      );

      int compareMessages(ApiMessage a, ApiMessage b) {
        final bool aPending = a.id < 0 || a.isSending;
        final bool bPending = b.id < 0 || b.isSending;

        if (aPending != bPending) {
          final int timeCmp = a.resolvedSentAt.compareTo(b.resolvedSentAt);
          if (timeCmp != 0) return timeCmp;
          return aPending ? 1 : -1;
        }

        final int timeCmp = a.resolvedSentAt.compareTo(b.resolvedSentAt);
        if (timeCmp != 0) return timeCmp;

        if (!aPending && !bPending) {
          return a.id.compareTo(b.id);
        }

        return a.id.abs().compareTo(b.id.abs());
      }

      final list = [confirmedMsg2, pendingMsg, confirmedMsg1]..sort(compareMessages);

      expect(list[0].id, 101);
      expect(list[1].id, 102);
      expect(list[2].id, -1741234567890); // Pending message is last (newest/bottom)
    });
  });

  group('MessageBubble Widget Tests', () {
    testWidgets('Renders short message without crashing and displays pending clock icon when isSending is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                text: 's',
                formattedTime: '15:49',
                isMine: true,
                chatId: 1,
                isSending: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('s'), findsOneWidget);
      expect(find.text('15:49'), findsOneWidget);
      // Verify clock icon appears for pending sending message
      expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
    });

    testWidgets('Renders checkmark when message is confirmed (isSending is false)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                text: 'Hello world',
                formattedTime: '15:50',
                isMine: true,
                chatId: 1,
                isSending: false,
                isRead: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hello world'), findsOneWidget);
      expect(find.text('15:50'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.access_time_rounded), findsNothing);
    });

    testWidgets('Short single-line message text and timestamp have zero overlap (strictly separated horizontally)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                text: 'ыы',
                formattedTime: '15:51',
                isMine: true,
                chatId: 1,
                isSending: false,
                isRead: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final textRight = tester.getTopRight(find.text('ыы')).dx;
      final timeAndCheckLeft = tester.getTopLeft(find.text('15:51')).dx;

      // The right boundary of 'ыы' must be less than the left boundary of the timestamp
      expect(textRight, lessThanOrEqualTo(timeAndCheckLeft));
    });

    testWidgets('Multi-line message places timestamp on its own line below the text (zero vertical overlap)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                text: 'Первая строка\nВторая строка',
                formattedTime: '15:52',
                isMine: false,
                chatId: 1,
                isSending: false,
                isRead: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final textBottom = tester.getBottomLeft(find.text('Первая строка\nВторая строка')).dy;
      final timeTop = tester.getTopLeft(find.text('15:52')).dy;

      // The bottom boundary of the text must be strictly at or above the top boundary of the timestamp
      expect(textBottom, lessThanOrEqualTo(timeTop));
    });
  });
}
