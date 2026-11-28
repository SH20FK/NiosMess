import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/ai/ai_action.dart';
import 'package:pulse_flutter/core/ai/ai_rewrite_request.dart';
import 'package:pulse_flutter/core/motion/smooth_text_streamer.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';

/// Opens the remote delta stream for one rewrite pass.
///
/// A future (not a bare stream) so a transport that needs an `await` — or
/// throws before the first chunk — lands in the controller's error path.
typedef ChatAiStreamRequest =
    Future<Stream<String>> Function(AiRewriteRequest request);

/// Owns the AI rewrite pass over the composer: the remote subscription, the
/// [SmoothTextStreamer] that types the deltas out and the busy flag behind the
/// "AI is working" chip.
///
/// A plain class, like `ChatScrollCoordinator`: no `ref`, no `BuildContext`.
/// The screen hands in the [TickerProvider] (the streamer needs a real
/// `Ticker`), the composer controller, and the side effects it owns — the busy
/// flag, the error toast and the semantic sound events.
///
/// Behaviour carried over verbatim from the screen:
/// * `dispose()` drops the subscription **before** the streamer.
/// * The text typed before the rewrite is restored **only** when the failure
///   arrives before the first chunk; a failure after that keeps what was
///   already rendered.
/// * Exactly one sound event per pass: `aiStart`, then one of `aiComplete` /
///   `aiError`.
/// * `cancelOnError: true` — a failed stream is not listened to again.
/// * Every rendered chunk puts the caret at the end of the composer.
/// * A second `start()` cancels the first pass, so there is never more than one
///   subscription or ticker alive.
class ChatAiRewriteController {
  ChatAiRewriteController({
    required TickerProvider vsync,
    required TextEditingController textController,
    required bool Function() reduceMotion,
    required ChatAiStreamRequest streamRequest,
    required void Function(bool busy) onBusyChanged,
    required void Function(Object error) onError,
    required void Function(SoundEvent event) onSound,
  }) : _vsync = vsync,
       _textController = textController,
       _reduceMotion = reduceMotion,
       _streamRequest = streamRequest,
       _onBusyChanged = onBusyChanged,
       _onError = onError,
       _onSound = onSound;

  final TickerProvider _vsync;
  final TextEditingController _textController;
  final bool Function() _reduceMotion;
  final ChatAiStreamRequest _streamRequest;
  final void Function(bool busy) _onBusyChanged;
  final void Function(Object error) _onError;
  final void Function(SoundEvent event) _onSound;

  SmoothTextStreamer? _textStreamer;
  StreamSubscription<String>? _streamSubscription;

  /// Bumped by [start], [cancel] and [dispose]; stale async work (a stream
  /// future that resolves after a cancel) and stale streamer callbacks compare
  /// against it and do nothing.
  int _session = 0;

  bool _isProcessing = false;
  bool _terminalSoundSent = false;
  bool _isDisposed = false;

  bool get isProcessing => _isProcessing;

  /// True while a remote stream is attached.
  bool get hasActiveStream => _streamSubscription != null;

  /// True while the streamer is still driving a `Ticker`.
  bool get isTyping => _textStreamer?.isActive ?? false;

  /// Rewrites the composer text. The secret-chat guard and the "empty input"
  /// gate live in the caller for the guard and here for the empty text.
  ///
  /// Calling this again while a pass is running cancels that pass first.
  Future<void> start(AiAction action, {String? targetLanguage}) async {
    if (_isDisposed) return;
    final String sourceText = _textController.text.trim();
    if (sourceText.isEmpty) return;

    cancel();

    // The whole composer content, not the trimmed request text: that is what
    // the user typed and what an early failure must put back.
    final String backupText = _textController.text;
    final int session = ++_session;
    bool hasReceivedFirstChunk = false;

    _terminalSoundSent = false;
    _setProcessing(true);
    _onSound(SoundEvent.aiStart);

    final SmoothTextStreamer streamer = SmoothTextStreamer(
      onUpdate: (String rendered, bool isFinished) {
        if (!_isCurrent(session)) return;
        _textController.text = rendered;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: rendered.length),
        );
        if (isFinished) _setProcessing(false);
      },
      onDone: (String fullText) {
        if (!_isCurrent(session)) return;
        _setProcessing(false);
      },
      vsync: _vsync,
      reduceMotion: _reduceMotion(),
    );
    _textStreamer = streamer;

    try {
      final Stream<String> stream = await _streamRequest(
        AiRewriteRequest(
          text: sourceText,
          action: action,
          targetLanguage: targetLanguage,
        ),
      );
      // Cancelled or superseded while the stream was being opened.
      if (!_isCurrent(session)) return;
      _streamSubscription = stream.listen(
        (String chunk) {
          if (!_isCurrent(session)) return;
          hasReceivedFirstChunk = true;
          streamer.appendChunk(chunk);
        },
        onError: (Object error) {
          if (!_isCurrent(session)) return;
          _teardownStream();
          _setProcessing(false);
          if (!hasReceivedFirstChunk) _textController.text = backupText;
          _playTerminal(SoundEvent.aiError);
          _onError(error);
        },
        onDone: () {
          if (!_isCurrent(session)) return;
          // The remote pass is over even while the typewriter drains.
          _streamSubscription = null;
          _playTerminal(SoundEvent.aiComplete);
          streamer.completeStream();
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (!_isCurrent(session)) return;
      _teardownStream();
      _setProcessing(false);
      if (!hasReceivedFirstChunk) _textController.text = backupText;
      _playTerminal(SoundEvent.aiError);
      _onError(error);
    }
  }

  /// Stops the running pass without touching the composer text — the user
  /// either pressed the AI chip's cancel or started another pass.
  void cancel() {
    if (_isDisposed) return;
    _session++;
    _teardownStream();
    _setProcessing(false);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _session++;
    // Order matters: the remote subscription goes first so no chunk can reach
    // the streamer while its ticker is being torn down.
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _textStreamer?.dispose();
    _textStreamer = null;
    // Silent: the owning widget is going away together with the flag's
    // listener, so nothing should be notified.
    _isProcessing = false;
  }

  bool _isCurrent(int session) => !_isDisposed && session == _session;

  /// Drops the subscription and the streamer, subscription first.
  void _teardownStream() {
    final StreamSubscription<String>? subscription = _streamSubscription;
    _streamSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());

    final SmoothTextStreamer? streamer = _textStreamer;
    _textStreamer = null;
    if (streamer != null) {
      streamer.cancel();
      streamer.dispose();
    }
  }

  void _setProcessing(bool busy) {
    if (_isProcessing == busy) return;
    _isProcessing = busy;
    _onBusyChanged(busy);
  }

  /// At most one terminal sound per pass, even if two error paths race.
  void _playTerminal(SoundEvent event) {
    if (_terminalSoundSent) return;
    _terminalSoundSent = true;
    _onSound(event);
  }
}
