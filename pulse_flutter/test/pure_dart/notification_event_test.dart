import 'package:test/test.dart';
import 'package:pulse_flutter/core/notifications/notification_event.dart';

void main() {
  test('WS and FCM resolve to the same stable message identity', () {
    final ws = NotificationEvent.fromJson({'chat_id': 42, 'message_id': 9});
    final fcm = NotificationEvent.fromJson({
      'chat_id': '42',
      'message_id': '9',
      'account_id': '7',
    });
    expect(ws.id, fcm.id);
    expect(fcm.belongsTo(7), isTrue);
    expect(fcm.belongsTo(8), isFalse);
    expect(fcm.target, '/chat/42');
  });
  test(
    'local route allowlist rejects external, auth and malformed destinations',
    () {
      for (final route in [
        'https://example.invalid',
        '//evil',
        '/login',
        '/chat/../login',
        '/profile/a?redirect=x',
      ]) {
        expect(NotificationEvent.fromJson({'route': route}).target, isNull);
      }
      for (final route in [
        '/niosgram/post/42/comments',
        '/profile/test-user',
      ]) {
        expect(NotificationEvent.fromJson({'route': route}).target, route);
      }
    },
  );
  test('call expiry rejects old ringing but permits a fresh call', () {
    final now = DateTime.utc(2026, 10, 24);
    expect(
      NotificationEvent.fromJson({
        'type': 'incoming_call',
        'created_at': now
            .subtract(const Duration(minutes: 2))
            .toIso8601String(),
      }).expiredAt(now),
      isTrue,
    );
    expect(
      NotificationEvent.fromJson({
        'type': 'incoming_call',
        'expires_at': now.add(const Duration(seconds: 30)).toIso8601String(),
      }).expiredAt(now),
      isFalse,
    );
  });
  test(
    'retained unread stays bounded and duplicate updates preserve read state',
    () {
      var rows = <NotificationEvent>[];
      for (var i = 0; i < 110; i++) {
        rows = mergeNotification(
          rows,
          NotificationEvent.fromJson({
            'event_id': 'event-$i',
            'created_at': DateTime.utc(
              2026,
            ).add(Duration(seconds: i)).toIso8601String(),
          }),
        );
      }
      expect(rows.length, 100);
      rows[0] = rows[0].read();
      rows = mergeNotification(
        rows,
        NotificationEvent.fromJson({
          ...rows[0].toJson(),
          'is_read': false,
          'body': 'updated',
        }),
      );
      expect(rows.where((n) => !n.isRead).length, 99);
      expect(rows.first.isRead, isTrue);
      expect(rows.first.body, 'updated');
    },
  );
  test(
    'native IDs survive restarts and do not repeat at the old 100 second boundary',
    () {
      expect(
        notificationSystemId('message:42:9'),
        notificationSystemId('message:42:9'),
      );
      expect(
        notificationSystemId('message:42:9'),
        isNot(notificationSystemId('message:42:10')),
      );
    },
  );
}
