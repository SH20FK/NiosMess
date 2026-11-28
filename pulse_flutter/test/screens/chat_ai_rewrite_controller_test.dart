// Tests for `lib/screens/chat_detail/chat_ai_rewrite_controller.dart`.
//
// The controller took the AI rewrite pass out of `_ChatDetailScreenState`.
// These tests freeze the six invariants the split had to keep: cancel-then-
// dispose ordering, backup restore only before the first chunk, exactly one
// terminal sound per pass, `cancelOnError`, the caret at the end of every
// rendered chunk, and a second `start()` leaving a single ticker/subscription.

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/ai/ai_action.dart';
import 'package:pulse_flutter/core/ai/ai_rewrite_request.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_ai_rewrite_controller.dart';

/// A [TestVSync] that keeps every ticker it hands out, so a test can count how
/// many of them are alive at once.
class _RecordingVSync implements TickerProvider {
  final TickerProvider _inner = const TestVSync();
  final List<Ticker> created = <Ticker>[];

  int get activeCount =>
      created.where((Ticker ticker) => ticker.isActive).length;

  @override
  Ticker createTicker(TickerCallback onTick) {
    final Ticker ticker = _inner.createTicker(onTick);
    created.add(ticker);
    return ticker;
  }
}

ChatAiRewriteController _controller({
  required ChatAiStreamRequest streamRequest,
  required TextEditingController text,
  required List<SoundEvent> sounds,
  required List<bool> busy,
  required List<Object> errors,
  TickerProvider vsync = const TestVSync(),
  bool reduceMotion = true,
}) {
  return ChatAiRewriteController(
    vsync: vsync,
    textController: text,
    reduceMotion: () => reduceMotion,
    streamRequest: streamRequest,
    onBusyChanged: busy.add,
    onError: errors.add,
    onSound: sounds.add,
  );
}

void main() {
  group('ChatAiRewriteController', () {
    testWidgets('successful stream renders the full text and completes once', (
      WidgetTester tester,
    ) async {
      final TextEditingController text = TextEditingController(
        text: 'original text',
      );
      final List<SoundEvent> sounds = <SoundEvent>[];
      final List<bool> busy = <bool>[];
      final List<Object> errors = <Object>[];
      final List<AiRewriteRequest> requests = <AiRewriteRequest>[];
      final StreamController<String> chunks = StreamController<String>();

      final ChatAiRewriteController controller = _controller(
        text: text,
        sounds: sounds,
        busy: busy,
        errors: errors,
        reduceMotion: false,
        streamRequest: (AiRewriteRequest request) async {
          requests.add(request);
          return chunks.stream;
        },
      );
      addTearDown(() {
        controller.dispose();
        text.dispose();
        unawaited(chunks.close());
      });

      await controller.start(AiAction.translate, targetLanguage: 'English');

      expect(requests.single.text, 'original text');
      expect(requests.single.action, AiAction.translate);
      expect(requests.single.targetLanguage, 'English');
      expect(controller.isProcessing, isTrue);
      expect(controller.hasActiveStream, isTrue);
      expect(sounds, <SoundEvent>[SoundEvent.aiStart]);

      chunks.add('Hello ');
      chunks.add('world');
      await chunks.close();
      await tester.pumpAndSettle();

      expect(text.text, 'Hello world');
      expect(controller.isProcessing, isFalse);
      expect(controller.hasActiveStream, isFalse);
      expect(sounds, <SoundEvent>[
        SoundEvent.aiStart,
        SoundEvent.aiComplete,
      ]);
      expect(busy, <bool>[true, false]);
      expect(errors, isEmpty);
      // Caret sits at the end of every rendered chunk.
      expect(text.selection.baseOffset, text.text.length);
      expect(text.selection.isCollapsed, isTrue);
    });

    testWidgets('failure before the first chunk restores the original text', (
      WidgetTester tester,
    ) async {
      final TextEditingController text = TextEditingController(
        text: 'original text',
      );
      final List<SoundEvent> sounds = <SoundEvent>[];
      final List<bool> busy = <bool>[];
      final List<Object> errors = <Object>[];
      final StreamController<String> chunks = StreamController<String>();

      final ChatAiRewriteController controller = _controller(
        text: text,
        sounds: sounds,
        busy: busy,
        errors: errors,
        streamRequest: (_) async => chunks.stream,
      );
      addTearDown(() {
        controller.dispose();
        text.dispose();
        unawaited(chunks.close());
      });

      await controller.start(AiAction.correct);
      expect(sounds, <SoundEvent>[SoundEvent.aiStart]);

      chunks.addError(StateError('boom'));
      await tester.pump();

      expect(text.text, 'original text');
      expect(errors.single, isA<StateError>());
      expect(controller.isProcessing, isFalse);
      expect(controller.hasActiveStream, isFalse);
      expect(sounds, <SoundEvent>[SoundEvent.aiStart, SoundEvent.aiError]);
      expect(busy, <bool>[true, false]);

      // `cancelOnError: true` — the failed stream is never listened to again.
      chunks.add('late chunk');
      chunks.addError(StateError('second'));
      await tester.pump();
      expect(text.text, 'original text');
      expect(errors.length, 1);
      expect(sounds, <SoundEvent>[SoundEvent.aiStart, SoundEvent.aiError]);
    });

    testWidgets('failure after the first chunk keeps the rendered text', (
      WidgetTester tester,
    ) async {
      final TextEditingController text = TextEditingController(
        text: 'original text',
      );
      final List<SoundEvent> sounds = <SoundEvent>[];
      final List<bool> busy = <bool>[];
      final List<Object> errors = <Object>[];
      final StreamController<String> chunks = StreamController<String>();

      final ChatAiRewriteController controller = _controller(
        text: text,
        sounds: sounds,
        busy: busy,
        errors: errors,
        streamRequest: (_) async => chunks.stream,
      );
      addTearDown(() {
        controller.dispose();
        text.dispose();
        unawaited(chunks.close());
      });

      await controller.start(AiAction.correct);
      chunks.add('rewritten');
      await tester.pump();
      expect(text.text, 'rewritten');

      chunks.addError(StateError('boom'));
      await tester.pump();

      // A failure after the first chunk must not put the old text back.
      expect(text.text, 'rewritten');
      expect(errors.single, isA<StateError>());
      expect(sounds, <SoundEvent>[SoundEvent.aiStart, SoundEvent.aiError]);
      expect(busy, <bool>[true, false]);
    });

    testWidgets('cancel() before done stops the typing', (
      WidgetTester tester,
    ) async {
      final TextEditingController text = TextEditingController(
        text: 'original text',
      );
      final List<SoundEvent> sounds = <SoundEvent>[];
      final List<bool> busy = <bool>[];
      final StreamController<String> chunks = StreamController<String>();

      final ChatAiRewriteController controller = _controller(
        text: text,
        sounds: sounds,
        busy: busy,
        errors: <Object>[],
        reduceMotion: false,
        streamRequest: (_) async => chunks.stream,
      );
      addTearDown(() {
        controller.dispose();
        text.dispose();
        unawaited(chunks.close());
      });

      await controller.start(AiAction.correct);
      chunks.add('0123456789abcdefghij');
      await tester.pump(const Duration(milliseconds: 16));

      final String partial = text.text;
      expect(partial, isNotEmpty);
      expect(partial.length, lessThan(20));
      expect(controller.isTyping, isTrue);
      // The caret is pushed to the end of every rendered chunk.
      expect(text.selection.baseOffset, partial.length);

      controller.cancel();
      expect(controller.isProcessing, isFalse);
      expect(controller.isTyping, isFalse);
      expect(controller.hasActiveStream, isFalse);

      // Neither more remote chunks nor more frames may move the text again.
      chunks.add('MORE');
      await tester.pump(const Duration(milliseconds: 100));
      expect(text.text, partial);

      // No completion is announced for a cancelled pass.
      expect(sounds, <SoundEvent>[SoundEvent.aiStart]);
      expect(busy, <bool>[true, false]);
    });

    testWidgets('a second start leaves one ticker and one subscription', (
      WidgetTester tester,
    ) async {
      final TextEditingController text = TextEditingController(
        text: 'original text',
      );
      final List<SoundEvent> sounds = <SoundEvent>[];
      final List<bool> busy = <bool>[];
      final StreamController<String> first = StreamController<String>();
      final StreamController<String> second = StreamController<String>();
      final _RecordingVSync vsync = _RecordingVSync();
      int opened = 0;

      final ChatAiRewriteController controller = _controller(
        text: text,
        sounds: sounds,
        busy: busy,
        errors: <Object>[],
        vsync: vsync,
        reduceMotion: false,
        streamRequest: (_) async {
          opened++;
          return opened == 1 ? first.stream : second.stream;
        },
      );
      addTearDown(() {
        controller.dispose();
        text.dispose();
        unawaited(first.close());
        unawaited(second.close());
      });

      await controller.start(AiAction.correct);
      first.add('OLD PASS');
      await tester.pump();
      expect(vsync.activeCount, 1);
      final int tickersAfterFirst = vsync.created.length;

      // Second start while the first pass is still typing.
      await controller.start(AiAction.correct);
      expect(vsync.activeCount, 0);
      expect(controller.hasActiveStream, isTrue); // the new pass only

      first.add('ignored');
      await tester.pump();
      expect(text.text, isNot(contains('ignored')));

      second.add('new pass');
      await tester.pump();

      expect(vsync.activeCount, 1);
      expect(vsync.created.length, tickersAfterFirst + 1);
      expect(controller.hasActiveStream, isTrue);

      second.add(' done');
      await second.close();
      await tester.pumpAndSettle();

      expect(text.text, 'new pass done');
      expect(vsync.activeCount, 0);
      expect(vsync.created.length, tickersAfterFirst + 1);
      expect(controller.isProcessing, isFalse);
    });

    testWidgets('dispose() drops the subscription before the streamer', (
      WidgetTester tester,
    ) async {
      final TextEditingController text = TextEditingController(
        text: 'original text',
      );
      final List<SoundEvent> sounds = <SoundEvent>[];
      final StreamController<String> chunks = StreamController<String>();

      final ChatAiRewriteController controller = _controller(
        text: text,
        sounds: sounds,
        busy: <bool>[],
        errors: <Object>[],
        reduceMotion: false,
        streamRequest: (_) async => chunks.stream,
      );
      addTearDown(() {
        text.dispose();
        unawaited(chunks.close());
      });

      await controller.start(AiAction.correct);
      chunks.add('typed');
      await tester.pump();
      final String typed = text.text;

      controller.dispose();

      expect(controller.isTyping, isFalse);
      expect(chunks.hasListener, isFalse);
      chunks.add('after dispose');
      await tester.pump(const Duration(milliseconds: 100));
      expect(text.text, typed);
      // Disposing is not an error and announces no sound.
      expect(sounds, <SoundEvent>[SoundEvent.aiStart]);
    });
  });
}
