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
        notifier.setPreference('private', false),
        notifier.setPreference('calls', false),
      ]);

      final NotificationPreferences value = c
          .read(notificationPreferencesProvider)
          .value!;
      expect(value.privateMessages, isFalse);
      expect(value.calls, isFalse);
      expect(value.groups, isTrue);
      expect(value.activity, isTrue);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> stored =
          jsonDecode(prefs.getString(_key)!) as Map<String, dynamic>;
      expect(stored['private'], isFalse);
      expect(stored['calls'], isFalse);
      expect(auth.registrations, 2);
    });

    test('a legacy messages fallback stays on while any kind is on', () async {
      final ProviderContainer c = await boot();
      await c
          .read(notificationPreferencesProvider.notifier)
          .setPreference('groups', false);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> stored =
          jsonDecode(prefs.getString(_key)!) as Map<String, dynamic>;
      // A server that predates the three kinds still understands this one.
      expect(stored['messages'], isTrue);
      expect(stored['groups'], isFalse);
      expect(stored['private'], isTrue);
      expect(stored['channels'], isTrue);

      // Every kind off must silence that older server too.
      await c
          .read(notificationPreferencesProvider.notifier)
          .setPreference('private', false);
      await c
          .read(notificationPreferencesProvider.notifier)
          .setPreference('channels', false);
      final Map<String, dynamic> off =
          jsonDecode(prefs.getString(_key)!) as Map<String, dynamic>;
      expect(off['messages'], isFalse);
    });

    test('reset turns every category back on and drops the key', () async {
      final ProviderContainer c = await boot(<String, Object>{
        _key: jsonEncode(<String, bool>{'messages': false, 'sound': false}),
      });
      expect(
        c.read(notificationPreferencesProvider).value!.privateMessages,
        isFalse,
      );

      await c.read(notificationPreferencesProvider.notifier).reset();

      final NotificationPreferences value = c
          .read(notificationPreferencesProvider)
          .value!;
      expect(value.privateMessages, isTrue);
      expect(value.groups, isTrue);
      expect(value.channels, isTrue);
      expect(value.sound, isTrue);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(_key), isFalse);
      expect(auth.registrations, 1);
    });
  });

  group('Legacy JSON migration', () {
    test('messages off without new keys disables all three kinds', () async {
      final ProviderContainer c = await boot(<String, Object>{
        _key: jsonEncode(<String, bool>{'messages': false}),
      });
      final NotificationPreferences value = c
          .read(notificationPreferencesProvider)
          .value!;
      expect(value.privateMessages, isFalse);
      expect(value.groups, isFalse);
      expect(value.channels, isFalse);
      // Unrelated categories are untouched by the migration.
      expect(value.calls, isTrue);
    });

    test('messages on without new keys keeps all three kinds on', () async {
      final ProviderContainer c = await boot(<String, Object>{
        _key: jsonEncode(<String, bool>{'messages': true}),
      });
      final NotificationPreferences value = c
          .read(notificationPreferencesProvider)
          .value!;
      expect(value.privateMessages, isTrue);
      expect(value.groups, isTrue);
      expect(value.channels, isTrue);
    });

    test('new keys win over a legacy messages switch', () async {
      final ProviderContainer c = await boot(<String, Object>{
        _key: jsonEncode(<String, dynamic>{
          'messages': false,
          'private': false,
          'groups': true,
          'channels': false,
        }),
      });
      final NotificationPreferences value = c
          .read(notificationPreferencesProvider)
          .value!;
      expect(value.privateMessages, isFalse);
      expect(value.groups, isTrue);
      expect(value.channels, isFalse);
    });

    test('missing new keys inside a migrated blob default to on', () async {
      final ProviderContainer c = await boot(<String, Object>{
        _key: jsonEncode(<String, bool>{'private': false}),
      });
      final NotificationPreferences value = c
          .read(notificationPreferencesProvider)
          .value!;
      expect(value.privateMessages, isFalse);
      expect(value.groups, isTrue);
      expect(value.channels, isTrue);
    });
  });

  group('messagesEnabledFor', () {
    const NotificationPreferences value = NotificationPreferences(
      privateMessages: false,
      groups: true,
      channels: false,
    );

    test('maps wire kinds and local chat types', () {
      expect(value.messagesEnabledFor('private'), isFalse);
      expect(value.messagesEnabledFor('direct'), isFalse);
      expect(value.messagesEnabledFor('group'), isTrue);
      expect(value.messagesEnabledFor('channel'), isFalse);
    });

    test('unknown kinds stay on unless every kind is off', () {
      expect(value.messagesEnabledFor(null), isTrue);
      expect(value.messagesEnabledFor('reminder'), isTrue);

      const NotificationPreferences allOff = NotificationPreferences(
        privateMessages: false,
        groups: false,
        channels: false,
      );
      expect(allOff.messagesEnabledFor(null), isFalse);
      expect(allOff.messagesEnabledFor('unknown'), isFalse);
    });
  });
}
