import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('dispose cleans up gracefully and can be called multiple times', () async {
      await soundService.initialize();
      await soundService.dispose();
      await expectLater(soundService.dispose(), completes);
    });
  });
}
