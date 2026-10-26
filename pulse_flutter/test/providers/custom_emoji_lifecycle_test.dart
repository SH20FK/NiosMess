import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture1',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
  );
  void switchAccount() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'fixture2',
      userId: 2,
      username: 'two',
      displayName: 'Two',
    ),
  );
}

Map<String, dynamic> _sets(int id) => {
  'sets': [
    {'id': id, 'name': 'pack$id', 'title': 'Pack $id', 'emojis': []},
  ],
};
void main() {
  group('custom emoji account lifecycle and offline metadata', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    ProviderContainer make(
      Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
      request,
    ) {
      final ws = WebSocketClient(
        baseUrl: 'https://invalid.test',
        readToken: () => 'fixture',
      );
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          webSocketClientProvider.overrideWithValue(ws),
          customEmojiRequestProvider.overrideWithValue(request),
        ],
      );
      addTearDown(() {
        container.dispose();
        ws.close();
      });
      return container;
    }

    test(
      'refresh persists added packs and offline restart restores them',
      () async {
        var id = 1;
        final container = make((_, _) async => _sets(id));
        expect(
          (await container.read(customEmojiSetsProvider.future)).single.id,
          1,
        );
        id = 2;
        await container.read(customEmojiSetsProvider.notifier).refresh();
        final prefs = await SharedPreferences.getInstance();
        expect(
          (jsonDecode(prefs.getString('custom_emoji_sets_v1_1')!) as List)
              .single['id'],
          2,
        );
        final offline = make((_, _) => Future.error(StateError('offline')));
        expect(
          (await offline.read(customEmojiSetsProvider.future)).single.id,
          2,
        );
      },
    );
    test(
      'older refresh cannot overwrite the newer list or its disk cache',
      () async {
        final requests = <Completer<Map<String, dynamic>>>[];
        var initial = true;
        final container = make((_, _) {
          if (initial) {
            initial = false;
            return Future.value(_sets(1));
          }
          final pending = Completer<Map<String, dynamic>>();
          requests.add(pending);
          return pending.future;
        });
        await container.read(customEmojiSetsProvider.future);
        final notifier = container.read(customEmojiSetsProvider.notifier);
        final older = notifier.refresh(), newer = notifier.refresh();
        requests[1].complete(_sets(3));
        await newer;
        requests[0].complete(_sets(2));
        await older;
        expect(container.read(customEmojiSetsProvider).value!.single.id, 3);
        final prefs = await SharedPreferences.getInstance();
        expect(
          (jsonDecode(prefs.getString('custom_emoji_sets_v1_1')!) as List)
              .single['id'],
          3,
        );
      },
    );
    test(
      'account switch fences delayed refresh and never writes the new account key',
      () async {
        final pending = Completer<Map<String, dynamic>>();
        var calls = 0;
        final container = make((_, _) {
          calls++;
          return calls == 2 ? pending.future : Future.value(_sets(calls));
        });
        await container.read(customEmojiSetsProvider.future);
        final refresh = container
            .read(customEmojiSetsProvider.notifier)
            .refresh();
        (container.read(authProvider.notifier) as _Auth).switchAccount();
        await container.read(customEmojiSetsProvider.future);
        pending.complete(_sets(99));
        await refresh;
        expect(container.read(customEmojiSetsProvider).value!.single.id, 3);
        final prefs = await SharedPreferences.getInstance();
        expect(
          (jsonDecode(prefs.getString('custom_emoji_sets_v1_2')!) as List)
              .single['id'],
          3,
        );
        expect(
          (jsonDecode(prefs.getString('custom_emoji_sets_v1_1')!) as List)
              .single['id'],
          1,
        );
      },
    );
    test(
      'dispose fences a late refresh without accessing disposed ref',
      () async {
        final pending = Completer<Map<String, dynamic>>();
        var calls = 0;
        final ws = WebSocketClient(
          baseUrl: 'https://invalid.test',
          readToken: () => 'fixture',
        );
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            webSocketClientProvider.overrideWithValue(ws),
            customEmojiRequestProvider.overrideWithValue(
              (_, _) => ++calls == 1 ? Future.value(_sets(1)) : pending.future,
            ),
          ],
        );
        await container.read(customEmojiSetsProvider.future);
        final refresh = container
            .read(customEmojiSetsProvider.notifier)
            .refresh();
        container.dispose();
        pending.complete(_sets(2));
        await refresh;
        ws.close();
      },
    );
    test(
      'switch immediately clears previous account packs while the new request is pending',
      () async {
        final pending = Completer<Map<String, dynamic>>();
        var calls = 0;
        final container = make(
          (_, _) => ++calls == 1 ? Future.value(_sets(1)) : pending.future,
        );
        await container.read(customEmojiSetsProvider.future);
        (container.read(authProvider.notifier) as _Auth).switchAccount();
        final next = container.read(customEmojiSetsProvider.future);
        expect(container.read(customEmojiSetsProvider).value ?? [], isEmpty);
        var finished = false;
        final observed = next.then((_) => finished = true);
        await Future<void>.delayed(Duration.zero);
        expect(finished, isFalse);
        pending.complete(_sets(2));
        await observed;
        expect(container.read(customEmojiSetsProvider).value!.single.id, 2);
      },
    );
  });
}
