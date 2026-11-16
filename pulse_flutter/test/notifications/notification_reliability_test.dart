import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidFlutterLocalNotificationsPlugin;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/notifications/notification_event.dart';
import 'package:pulse_flutter/core/notifications/notification_history_store.dart';
import 'package:pulse_flutter/core/notifications/legacy_notification_archive.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 87001,
      username: 'fixture',
      displayName: 'Fixture',
    ),
  );
  void replaceToken() {
    final previous = state.session!;
    state = state.copyWith(
      session: AuthSession(
        accessToken: 'replacement',
        userId: previous.userId,
        username: previous.username,
        displayName: previous.displayName,
      ),
    );
  }

  void switchAccount() {
    state = state.copyWith(
      session: const AuthSession(
        accessToken: 'fixture2',
        userId: 87002,
        username: 'other',
        displayName: 'Other',
      ),
    );
  }
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    soundEffects: false,
    haptics: false,
  );
}

class _Options extends NotificationPreferencesNotifier {
  @override
  Future<NotificationPreferences> build() async =>
      const NotificationPreferences(sound: false);
}

class _Socket extends WebSocketClient {
  _Socket() : super(baseUrl: 'wss://fixture.invalid', readToken: () => null);
  final events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  @override
  Stream<Map<String, dynamic>> get pushStream => events.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  List<Override> overrides() => [
    authProvider.overrideWith(_Auth.new),
    uiSettingsProvider.overrideWith(_Settings.new),
    notificationPreferencesProvider.overrideWith(_Options.new),
  ];
  test(
    'encrypted history survives reopen, stays account scoped and logout drains late writes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios-notification-history-',
      );
      Hive.init(directory.path);
      HiveBootstrap.resetForTesting();
      try {
        final one = NotificationHistoryStore(87011);
        final two = NotificationHistoryStore(87012);
        final event = NotificationEvent.fromJson({
          'event_id': 'fixture',
          'account_id': 87011,
          'body': 'private fixture text',
        });
        await one.save([event]);
        await one.saveReplyDraft(42, 'private reply draft');
        expect(await two.restore(), isEmpty);
        await Hive.close();
        expect(
          (await NotificationHistoryStore(87011).restore()).single.body,
          'private fixture text',
        );
        expect(
          await NotificationHistoryStore(87011).readReplyDraft(42),
          'private reply draft',
        );
        final files = directory.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.hive'),
        );
        for (final file in files) {
          expect(
            String.fromCharCodes(await file.readAsBytes()),
            isNot(contains('private fixture text')),
          );
          expect(
            String.fromCharCodes(await file.readAsBytes()),
            isNot(contains('private reply draft')),
          );
        }
        final reopened = NotificationHistoryStore(87011);
        final write = reopened.save([event]);
        await reopened.erase();
        await write;
        await reopened.save([event]);
        expect(await Hive.boxExists('notification_history_v2_87011'), isFalse);
      } finally {
        await Hive.close();
        HiveBootstrap.resetForTesting();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'unowned legacy history is archived with verification instead of assigned to the next account',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios-notification-legacy-',
      );
      Hive.init(directory.path);
      try {
        final old = await Hive.openBox<String>('app_notifications_v1');
        await old.put('9', '{"body":"legacy private text"}');
        await archiveUnassignedNotifications();
        expect(old.isEmpty, isTrue);
        expect(
          Hive.box<String>('notification_unassigned_archive_v2').get('9'),
          '{"body":"legacy private text"}',
        );
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'foreground history deduplicates FCM/WS and clears immediately on account switch',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios-notification-provider-',
      );
      Hive.init(directory.path);
      HiveBootstrap.resetForTesting();
      final socket = _Socket();
      final container = ProviderContainer(
        overrides: [
          ...overrides(),
          webSocketClientProvider.overrideWithValue(socket),
        ],
      );
      try {
        final notifier = container.read(notificationsProvider.notifier);
        final data = {
          'event_id': 'message:42:9',
          'account_id': 87001,
          'chat_id': 42,
          'title': 'Fixture',
          'body': 'one',
        };
        await notifier.accept(data);
        notifier.markRead('message:42:9');
        await notifier.accept({...data, 'body': 'updated'});
        expect(container.read(notificationsProvider).notifications.length, 1);
        expect(container.read(notificationsProvider).unreadCount, 0);
        (container.read(authProvider.notifier) as _Auth).switchAccount();
        expect(container.read(notificationsProvider).notifications, isEmpty);
        await container.read(notificationsProvider.notifier).accept(data);
        expect(container.read(notificationsProvider).notifications, isEmpty);
        await NotificationHistoryStore.eraseAccount(87001);
        await NotificationHistoryStore.eraseAccount(87002);
      } finally {
        container.dispose();
        await socket.events.close();
        socket.close();
        await Hive.close();
        HiveBootstrap.resetForTesting();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'startup event and remote read receipt retain the restored encrypted history on disk',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios-notification-startup-',
      );
      Hive.init(directory.path);
      HiveBootstrap.resetForTesting();
      final seeded = NotificationHistoryStore(87001);
      await seeded.save([
        NotificationEvent.fromJson({
          'event_id': 'old-event',
          'chat_id': 42,
          'account_id': 87001,
          'body': 'old',
        }),
      ]);
      await Hive.close();
      final socket = _Socket();
      final container = ProviderContainer(
        overrides: [
          ...overrides(),
          webSocketClientProvider.overrideWithValue(socket),
        ],
      );
      try {
        final notifier = container.read(notificationsProvider.notifier);
        notifier.markChatRead(42);
        await notifier.accept({
          'event_id': 'new-event',
          'account_id': 87001,
          'chat_id': 43,
          'body': 'new',
        });
        final restored = await NotificationHistoryStore(87001).restore();
        expect(restored.map((n) => n.id).toSet(), {'old-event', 'new-event'});
        expect(restored.singleWhere((n) => n.id == 'old-event').isRead, isTrue);
        expect(container.read(notificationsProvider).unreadCount, 1);
      } finally {
        container.dispose();
        socket.close();
        await NotificationHistoryStore.eraseAccount(87001);
        await Hive.close();
        HiveBootstrap.resetForTesting();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'chat notifications reuse one stable id and read receipts cancel that exact notification',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'notifications.active_account': 87001,
        'ui.notifications': true,
      });
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              calls.add(call);
              // initialize() coerces the result to a non-null bool.
              return call.method == 'initialize' ? true : null;
            },
          );
      final chat = PushNotificationService.chatNotificationId(42);
      await PushNotificationService.showLocalNotification(<String, dynamic>{
        'event_id': 'message:42:1',
        'account_id': 87001,
        'chat_id': 42,
        'title': 'Fixture',
        'body': 'one',
      });
      await PushNotificationService.showLocalNotification(<String, dynamic>{
        'event_id': 'message:42:2',
        'account_id': 87001,
        'chat_id': 42,
        'title': 'Fixture',
        'body': 'two',
      });
      await PushNotificationService.cancelChatNotification(42);
      final shows = calls.where((c) => c.method == 'show').toList();
      expect(shows, hasLength(2));
      expect(shows.first.arguments, isA<Map>());
      expect((shows.first.arguments as Map)['id'], chat);
      expect((shows.last.arguments as Map)['id'], chat);
      final cancels = calls.where((c) => c.method == 'cancel').toList();
      expect(cancels, hasLength(1));
      expect(
        (cancels.single.arguments as Map)['id'],
        chat,
        reason:
            'Read receipts must cancel the notification id that show() '
            'actually posted (the legacy bug canceled id 0 with a tag that '
            'show() never set).',
      );
    },
  );
  test('notification ids stay stable and distinct across chats and rooms', () {
    final a = PushNotificationService.chatNotificationId(42);
    expect(PushNotificationService.chatNotificationId(42), a);
    expect(PushNotificationService.chatNotificationId(43), isNot(a));
    expect(a, allOf(greaterThan(0), lessThan(0x80000000)));
    expect(
      PushNotificationService.callNotificationId('room-a'),
      isNot(PushNotificationService.callNotificationId('room-b')),
    );
  });
}
