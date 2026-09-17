import 'dart:async';
import 'dart:math';

/// High-performance, ultra-smooth streaming text animator.
/// Decouples network packet bursts from visual rendering by pacing characters
/// through an adaptive, spring-smoothed typewriter queue at 60/120 FPS.
class SmoothTextStreamer {
  SmoothTextStreamer({
    required this.onUpdate,
    this.onDone,
    this.onError,
    this.initialText = '',
    this.minCharIntervalMs = 22,
  }) {
    _currentRendered = initialText;
  }

  final void Function(String text, bool isFinished) onUpdate;
  final void Function(String fullText)? onDone;
  final void Function(dynamic error)? onError;
  final String initialText;
  final int minCharIntervalMs;

  final StringBuffer _targetBuffer = StringBuffer();
  String _currentRendered = '';
  Timer? _ticker;
  bool _isStreamCompleted = false;
  bool _isDisposed = false;

  String get currentText => _currentRendered;
  bool get isActive => _ticker != null;

  /// Appends a new delta chunk from SSE stream.
  void appendChunk(String chunk) {
    if (_isDisposed) return;
    _targetBuffer.write(chunk);
    _ensureTickerStarted();
  }

  /// Signals that the remote network stream finished sending deltas.
  void completeStream([String? finalFullText]) {
    if (_isDisposed) return;
    if (finalFullText != null && finalFullText.length > _targetBuffer.length) {
      final String remainder = finalFullText.substring(_targetBuffer.length);
      _targetBuffer.write(remainder);
    }
    _isStreamCompleted = true;
    _ensureTickerStarted();
  }

  /// Cancels streaming immediately and stops the animation timer.
  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    _isStreamCompleted = true;
  }

  void dispose() {
    _isDisposed = true;
    _ticker?.cancel();
    _ticker = null;
  }

  void _ensureTickerStarted() {
    if (_ticker != null || _isDisposed) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 16), _onTick);
  }

  void _onTick(Timer timer) {
    if (_isDisposed) {
      timer.cancel();
      return;
    }

    final String target = _targetBuffer.toString();
    final int remaining = target.length - _currentRendered.length;

    if (remaining <= 0) {
      if (_isStreamCompleted) {
        timer.cancel();
        _ticker = null;
        onUpdate(_currentRendered, true);
        onDone?.call(_currentRendered);
      }
      return;
    }

    // Adaptive step sizing based on backlog depth:
    // - Low backlog (< 6 chars): 1 char per frame (smooth typing)
    // - Medium backlog (6 - 25 chars): 2-4 chars per frame
    // - High backlog (25+ chars): smoothly accelerates to catch up without visual stalls
    final int charsToTake;
    if (_isStreamCompleted) {
      // When complete, quickly drain smoothly within ~150-250ms
      charsToTake = max(1, (remaining / 6).ceil());
    } else if (remaining > 40) {
      charsToTake = max(3, (remaining / 10).ceil());
    } else if (remaining > 15) {
      charsToTake = 2;
    } else {
      charsToTake = 1;
    }

    final int nextLength = min(target.length, _currentRendered.length + charsToTake);
    _currentRendered = target.substring(0, nextLength);

    final bool isDone = _isStreamCompleted && _currentRendered.length == target.length;
    onUpdate(_currentRendered, isDone);

    if (isDone) {
      timer.cancel();
      _ticker = null;
      onDone?.call(_currentRendered);
    }
  }
}
