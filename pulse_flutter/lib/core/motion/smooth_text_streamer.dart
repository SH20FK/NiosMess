import 'dart:async';
import 'dart:math';

import 'package:flutter/scheduler.dart';

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
    this.vsync,
    this.reduceMotion = false,
  }) {
    _currentRendered = initialText;
  }

  final void Function(String text, bool isFinished) onUpdate;
  final void Function(String fullText)? onDone;
  final void Function(dynamic error)? onError;
  final String initialText;
  final int minCharIntervalMs;

  /// When true (the platform "reduce motion" setting) the queue is written
  /// out at once and no [Ticker] is created: text still streams, it just is
  /// not typed out character by character.
  final bool reduceMotion;

  /// Host [TickerProvider] that drives the queue from the vsync frame callback.
  ///
  /// Pass the owning `State` (with a `TickerProvider` mixin) so the composer is
  /// only written inside a frame, never from an arbitrary timer callback.
  /// When omitted — pure-Dart use and unit tests — the streamer keeps the
  /// legacy fixed 16 ms timer as a fallback.
  final TickerProvider? vsync;

  /// Pacing budget carried over from the old 16 ms timer, so typing speed stays
  /// identical on 60 Hz, 90 Hz and 120 Hz displays.
  static const Duration _frameBudget = Duration(milliseconds: 16);

  final StringBuffer _targetBuffer = StringBuffer();
  String _target = '';
  String _currentRendered = '';
  Ticker? _ticker;
  Timer? _fallbackTimer;
  Duration _lastTickElapsed = Duration.zero;
  Duration _accumulatedTick = Duration.zero;
  bool _isStreamCompleted = false;
  bool _isDisposed = false;

  String get currentText => _currentRendered;
  bool get isActive => _ticker != null || _fallbackTimer != null;

  /// Appends a new delta chunk from SSE stream.
  void appendChunk(String chunk) {
    if (_isDisposed) return;
    _targetBuffer.write(chunk);
    _target = _targetBuffer.toString();
    if (_flushIfReducedMotion()) return;
    _ensureTickerStarted();
  }

  /// Signals that the remote network stream finished sending deltas.
  void completeStream([String? finalFullText]) {
    if (_isDisposed) return;
    if (finalFullText != null && finalFullText.length > _targetBuffer.length) {
      final String remainder = finalFullText.substring(_targetBuffer.length);
      _targetBuffer.write(remainder);
      _target = _targetBuffer.toString();
    }
    _isStreamCompleted = true;
    if (_flushIfReducedMotion()) return;
    _ensureTickerStarted();
  }

  /// With reduced motion the queue is drained in one step and the driver is
  /// never started. Returns `true` when the caller must not start it.
  bool _flushIfReducedMotion() {
    if (!reduceMotion) return false;
    final bool changed = _currentRendered != _target;
    _currentRendered = _target;
    final bool isDone = _isStreamCompleted;
    if (changed || isDone) {
      onUpdate(_currentRendered, isDone);
      if (isDone) onDone?.call(_currentRendered);
    }
    return true;
  }

  /// Cancels streaming immediately and stops the animation driver.
  void cancel() {
    _stopDriver();
    _isStreamCompleted = true;
  }

  void dispose() {
    _isDisposed = true;
    _stopDriver();
  }

  void _ensureTickerStarted() {
    if (isActive || _isDisposed) return;
    final TickerProvider? provider = vsync;
    if (provider != null) {
      _lastTickElapsed = Duration.zero;
      // Start with a full budget so the very first frame already advances.
      _accumulatedTick = _frameBudget;
      final Ticker ticker = provider.createTicker(_onTickerTick);
      _ticker = ticker;
      ticker.start();
    } else {
      _fallbackTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        _onTimerTick,
      );
    }
  }

  void _stopDriver() {
    final Ticker? ticker = _ticker;
    _ticker = null;
    if (ticker != null) {
      ticker
        ..stop()
        ..dispose();
    }
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _lastTickElapsed = Duration.zero;
    _accumulatedTick = Duration.zero;
  }

  /// Vsync driver: advances at most one [_frameBudget] step per frame so high
  /// refresh-rate panels do not type faster than 60 Hz ones.
  void _onTickerTick(Duration elapsed) {
    if (_isDisposed) {
      _stopDriver();
      return;
    }
    _accumulatedTick += elapsed - _lastTickElapsed;
    _lastTickElapsed = elapsed;
    if (_accumulatedTick < _frameBudget) return;
    _accumulatedTick = Duration.zero;
    if (_advance()) _stopDriver();
  }

  void _onTimerTick(Timer timer) {
    if (_isDisposed) {
      _stopDriver();
      return;
    }
    if (_advance()) _stopDriver();
  }

  /// Advances the typewriter queue by one paced frame.
  ///
  /// Returns `true` when the queue is drained and the driver must stop.
  bool _advance() {
    final String target = _target;
    final int remaining = target.length - _currentRendered.length;

    if (remaining <= 0) {
      if (_isStreamCompleted) {
        onUpdate(_currentRendered, true);
        onDone?.call(_currentRendered);
      }
      return true;
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

    final int nextLength = min(
      target.length,
      _currentRendered.length + charsToTake,
    );
    _currentRendered = target.substring(0, nextLength);

    final bool isDone =
        _isStreamCompleted && _currentRendered.length == target.length;
    onUpdate(_currentRendered, isDone);

    if (isDone) {
      onDone?.call(_currentRendered);
      return true;
    }
    return false;
  }
}
