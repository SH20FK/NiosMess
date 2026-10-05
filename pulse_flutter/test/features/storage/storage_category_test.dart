import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/features/storage/domain/storage_snapshot.dart';

void main() {
  group('StorageCategory detection', () {
    test('detects images', () {
      expect(
        StorageCategory.detectFromFilePath('/data/cache/photo_123.jpg'),
        StorageCategory.images,
      );
      expect(
        StorageCategory.detectFromFilePath('C:\\temp\\image.PNG'),
        StorageCategory.images,
      );
      expect(
        StorageCategory.detectFromFilePath('/cache/pic.webp'),
        StorageCategory.images,
      );
    });

    test('detects videos', () {
      expect(
        StorageCategory.detectFromFilePath('/storage/video_456.mp4'),
        StorageCategory.videos,
      );
      expect(
        StorageCategory.detectFromFilePath('/movies/clip.mov'),
        StorageCategory.videos,
      );
    });

    test('detects audio', () {
      expect(
        StorageCategory.detectFromFilePath('/voice/voice_message.ogg'),
        StorageCategory.audio,
      );
      expect(
        StorageCategory.detectFromFilePath('/music/track.mp3'),
        StorageCategory.audio,
      );
    });

    test('detects files & documents', () {
      expect(
        StorageCategory.detectFromFilePath('/docs/report.pdf'),
        StorageCategory.files,
      );
      expect(
        StorageCategory.detectFromFilePath('/downloads/archive.zip'),
        StorageCategory.files,
      );
    });

    test('detects avatars, stickers, and secret chats', () {
      expect(
        StorageCategory.detectFromFilePath('/cache/avatars/user_10.png'),
        StorageCategory.avatars,
      );
      expect(
        StorageCategory.detectFromFilePath('/stickers/pack_1/sticker_2.tgs'),
        StorageCategory.stickers,
      );
      expect(
        StorageCategory.detectFromFilePath('/secret_chat/session_key'),
        StorageCategory.secretChatCache,
      );
    });
  });
}
