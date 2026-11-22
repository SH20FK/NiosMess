// In-place inbox search: the header becomes the field and the results replace
// the chat list, so nothing here pushes a route.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/features/chats/application/inbox_search_controller.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/search_repository.dart';
import 'package:pulse_flutter/widgets/chat/chat_list_header.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'me',
      displayName: 'Me',
    ),
  );
}

class _Repo extends Fake implements SearchRepository {
  final List<String> queries = <String>[];
  bool fail = false;

  @override
  Future<ApiSearchResult> search(String query) async {
    queries.add(query);
    if (fail) throw StateError('offline fixture');
    return const ApiSearchResult(
      users: <ApiSearchUser>[
        ApiSearchUser(
          id: 7,
          username: 'ann',
          displayName: 'Ann',
          bio: '',
          badges: [],
        ),
      ],
      chats: <ApiSearchChat>[],
      messages: <ApiSearchMessage>[],
    );
  }
}

ProviderContainer _container(_Repo repo) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(_Auth.new),
      searchRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Longer than the controller's 220 ms debounce. Only for asserting that
/// nothing happened; positive outcomes are awaited with [_until].
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 320));

/// Waits for [condition] instead of a fixed delay, so a loaded test run cannot
/// outpace the debounce.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 300 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a burst of typing sends one trimmed request', () async {
    final _Repo repo = _Repo();
    final ProviderContainer c = _container(repo);
    final InboxSearchController search = c.read(inboxSearchProvider.notifier);

    // Typing into a closed search is ignored.
    search.setQuery('ann');
    expect(c.read(inboxSearchProvider).active, isFalse);

    search.open();
    expect(c.read(inboxSearchProvider).active, isTrue);
    // Open but empty: the chat list stays on screen.
    expect(c.read(inboxSearchProvider).hasQuery, isFalse);

    search.setQuery('a');
    search.setQuery(' an');
    search.setQuery(' ann ');
    expect(c.read(inboxSearchProvider).query, 'ann');
    expect(c.read(inboxSearchProvider).loading, isTrue);

    await _until(() => !c.read(inboxSearchProvider).loading);
    expect(repo.queries, <String>['ann']);
    final InboxSearchState state = c.read(inboxSearchProvider);
    expect(state.loading, isFalse);
    expect(state.failed, isFalse);
    expect(state.result?.users.single.username, 'ann');
  });

  test('scope survives typing; close drops the query and its request', () async {
    final _Repo repo = _Repo();
    final ProviderContainer c = _container(repo);
    final InboxSearchController search = c.read(inboxSearchProvider.notifier);

    search.open();
    search.setScope(InboxSearchScope.people);
    search.setQuery('ann');
    expect(c.read(inboxSearchProvider).scope, InboxSearchScope.people);

    search.close();
    await _settle();
    expect(repo.queries, isEmpty);
    expect(c.read(inboxSearchProvider).active, isFalse);
    expect(c.read(inboxSearchProvider).scope, InboxSearchScope.all);
  });

  test('a failed request is reported and retry repeats it', () async {
    final _Repo repo = _Repo()..fail = true;
    final ProviderContainer c = _container(repo);
    final InboxSearchController search = c.read(inboxSearchProvider.notifier);

    search.open();
    search.setQuery('ann');
    await _until(() => !c.read(inboxSearchProvider).loading);
    expect(c.read(inboxSearchProvider).failed, isTrue);
    expect(c.read(inboxSearchProvider).loading, isFalse);

    repo.fail = false;
    search.retry();
    expect(c.read(inboxSearchProvider).loading, isTrue);
    await _until(() => !c.read(inboxSearchProvider).loading);
    expect(c.read(inboxSearchProvider).failed, isFalse);
    expect(c.read(inboxSearchProvider).result, isNotNull);
    expect(repo.queries, <String>['ann', 'ann']);
  });

  Future<ProviderContainer> pumpHost(
    WidgetTester tester,
    Widget home, {
    bool withAuth = true,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        if (withAuth) authProvider.overrideWith(_Auth.new),
        searchRepositoryProvider.overrideWithValue(_Repo()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(useMaterial3: true),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  const ValueKey<String> openKey = ValueKey<String>('inbox-search-open');
  const ValueKey<String> fieldKey = ValueKey<String>('inbox-search-field');
  const ValueKey<String> clearKey = ValueKey<String>('inbox-search-clear');
  const ValueKey<String> closeKey = ValueKey<String>('inbox-search-close');

  testWidgets('the header turns into a search field in place', (tester) async {
    final ProviderContainer c = await pumpHost(
      tester,
      const Scaffold(appBar: ChatListHeader()),
    );
    expect(find.text('Чаты'), findsOneWidget);
    expect(find.byKey(fieldKey), findsNothing);

    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();

    expect(c.read(inboxSearchProvider).active, isTrue);
    expect(find.byKey(fieldKey), findsOneWidget);
    // Same bar, no second route: the title is gone, the field took its slot.
    expect(find.text('Чаты'), findsNothing);
    expect(find.byKey(openKey), findsNothing);
    expect(tester.getSize(find.byType(ChatListHeader)).height, 64);
    // Nothing typed yet: no clear button.
    expect(find.byKey(clearKey), findsNothing);

    await tester.enterText(find.byKey(fieldKey), 'ann');
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    expect(c.read(inboxSearchProvider).query, 'ann');
    expect(find.byKey(clearKey), findsOneWidget);

    await tester.tap(find.byKey(clearKey));
    await tester.pumpAndSettle();
    expect(c.read(inboxSearchProvider).query, isEmpty);
    // Clearing keeps the search open.
    expect(c.read(inboxSearchProvider).active, isTrue);
    expect(find.byKey(fieldKey), findsOneWidget);

    await tester.tap(find.byKey(closeKey));
    await tester.pumpAndSettle();
    expect(c.read(inboxSearchProvider).active, isFalse);
    expect(find.byKey(fieldKey), findsNothing);
    expect(find.text('Чаты'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape closes the search', (tester) async {
    final ProviderContainer c = await pumpHost(
      tester,
      const Scaffold(appBar: ChatListHeader()),
    );
    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();
    expect(c.read(inboxSearchProvider).active, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(c.read(inboxSearchProvider).active, isFalse);
    expect(find.byKey(fieldKey), findsNothing);
  });

  testWidgets('search field fits 320 dp at 200% text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpHost(
      tester,
      Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: const Scaffold(appBar: ChatListHeader()),
        ),
      ),
    );
    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(fieldKey), 'очень длинный запрос');
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(closeKey).hitTestable(), findsOneWidget);
    expect(find.byKey(clearKey).hitTestable(), findsOneWidget);
  });
}
