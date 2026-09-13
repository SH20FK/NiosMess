import 'package:flutter/foundation.dart';

/// Singleton coordinator for voice message playback across all chat bubbles.
///
/// Ensures only one voice message can play at a time. When a new voice message
/// begins playback, any previously playing message is automatically paused.
class GlobalVoicePlaybackService {
  GlobalVoicePlaybackService._();
  static final GlobalVoicePlaybackService instance = GlobalVoicePlaybackService._();

  String? _activeAudioUrl;
  VoidCallback? _activeStopCallback;

  String? get activeAudioUrl => _activeAudioUrl;

  /// Registers a player as actively playing. If another player is currently playing,
  /// its stop callback will be invoked immediately.
  void registerPlaying(String audioUrl, VoidCallback onStop) {
    if (_activeAudioUrl != null && _activeAudioUrl != audioUrl) {
      try {
        _activeStopCallback?.call();
      } catch (e) {
        debugPrint('[GlobalVoicePlayback] Error pausing previous voice message: $e');
      }
    }
    _activeAudioUrl = audioUrl;
    _activeStopCallback = onStop;
  }

  /// Unregisters the player if it was the active one.
  void unregisterPlaying(String audioUrl) {
    if (_activeAudioUrl == audioUrl) {
      _activeAudioUrl = null;
      _activeStopCallback = null;
    }
  }
}
