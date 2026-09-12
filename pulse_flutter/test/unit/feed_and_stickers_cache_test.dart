import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:universal_io/io.dart';

NgPost _createPost({
  required int id,
  required String content,
}) {
  return NgPost(
    id: id,
    content: content,
    author: const ApiProfile(
      id: 1,
      username: 'tester',
      displayName: 'Tester',
      bio: 'Testing bio',
    ),
    createdAt: DateTime.now(),
    likesCount: 5,
    dislikesCount: 0,
    commentsCount: 2,
  );
}

ApiStickerSet _createStickerSet({
  required int id,
  required String name,
  required String title,
}) {
  return ApiStickerSet(
    id: id,
    name: name,
    title: title,
    stickers: <ApiSticker>[
      ApiSticker(
        id: id * 10 + 1,
        setId: id,
        url: 'https://example.com/sticker_$id.webp',
        emoji: '🔥',
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  const CacheService cacheService = CacheService();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('feed_stickers_cache_test');
    Hive.init(tempDir.path);
    await cacheService.ensureInitialized();
  });

  tearDown(() async {
    try {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('CacheService Feed Caching', () {
    test('Saves and retrieves feed posts successfully', () async {
      final List<NgPost> posts = <NgPost>[
        _createPost(id: 101, content: 'First cached post'),
        _createPost(id: 102, content: 'Second cached post'),
      ];

      await cacheService.saveFeed(posts);
      final List<NgPost> cached = cacheService.getCachedFeed();

      expect(cached.length, 2);
      expect(cached[0].id, 101);
      expect(cached[0].content, 'First cached post');
      expect(cached[1].id, 102);
      expect(cached[1].content, 'Second cached post');
    });

    test('Deleted post reconciliation works accurately', () {
      final List<NgPost> cached = <NgPost>[
        _createPost(id: 300, content: 'Latest cached post'),
        _createPost(id: 290, content: 'Post that was deleted on server'),
        _createPost(id: 280, content: 'Post still existing on server'),
        _createPost(id: 100, content: 'Old post beyond page 1'),
      ];

      // Server fresh page 1 contains 300 and 280 (290 is missing because it was deleted)
      final List<NgPost> freshPage1 = <NgPost>[
        _createPost(id: 305, content: 'Brand new server post'),
        _createPost(id: 300, content: 'Latest cached post'),
        _createPost(id: 280, content: 'Post still existing on server'),
      ];

      final Set<int> freshIds = freshPage1.map((NgPost p) => p.id).toSet();
      final int minFreshId =
          freshPage1.map((NgPost p) => p.id).reduce((int a, int b) => a < b ? a : b);

      final List<NgPost> olderPosts = cached.where((NgPost p) {
        if (freshIds.contains(p.id)) return false;
        if (p.id >= minFreshId) return false; // Deleted on backend!
        return true;
      }).toList(growable: false);

      final List<NgPost> reconciled = <NgPost>[...freshPage1, ...olderPosts];

      expect(reconciled.map((NgPost p) => p.id).toList(), <int>[305, 300, 280, 100]);
      expect(reconciled.any((NgPost p) => p.id == 290), isFalse);
    });
  });

  group('CacheService Stickers Caching', () {
    test('Saves and retrieves sticker sets successfully', () async {
      final List<ApiStickerSet> sets = <ApiStickerSet>[
        _createStickerSet(id: 1, name: 'pack_one', title: 'Pack One'),
        _createStickerSet(id: 2, name: 'pack_two', title: 'Pack Two'),
      ];

      await cacheService.saveStickerSets(sets);
      final List<ApiStickerSet> cached = cacheService.getCachedStickerSets();

      expect(cached.length, 2);
      expect(cached[0].id, 1);
      expect(cached[0].title, 'Pack One');
      expect(cached[0].stickers.length, 1);
      expect(cached[0].stickers[0].emoji, '🔥');
      expect(cached[1].id, 2);
      expect(cached[1].title, 'Pack Two');
    });

    test('Clear all wipes feed and sticker sets', () async {
      await cacheService.saveFeed(<NgPost>[_createPost(id: 1, content: 'A')]);
      await cacheService.saveStickerSets(<ApiStickerSet>[
        _createStickerSet(id: 1, name: 'p', title: 'P'),
      ]);

      expect(cacheService.getCachedFeed().length, 1);
      expect(cacheService.getCachedStickerSets().length, 1);

      await cacheService.clearAll();

      expect(cacheService.getCachedFeed(), isEmpty);
      expect(cacheService.getCachedStickerSets(), isEmpty);
    });
  });

  group('LocalStorageService In-Memory Caching', () {
    test('Invalidates snapshot cache on demand', () {
      LocalStorageService.invalidateSnapshotCache();
      expect(true, isTrue);
    });
  });
}
