import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';

class _PlayingMedia {
  _PlayingMedia(this.onPause, this.onResume);
  final VoidCallback onPause;
  final VoidCallback onResume;
}

class _DecoderLease {
  _DecoderLease(this.release, this.userInitiated);
  final Future<void> Function() release;
  final bool userInitiated;
}

class _PosterLease {
  _PosterLease(this.bytes, this.evict);
  final int bytes;
  final VoidCallback evict;
}

/// Native decoder reservations are granted before controller initialization.
/// Tokens belong to widget instances, never URLs (identical stickers may coexist).
class AnimatedMediaControllerPool extends ChangeNotifier {
  AnimatedMediaControllerPool._();

  static final AnimatedMediaControllerPool instance =
      AnimatedMediaControllerPool._();

  final Map<Object, _DecoderLease> _decoders = {};
  final Map<Object, _PlayingMedia> _playing = {};
  final Set<Object> _fastScrollSources = {};
  final Set<Future<void>> _releases = {};
  final Map<Object, _PosterLease> _posters = {};
  int _posterBytes = 0;
  static const maxPosterCount = 8;
  static const maxPosterBytes = 2 * 1024 * 1024;
  static const _defaultScrollSource = 'default';
  Future<void> _acquisition = SynchronousFuture<void>(null);
  int _generation = 0;

  bool get isFastScrolling => _fastScrollSources.isNotEmpty;
  int get activeCount => _playing.length;
  int get initializedCount => _decoders.length;
  int get posterCount => _posters.length;
  int get posterBytes => _posterBytes;

  bool retainPoster({
    required Object id,
    required int bytes,
    required VoidCallback onEvict,
  }) {
    if (bytes > maxPosterBytes || bytes <= 0) return false;
    releasePoster(id);
    while (_posters.length >= maxPosterCount ||
        _posterBytes + bytes > maxPosterBytes) {
      final oldest = _posters.keys.first;
      final lease = _posters[oldest]!;
      releasePoster(oldest);
      lease.evict();
    }
    _posters[id] = _PosterLease(bytes, onEvict);
    _posterBytes += bytes;
    return true;
  }

  void releasePoster(Object id) {
    final removed = _posters.remove(id);
    if (removed != null) _posterBytes -= removed.bytes;
  }

  int getMaxActive(PerformanceTier tier) => isFastScrolling
      ? 0
      : switch (tier) {
          PerformanceTier.tierA => 2,
          PerformanceTier.tierB => 1,
          PerformanceTier.tierC => 0,
        };

  int getMaxInitialized(PerformanceTier tier) => getMaxActive(tier);
  bool canAutoplay(PerformanceTier tier) => getMaxActive(tier) > 0;

  void enforceBudget(PerformanceTier tier) {
    final hasManual = _decoders.values.any((entry) => entry.userInitiated);
    final limit = hasManual ? 1 : getMaxInitialized(tier);
    while (_decoders.length > limit) {
      final candidate = _decoders.entries.firstWhere(
        (entry) => !entry.value.userInitiated,
        orElse: () => _decoders.entries.first,
      );
      unawaited(release(candidate.key));
    }
  }

  /// Evicted codecs finish releasing before a replacement may initialize.
  Future<bool> acquireInitialization({
    required Object id,
    required PerformanceTier tier,
    required Future<void> Function() onRelease,
    bool isUserInitiated = false,
  }) {
    final completion = Completer<bool>();
    final generation = _generation;
    _acquisition = _acquisition.then((_) async {
      try {
        if (_releases.isNotEmpty) await Future.wait(_releases.toList());
        final limit = isUserInitiated ? 1 : getMaxInitialized(tier);
        if (generation != _generation || limit == 0) {
          completion.complete(false);
          return;
        }
        if (_decoders.containsKey(id)) {
          completion.complete(true);
          return;
        }
        // Autoplay must never steal the codec of a manually playing circle.
        if (!isUserInitiated &&
            _decoders.values.any((entry) => entry.userInitiated)) {
          completion.complete(false);
          return;
        }
        while (_decoders.length >= limit) {
          await release(_decoders.keys.first);
        }
        if (generation != _generation ||
            (!isUserInitiated && !canAutoplay(tier))) {
          completion.complete(false);
          return;
        }
        _decoders[id] = _DecoderLease(onRelease, isUserInitiated);
        completion.complete(true);
      } catch (error, stack) {
        completion.completeError(error, stack);
      }
    });
    return completion.future;
  }

  bool requestPlay({
    required Object id,
    required PerformanceTier tier,
    required VoidCallback onPause,
    required VoidCallback onResume,
    bool isUserInitiated = false,
  }) {
    if (!_decoders.containsKey(id)) return false;
    final limit = isUserInitiated ? 1 : getMaxActive(tier);
    if (limit == 0) return false;
    _playing.remove(id);
    while (_playing.length >= limit) {
      final oldest = _playing.remove(_playing.keys.first)!;
      oldest.onPause();
    }
    _playing[id] = _PlayingMedia(onPause, onResume);
    return true;
  }

  void notifyPaused(Object id) => _playing.remove(id);
  void notifyDisposed(Object id) => unawaited(release(id));

  Future<void> release(Object id) {
    try {
      _playing.remove(id)?.onPause();
    } catch (_) {
      /* The controller may have already lost its native texture. */
    }
    final entry = _decoders.remove(id);
    if (entry == null) return Future<void>.value();
    late final Future<void> release;
    release = Future<void>.sync(entry.release)
        .catchError((Object _) {
          debugPrint('AnimatedMediaControllerPool: DECODER_RELEASE_FAILED');
        })
        .whenComplete(() {
          _releases.remove(release);
        });
    _releases.add(release);
    return release;
  }

  void setFastScrolling(bool isFast, {Object? source}) {
    final wasFast = isFastScrolling;
    final token = source ?? _defaultScrollSource;
    if (isFast) {
      _fastScrollSources.add(token);
    } else {
      _fastScrollSources.remove(token);
    }
    if (wasFast == isFastScrolling) return;
    if (isFastScrolling) {
      for (final id in _decoders.keys.toList(growable: false)) {
        if (!_decoders[id]!.userInitiated) unawaited(release(id));
      }
    }
    notifyListeners();
  }

  void reset() {
    _generation++;
    // Old queued acquisitions are invalidated by generation. A fresh queue
    // must not inherit their scheduling zone (or wait on an obsolete request).
    // The native release barrier below still protects replacement codecs.
    _acquisition = SynchronousFuture<void>(null);
    for (final id in _decoders.keys.toList(growable: false)) {
      unawaited(release(id));
    }
    _playing.clear();
    _fastScrollSources.clear();
    for (final entry in _posters.values.toList()) {
      entry.evict();
    }
    _posters.clear();
    _posterBytes = 0;
  }
}
