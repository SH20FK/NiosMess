import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('account-scoped protected drafts', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });
    test(
      'accounts sharing a chat ID never see one another drafts, including whitespace',
      () async {
        final a = DraftStorage.forAccount(1), b = DraftStorage.forAccount(2);
        await a.set(42, '  original text\n');
        await b.set(42, 'another account');
        expect(await a.get(42), '  original text\n');
        expect(await b.get(42), 'another account');
        expect(await a.asMap(), {42: '  original text\n'});
        expect(
          (await SharedPreferences.getInstance()).getKeys().where(
            (key) => key.startsWith('draft.'),
          ),
          isEmpty,
        );
        expect(
          await const FlutterSecureStorage().read(key: 'draft.secure.v2.1'),
          isNotNull,
        );
      },
    );
    test(
      'concurrent saves preserve both chats instead of losing one map update',
      () async {
        final a = DraftStorage.forAccount(1);
        await Future.wait([a.set(1, 'first'), a.set(2, 'second')]);
        expect(await a.asMap(), {1: 'first', 2: 'second'});
      },
    );
    test(
      'legacy source is removed only after known-owner secure copy is verified',
      () async {
        SharedPreferences.setMockInitialValues({
          'draft.42': 'legacy original',
          'draft.owner.42': 1,
        });
        FlutterSecureStorage.setMockInitialValues({'e2ee.legacy_owner': '1'});
        expect(await DraftStorage.forAccount(2).get(42), isNull);
        expect(
          (await SharedPreferences.getInstance()).getString('draft.42'),
          'legacy original',
        );
        expect(await DraftStorage.forAccount(1).get(42), 'legacy original');
        expect(
          (await SharedPreferences.getInstance()).getString('draft.42'),
          isNull,
        );
        expect(await DraftStorage.forAccount(1).get(42), 'legacy original');
      },
    );
    test(
      'ambiguous legacy owner remains untouched and is not exposed in inbox',
      () async {
        SharedPreferences.setMockInitialValues({'draft.42': 'unknown owner'});
        FlutterSecureStorage.setMockInitialValues({'e2ee.legacy_owner': '1'});
        final a = DraftStorage.forAccount(1);
        expect(await a.get(42), isNull);
        expect(await a.asMap(), isEmpty);
        expect(
          (await SharedPreferences.getInstance()).getString('draft.42'),
          'unknown owner',
        );
      },
    );
    test(
      'logout fences retained screen writes and only erases its account',
      () async {
        final old = DraftStorage.forAccount(1),
            other = DraftStorage.forAccount(2);
        await old.set(42, 'one');
        await other.set(42, 'two');
        await DraftStorage.eraseAccount(1);
        await expectLater(old.set(42, 'late dispose save'), throwsStateError);
        expect(await DraftStorage.forAccount(1).asMap(), isEmpty);
        expect(await other.get(42), 'two');
      },
    );
  });
}
