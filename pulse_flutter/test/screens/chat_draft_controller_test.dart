// Tests for `lib/screens/chat_detail/chat_draft_controller.dart`.
//
// The controller took draft persistence out of `_ChatDetailScreenState`. These
// tests freeze the seven invariants the split had to keep:
//   1. `DraftStorage` is handed in (the screen caches it in `initState`), so the
//      controller never reads `ref` — this file never builds a provider scope.
//   2. `dispose()` cancels the pending debounce **before** the final save; the
//      last <500 ms of typing is written exactly once.
//   3. A failing secret-engine write is swallowed: a secret chat cannot break
//      because the journal is unavailable.
//   4. The ordinary-persistence gate keeps a secret chat out of `DraftStorage`.
//   5. `isSecret` is read when it matters, not in the constructor.
//   6. `applyRemote` never overwrites text typed since the last save.
//   7. The empty string keeps its current meaning: `set('')` (storage drops the
//      key) from `saveNow`, `remove` from `clear`.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_draft_controller.dart';

/// Stands in for the account-scoped store. The write path mirrors
/// `DraftStorage.set`: an empty text removes the key.
class _FakeStorage implements DraftStorage {
  @override
  int? get accountId => 7;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  final Map<int, String> drafts = <int, String>{};
  final List<(int, String)> sets = <(int, String)>[];
  final List<int> removes = <int>[];
  int getCalls = 0;
  Object? writeFailure;

  @override
  Future<String?> get(int chatId) async {
    getCalls++;
    return drafts[chatId];
  }

  @override
  Future<void> set(int chatId, String text) async {
    sets.add((chatId, text));
    if (writeFailure != null) throw writeFailure!;
    if (text.trim().isEmpty) {
      drafts.remove(chatId);
    } else {
      drafts[chatId] = text;
    }
  }

  @override
  Future<void> remove(int chatId) async {
    removes.add(chatId);
    drafts.remove(chatId);
  }

  @override
  Future<bool> compareAndSet(
    int chatId,
    String expected,
    String replacement,
  ) async {
    if ((drafts[chatId] ?? '') != expected) return false;
    await set(chatId, replacement);
    return true;
  }

  @override
  Future<List<ChatDraftEntry>> list() async => <ChatDraftEntry>[
    for (final MapEntry<int, String> entry in drafts.entries)
      ChatDraftEntry(chatId: entry.key, text: entry.value),
  ];

  @override
  Future<Map<int, String>> asMap() async => Map<int, String>.of(drafts);
}

/// Fake secret engine. `open` mirrors `engine.findChat(chatId) != null`.
class _FakeSecretSink implements SecretDraftSink {
  bool open = false;
  final Map<int, String> drafts = <int, String>{};
  final List<(int, String)> saves = <(int, String)>[];
  final List<int> reads = <int>[];
  Object? saveFailure;

  @override
  bool isOpen(int chatId) => open;

  @override
  String? read(int chatId) {
    reads.add(chatId);
    return drafts[chatId];
  }

  @override
  Future<void> save(int chatId, String text) async {
    saves.add((chatId, text));
    if (saveFailure != null) throw saveFailure!;
    drafts[chatId] = text;
  }
}

class _Harness {
  _Harness({this.secret = false, this.canPersist = true}) {
    controller = ChatDraftController(
      chatId: chatId,
      textController: text,
      storage: storage,
      isSecret: () => secret,
      canPersistOrdinaryDraft: () => canPersist,
      onBannerChanged: () => bannerChanges++,
      secretSink: () => sink,
      ensureSecretReady: () async => readyCalls++,
      onError: errors.add,
    );
  }

  final int? chatId = 42;
  bool secret;
  bool canPersist;
  final TextEditingController text = TextEditingController();
  final _FakeStorage storage = _FakeStorage();
  final _FakeSecretSink sink = _FakeSecretSink();
  final List<Object> errors = <Object>[];
  int bannerChanges = 0;
  int readyCalls = 0;
  late final ChatDraftController controller;

  void dispose() {
    controller.dispose();
    text.dispose();
  }
}

void main() {
  group('ChatDraftController', () {
    test('restore loads an ordinary draft, raises the banner once and never '
        'overwrites a non-empty composer', () async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);
      h.storage.drafts[42] = 'hello';

      await h.controller.restore();

      expect(h.text.text, 'hello');
      expect(h.controller.showRestoredBanner, isTrue);
      expect(h.bannerChanges, 1);
      expect(h.sink.reads, isEmpty, reason: 'ordinary chat is not secret');

      h.text.text = 'typed already';
      await h.controller.restore();
      expect(h.text.text, 'typed already');
    });

    test('saveNow persists an ordinary draft and no banner is raised on save',
        () async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);

      h.text.text = '  hello  ';
      h.controller.saveNow();
      await pumpEventQueue();

      expect(h.storage.sets, <(int, String)>[(42, 'hello')]);
      expect(h.storage.drafts[42], 'hello');
      expect(h.controller.showRestoredBanner, isFalse);
      expect(h.errors, isEmpty);
    });

    test('saveNow with empty text calls set("") and the store drops the key '
        'instead of calling remove', () async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);
      h.storage.drafts[42] = 'old';

      h.text.text = '   ';
      h.controller.saveNow();
      await pumpEventQueue();

      expect(h.storage.sets, <(int, String)>[(42, '')]);
      expect(h.storage.removes, isEmpty);
      expect(h.storage.drafts, isEmpty);
      expect(h.errors, isEmpty);
    });

    test('the ordinary gate keeps the store untouched while it is closed',
        () async {
      final _Harness h = _Harness(canPersist: false);
      addTearDown(h.dispose);

      h.text.text = 'draft';
      h.controller.saveNow();
      await pumpEventQueue();

      expect(h.storage.sets, isEmpty);
      // And a remote draft may not land either: the composer still holds text
      // the user typed after the last (blocked) save.
      h.controller.applyRemote('remote');
      expect(h.text.text, 'draft');
    });

    testWidgets('debounce writes once, 500 ms after the last keystroke',
        (WidgetTester tester) async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);

      for (final String value in <String>['h', 'he', 'hel', 'hell', 'hello']) {
        h.text.text = value;
        h.controller.scheduleSave();
      }
      expect(h.controller.hasPendingSave, isTrue);

      await tester.pump(const Duration(milliseconds: 499));
      expect(h.storage.sets, isEmpty);

      await tester.pump(const Duration(milliseconds: 2));
      expect(h.storage.sets, <(int, String)>[(42, 'hello')]);

      await tester.pump(const Duration(seconds: 2));
      expect(h.storage.sets, <(int, String)>[(42, 'hello')]);
      expect(h.controller.hasPendingSave, isFalse);
    });

    test('a secret chat writes to the engine and never to DraftStorage',
        () async {
      final _Harness h = _Harness(secret: true);
      addTearDown(h.dispose);

      h.text.text = 'shh';
      h.controller.saveNow();
      await pumpEventQueue();

      expect(h.storage.sets, isEmpty);
      expect(h.storage.drafts, isEmpty);
      expect(h.sink.saves, <(int, String)>[(42, 'shh')]);
      expect(h.sink.drafts[42], 'shh');
    });

    test('a chat the engine already owns is routed to the engine even before '
        'metadata flags it secret', () async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);
      h.sink.open = true;
      h.sink.drafts[42] = 'legacy';

      h.text.text = 'typed';
      h.controller.saveNow();
      await pumpEventQueue();

      expect(h.storage.sets, isEmpty);
      expect(h.sink.saves, <(int, String)>[(42, 'typed')]);
    });

    test('isSecret is read lazily: flipping it after construction redirects '
        'the save', () async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);

      h.secret = true;
      h.text.text = 'late';
      h.controller.saveNow();
      await pumpEventQueue();

      expect(h.storage.sets, isEmpty);
      expect(h.sink.saves, <(int, String)>[(42, 'late')]);
    });

    test('restore for a secret chat waits for the coordinator and reads the '
        'engine draft', () async {
      final _Harness h = _Harness(secret: true);
      addTearDown(h.dispose);
      h.sink.drafts[42] = 'secret draft';

      await h.controller.restore();

      expect(h.readyCalls, 1);
      expect(h.sink.reads, <int>[42]);
      expect(h.storage.getCalls, 0);
      expect(h.text.text, 'secret draft');
      expect(h.controller.showRestoredBanner, isTrue);
    });

    test('a failing engine write is swallowed', () async {
      final _Harness h = _Harness(secret: true);
      addTearDown(h.dispose);
      h.sink.saveFailure = StateError('journal unavailable');

      h.text.text = 'shh';
      h.controller.saveNow();
      await pumpEventQueue();

      expect(h.sink.saves, hasLength(1));
      expect(h.errors, isEmpty);
    });

    test('an ordinary write failure is reported, not thrown', () async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);
      h.storage.writeFailure = StateError('DRAFT_ACCOUNT_CLOSED');

      h.text.text = 'draft';
      h.controller.saveNow();
      await pumpEventQueue();

      expect(h.errors.single, isA<StateError>());
    });

    test('clear() removes the ordinary draft and resets the banner',
        () async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);
      h.storage.drafts[42] = 'hello';
      await h.controller.restore();
      expect(h.controller.showRestoredBanner, isTrue);

      h.controller.clear();
      await pumpEventQueue();

      expect(h.storage.removes, <int>[42]);
      expect(h.storage.drafts, isEmpty);
      expect(h.sink.saves, isEmpty);
      expect(h.text.text, isEmpty);
      expect(h.controller.showRestoredBanner, isFalse);
      expect(h.bannerChanges, 2);
    });

    test('clear() writes an empty draft into the secret engine instead',
        () async {
      final _Harness h = _Harness(secret: true);
      addTearDown(h.dispose);
      h.text.text = 'secret';

      h.controller.clear();
      await pumpEventQueue();

      expect(h.sink.saves, <(int, String)>[(42, '')]);
      expect(h.storage.removes, isEmpty);
      expect(h.text.text, isEmpty);
    });

    test('applyRemote lands on an untouched composer and never overwrites '
        'what the user typed', () async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);

      h.controller.applyRemote('from another device');
      expect(h.text.text, 'from another device');

      h.text.text = 'typed here';
      h.controller.applyRemote('remote again');
      expect(h.text.text, 'typed here');
    });

    test('applyRemote replaces the last saved text, not a newer edit',
        () async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);

      h.text.text = 'saved';
      h.controller.saveNow();
      await pumpEventQueue();

      h.controller.applyRemote('remote');
      expect(h.text.text, 'remote');

      h.text.text = 'remote plus typing';
      h.controller.applyRemote('remote again');
      expect(h.text.text, 'remote plus typing');
    });

    testWidgets('dispose cancels the pending debounce, then saves the latest '
        'text exactly once', (WidgetTester tester) async {
      final _Harness h = _Harness();
      addTearDown(h.dispose);

      h.text.text = 'a';
      h.controller.scheduleSave();
      await tester.pump(const Duration(milliseconds: 300));
      h.text.text = 'ab';
      h.controller.scheduleSave();

      h.controller.dispose();

      expect(h.storage.sets, <(int, String)>[(42, 'ab')]);
      expect(h.text.text, 'ab');

      await tester.pump(const Duration(seconds: 1));
      expect(
        h.storage.sets,
        <(int, String)>[(42, 'ab')],
        reason: 'the cancelled timer must not fire after dispose',
      );
      expect(h.controller.hasPendingSave, isFalse);
    });

    test('dispose is idempotent and does not duplicate the final save',
        () async {
      final _Harness h = _Harness();
      addTearDown(h.text.dispose);

      h.text.text = 'last';
      h.controller.dispose();
      h.controller.dispose();
      await pumpEventQueue();

      expect(h.storage.sets, <(int, String)>[(42, 'last')]);
    });

    test('dispose saves a secret chat through the engine', () async {
      final _Harness h = _Harness(secret: true);
      addTearDown(h.text.dispose);

      h.text.text = 'secret last';
      h.controller.dispose();
      await pumpEventQueue();

      expect(h.storage.sets, isEmpty);
      expect(h.sink.saves, <(int, String)>[(42, 'secret last')]);
    });
  });
}
