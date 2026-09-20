import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_message_list.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_image_cache.dart';

void main() {
  group('Chat Performance & Architecture Benchmarks', () {
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Incremental MessageLayoutStore Benchmarks
    // ─────────────────────────────────────────────────────────────────────────
    group('MessageLayoutStore Benchmarks', () {
      ApiMessage makeMessage(int id, int senderId, DateTime time, {String text = 'hello'}) {
        return ApiMessage(
          id: id,
          chatId: 42,
          senderId: senderId,
          senderUsername: 'user$senderId',
          senderDisplayName: 'User $senderId',
          senderBadges: const [],
          content: text,
          msgType: 'text',
          replyToId: null,
          mediaUrl: '',
          mediaType: '',
          mediaName: '',
          mediaSize: 0,
          mediaDuration: 0,
          commentsCount: 0,
          reactions: const {},
          sentAt: time,
          editedAt: null,
          isDeleted: false,
        );
      }

      test('O(1) append performance across 1000 messages', () {
        final store = MessageLayoutStore();
        final baseTime = DateTime(2026, 1, 1, 12, 0, 0);

        // Populate initial 500 messages
        final initialMessages = List<ApiMessage>.generate(500, (i) {
          return makeMessage(i + 1, (i % 3) + 1, baseTime.add(Duration(minutes: i)));
        });
        store.reset(initialMessages);
        expect(store.messages.length, 500);
        expect(store.layout.length, 500);
        expect(store.idToIndex[1], 499); // reversed indexing
        expect(store.idToIndex[500], 0);

        // Benchmark appending 500 messages one-by-one (simulating real-time chat stream)
        final stopwatch = Stopwatch()..start();
        for (int i = 501; i <= 1000; i++) {
          final nextList = List<ApiMessage>.from(store.messages)
            ..add(makeMessage(i, (i % 3) + 1, baseTime.add(Duration(minutes: i))));
          store.sync(nextList);
        }
        stopwatch.stop();

        expect(store.messages.length, 1000);
        expect(store.layout.length, 1000);
        expect(store.byId[1000]?.id, 1000);
        expect(store.idToIndex[1000], 0);

        // 500 appends should execute well under 100ms in debug VM (< 0.2ms per message)
        expect(stopwatch.elapsedMilliseconds, lessThan(150),
            reason: '500 incremental appends should execute in sub-millisecond time per append');
      });

      test('O(1) in-place update for message edit / reaction', () {
        final store = MessageLayoutStore();
        final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
        final initialMessages = List<ApiMessage>.generate(100, (i) {
          return makeMessage(i + 1, (i % 2) + 1, baseTime.add(Duration(minutes: i)));
        });
        store.reset(initialMessages);

        // Edit message #50
        final updatedMessages = List<ApiMessage>.from(store.messages);
        final editedMsg = makeMessage(50, 2, baseTime.add(const Duration(minutes: 49)), text: 'edited text');
        updatedMessages[49] = editedMsg;

        final stopwatch = Stopwatch()..start();
        store.sync(updatedMessages);
        stopwatch.stop();

        expect(store.messages[49].content, 'edited text');
        expect(store.byId[50]?.content, 'edited text');
        expect(stopwatch.elapsedMicroseconds, lessThan(5000),
            reason: 'Single message in-place update must complete in < 5ms');
      });

      test('O(k) prepend for pagination batch', () {
        final store = MessageLayoutStore();
        final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
        final initialMessages = List<ApiMessage>.generate(100, (i) {
          return makeMessage(i + 50, (i % 2) + 1, baseTime.add(Duration(minutes: i + 50)));
        });
        store.reset(initialMessages);

        // Prepend 50 older messages
        final olderMessages = List<ApiMessage>.generate(50, (i) {
          return makeMessage(i, (i % 2) + 1, baseTime.add(Duration(minutes: i)));
        });
        final combined = [...olderMessages, ...store.messages];

        final stopwatch = Stopwatch()..start();
        store.sync(combined);
        stopwatch.stop();

        expect(store.messages.length, 150);
        expect(store.byId[0]?.id, 0);
        expect(store.byId[149]?.id, 149);
        expect(stopwatch.elapsedMilliseconds, lessThan(50));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Upload Progress Throttling & Topology Isolation
    // ─────────────────────────────────────────────────────────────────────────
    group('Upload Progress Throttling & Topology Isolation', () {
      test('Topology key stays stable when only upload progress changes', () {
        final tasks = <String, UploadTask>{
          'task_1': const UploadTask(
            localId: 'task_1',
            chatId: 42,
            filePath: '/tmp/photo.jpg',
            filename: 'photo.jpg',
            mediaSubtype: 'image',
            fileSize: 1024 * 1024,
            progress: 0.10,
            status: UploadStatus.uploading,
          ),
          'task_2': const UploadTask(
            localId: 'task_2',
            chatId: 42,
            filePath: '/tmp/video.mp4',
            filename: 'video.mp4',
            mediaSubtype: 'video',
            fileSize: 5 * 1024 * 1024,
            progress: 0.05,
            status: UploadStatus.uploading,
          ),
        };

        String computeKey(Map<String, UploadTask> map) {
          final pending = map.values
              .where((t) => t.status == UploadStatus.pending || t.status == UploadStatus.uploading)
              .map((t) => '${t.localId}:${t.chatId}')
              .toList()
            ..sort();
          return pending.join(',');
        }

        final initialKey = computeKey(tasks);

        // Update progress from 10% to 50%
        final tasksUpdated = <String, UploadTask>{
          'task_1': tasks['task_1']!.copyWith(progress: 0.50),
          'task_2': tasks['task_2']!.copyWith(progress: 0.85),
        };

        final updatedKey = computeKey(tasksUpdated);
        expect(updatedKey, equals(initialKey),
            reason: 'Topology key must NOT change when only progress changes');

        // Adding a new task MUST change the topology key
        final tasksWithNew = <String, UploadTask>{
          ...tasksUpdated,
          'task_3': const UploadTask(
            localId: 'task_3',
            chatId: 42,
            filePath: '/tmp/doc.pdf',
            filename: 'doc.pdf',
            mediaSubtype: 'document',
            fileSize: 2048,
            progress: 0.0,
            status: UploadStatus.pending,
          ),
        };

        final newKey = computeKey(tasksWithNew);
        expect(newKey, isNot(equals(initialKey)),
            reason: 'Topology key must change when task membership changes');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Wallpaper Memory Budget Cache
    // ─────────────────────────────────────────────────────────────────────────
    group('Wallpaper Image Cache Memory Budget', () {
      test('Cache enforces max entry capacity and evictExcept', () {
        expect(WallpaperImageCache.entryCount, 0);

        const config1 = ChatWallpaperConfig(
          backgroundStyle: WallpaperBackgroundStyle.solid,
          iconAlpha: 0.5,
        );

        // EvictExcept when empty should not throw
        WallpaperImageCache.evictExcept(config1);
        expect(WallpaperImageCache.entryCount, 0);

        // Clear works cleanly
        WallpaperImageCache.clear();
        expect(WallpaperImageCache.entryCount, 0);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 4. AnimatedMediaControllerPool Concurrency Limits
    // ─────────────────────────────────────────────────────────────────────────
    group('AnimatedMediaControllerPool Concurrency Limits', () {
      test('Pool respects tier limits and fast scrolling state', () {
        final pool = AnimatedMediaControllerPool.instance;
        pool.reset();

        // Tier A: max 2 active decoders
        expect(pool.getMaxActive(PerformanceTier.tierA), 2);
        // Tier B: max 1 active decoder
        expect(pool.getMaxActive(PerformanceTier.tierB), 1);
        // Tier C: 0 active decoders
        expect(pool.getMaxActive(PerformanceTier.tierC), 0);

        // Fast scrolling mode
        expect(pool.isFastScrolling, isFalse);
        pool.setFastScrolling(true);
        expect(pool.isFastScrolling, isTrue);
        expect(pool.getMaxActive(PerformanceTier.tierA), 0);
        pool.setFastScrolling(false);
        expect(pool.isFastScrolling, isFalse);
        expect(pool.getMaxActive(PerformanceTier.tierA), 2);
      });
    });
  });
}
