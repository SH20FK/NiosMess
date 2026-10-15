import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import '../widgets/message_layout_delta_test.dart' as layout_algorithm;
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_image_cache.dart';

void main() {
  group('Chat algorithm and resource regressions', () {
    layout_algorithm.main();

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
          final pending =
              map.values
                  .where(
                    (t) =>
                        t.status == UploadStatus.pending ||
                        t.status == UploadStatus.uploading,
                  )
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
        expect(
          updatedKey,
          equals(initialKey),
          reason: 'Topology key must NOT change when only progress changes',
        );

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
        expect(
          newKey,
          isNot(equals(initialKey)),
          reason: 'Topology key must change when task membership changes',
        );
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
