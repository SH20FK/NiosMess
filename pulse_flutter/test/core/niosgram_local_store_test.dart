import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/core/storage/niosgram_draft_store.dart';
import 'package:pulse_flutter/core/storage/niosgram_saved_store.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:universal_io/io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NiosGram account-local data', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('niosgram-store-test-');
      Hive.init(directory.path);
      HiveBootstrap.resetForTesting();
      FlutterSecureStorage.setMockInitialValues({});
    });
    tearDown(() async {
      await Hive.close();
      HiveBootstrap.resetForTesting();
      await directory.delete(recursive: true);
    });

    test(
      'draft text, poll and encrypted media survive a new store instance',
      () async {
        final first = NiosgramDraftStore(101);
        final other = NiosgramDraftStore(102);
        final bytes = Uint8List.fromList(
          utf8.encode('test-only media payload'),
        );
        final file = await first.saveFile('clip.mp4', bytes, durationMs: 3300);
        await first.write(
          NiosgramPostDraft(
            text: 'a draft :custom_emoji:',
            poll: {
              'question': 'Question?',
              'options': ['yes', 'no'],
            },
            files: [file],
          ),
        );
        final restored = NiosgramDraftStore(101);
        final draft = (await restored.read())!;
        expect(draft.text, 'a draft :custom_emoji:');
        expect(draft.poll!['question'], 'Question?');
        expect(draft.files.single.name, 'clip.mp4');
        expect(draft.files.single.durationMs, 3300);
        expect(
          await restored.readFile(draft.files.single),
          orderedEquals(bytes),
        );
        expect(await other.read(), isNull);
        final box = Hive.lazyBox<Uint8List>('niosgram_draft_media_v1');
        final ciphertext = await box.get('101:${file.id}');
        expect(
          utf8.decode(ciphertext!, allowMalformed: true),
          isNot(contains('test-only media payload')),
        );
        ciphertext[12] ^= 1;
        await box.put('101:${file.id}', ciphertext);
        await expectLater(restored.readFile(file), throwsA(anything));
        // A damaged attachment never deletes the draft metadata.
        expect((await restored.read())!.text, 'a draft :custom_emoji:');
      },
    );

    test(
      'logout fences late writes and leaves the other account intact',
      () async {
        final first = NiosgramDraftStore(201);
        final second = NiosgramDraftStore(202);
        final media = await first.saveFile(
          'photo.png',
          Uint8List.fromList([1, 2, 3]),
        );
        await first.write(NiosgramPostDraft(text: 'first', files: [media]));
        await second.write(const NiosgramPostDraft(text: 'second'));
        await NiosgramDraftStore.eraseAccount(201);
        await expectLater(
          first.write(const NiosgramPostDraft(text: 'late')),
          throwsStateError,
        );
        expect(await NiosgramDraftStore(201).read(), isNull);
        expect((await second.read())!.text, 'second');
      },
    );

    test(
      'saved posts persist per account without private quiz or reaction data',
      () async {
        final post = NgPost(
          id: 77,
          content: 'public fixture',
          author: const ApiProfile(
            id: 3,
            username: 'author',
            displayName: 'Author',
            bio: '',
          ),
          createdAt: DateTime.utc(2026),
          likesCount: 1,
          dislikesCount: 0,
          commentsCount: 0,
          myReaction: true,
          poll: {
            'correct': 1,
            'explanation': 'private',
            'my_choices': [1],
          },
        );
        final first = NiosgramSavedStore(301);
        final second = NiosgramSavedStore(302);
        await first.toggle(post);
        final saved = (await NiosgramSavedStore(301).read()).single;
        expect(saved.id, post.id);
        expect(saved.myReaction, isNull);
        expect(saved.poll!.containsKey('correct'), isFalse);
        expect(saved.poll!.containsKey('explanation'), isFalse);
        expect(saved.poll!['my_choices'], isEmpty);
        expect(await second.read(), isEmpty);
        await NiosgramSavedStore.eraseAccount(301);
        await expectLater(first.toggle(post), throwsStateError);
        expect(await NiosgramSavedStore(301).read(), isEmpty);
      },
    );
  });
}
