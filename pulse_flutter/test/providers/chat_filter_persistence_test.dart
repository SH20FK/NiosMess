// The inbox type filter between launches:
// * a chat type (groups, channels, direct, bots) is remembered per account;
// * "unread" is not: reopening into an empty unread list reads as lost chats;
// * a choice made while the store is still opening wins over the saved one.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/chat_filter_provider.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 7,
      username: 'me',
      displayName: 'Me',
    ),
  );
}

const String _key = 'chat_filter_v1_7';

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer launch() {
    final ProviderContainer container = ProviderContainer(
      overrides: [authProvider.overrideWith(_Auth.new)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a chat type survives a restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer first = launch();
    expect(first.read(chatFilterProvider), ChatFilter.all);
    await _settle();
    first.read(chatFilterProvider.notifier).updateFilter(ChatFilter.channels);
    await _settle();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_key), 'channels');

    final ProviderContainer second = launch();
    // The store opens asynchronously: the first frame shows every chat.
    expect(second.read(chatFilterProvider), ChatFilter.all);
    await _settle();
    expect(second.read(chatFilterProvider), ChatFilter.channels);
  });

  test('unread is a passing view and is not remembered', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{_key: 'groups'});
    final ProviderContainer first = launch();
    first.read(chatFilterProvider);
    await _settle();
    expect(first.read(chatFilterProvider), ChatFilter.groups);

    first.read(chatFilterProvider.notifier).updateFilter(ChatFilter.unread);
    await _settle();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_key), isNull);

    final ProviderContainer second = launch();
    second.read(chatFilterProvider);
    await _settle();
    expect(second.read(chatFilterProvider), ChatFilter.all);
  });

  test('a choice made before the store opens wins over the saved one', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{_key: 'groups'});
    final ProviderContainer container = launch();
    container.read(chatFilterProvider);
    container.read(chatFilterProvider.notifier).updateFilter(ChatFilter.direct);
    await _settle();

    expect(container.read(chatFilterProvider), ChatFilter.direct);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_key), 'direct');
  });

  test('a garbage value in the store falls back to every chat', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{_key: 'pinned'});
    final ProviderContainer container = launch();
    container.read(chatFilterProvider);
    await _settle();

    expect(container.read(chatFilterProvider), ChatFilter.all);
  });
}
