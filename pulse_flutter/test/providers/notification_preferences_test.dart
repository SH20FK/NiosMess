import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  int registrations = 0;

  @override
  AuthState build() => const AuthState(
    hydrated: true,
    busy: false,
    session: AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'account1',
      displayName: 'Account 1',
    ),
    pendingIdentifier: null,
    error: null,
    profile: null,
  );

  @override
  Future<void> refreshFcmTokenRegistration() async {
    registrations++;
  }
}

const String _key = 'notification_preferences_1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Auth auth;

  Future<ProviderContainer> boot([
    Map<String, Object> initial = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    auth = _Auth();
    final ProviderContainer container = ProviderContainer(
      overrides: [authProvider.overrideWith(() => auth)],
    );
    addTearDown(container.dispose);
    await container.read(notificationPreferencesProvider.future);
    return container;
  }

  group('Notification preferences', () {
    test('two switches flipped back to back keep both values', () async {
      final ProviderContainer c = await boot();
      final NotificationPreferencesNotifier notifier = c.read(
        notificationPreferencesProvider.notifier,
      );

      await Future.wait(<Future<void>>[
        notifier.setPreference('messages', false),
        notifier.setPreference('calls', false),
      ]);

      final NotificationPreferences value = c
          .read(notificationPreferencesProvider)
          .value!;
      expect(value.messages, isFalse);
      expect(value.calls, isFalse);
      expect(value.activity, isTrue);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> stored =
          jsonDecode(prefs.getString(_key)!) as Map<String, dynamic>;
      expect(stored['messages'], isFalse);
      expect(stored['calls'], isFalse);
      expect(auth.registrations, 2);
    });

    test('reset turns every category back on and drops the key', () async {
      final ProviderContainer c = await boot(<String, Object>{
        _key: jsonEncode(<String, bool>{'messages': false, 'sound': false}),
      });
      expect(c.read(notificationPreferencesProvider).value!.messages, isFalse);

      await c.read(notificationPreferencesProvider.notifier).reset();

      final NotificationPreferences value = c
          .read(notificationPreferencesProvider)
          .value!;
      expect(value.messages, isTrue);
      expect(value.sound, isTrue);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(_key), isFalse);
      expect(auth.registrations, 1);
    });
  });
}
