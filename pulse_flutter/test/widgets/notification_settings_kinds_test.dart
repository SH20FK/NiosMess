import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/screens/settings_notifications_screen.dart';
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

class _Sound extends SoundService {
  @override
  Future<void> playEvent(SoundEvent event, {double? volume}) async {}
}

const String _key = 'notification_preferences_1';

Widget _app(Widget screen, {ProviderContainer? container}) {
  final content = MaterialApp(
    theme: ThemeData(useMaterial3: true),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: screen,
  );
  return container == null
      ? ProviderScope(child: content)
      : UncontrolledProviderScope(container: container, child: content);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('one switch per chat kind replaces the messages row', (
    tester,
  ) async {
    final auth = _Auth();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => auth),
        appSoundProvider.overrideWithValue(_Sound()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(const SettingsNotificationsScreen(), container: container),
    );
    await tester.pumpAndSettle();

    expect(find.text('Private chats'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('Channels'), findsOneWidget);
    // The old single "Messages" row is gone.
    expect(find.text('Messages'), findsNothing);
    expect(auth.registrations, 0);

    // Flip Groups off: the other two kinds stay on.
    await tester.ensureVisible(find.text('Groups'));
    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();

    final NotificationPreferences value = container
        .read(notificationPreferencesProvider)
        .value!;
    expect(value.groups, isFalse);
    expect(value.privateMessages, isTrue);
    expect(value.channels, isTrue);
    expect(auth.registrations, 1);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> stored =
        jsonDecode(prefs.getString(_key)!) as Map<String, dynamic>;
    expect(stored['groups'], isFalse);
    // The old server learns about the change through this one switch.
    expect(stored['messages'], isTrue);

    // And back on, still without waking the other switches.
    await tester.ensureVisible(find.text('Groups'));
    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(
      container.read(notificationPreferencesProvider).value!.groups,
      isTrue,
    );
    expect(
      container.read(notificationPreferencesProvider).value!.privateMessages,
      isTrue,
    );
  });
}
