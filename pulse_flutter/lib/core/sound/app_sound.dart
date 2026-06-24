import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

enum AppSound {
  connectionReady('sounds/connectionyes.ogg'),
  connect('sounds/connect.ogg'),
  reconnect('sounds/reconnect.ogg'),
  busy('sounds/busy.ogg'),
  callEnd('sounds/end.ogg'),
  dialTone('sounds/goodock.ogg'),
  message('sounds/message.ogg'),
  navigation('sounds/nav1.ogg'),
  micOn('sounds/micro on.ogg'),
  micOff('sounds/micro off.ogg'),
  videoOn('sounds/video on.ogg'),
  videoOff('sounds/video off.ogg'),
  voiceMessageStart('sounds/startvoicesms.ogg'),
  voiceMessageSend('sounds/endvoicesms.ogg'),
  ringtone('sounds/ringtone kalodecc.ogg'),
  videoRingtone('sounds/zvonit video.ogg');

  const AppSound(this.assetPath);

  final String assetPath;
}

class SoundService {
  final AudioPlayer _effectPlayer = AudioPlayer(playerId: 'nios_effects');
  final List<AudioPlayer> _uiPlayers = List<AudioPlayer>.generate(
    3,
    (int index) => AudioPlayer(playerId: 'nios_ui_$index'),
  );
  final AudioPlayer _loopPlayer = AudioPlayer(playerId: 'nios_loops');

  AppSound? _loopingSound;
  Future<void>? _initializing;
  bool _enabled = true;
  double _volume = 0.85;

  bool get enabled => _enabled;
  double get volume => _volume;

  Future<void> initialize() {
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      for (final AudioPlayer player in _uiPlayers) {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
      }
      await _effectPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _effectPlayer.setReleaseMode(ReleaseMode.stop);
      await _loopPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _loopPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) { debugPrint('[app_sound.dart] Error: $e'); }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) {
      await stopLoop();
      try {
        await _effectPlayer.stop();
        for (final AudioPlayer player in _uiPlayers) {
          await player.stop();
        }
      } catch (e) { debugPrint('[app_sound.dart] Error: $e'); }
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
  }

  Future<void> play(AppSound sound, {double volume = 0.9}) async {
    if (!_enabled) return;
    try {
      await initialize();
      await _effectPlayer.stop();
      await _effectPlayer.setReleaseMode(ReleaseMode.stop);
      await _effectPlayer.play(
        AssetSource(sound.assetPath),
        volume: _effectiveVolume(volume),
      );
    } catch (e) { debugPrint('[app_sound.dart] Error: $e'); }
  }

  Future<void> playUiTick({double volume = 0.85}) async {
    // Disabled to prevent audio session interruption of background music on desktop
  }

  Future<void> startLoop(AppSound sound, {double volume = 0.75}) async {
    if (!_enabled) return;
    if (_loopingSound == sound) return;
    _loopingSound = sound;
    try {
      await initialize();
      await _loopPlayer.stop();
      await _loopPlayer.setReleaseMode(ReleaseMode.loop);
      await _loopPlayer.play(
        AssetSource(sound.assetPath),
        volume: _effectiveVolume(volume),
      );
    } catch (e) { debugPrint('[app_sound.dart] Error: $e'); }
  }

  Future<void> stopLoop() async {
    _loopingSound = null;
    try {
      await _loopPlayer.stop();
    } catch (e) { debugPrint('[app_sound.dart] Error: $e'); }
  }

  Future<void> dispose() async {
    await _effectPlayer.dispose();
    for (final AudioPlayer player in _uiPlayers) {
      await player.dispose();
    }
    await _loopPlayer.dispose();
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
