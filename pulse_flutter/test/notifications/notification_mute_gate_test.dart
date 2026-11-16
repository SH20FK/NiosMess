import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    hydrated: true,
    busy: false,
    session: AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
    pendingIdentifier: null,
    error: null,
    profile: null,
  );
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults();
}

class _Options extends NotificationPreferencesNotifier {
  @override
  Future<NotificationPreferences> build() async =>
      const NotificationPreferences();
}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');

  final StreamController<Map<String, dynamic>> pushes =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get pushStream => pushes.stream;

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async => <String, dynamic>{};

  @override
  void close() {
    unawaited(pushes.close());
    super.close();
  }
}

Map<String, dynamic> _message(int chatId, String body) => <String, dynamic>{
  'event_id': 'message:$chatId:1',
  'account_id': 1,
  'chat_id': chatId,
  'title': 'Chat $chatId',
  'body': body,
  'created_at': DateTime.now().toUtc().toIso8601String(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accept() drops notifications for a muted chat', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'chat_notifications_muted_1_9': true,
    });
    final _Socket socket = _Socket();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        webSocketClientProvider.overrideWithValue(socket),
        authProvider.overrideWith(_Auth.new),
        uiSettingsProvider.overrideWith(_Settings.new),
        notificationPreferencesProvider.overrideWith(_Options.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(socket.close);

    final NotificationsNotifier notifier = container.read(
      notificationsProvider.notifier,
    );
    await notifier.accept(_message(9, 'muted text'));
    expect(container.read(notificationsProvider).notifications, isEmpty);

    await notifier.accept(_message(8, 'audible text'), present: false);
    expect(
      container.read(notificationsProvider).notifications.single.body,
      'audible text',
    );
  });
}
