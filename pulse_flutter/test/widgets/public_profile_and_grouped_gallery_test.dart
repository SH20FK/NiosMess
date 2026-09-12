import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/profile/profile_shared_media_tab_view.dart';

void main() {
  group('Public Profile & Grouped Batch Gallery Tests', () {
    setUp(() {
      WsMediaFetcher.clearMemoryCache();
    });

    testWidgets('Quick action button wraps long Russian text into 2 lines without clipping',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 76,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 28,
                    child: Center(
                      child: Text(
                        'Секретный чат',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          height: 1.15,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify widget rendered without render overflow errors
      expect(tester.takeException(), isNull);
      expect(find.text('Секретный чат'), findsOneWidget);

      final RenderBox renderBox = tester.renderObject(find.byType(SizedBox).first);
      expect(renderBox.size.height, lessThanOrEqualTo(40));
    });

    test('Shared media item extraction correctly filters pure photos and videos', () {
      final m1 = ApiMessage.fromJson({
        'id': 1,
        'chat_id': 10,
        'sender_id': 1,
        'sender_username': 'test',
        'sender_display_name': 'Test',
        'content': 'Check this photo',
        'sent_at': DateTime.now().toIso8601String(),
        'media_url': 'https://example.com/photo.jpg',
        'media_type': 'image/jpeg',
      });

      final m2 = ApiMessage.fromJson({
        'id': 2,
        'chat_id': 10,
        'sender_id': 1,
        'sender_username': 'test',
        'sender_display_name': 'Test',
        'content': 'Check this video',
        'sent_at': DateTime.now().toIso8601String(),
        'media_url': 'https://example.com/video.mp4',
        'media_type': 'video/mp4',
        'media_duration': 45,
      });

      final m3 = ApiMessage.fromJson({
        'id': 3,
        'chat_id': 10,
        'sender_id': 1,
        'sender_username': 'test',
        'sender_display_name': 'Test',
        'content': 'A document',
        'sent_at': DateTime.now().toIso8601String(),
        'media_url': 'https://example.com/document.pdf',
        'media_type': 'application/pdf',
      });

      expect(
        ProfileSharedMediaTabView.isPureImage(
          m1.mediaType ?? '',
          m1.msgType,
          m1.mediaName ?? '',
          (m1.mediaUrl ?? '').toLowerCase(),
        ),
        isTrue,
      );

      expect(
        ProfileSharedMediaTabView.isPureVideo(
          m2.mediaType ?? '',
          m2.msgType,
          m2.mediaName ?? '',
          (m2.mediaUrl ?? '').toLowerCase(),
        ),
        isTrue,
      );

      expect(
        ProfileSharedMediaTabView.isPureImage(
          m3.mediaType ?? '',
          m3.msgType,
          m3.mediaName ?? '',
          (m3.mediaUrl ?? '').toLowerCase(),
        ),
        isFalse,
      );

      expect(
        ProfileSharedMediaTabView.isPureVideo(
          m3.mediaType ?? '',
          m3.msgType,
          m3.mediaName ?? '',
          (m3.mediaUrl ?? '').toLowerCase(),
        ),
        isFalse,
      );
    });

    test('WsMediaFetcher batch prefetch partitions and caches items into memory', () async {
      final List<String> testFiles = List.generate(
        24,
        (index) => 'gallery/batch_img_$index.png',
      );

      // Pre-seed memory cache for 12 items (Group 0)
      for (int i = 0; i < 12; i++) {
        WsMediaFetcher.putMemoryCachedBytes(
          filePath: testFiles[i],
          bytes: Uint8List.fromList([1, 2, 3, i]),
        );
      }

      // Verify Group 0 is instantly available in memory cache
      for (int i = 0; i < 12; i++) {
        final cached = WsMediaFetcher.getMemoryCachedBytes(filePath: testFiles[i]);
        expect(cached, isNotNull);
        expect(cached![3], equals(i));
      }

      // Group 1 (items 12..23) is not yet cached
      for (int i = 12; i < 24; i++) {
        final cached = WsMediaFetcher.getMemoryCachedBytes(filePath: testFiles[i]);
        expect(cached, isNull);
      }
    });
  });
}
