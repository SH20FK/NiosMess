import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

enum AppSound {
  message('sounds/message.ogg'),
  navigation('sounds/nav1.ogg');

  const AppSound(this.assetPath);

  final String assetPath;
}

class SoundService {
  AudioPlayer? _effectPlayer;
  List<AudioPlayer>? _uiPlayers;
  AudioPlayer? _loopPlayer;

  AppSound? _loopingSound;
  Future<void>? _initializing;
  bool _enabled = true;
  double _volume = 0.85;

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
      options: const <AVAudioSessionOptions>{},
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
      await AudioCache.instance.load(AppSound.message.assetPath);
      await AudioCache.instance.load(AppSound.navigation.assetPath);
    } catch (e) {
      debugPrint('[SoundService] AudioCache pre-cache warning: $e');
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
        3,
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
      await _loopPlayer!.setReleaseMode(ReleaseMode.stop);
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
        await _effectPlayer?.stop();
        if (_uiPlayers != null) {
          for (final AudioPlayer player in _uiPlayers!) {
            await player.stop();
          }
        }
      } catch (e) {
        debugPrint('[app_sound.dart] Error: $e');
      }
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _effectPlayer?.setVolume(_effectiveVolume(0.9));
    if (_uiPlayers != null) {
      for (final AudioPlayer player in _uiPlayers!) {
        player.setVolume(_effectiveVolume(0.85));
      }
    }
    _loopPlayer?.setVolume(_effectiveVolume(0.75));
  }

  Future<void> play(AppSound sound, {double volume = 0.9}) async {
    if (!_enabled) return;
    try {
      await initialize();
      final AudioPlayer? player = _effectPlayer;
      if (player == null) return;
      await player.stop();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(
        AssetSource(sound.assetPath),
        volume: _effectiveVolume(volume),
      );
    } catch (e) {
      debugPrint('[app_sound.dart] Error: $e');
    }
  }

  int _uiPlayerIndex = 0;

  Future<void> playUiTick({double volume = 0.85}) async {
    if (!_enabled) return;
    try {
      await initialize();
      final List<AudioPlayer>? uiPlayers = _uiPlayers;
      if (uiPlayers == null || uiPlayers.isEmpty) return;
      final AudioPlayer player = uiPlayers[_uiPlayerIndex % uiPlayers.length];
      _uiPlayerIndex++;
      await player.stop();
      await player.play(
        AssetSource(AppSound.navigation.assetPath),
        volume: _effectiveVolume(volume),
      );
    } catch (e) {
      debugPrint('[app_sound.dart] playUiTick error: $e');
    }
  }

  Future<void> startLoop(AppSound sound, {double volume = 0.75}) async {
    if (!_enabled) return;
    if (_loopingSound == sound) return;
    _loopingSound = sound;
    try {
      await initialize();
      final AudioPlayer? player = _loopPlayer;
      if (player == null) return;
      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AssetSource(sound.assetPath),
        volume: _effectiveVolume(volume),
      );
    } catch (e) {
      debugPrint('[app_sound.dart] Error: $e');
    }
  }

  Future<void> stopLoop() async {
    _loopingSound = null;
    try {
      await _loopPlayer?.stop();
    } catch (e) {
      debugPrint('[app_sound.dart] Error: $e');
    }
  }

  Future<void> dispose() async {
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
