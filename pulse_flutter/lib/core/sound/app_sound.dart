import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    defaultVolume: 0.38,
    cooldownMs: 40,
  ),
  uiSelect(
    'sounds/ui_select.ogg',
    priority: SoundPriority.low,
    defaultVolume: 0.42,
    cooldownMs: 40,
  ),
  toggleOn(
    'sounds/ui_toggle_on.ogg',
    priority: SoundPriority.low,
    defaultVolume: 0.42,
  ),
  toggleOff(
    'sounds/ui_toggle_off.ogg',
    priority: SoundPriority.low,
    defaultVolume: 0.38,
  ),
  confirm(
    'sounds/ui_confirm.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.45,
  ),
  cancel(
    'sounds/ui_cancel.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.40,
  ),

  // UI Status
  success(
    'sounds/ui_success.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.48,
  ),
  error(
    'sounds/ui_error.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.45,
  ),

  // Messaging (warm digital-organic pulse)
  messageSend(
    'sounds/message_send.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.48,
  ),
  messageReceive(
    'sounds/message_receive.ogg',
    priority: SoundPriority.high,
    defaultVolume: 0.52,
  ),
  mention(
    'sounds/message_mention.ogg',
    priority: SoundPriority.urgent,
    defaultVolume: 0.65,
  ),
  reaction(
    'sounds/reaction.ogg',
    priority: SoundPriority.low,
    defaultVolume: 0.40,
  ),
  stickerSend(
    'sounds/sticker_send.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.45,
  ),

  // Media & Files
  uploadComplete(
    'sounds/upload_complete.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.45,
  ),
  uploadError(
    'sounds/upload_error.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.45,
  ),

  // Voice Recording
  recordStart(
    'sounds/record_start.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.42,
  ),
  recordLock(
    'sounds/record_lock.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.44,
  ),
  recordCancel(
    'sounds/record_cancel.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.40,
  ),
  recordSend(
    'sounds/record_send.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.48,
  ),

  // AI Assistant
  aiStart(
    'sounds/ai_start.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.44,
  ),
  aiComplete(
    'sounds/ai_complete.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.50,
  ),
  aiError(
    'sounds/ai_error.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.45,
  ),

  // Security & Encryption
  securityConnecting(
    'sounds/security_connecting.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.44,
  ),
  securityVerified(
    'sounds/security_verified.ogg',
    priority: SoundPriority.normal,
    defaultVolume: 0.52,
  ),
  securityWarning(
    'sounds/security_warning.ogg',
    priority: SoundPriority.urgent,
    defaultVolume: 0.60,
  ),

  // Calls & Real-Time Communication
  callIncoming(
    'sounds/call_incoming.ogg',
    priority: SoundPriority.urgent,
    defaultVolume: 0.85,
    isLoop: true,
  ),
  callConnected(
    'sounds/call_connected.ogg',
    priority: SoundPriority.high,
    defaultVolume: 0.55,
  ),
  callEnded(
    'sounds/call_ended.ogg',
    priority: SoundPriority.high,
    defaultVolume: 0.55,
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
  List<AudioPlayer>? _effectPlayers;
  List<AudioPlayer>? _uiPlayers;
  AudioPlayer? _loopPlayer;

  dynamic _loopingTarget;
  Future<void>? _initializing;
  bool _enabled = true;
  double _volume = 0.85;

  final Map<SoundEvent, int> _lastPlayedTimestamp = <SoundEvent, int>{};
  int _uiPlayerIndex = 0;
  int _effectPlayerIndex = 0;

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

  Future<void> _setupPlayer(AudioPlayer player, ReleaseMode releaseMode) async {
    await player.setAudioContext(_audioContext);
    await player.setPlayerMode(PlayerMode.mediaPlayer);
    await player.setReleaseMode(releaseMode);
    if (kDebugMode) {
      player.onPlayerStateChanged.listen((PlayerState state) {
        debugPrint('[SoundService:${player.playerId}] State: $state');
      });
      player.onLog.listen((String log) {
        debugPrint('[SoundService:${player.playerId}] Log: $log');
      });
    }
  }

  Future<void> _initialize() async {
    try {
      await AudioPlayer.global.setAudioContext(_audioContext);
    } catch (e) {
      debugPrint('[SoundService] Global AudioContext warning: $e');
    }

    try {
      _priorityPlayer = AudioPlayer(playerId: 'nios_priority');
      await _setupPlayer(_priorityPlayer!, ReleaseMode.stop);
    } catch (e) {
      debugPrint('[SoundService] _priorityPlayer init error: $e');
    }

    try {
      _effectPlayers = List<AudioPlayer>.generate(
        4,
        (int index) => AudioPlayer(playerId: 'nios_effect_$index'),
      );
      for (final AudioPlayer player in _effectPlayers!) {
        await _setupPlayer(player, ReleaseMode.stop);
      }
    } catch (e) {
      debugPrint('[SoundService] _effectPlayers init error: $e');
    }

    try {
      _uiPlayers = List<AudioPlayer>.generate(
        4,
        (int index) => AudioPlayer(playerId: 'nios_ui_$index'),
      );
      for (final AudioPlayer player in _uiPlayers!) {
        await _setupPlayer(player, ReleaseMode.stop);
      }
    } catch (e) {
      debugPrint('[SoundService] _uiPlayers init error: $e');
    }

    try {
      _loopPlayer = AudioPlayer(playerId: 'nios_loops');
      await _setupPlayer(_loopPlayer!, ReleaseMode.loop);
    } catch (e) {
      debugPrint('[SoundService] _loopPlayer init error: $e');
    }

    if (kDebugMode) {
      unawaited(verifyBundleAssets().then((Map<String, bool> results) {
        final int ok = results.values.where((bool v) => v).length;
        debugPrint('[SoundService] Asset diagnostic: $ok/${results.length} bundle assets verified');
      }));
    }
  }

  /// Verifies all registered [SoundEvent] and [AppSound] assets against the Flutter rootBundle.
  /// Returns a map of asset key to boolean load status.
  static Future<Map<String, bool>> verifyBundleAssets() async {
    final Map<String, bool> results = <String, bool>{};
    for (final SoundEvent event in SoundEvent.values) {
      final String key = 'assets/${event.assetPath}';
      try {
        final ByteData data = await rootBundle.load(key);
        results[key] = data.lengthInBytes > 0;
      } catch (e) {
        results[key] = false;
        debugPrint('[SoundService:AssetDiagnostic] Missing asset $key: $e');
      }
    }
    for (final AppSound legacy in AppSound.values) {
      final String key = 'assets/${legacy.assetPath}';
      if (!results.containsKey(key)) {
        try {
          final ByteData data = await rootBundle.load(key);
          results[key] = data.lengthInBytes > 0;
        } catch (e) {
          results[key] = false;
          debugPrint('[SoundService:AssetDiagnostic] Missing legacy asset $key: $e');
        }
      }
    }
    return results;
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) {
      await stopLoop();
      try {
        await _priorityPlayer?.stop();
        if (_effectPlayers != null) {
          for (final AudioPlayer player in _effectPlayers!) {
            await player.stop();
          }
        }
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
    if (_effectPlayers != null) {
      for (final AudioPlayer player in _effectPlayers!) {
        player.setVolume(_effectiveVolume(0.85));
      }
    }
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

      AudioPlayer? player;
      // Routing according to priority and event type
      if (event.priority == SoundPriority.urgent) {
        player = _priorityPlayer ?? _effectPlayers?.first;
      } else if (event.priority == SoundPriority.low) {
        // Round-robin UI player pool
        final List<AudioPlayer>? pool = _uiPlayers;
        if (pool != null && pool.isNotEmpty) {
          player = pool[_uiPlayerIndex % pool.length];
          _uiPlayerIndex++;
        } else {
          player = _effectPlayers?.first ?? _priorityPlayer;
        }
      } else {
        // Normal or High effects: Round-robin effect pool to prevent clipping preceding sounds
        final List<AudioPlayer>? pool = _effectPlayers;
        if (pool != null && pool.isNotEmpty) {
          player = pool[_effectPlayerIndex % pool.length];
          _effectPlayerIndex++;
        } else {
          player = _priorityPlayer;
        }
      }

      if (player == null) {
        debugPrint('[SoundService] playEvent: No player available for ${event.name}');
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '[SoundService] playEvent: ${event.name} | asset: ${event.assetPath} | '
          'priority: ${event.priority.name} | enabled: $_enabled | '
          'globalVol: ${_volume.toStringAsFixed(2)} | defaultVol: ${event.defaultVolume.toStringAsFixed(2)} | '
          'effectiveVol: ${effectiveVol.toStringAsFixed(2)} | player: ${player.playerId}',
        );
      }

      await player.stop();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(
        AssetSource(event.assetPath),
        volume: effectiveVol,
      );
    } catch (e, st) {
      debugPrint('[SoundService] playEvent error for ${event.name}: $e\n$st');
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
      final double effectiveVol = _effectiveVolume(volume ?? defaultVol);

      if (kDebugMode) {
        debugPrint(
          '[SoundService] startLoop: $assetPath | enabled: $_enabled | '
          'globalVol: ${_volume.toStringAsFixed(2)} | effectiveVol: ${effectiveVol.toStringAsFixed(2)}',
        );
      }

      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AssetSource(assetPath),
        volume: effectiveVol,
      );
    } catch (e, st) {
      debugPrint('[SoundService] startLoop error: $e\n$st');
    }
  }

  /// Stops current looping playback.
  Future<void> stopLoop() async {
    if (kDebugMode && _loopingTarget != null) {
      debugPrint('[SoundService] stopLoop called (was looping: $_loopingTarget)');
    }
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
    if (_effectPlayers != null) {
      for (final AudioPlayer player in _effectPlayers!) {
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
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
    _effectPlayers = null;
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
