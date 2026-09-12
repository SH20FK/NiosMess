import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/widgets/chat/ws_cached_image.dart';

void main() {
  group('Gallery & Media Optimization Tests', () {
    setUp(() {
      WsMediaFetcher.clearMemoryCache();
    });

    tearDown(() {
      WsMediaFetcher.clearMemoryCache();
    });

    test('WsMediaFetcher cleanFilePath handles various URL formats', () {
      expect(
        WsMediaFetcher.cleanFilePath('/api/media/photos/sample.jpg?token=123'),
        'photos/sample.jpg',
      );
      expect(
        WsMediaFetcher.cleanFilePath('/static/uploads/avatar.png'),
        'avatar.png',
      );
      expect(
        WsMediaFetcher.cleanFilePath('https://example.com/files/chat_42/doc.pdf'),
        'files/chat_42/doc.pdf',
      );
      expect(
        WsMediaFetcher.cleanFilePath('///already/clean/path.png'),
        'already/clean/path.png',
      );
      expect(
        WsMediaFetcher.cleanFilePath(''),
        '',
      );
    });

    test('WsMediaFetcher memory cache stores and retrieves bytes synchronously', () {
      const filePath = 'gallery/test_photo.jpg';
      final dummyBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);

      // Initially null
      expect(WsMediaFetcher.getMemoryCachedBytes(filePath: filePath), isNull);

      // Store bytes directly
      WsMediaFetcher.putMemoryCachedBytes(filePath: filePath, bytes: dummyBytes);

      // Verify retrieval returns exact bytes
      final cached = WsMediaFetcher.getMemoryCachedBytes(filePath: filePath);
      expect(cached, isNotNull);
      expect(cached, equals(dummyBytes));
      expect(WsMediaFetcher.currentMemoryBytes, equals(dummyBytes.length));
      expect(WsMediaFetcher.memoryEntryCount, equals(1));
    });

    test('WsMediaFetcher E2EE key hashing is deterministic across different Uint8List instances', () {
      const filePath = 'secret/e2ee_photo.jpg';
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      // Two distinct instances of Uint8List with identical byte contents (simulating separate base64Decode calls)
      final keyInstanceA = Uint8List.fromList([10, 20, 30, 40, 50, 60]);
      final keyInstanceB = Uint8List.fromList([10, 20, 30, 40, 50, 60]);
      final differentKey = Uint8List.fromList([99, 88, 77, 66]);

      expect(identical(keyInstanceA, keyInstanceB), isFalse);

      // Store with keyInstanceA
      WsMediaFetcher.putMemoryCachedBytes(
        filePath: filePath,
        bytes: dummyBytes,
        e2eeFileKey: keyInstanceA,
      );

      // Look up with keyInstanceB -> MUST hit cache because content hash matches!
      final hitWithB = WsMediaFetcher.getMemoryCachedBytes(
        filePath: filePath,
        e2eeFileKey: keyInstanceB,
      );
      expect(hitWithB, isNotNull);
      expect(hitWithB, equals(dummyBytes));

      // Look up with differentKey -> MUST miss
      final missWithDifferent = WsMediaFetcher.getMemoryCachedBytes(
        filePath: filePath,
        e2eeFileKey: differentKey,
      );
      expect(missWithDifferent, isNull);

      // Look up without key -> MUST miss
      final missWithoutKey = WsMediaFetcher.getMemoryCachedBytes(
        filePath: filePath,
      );
      expect(missWithoutKey, isNull);
    });

    test('WsMediaFetcher rejects oversized items to prevent memory bloat', () {
      const filePath = 'huge/video.mp4';
      // 3.5 MB dummy array (> 3MB single entry limit)
      final hugeBytes = Uint8List(3 * 1024 * 1024 + 500 * 1024);

      WsMediaFetcher.putMemoryCachedBytes(filePath: filePath, bytes: hugeBytes);

      // Should not be stored in RAM cache
      expect(WsMediaFetcher.getMemoryCachedBytes(filePath: filePath), isNull);
      expect(WsMediaFetcher.currentMemoryBytes, equals(0));
      expect(WsMediaFetcher.memoryEntryCount, equals(0));
    });

    test('WsMediaFetcher LRU eviction respects maximum entry limit', () {
      // Add 125 small entries (limit is 120)
      for (int i = 0; i < 125; i++) {
        WsMediaFetcher.putMemoryCachedBytes(
          filePath: 'img_$i.png',
          bytes: Uint8List.fromList([i & 0xFF]),
        );
      }

      expect(WsMediaFetcher.memoryEntryCount, lessThanOrEqualTo(120));
      // First 5 entries should have been evicted
      expect(WsMediaFetcher.getMemoryCachedBytes(filePath: 'img_0.png'), isNull);
      expect(WsMediaFetcher.getMemoryCachedBytes(filePath: 'img_4.png'), isNull);
      // Newest entry must still be present
      expect(WsMediaFetcher.getMemoryCachedBytes(filePath: 'img_124.png'), isNotNull);
    });

    test('WsMediaFetcher clearMemoryCache resets entries and byte counter to zero', () {
      WsMediaFetcher.putMemoryCachedBytes(
        filePath: 'test1.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      WsMediaFetcher.putMemoryCachedBytes(
        filePath: 'test2.jpg',
        bytes: Uint8List.fromList([4, 5, 6]),
      );

      expect(WsMediaFetcher.memoryEntryCount, equals(2));
      expect(WsMediaFetcher.currentMemoryBytes, equals(6));

      WsMediaFetcher.clearMemoryCache();

      expect(WsMediaFetcher.memoryEntryCount, equals(0));
      expect(WsMediaFetcher.currentMemoryBytes, equals(0));
      expect(WsMediaFetcher.getMemoryCachedBytes(filePath: 'test1.jpg'), isNull);
    });

    testWidgets('WsCachedImage displays cached bytes immediately on first pump',
        (WidgetTester tester) async {
      const path = 'gallery/instant_photo.png';
      // Valid 1x1 transparent PNG bytes
      final pngBytes = Uint8List.fromList(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      WsMediaFetcher.putMemoryCachedBytes(filePath: path, bytes: pngBytes);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WsCachedImage(
                mediaUrl: path,
                chatId: 1,
                isE2ee: false,
                width: 100,
                height: 100,
                memCacheWidth: 200,
              ),
            ),
          ),
        ),
      );

      // Since bytes were already in memory cache, Image.memory should render on first frame
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('WsCachedImage handles local pseudo-URLs gracefully without network requests',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WsCachedImage(
                mediaUrl: 'local://pending_upload.png',
                chatId: 1,
                isE2ee: false,
                width: 120,
                height: 120,
                memCacheWidth: 240,
              ),
            ),
          ),
        ),
      );

      // Should render without throwing uncaught exceptions
      expect(find.byType(WsCachedImage), findsOneWidget);
    });
  });
}
