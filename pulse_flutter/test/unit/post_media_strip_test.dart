import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/post_media_strip.dart';

void main() {
  group('PostMediaStrip isVideoFile tests', () {
    test('identifies common video formats correctly', () {
      expect(PostMediaStrip.isVideoFile('video.mp4'), isTrue);
      expect(PostMediaStrip.isVideoFile('CLIP.MOV'), isTrue);
      expect(PostMediaStrip.isVideoFile('record.mkv'), isTrue);
      expect(PostMediaStrip.isVideoFile('animation.webm'), isTrue);
      expect(PostMediaStrip.isVideoFile('movie.avi'), isTrue);
      expect(PostMediaStrip.isVideoFile('mobile.3gp'), isTrue);
    });

    test('identifies non-video formats correctly', () {
      expect(PostMediaStrip.isVideoFile('photo.jpg'), isFalse);
      expect(PostMediaStrip.isVideoFile('image.png'), isFalse);
      expect(PostMediaStrip.isVideoFile('pic.webp'), isFalse);
      expect(PostMediaStrip.isVideoFile('doc.pdf'), isFalse);
      expect(PostMediaStrip.isVideoFile('archive.zip'), isFalse);
    });
  });
}
