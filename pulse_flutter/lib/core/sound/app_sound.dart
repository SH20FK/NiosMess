import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Acoustic event priority for resource contention and routing.
enum SoundPriority {
  low,
  normal,
  high,
  urgent,
}

/// Semantic acoustic events for NiosMess Material 3 Expressive audio design.
enum SoundEvent {
  // UI Interaction feedback (restrained, warm ceramic transient)
  uiTap(
    'sounds/ui_tap.ogg',
    priority: SoundPriority.low,
    defaultVolume: 0.20,
    cooldownMs: 50,
  ),
  uiSelect(
    'sounds/ui_select.ogg',
    priority: SoundPriority.low,
    defaultVolume: 0.25,
    cooldownMs: 50,
  ),
  toggleOn(
    'sounds/ui_toggle_on.ogg',
    priority: SoundPriority.low,
    defaultVolume: 0.25,
  ),
  toggleOff(
    'sounds/ui_toggle_off.ogg',
    priority: SoundPriority.low,
    defaultVolume: 0.25,
  ),
  confirm(
    'sounds/ui_confirm.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.35,
  ),
  cancel(
    'sounds/ui_cancel.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.30,
  ),

  // UI Status
  success(
    'sounds/ui_success.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.38,
  ),
  error(
    'sounds/ui_error.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.35,
  ),

  // Messaging (warm digital-organic pulse)
  messageSend(
    'sounds/message_send.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.38,
  ),
  messageReceive(
    'sounds/message_receive.ogg',
    priority: SoundPriority.high,
    defaultVolume: 0.42,
  ),
  mention(
    'sounds/message_mention.ogg',
    priority: SoundPriority.urgent,
    defaultVolume: 0.58,
  ),
  reaction(
    'sounds/reaction.ogg',
    priority: SoundPriority.low,
    defaultVolume: 0.28,
  ),
  stickerSend(
    'sounds/sticker_send.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.35,
  ),

  // Media & Files
  uploadComplete(
    'sounds/upload_complete.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.38,
  ),
  uploadError(
    'sounds/upload_error.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.38,
  ),

  // Voice Recording
  recordStart(
    'sounds/record_start.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.32,
  ),
  recordLock(
    'sounds/record_lock.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.35,
  ),
  recordCancel(
    'sounds/record_cancel.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.32,
  ),
  recordSend(
    'sounds/record_send.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.38,
  ),

  // AI Assistant
  aiStart(
    'sounds/ai_start.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.35,
  ),
  aiComplete(
    'sounds/ai_complete.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.40,
  ),
  aiError(
    'sounds/ai_error.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.35,
  ),

  // Security & Encryption
  securityConnecting(
    'sounds/security_connecting.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.35,
  ),
  securityVerified(
    'sounds/security_verified.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.42,
  ),
  securityWarning(
    'sounds/security_warning.ogg',
    priority: SoundPriority.urgent,
    defaultVolume: 0.52,
  ),

  // Calls & Real-Time Communication
  callIncoming(
    'sounds/call_incoming.ogg',
    priority: SoundPriority.urgent,
    defaultVolume: 0.75,
    isLoop: true,
  ),
  callConnected(
    'sounds/call_connected.ogg',
    priority: SoundPriority.high,
    defaultVolume: 0.45,
  ),
  callEnded(
    'sounds/call_ended.ogg',
    priority: SoundPriority.high,
    defaultVolume: 0.45,
  );

  const SoundEvent(
    this.assetPath, {
    required this.priority,
    required this.defaultVolume,
    this.cooldownMs = 0,
    this.isLoop = false,
  });

  final String assetPath;
  final SoundPriority priority;
  final double defaultVolume;
  final int cooldownMs;
  final bool isLoop;
}

/// Legacy enum for backward compatibility with existing tests and call sites.
enum AppSound {
  message('sounds/message.ogg', SoundEvent.messageReceive),
  navigation('sounds/nav1.ogg', SoundEvent.uiTap);

  const AppSound(this.assetPath, this.event);

  final String assetPath;
  final SoundEvent event;
}

/// Central audio service managing playback, audio context, volume curves,
/// pool concurrency, and seamless looping.
class SoundService {
  AudioPlayer? _priorityPlayer;
  AudioPlayer? _effectPlayer;
  List<AudioPlayer>? _uiPlayers;
  AudioPlayer? _loopPlayer;

  dynamic _loopingTarget;
  Future<void>? _initializing;
  bool _enabled = true;
  double _volume = 0.85;

  final Map<SoundEvent, int> _lastPlayedTimestamp = <SoundEvent, int>{};
  int _uiPlayerIndex = 0;

  static final AudioContext _audioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      audioMode: AndroidAudioMode.normal,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: <AVAudioSessionOptions>{},
    ),
  );

  bool get enabled => _enabled;
  double get volume => _volume;

  Future<void> initialize() {
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await AudioPlayer.global.setAudioContext(_audioContext);
    } catch (e) {
      debugPrint('[SoundService] Global AudioContext warning: $e');
    }

    try {
      _priorityPlayer = AudioPlayer(playerId: 'nios_priority');
      await _priorityPlayer!.setAudioContext(_audioContext);
      await _priorityPlayer!.setPlayerMode(PlayerMode.mediaPlayer);
      await _priorityPlayer!.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('[SoundService] _priorityPlayer init error: $e');
    }

    try {
      _effectPlayer = AudioPlayer(playerId: 'nios_effects');
      await _effectPlayer!.setAudioContext(_audioContext);
      await _effectPlayer!.setPlayerMode(PlayerMode.mediaPlayer);
      await _effectPlayer!.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('[SoundService] _effectPlayer init error: $e');
    }

    try {
      _uiPlayers = List<AudioPlayer>.generate(
        4,
        (int index) => AudioPlayer(playerId: 'nios_ui_$index'),
      );
      for (final AudioPlayer player in _uiPlayers!) {
        await player.setAudioContext(_audioContext);
        await player.setPlayerMode(PlayerMode.mediaPlayer);
        await player.setReleaseMode(ReleaseMode.stop);
      }
    } catch (e) {
      debugPrint('[SoundService] _uiPlayers init error: $e');
    }

    try {
      _loopPlayer = AudioPlayer(playerId: 'nios_loops');
      await _loopPlayer!.setAudioContext(_audioContext);
      await _loopPlayer!.setPlayerMode(PlayerMode.mediaPlayer);
      await _loopPlayer!.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('[SoundService] _loopPlayer init error: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) {
      await stopLoop();
      try {
        await _priorityPlayer?.stop();
        await _effectPlayer?.stop();
        if (_uiPlayers != null) {
          for (final AudioPlayer player in _uiPlayers!) {
            await player.stop();
          }
        }
      } catch (e) {
        debugPrint('[SoundService] Stop on disable error: $e');
      }
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _priorityPlayer?.setVolume(_effectiveVolume(0.9));
    _effectPlayer?.setVolume(_effectiveVolume(0.85));
    if (_uiPlayers != null) {
      for (final AudioPlayer player in _uiPlayers!) {
        player.setVolume(_effectiveVolume(0.75));
      }
    }
    _loopPlayer?.setVolume(_effectiveVolume(0.75));
  }

  /// Plays a semantic SoundEvent with rate-limiting, priority routing and normalized volume.
  Future<void> playEvent(SoundEvent event, {double? volume}) async {
    if (!_enabled) return;

    // Check cooldown for rapid events (e.g. uiTap, uiSelect)
    if (event.cooldownMs > 0) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int lastPlayed = _lastPlayedTimestamp[event] ?? 0;
      if (now - lastPlayed < event.cooldownMs) {
        return; // Throttled
      }
      _lastPlayedTimestamp[event] = now;
    }

    try {
      await initialize();
      final double effectiveVol = _effectiveVolume(volume ?? event.defaultVolume);

      // Routing according to priority and event type
      if (event.priority == SoundPriority.urgent) {
        final AudioPlayer? player = _priorityPlayer ?? _effectPlayer;
        if (player == null) return;
        await player.stop();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.play(
          AssetSource(event.assetPath),
          volume: effectiveVol,
        );
      } else if (event.priority == SoundPriority.low) {
        // Round-robin UI player pool
        final List<AudioPlayer>? uiPool = _uiPlayers;
        if (uiPool == null || uiPool.isEmpty) {
          final AudioPlayer? fallback = _effectPlayer;
          if (fallback == null) return;
          await fallback.stop();
          await fallback.play(AssetSource(event.assetPath), volume: effectiveVol);
          return;
        }
        final AudioPlayer player = uiPool[_uiPlayerIndex % uiPool.length];
        _uiPlayerIndex++;
        await player.stop();
        await player.play(
          AssetSource(event.assetPath),
          volume: effectiveVol,
        );
      } else {
        // Normal or High effects
        final AudioPlayer? player = _effectPlayer;
        if (player == null) return;
        await player.stop();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.play(
          AssetSource(event.assetPath),
          volume: effectiveVol,
        );
      }
    } catch (e) {
      debugPrint('[SoundService] playEvent error for ${event.name}: $e');
    }
  }

  /// Legacy play method.
  Future<void> play(AppSound sound, {double? volume}) async {
    return playEvent(sound.event, volume: volume);
  }

  /// Legacy UI tick method.
  Future<void> playUiTick({double? volume}) async {
    return playEvent(SoundEvent.uiTap, volume: volume);
  }

  /// Legacy UI select method.
  Future<void> playUiSelect({double? volume}) async {
    return playEvent(SoundEvent.uiSelect, volume: volume);
  }

  /// Legacy reaction sound.
  Future<void> playReaction({double? volume}) async {
    return playEvent(SoundEvent.reaction, volume: volume);
  }

  /// Starts a seamless loop for either [SoundEvent] or [AppSound].
  Future<void> startLoop(dynamic soundOrEvent, {double? volume}) async {
    if (!_enabled) return;
    if (_loopingTarget == soundOrEvent) return;
    _loopingTarget = soundOrEvent;

    String assetPath;
    double defaultVol = 0.75;
    if (soundOrEvent is SoundEvent) {
      assetPath = soundOrEvent.assetPath;
      defaultVol = soundOrEvent.defaultVolume;
    } else if (soundOrEvent is AppSound) {
      assetPath = soundOrEvent.assetPath;
      defaultVol = soundOrEvent.event.defaultVolume;
    } else {
      return;
    }

    try {
      await initialize();
      final AudioPlayer? player = _loopPlayer;
      if (player == null) return;
      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AssetSource(assetPath),
        volume: _effectiveVolume(volume ?? defaultVol),
      );
    } catch (e) {
      debugPrint('[SoundService] startLoop error: $e');
    }
  }

  /// Stops current looping playback.
  Future<void> stopLoop() async {
    _loopingTarget = null;
    try {
      await _loopPlayer?.stop();
    } catch (e) {
      debugPrint('[SoundService] stopLoop error: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _priorityPlayer?.dispose();
    } catch (_) {}
    try {
      await _effectPlayer?.dispose();
    } catch (_) {}
    if (_uiPlayers != null) {
      for (final AudioPlayer player in _uiPlayers!) {
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
    try {
      await _loopPlayer?.dispose();
    } catch (_) {}
    _priorityPlayer = null;
    _effectPlayer = null;
    _uiPlayers = null;
    _loopPlayer = null;
    _initializing = null;
  }

  double _effectiveVolume(double requestedVolume) {
    return (requestedVolume.clamp(0.0, 1.0) * _volume).clamp(0.0, 1.0);
  }
}

typedef AppSoundController = SoundService;

final Provider<SoundService> soundServiceProvider = Provider<SoundService>((
  Ref ref,
) {
  final SoundService service = SoundService();
  service.initialize();

  final UiSettingsState initialSettings = ref.read(uiSettingsProvider);
  service.setEnabled(initialSettings.soundEffects);
  service.setVolume(initialSettings.soundVolume);

  ref.listen<bool>(
    uiSettingsProvider.select((UiSettingsState state) => state.soundEffects),
    (_, bool next) => service.setEnabled(next),
  );
  ref.listen<double>(
    uiSettingsProvider.select((UiSettingsState state) => state.soundVolume),
    (_, double next) => service.setVolume(next),
  );
  ref.onDispose(service.dispose);
  return service;
});

final Provider<SoundService> appSoundProvider = soundServiceProvider;
