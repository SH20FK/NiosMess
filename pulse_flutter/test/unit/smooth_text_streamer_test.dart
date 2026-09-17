import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/smooth_text_streamer.dart';

void main() {
  group('SmoothTextStreamer Unit Tests', () {
    test('initializes with initialText correctly', () {
      final streamer = SmoothTextStreamer(
        initialText: 'Hello',
        onUpdate: (String text, bool isFinished) {},
      );

      expect(streamer.currentText, 'Hello');
      expect(streamer.isActive, isFalse);
      streamer.dispose();
    });

    test('buffers chunks and smoothly emits updates until complete', () async {
      final updates = <String>[];
      final completer = Completer<String>();

      final streamer = SmoothTextStreamer(
        onUpdate: (text, isFinished) {
          updates.add(text);
          if (isFinished) {
            completer.complete(text);
          }
        },
        onDone: (full) {
          if (!completer.isCompleted) {
            completer.complete(full);
          }
        },
      );

      streamer.appendChunk('Hi');
      expect(streamer.isActive, isTrue);

      streamer.appendChunk(' there!');
      streamer.completeStream();

      final result = await completer.future.timeout(const Duration(seconds: 3));
      expect(result, 'Hi there!');
      expect(updates.isNotEmpty, isTrue);
      expect(updates.last, 'Hi there!');
      expect(streamer.isActive, isFalse);

      streamer.dispose();
    });

    test('cancel immediately stops streaming and suppresses further updates', () async {
      final updates = <String>[];

      final streamer = SmoothTextStreamer(
        onUpdate: (text, isFinished) {
          updates.add(text);
        },
      );

      streamer.appendChunk('Long piece of text that should be canceled halfway through');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      streamer.cancel();

      final countAtCancel = updates.length;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(updates.length, countAtCancel);
      expect(streamer.isActive, isFalse);

      streamer.dispose();
    });

    test('completeStream with finalFullText catches up differences', () async {
      final completer = Completer<String>();

      final streamer = SmoothTextStreamer(
        onUpdate: (text, isFinished) {
          if (isFinished) {
            completer.complete(text);
          }
        },
      );

      streamer.appendChunk('Start');
      streamer.completeStream('Start and Finish');

      final result = await completer.future.timeout(const Duration(seconds: 3));
      expect(result, 'Start and Finish');

      streamer.dispose();
    });
  });
}
