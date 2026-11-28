import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidFlutterLocalNotificationsPlugin;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int account = 87001;

  Future<List<String>> postedBodies(
    List<Map<String, dynamic>> events,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'notifications.active_account': account,
      'ui.notifications': true,
      'ui.localeCode': 'ru',
    });
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async {
            calls.add(call);
            return call.method == 'initialize' ? true : null;
          },
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            null,
          ),
    );
    for (final event in events) {
      await PushNotificationService.showLocalNotification(
        <String, dynamic>{
          'account_id': account,
          'chat_id': 42,
          'chat_kind': 'private',
          'title': 'Fixture',
          ...event,
        },
      );
    }
    return calls
        .where((c) => c.method == 'show')
        .map((c) => (c.arguments as Map)['body']?.toString() ?? '')
        .toList();
  }

  test('server generic push bodies follow the Russian UI locale', () async {
    final bodies = await postedBodies(<Map<String, dynamic>>[
      // Ordinary E2EE chat: server mislabels it as a secret message.
      {'event_id': 'e1', 'body': 'New secret message', 'is_secret': 'false'},
      // Secret chat: generic body must read as a secret message.
      {'event_id': 'e2', 'body': 'New secret message', 'is_secret': 'true'},
      // Local secret path already sends the localized generic body.
      {'event_id': 'e3', 'body': 'Зашифрованное сообщение', 'is_secret': 'true'},
      {'event_id': 'e4', 'body': 'New message', 'is_secret': 'false'},
      {'event_id': 'e5', 'body': 'Sent a media file', 'is_secret': 'false'},
      // Real content must never be replaced by a placeholder.
      {'event_id': 'e6', 'body': 'Привет, как дела?', 'is_secret': 'false'},
    ]);
    expect(bodies, <String>[
      'Новое сообщение',
      'Новое секретное сообщение',
      'Новое секретное сообщение',
      'Новое сообщение',
      'Медиафайл',
      'Привет, как дела?',
    ]);
  });
}
