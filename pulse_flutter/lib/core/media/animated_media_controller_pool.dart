import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';

/// Entry for an actively playing animated media widget.
class _ActiveMediaEntry {
  _ActiveMediaEntry({
    required this.id,
    required this.onPause,
    required this.onResume,
  });

  final String id;
  final VoidCallback onPause;
  final VoidCallback onResume;
}

/// Global coordinator for animated media and video controllers in chat bubbles.
///
/// Guarantees:
/// - Maximum 1-2 active playing video decoders concurrently.
/// - Tier-aware: Tier A = 2, Tier B = 1, Tier C / Power Saver = 0 (poster frame only).
/// - Automatically pauses oldest active players when new items enter the viewport.
/// - Pauses active media during rapid flings / fast scrolling.
class AnimatedMediaControllerPool {
  AnimatedMediaControllerPool._();

  static final AnimatedMediaControllerPool instance =
      AnimatedMediaControllerPool._();

  final List<_ActiveMediaEntry> _activePlayers = <_ActiveMediaEntry>[];
  bool _isFastScrolling = false;
  bool get isFastScrolling => _isFastScrolling;

  /// Returns maximum concurrent active players for the given [tier].
  int getMaxActive(PerformanceTier tier) {
    if (_isFastScrolling) return 0;
    return switch (tier) {
      PerformanceTier.tierA => 2,
      PerformanceTier.tierB => 1,
      PerformanceTier.tierC => 0,
    };
  }

  /// Whether autoplay is currently allowed for the given [tier].
  bool canAutoplay(PerformanceTier tier) {
    if (_isFastScrolling) return false;
    return tier != PerformanceTier.tierC;
  }

  /// Requests permission to play. If limit is reached, pauses the oldest player.
  /// Returns `true` if this item is allowed to play.
  bool requestPlay({
    required String id,
    required PerformanceTier tier,
    required VoidCallback onPause,
    required VoidCallback onResume,
    bool isUserInitiated = false,
  }) {
    // If already active, move to MRU position
    final int existingIndex = _activePlayers.indexWhere((e) => e.id == id);
    if (existingIndex >= 0) {
      final entry = _activePlayers.removeAt(existingIndex);
      _activePlayers.add(entry);
      return true;
    }

    final int maxAllowed = isUserInitiated ? 1 : getMaxActive(tier);
    if (maxAllowed <= 0 && !isUserInitiated) {
      return false;
    }

    // Evict oldest until under budget
    while (_activePlayers.length >= maxAllowed && _activePlayers.isNotEmpty) {
      final oldest = _activePlayers.removeAt(0);
      try {
        oldest.onPause();
      } catch (_) {}
    }

    _activePlayers.add(
      _ActiveMediaEntry(
        id: id,
        onPause: onPause,
        onResume: onResume,
      ),
    );
    return true;
  }

  /// Informs the pool that a media element was paused (e.g. scrolled offscreen).
  void notifyPaused(String id) {
    _activePlayers.removeWhere((e) => e.id == id);
  }

  /// Informs the pool that a media controller was disposed.
  void notifyDisposed(String id) {
    _activePlayers.removeWhere((e) => e.id == id);
  }

  /// Notifies the pool of scroll activity. Pauses active players during fast flings.
  void setFastScrolling(bool isFast) {
    if (_isFastScrolling == isFast) return;
    _isFastScrolling = isFast;
    if (_isFastScrolling) {
      for (final entry in _activePlayers) {
        try {
          entry.onPause();
        } catch (_) {}
      }
    } else {
      for (final entry in _activePlayers) {
        try {
          entry.onResume();
        } catch (_) {}
      }
    }
  }

  /// Resets all active players (e.g. when exiting chat).
  void reset() {
    for (final entry in _activePlayers) {
      try {
        entry.onPause();
      } catch (_) {}
    }
    _activePlayers.clear();
    _isFastScrolling = false;
  }

  /// Number of currently active playing media items.
  int get activeCount => _activePlayers.length;
}
