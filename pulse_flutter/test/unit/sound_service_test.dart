import 'dart:async';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';

class MockAudioplayersPlatform extends AudioplayersPlatformInterface {
  final Map<String, StreamController<AudioEvent>> _controllers =
      <String, StreamController<AudioEvent>>{};

  @override
  Future<void> create(String playerId) async {
    _controllers[playerId] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Future<void> dispose(String playerId) async {
    await _controllers[playerId]?.close();
    _controllers.remove(playerId);
  }

  @override
  Future<void> emitError(String playerId, String code, String message) async {}

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<int?> getDuration(String playerId) async => 0;

  @override
  Future<void> pause(String playerId) async {}

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> resume(String playerId) async {}

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setAudioContext(
    String playerId,
    AudioContext audioContext,
  ) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  final List<({String playerId, String url})> playedSources = <({String playerId, String url})>[];

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    _controllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    playedSources.add((playerId: playerId, url: url));
    _controllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> stop(String playerId) async {}

  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    return _controllers
        .putIfAbsent(playerId, () => StreamController<AudioEvent>.broadcast())
        .stream;
  }
}

class MockGlobalAudioplayersPlatform
    extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() {
    return const Stream<GlobalAudioEvent>.empty();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioplayersPlatformInterface.instance = MockAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance =
        MockGlobalAudioplayersPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
  });

  group('SoundEvent Enum', () {
    test('defines all 28 semantic events with calibrated volumes', () {
      expect(SoundEvent.values.length, 28);
      expect(SoundEvent.uiTap.defaultVolume, 0.38);
      expect(SoundEvent.uiSelect.defaultVolume, 0.42);
      expect(SoundEvent.toggleOn.defaultVolume, 0.42);
      expect(SoundEvent.toggleOff.defaultVolume, 0.38);
      expect(SoundEvent.messageReceive.defaultVolume, 0.52);
      expect(SoundEvent.messageSend.defaultVolume, 0.48);
      expect(SoundEvent.mention.defaultVolume, 0.65);
      expect(SoundEvent.callIncoming.defaultVolume, 0.85);

      for (final SoundEvent event in SoundEvent.values) {
        expect(event.assetPath, startsWith('sounds/'));
        expect(event.assetPath, endsWith('.ogg'));
        expect(event.defaultVolume, greaterThanOrEqualTo(0.35));
        expect(event.defaultVolume, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('AppSound Enum', () {
    test('sound enum defines valid assets', () {
      expect(AppSound.message.assetPath, 'sounds/message.ogg');
      expect(AppSound.navigation.assetPath, 'sounds/nav1.ogg');
    });
  });

  group('SoundService', () {
    late SoundService soundService;

    setUp(() {
      soundService = SoundService();
    });

    tearDown(() async {
      await soundService.dispose();
    });

    test('initializes with default enabled and volume settings', () {
      expect(soundService.enabled, isTrue);
      expect(soundService.volume, closeTo(0.85, 0.001));
    });

    test('clamps volume within [0.0, 1.0]', () {
      soundService.setVolume(0.5);
      expect(soundService.volume, closeTo(0.5, 0.001));

      soundService.setVolume(-0.2);
      expect(soundService.volume, 0.0);

      soundService.setVolume(1.8);
      expect(soundService.volume, 1.0);
    });

    test('setEnabled toggles state correctly', () async {
      await soundService.setEnabled(false);
      expect(soundService.enabled, isFalse);

      await soundService.setEnabled(true);
      expect(soundService.enabled, isTrue);
    });

    test('initialize completes safely', () async {
      await expectLater(soundService.initialize(), completes);
    });

    test('all 28 SoundEvent items can be played without error', () async {
      for (final SoundEvent event in SoundEvent.values) {
        await expectLater(soundService.playEvent(event), completes);
      }
    });

    test('play, playUiTick, startLoop, stopLoop run without throwing', () async {
      await expectLater(soundService.play(AppSound.message), completes);
      await expectLater(soundService.playUiTick(), completes);
      await expectLater(soundService.startLoop(AppSound.navigation), completes);
      await expectLater(soundService.stopLoop(), completes);

      await soundService.setEnabled(false);
      await expectLater(soundService.play(AppSound.message), completes);
      await expectLater(soundService.playUiTick(), completes);
      await expectLater(soundService.startLoop(AppSound.navigation), completes);
    });

    test('effect pool distributes rapid normal events without collisions', () async {
      final mock = AudioplayersPlatformInterface.instance as MockAudioplayersPlatform;
      mock.playedSources.clear();

      // Play 4 normal events rapidly
      await soundService.playEvent(SoundEvent.messageSend);
      await soundService.playEvent(SoundEvent.messageReceive);
      await soundService.playEvent(SoundEvent.uploadComplete);
      await soundService.playEvent(SoundEvent.aiComplete);

      expect(mock.playedSources.length, 4);
      final playerIds = mock.playedSources.map((s) => s.playerId).toList();
      expect(playerIds, containsAll(<String>['nios_effect_0', 'nios_effect_1', 'nios_effect_2', 'nios_effect_3']));
    });

    test('dispose cleans up gracefully and can be called multiple times', () async {
      await soundService.initialize();
      await soundService.dispose();
      await expectLater(soundService.dispose(), completes);
    });
  });
}
