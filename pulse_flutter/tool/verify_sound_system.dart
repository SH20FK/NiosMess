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
  final List<String> incompleteMasters = <String>[];

  if (masterDir.existsSync()) {
    for (final String asset in requiredAssets) {
      final Directory assetMasterDir = Directory('assets/sounds/master/$asset');
      if (!assetMasterDir.existsSync()) {
        incompleteMasters.add('$asset (missing dir)');
      } else {
        final int variants = assetMasterDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('variant_'))
            .length;
        if (variants < 5) {
          incompleteMasters.add('$asset ($variants/5 variants)');
        }
      }
    }
  }

  report(
    'Master directory contains all 5 variations for all 28 assets',
    incompleteMasters.isEmpty,
    'Incomplete: ${incompleteMasters.join(', ')}',
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
