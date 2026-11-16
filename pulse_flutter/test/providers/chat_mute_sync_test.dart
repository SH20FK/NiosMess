import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  int registrations = 0;

  @override
  AuthState build() => _state(1);

  static AuthState _state(int userId) => AuthState(
    hydrated: true,
    busy: false,
    session: AuthSession(
      accessToken: 'fixture',
      userId: userId,
      username: 'account$userId',
      displayName: 'Account $userId',
    ),
    pendingIdentifier: null,
    error: null,
    profile: null,
  );

  void switchAccount(int userId) {
    state = _state(userId);
  }

  @override
  Future<void> refreshFcmTokenRegistration() async {
    registrations++;
  }
}

String _key(int account, int chatId) =>
    'chat_notifications_muted_${account}_$chatId';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Auth auth;

  ProviderContainer container() {
    auth = _Auth();
    final ProviderContainer result = ProviderContainer(
      overrides: [authProvider.overrideWith(() => auth)],
    );
    addTearDown(result.dispose);
    return result;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _key(1, 5): true,
      _key(1, 6): false,
      _key(2, 9): true,
    });
  });

  test('hub loads only the current account mute set', () async {
    final ProviderContainer c = container();

    expect(await c.read(chatMuteHubProvider.future), <int>{5});
    expect(await c.read(chatMutedProvider(5).future), isTrue);
    expect(await c.read(chatMutedProvider(6).future), isFalse);
    expect(await c.read(chatMutedProvider(9).future), isFalse);
    // One family element per chat is cheap now: state lives in the hub.
    expect(c.read(chatMuteHubProvider).value, <int>{5});
  });

  test('toggle persists the prefs mirror and refreshes FCM registration', () async {
    final ProviderContainer c = container();
    await c.read(chatMuteHubProvider.future);

    await c.read(chatMutedProvider(7).notifier).toggle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_key(1, 7)), isTrue);
    expect(c.read(chatMuteHubProvider).value, <int>{5, 7});
    expect(await c.read(chatMutedProvider(7).future), isTrue);
    expect(auth.registrations, 1);

    await c.read(chatMutedProvider(7).notifier).setMuted(false);

    expect(prefs.getBool(_key(1, 7)), isFalse);
    expect(c.read(chatMuteHubProvider).value, <int>{5});
    expect(await c.read(chatMutedProvider(7).future), isFalse);
    expect(auth.registrations, 2);
  });

  test('server mute hint is applied and persisted', () async {
    final ProviderContainer c = container();
    await c.read(chatMuteHubProvider.future);

    await c.read(chatMuteHubProvider.notifier).applyServerMute(8, true);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_key(1, 8)), isTrue);
    expect(await c.read(chatMutedProvider(8).future), isTrue);
    expect(auth.registrations, 1);

    // Re-delivered hint must not re-register the FCM token.
    await c.read(chatMuteHubProvider.notifier).applyServerMute(8, true);
    expect(auth.registrations, 1);

    await c.read(chatMuteHubProvider.notifier).applyServerMute(5, false);
    expect(prefs.getBool(_key(1, 5)), isFalse);
    expect(await c.read(chatMutedProvider(5).future), isFalse);
  });

  test('account switch reloads the mute set', () async {
    final ProviderContainer c = container();
    expect(await c.read(chatMutedProvider(5).future), isTrue);

    auth.switchAccount(2);
    await c.read(chatMuteHubProvider.future);

    expect(await c.read(chatMutedProvider(9).future), isTrue);
    expect(await c.read(chatMutedProvider(5).future), isFalse);
  });
}
