import 'dart:async';
import 'package:pulse_flutter/core/notifications/notification_reply_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/notifications/notification_event.dart';
import 'package:pulse_flutter/core/notifications/notification_history_store.dart';
import 'package:pulse_flutter/core/notifications/legacy_notification_archive.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/in_app_notification_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/notifications/in_app_notification_banner.dart';
import 'package:pulse_flutter/widgets/notifications/notification_overlay_host.dart';

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

class _Reply implements NotificationReplyService {
  final drafts = <int, String>{42: 'saved draft'};
  final sent = <String>[];
  bool fail = false;
  Completer<void>? saveGate;
  @override
  Future<String> loadDraft(int chatId) async => drafts[chatId] ?? '';
  @override
  Future<void> saveDraft(int chatId, String text) async {
    await saveGate?.future;
    drafts[chatId] = text;
  }

  @override
  Future<void> send(int chatId, String text, {required String localId}) async {
    if (fail) throw StateError('fixture offline');
    sent.add('$chatId:$text');
  }
}

class _History extends NotificationsNotifier {
  @override
  NotificationsState build() => const NotificationsState();
}

InAppNotificationItem _item(String id, String body, {int? chatId}) =>
    InAppNotificationItem(
      id: id,
      title: 'Мария · Рабочий чат',
      body: body,
      chatId: chatId,
      timestamp: DateTime(2026, 10, 24, 16, 20),
    );

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
  for (final tokenOnly in [false, true]) {
    test(
      'reply service is bound to its original account/token: tokenOnly=$tokenOnly',
      () async {
        final container = ProviderContainer(overrides: overrides());
        addTearDown(container.dispose);
        final service = container.read(notificationReplyServiceProvider);
        final auth = container.read(authProvider.notifier) as _Auth;
        tokenOnly ? auth.replaceToken() : auth.switchAccount();
        final replacement = container.read(notificationReplyServiceProvider);
        expect(identical(service, replacement), false);
        await expectLater(
          Future.sync(
            () => service.send(42, 'fixture old reply', localId: 'fixture'),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'code',
              'NOTIFICATION_ACCOUNT_CHANGED',
            ),
          ),
        );
      },
    );
  }
  test(
    'banner burst queues, merges a conversation and pauses its timeout',
    () async {
      final container = ProviderContainer(overrides: overrides());
      await container.read(notificationPreferencesProvider.future);
      final notifier = container.read(inAppNotificationProvider.notifier);
      notifier.show(_item('a', 'first', chatId: 42));
      notifier.show(_item('b', 'updated', chatId: 42));
      notifier.show(_item('c', 'next', chatId: 43));
      expect(container.read(inAppNotificationProvider)?.body, 'updated');
      notifier.pause(true);
      notifier.dismiss();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      expect(container.read(inAppNotificationProvider)?.id, 'c');
      notifier.clearAccount();
      container.dispose();
    },
  );
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

  testWidgets(
    'global banner updates same ID, wraps at 320px/200%, and tooltips have an Overlay',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      await container.read(notificationPreferencesProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            theme: ThemeData(useMaterial3: true),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: NotificationOverlayHost(
                child: Stack(
                  children: [child!, const InAppNotificationBannerOverlay()],
                ),
              ),
            ),
            home: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      final notifier = container.read(inAppNotificationProvider.notifier);
      notifier.show(_item('same', 'first', chatId: 42));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      notifier.show(_item('same', 'updated body', chatId: 42));
      await tester.pump();
      expect(find.text('updated body'), findsOneWidget);
      expect(find.text('first'), findsNothing);
      expect(find.text('Reply'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.longPress(find.byTooltip('Close'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      notifier.clearAccount();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'account switch during draft persistence cannot send old reply with new credentials',
    (tester) async {
      final reply = _Reply();
      final container = ProviderContainer(
        overrides: [
          ...overrides(),
          notificationReplyServiceProvider.overrideWithValue(reply),
          notificationsProvider.overrideWith(_History.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(notificationPreferencesProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            theme: ThemeData(useMaterial3: true),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Stack(
                children: [SizedBox.expand(), InAppNotificationBannerOverlay()],
              ),
            ),
          ),
        ),
      );
      container
          .read(inAppNotificationProvider.notifier)
          .show(_item('old-account', 'incoming', chatId: 42));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'fixture important old reply',
      );
      await tester.pump(const Duration(milliseconds: 350));
      final gate = Completer<void>();
      reply.saveGate = gate;
      await tester.tap(find.text('Send'));
      await tester.pump();
      (container.read(authProvider.notifier) as _Auth).switchAccount();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      gate.complete();
      reply.saveGate = null;
      await tester.pumpAndSettle();
      expect(reply.sent, isEmpty);
      expect(find.byType(TextField), findsNothing);
      reply.drafts[42] = 'new account fixture draft';
      container
          .read(inAppNotificationProvider.notifier)
          .show(_item('new-account', 'incoming', chatId: 42));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'new account fixture draft'),
        findsOneWidget,
      );
      container.read(inAppNotificationProvider.notifier).clearAccount();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'inline reply keeps its draft on failure, survives timeout and sends without navigation',
    (tester) async {
      final reply = _Reply();
      final container = ProviderContainer(
        overrides: [
          ...overrides(),
          notificationReplyServiceProvider.overrideWithValue(reply),
          notificationsProvider.overrideWith(_History.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(notificationPreferencesProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            theme: ThemeData(useMaterial3: true),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Stack(
                children: [SizedBox.expand(), InAppNotificationBannerOverlay()],
              ),
            ),
          ),
        ),
      );
      final notifier = container.read(inAppNotificationProvider.notifier);
      notifier.show(_item('reply-fixture', 'incoming', chatId: 42));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'saved draft'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'important reply');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(TextField), findsOneWidget);
      reply.fail = true;
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'important reply'), findsOneWidget);
      expect(reply.drafts[42], 'important reply');
      expect(
        find.text('Could not send. Your text is still here — try again.'),
        findsOneWidget,
      );
      reply.fail = false;
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(reply.sent, ['42:important reply']);
      expect(reply.drafts[42], '');
      expect(find.byType(TextField), findsNothing);
      expect(container.read(inAppNotificationProvider), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
