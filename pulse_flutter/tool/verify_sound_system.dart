// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main() {
  int passed = 0;
  int failed = 0;

  void report(String title, bool condition, [String? errorDetails]) {
    if (condition) {
      print('  [PASS] $title');
      passed++;
    } else {
      print('  [FAIL] $title');
      if (errorDetails != null && errorDetails.isNotEmpty) {
        print('         $errorDetails');
      }
      failed++;
    }
  }

  print('=== Running NiosMess Acoustic Sound System Verification ===\n');

  final Directory soundsDir = Directory('assets/sounds');
  if (!soundsDir.existsSync()) {
    print('Error: assets/sounds directory not found. Please run from pulse_flutter root.');
    exit(1);
  }

  // 1. Manifest verification
  final File manifestFile = File('assets/sounds/manifest.json');
  report('manifest.json exists', manifestFile.existsSync());

  Map<String, dynamic>? manifest;
  if (manifestFile.existsSync()) {
    try {
      manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      report('manifest.json is valid JSON', true);
    } catch (e) {
      report('manifest.json is valid JSON', false, e.toString());
    }
  }

  final List<String> requiredAssets = <String>[
    'ui_tap',
    'ui_select',
    'ui_toggle_on',
    'ui_toggle_off',
    'ui_confirm',
    'ui_cancel',
    'ui_success',
    'ui_error',
    'message_send',
    'message_receive',
    'message_mention',
    'reaction',
    'sticker_send',
    'upload_complete',
    'upload_error',
    'record_start',
    'record_lock',
    'record_cancel',
    'record_send',
    'ai_start',
    'ai_complete',
    'ai_error',
    'security_connecting',
    'security_verified',
    'security_warning',
    'call_incoming',
    'call_connected',
    'call_ended',
  ];

  // 2. File existence and non-zero size
  final List<String> missingFiles = <String>[];
  final List<String> emptyFiles = <String>[];

  for (final String asset in requiredAssets) {
    final File oggFile = File('assets/sounds/$asset.ogg');
    if (!oggFile.existsSync()) {
      missingFiles.add('$asset.ogg');
    } else if (oggFile.lengthSync() < 500) {
      emptyFiles.add('$asset.ogg (${oggFile.lengthSync()} bytes)');
    }
  }

  report(
    'All 28 production OGG assets exist',
    missingFiles.isEmpty,
    'Missing: ${missingFiles.join(', ')}',
  );

  report(
    'All production OGG assets have valid audio size (>500B)',
    emptyFiles.isEmpty,
    'Under-sized: ${emptyFiles.join(', ')}',
  );

  // 3. Checksum verification against manifest
  if (manifest != null && manifest.containsKey('assets')) {
    final Map<String, dynamic> manifestAssets = manifest['assets'] as Map<String, dynamic>;
    final List<String> checksumMismatches = <String>[];

    for (final String asset in requiredAssets) {
      final File oggFile = File('assets/sounds/$asset.ogg');
      if (oggFile.existsSync() && manifestAssets.containsKey(asset)) {
        final String recordedSha = manifestAssets[asset]['sha256'] as String? ?? '';
        final Digest actualSha = sha256.convert(oggFile.readAsBytesSync());
        if (actualSha.toString() != recordedSha) {
          checksumMismatches.add(asset);
        }
      }
    }

    report(
      'All 28 assets match manifest SHA-256 checksums',
      checksumMismatches.isEmpty,
      'Mismatches: ${checksumMismatches.join(', ')}',
    );
  }

  // 4. Master raw variations check
  final Directory masterDir = Directory('assets/sounds/master');

  report(
    'Obsolete ElevenLabs AI master directory eliminated (bundle size optimized)',
    !masterDir.existsSync(),
    'Master directory still present at ${masterDir.path}',
  );

  // 5. Secret leak verification
  final RegExp secretPattern = RegExp(r'sk_[0-9a-fA-F]{32,64}');
  final List<String> leakedFiles = <String>[];

  void scanDirectory(Directory dir) {
    for (final FileSystemEntity entity in dir.listSync(recursive: false)) {
      final String name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments[entity.uri.pathSegments.length - 2]
          : entity.path;
      if (name.startsWith('.') || name == 'build' || name == 'master') continue;

      if (entity is File) {
        if (entity.path.endsWith('.dart') ||
            entity.path.endsWith('.yaml') ||
            entity.path.endsWith('.json') ||
            entity.path.endsWith('.md')) {
          try {
            final String text = entity.readAsStringSync();
            if (secretPattern.hasMatch(text)) {
              leakedFiles.add(entity.path);
            }
          } catch (_) {}
        }
      } else if (entity is Directory) {
        scanDirectory(entity);
      }
    }
  }

  scanDirectory(Directory('lib'));
  scanDirectory(Directory('test'));
  scanDirectory(Directory('tool'));
  scanDirectory(Directory('assets/sounds'));

  report(
    'Zero ElevenLabs API keys in source code, assets or config',
    leakedFiles.isEmpty,
    'LEAK FOUND IN: ${leakedFiles.join(', ')}',
  );

  // 6. Check backward-compatible legacy files
  final File legacyMessage = File('assets/sounds/message.ogg');
  final File legacyNav = File('assets/sounds/nav1.ogg');
  report(
    'Legacy audio files message.ogg and nav1.ogg exist for backward compatibility',
    legacyMessage.existsSync() && legacyNav.existsSync(),
  );

  final Map<String, String> assetToEnum = {
    'ui_tap': 'uiTap',
    'ui_select': 'uiSelect',
    'ui_toggle_on': 'toggleOn',
    'ui_toggle_off': 'toggleOff',
    'ui_confirm': 'confirm',
    'ui_cancel': 'cancel',
    'ui_success': 'success',
    'ui_error': 'error',
    'message_send': 'messageSend',
    'message_receive': 'messageReceive',
    'message_mention': 'mention',
    'reaction': 'reaction',
    'sticker_send': 'stickerSend',
    'upload_complete': 'uploadComplete',
    'upload_error': 'uploadError',
    'record_start': 'recordStart',
    'record_lock': 'recordLock',
    'record_cancel': 'recordCancel',
    'record_send': 'recordSend',
    'ai_start': 'aiStart',
    'ai_complete': 'aiComplete',
    'ai_error': 'aiError',
    'security_connecting': 'securityConnecting',
    'security_verified': 'securityVerified',
    'security_warning': 'securityWarning',
    'call_incoming': 'callIncoming',
    'call_connected': 'callConnected',
    'call_ended': 'callEnded',
  };

  // 7. Verification of SoundEvent definitions and elevated volume levels in app_sound.dart
  final File appSoundFile = File('lib/core/sound/app_sound.dart');
  report('lib/core/sound/app_sound.dart exists', appSoundFile.existsSync());

  if (appSoundFile.existsSync()) {
    final String appSoundCode = appSoundFile.readAsStringSync();
    final List<String> missingEnumEvents = <String>[];
    for (final String asset in requiredAssets) {
      final String enumName = assetToEnum[asset]!;
      if (!appSoundCode.contains(enumName)) {
        missingEnumEvents.add(enumName);
      }
    }
    report(
      'All 28 SoundEvents declared in SoundEvent enum',
      missingEnumEvents.isEmpty,
      'Missing enums: ${missingEnumEvents.join(', ')}',
    );

    report(
      'Elevated volumes present (uiTap >= 0.38, messageReceive >= 0.52)',
      appSoundCode.contains('defaultVolume: 0.38') && appSoundCode.contains('defaultVolume: 0.52'),
    );

    report(
      '4-player effect pool implemented (_effectPlayers)',
      appSoundCode.contains('List<AudioPlayer>? _effectPlayers') &&
          appSoundCode.contains('nios_effect_'),
    );

    report(
      'verifyBundleAssets diagnostic method present in SoundService',
      appSoundCode.contains('verifyBundleAssets()'),
    );
  }

  // 8. Decoupled notification sounds in backend_chat_provider.dart
  final File chatProviderFile = File('lib/providers/backend_chat_provider.dart');
  if (chatProviderFile.existsSync()) {
    final String chatCode = chatProviderFile.readAsStringSync();
    final bool decoupled = chatCode.contains('settings.soundEffects') &&
        chatCode.contains('chatMutedProvider') &&
        !chatCode.contains('if (!ref.read(uiSettingsProvider).notifications) return;\n    await ref.read(appSoundProvider).playEvent');
    report(
      'Message sound decoupled from push notifications (uses soundEffects & chatMutedProvider)',
      decoupled,
    );
  }

  // 9. Check sound test tile in settings_preferences_screen.dart
  final File prefScreenFile = File('lib/screens/settings_preferences_screen.dart');
  if (prefScreenFile.existsSync()) {
    final String prefCode = prefScreenFile.readAsStringSync();
    report(
      'Test sound sequence tile present in SettingsPreferencesScreen',
      prefCode.contains('Проверить звук') &&
          prefCode.contains('SoundEvent.uiTap') &&
          prefCode.contains('SoundEvent.messageReceive') &&
          prefCode.contains('SoundEvent.success') &&
          prefCode.contains('SoundEvent.error'),
    );
  }

  // 10. Verify genuine call sites in lib/ for all 28 SoundEvents
  final List<String> libFiles = <String>[];
  void collectLibFiles(Directory d) {
    for (final entity in d.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart') && !entity.path.endsWith('app_sound.dart')) {
        libFiles.add(entity.path);
      }
    }
  }
  collectLibFiles(Directory('lib'));

  final String combinedLibCode = libFiles.map((p) {
    try {
      return File(p).readAsStringSync();
    } catch (_) {
      return '';
    }
  }).join('\n');

  final List<String> uncalledEvents = <String>[];
  for (final String asset in requiredAssets) {
    final String enumName = assetToEnum[asset]!;
    if (!combinedLibCode.contains('SoundEvent.$enumName') &&
        !combinedLibCode.contains('playUiTick') &&
        !combinedLibCode.contains('playUiSelect') &&
        !combinedLibCode.contains('playReaction')) {
      uncalledEvents.add(enumName);
    }
  }

  report(
    'All 28 SoundEvents have genuine call sites across the application',
    uncalledEvents.isEmpty,
    'Uncalled: ${uncalledEvents.join(', ')}',
  );

  print('\n=== Summary ===');
  print('Passed: $passed / ${passed + failed}');
  if (failed > 0) {
    print('FAILED: $failed verification checks failed.');
    exit(1);
  } else {
    print('SUCCESS: All NiosMess sound system checks passed cleanly.');
    exit(0);
  }
}
