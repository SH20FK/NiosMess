// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/models/api/upload_models.dart';

void main() async {
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

  print('=== Running NiosMess Upload Pipeline & Architecture Verification ===\n');

  // 1. Test UploadSpeedTracker - No early jitter
  print('-> Testing UploadSpeedTracker:');
  final tracker = UploadSpeedTracker(
    windowDuration: const Duration(milliseconds: 1000),
    minDurationForDisplay: const Duration(milliseconds: 500),
  );

  final m1 = tracker.updateProgress(65536, 1048576);
  report('UploadSpeedTracker suppresses speed before minDuration (0.0 Bps)', m1.smoothedBytesPerSecond == 0.0);
  report('UploadSpeedTracker suppresses ETA before minDuration (null)', m1.eta == null);
  report('UploadSpeedTracker records bytesSent correctly', m1.bytesSent == 65536);
  report('UploadSpeedTracker records totalBytes correctly', m1.totalBytes == 1048576);

  // 2. Test UploadSpeedTracker - Calculation after accumulation
  final fastTracker = UploadSpeedTracker(
    windowDuration: const Duration(milliseconds: 1000),
    minDurationForDisplay: const Duration(milliseconds: 40),
  );
  fastTracker.updateProgress(0, 1000000);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  final m2 = fastTracker.updateProgress(100000, 1000000);
  report('UploadSpeedTracker calculates positive speed after elapsed threshold', m2.smoothedBytesPerSecond > 0.0);
  report('UploadSpeedTracker computes realistic ETA after elapsed threshold', m2.eta != null && m2.eta!.inSeconds >= 0);

  // 3. Test formatSpeed and formatEta
  print('\n-> Testing Formatters:');
  report('formatSpeed(0) is empty', UploadSpeedTracker.formatSpeed(0).isEmpty);
  report('formatSpeed(500) -> 500 Б/с', UploadSpeedTracker.formatSpeed(500) == '500 Б/с');
  report('formatSpeed(2048) -> 2 КБ/с', UploadSpeedTracker.formatSpeed(2048) == '2 КБ/с');
  report('formatSpeed(1.5 MB/s) -> 1.5 МБ/с', UploadSpeedTracker.formatSpeed(1024 * 1024 * 1.5) == '1.5 МБ/с');
  report('formatEta(null) is empty', UploadSpeedTracker.formatEta(null).isEmpty);
  report('formatEta(0s) -> менее секунды', UploadSpeedTracker.formatEta(Duration.zero) == 'менее секунды');
  report('formatEta(15s) -> 15с осталось', UploadSpeedTracker.formatEta(const Duration(seconds: 15)) == '15с осталось');
  report('formatEta(2m 30s) -> 2м 30с', UploadSpeedTracker.formatEta(const Duration(minutes: 2, seconds: 30)) == '2м 30с');
  report('formatEta(1h 15m) -> 1ч 15м', UploadSpeedTracker.formatEta(const Duration(hours: 1, minutes: 15)) == '1ч 15м');

  // 4. Test CancellationToken
  print('\n-> Testing CancellationToken:');
  final token = CancellationToken();
  report('CancellationToken is not cancelled initially', !token.isCancelled);

  bool listenerFired = false;
  token.addListener(() => listenerFired = true);
  token.cancel();
  report('CancellationToken isCancelled becomes true upon cancel()', token.isCancelled);
  report('CancellationToken listener executed on cancel()', listenerFired);

  bool immediateListenerFired = false;
  token.addListener(() => immediateListenerFired = true);
  report('addListener on already-cancelled token fires immediately', immediateListenerFired);

  bool throwsCancelled = false;
  try {
    token.throwIfCancelled();
  } on UploadCancelledException {
    throwsCancelled = true;
  }
  report('throwIfCancelled() throws UploadCancelledException when cancelled', throwsCancelled);

  // 5. Test 64KB chunked stream generator logic
  print('\n-> Testing 64KB Chunked Stream Generator:');
  const int totalBytes = 160 * 1024; // 160 KB
  final dummyBytes = Uint8List(totalBytes);
  for (int i = 0; i < totalBytes; i++) {
    dummyBytes[i] = i % 256;
  }

  Stream<List<int>> createChunkedStream(
    Uint8List bytes, {
    int chunkSize = 64 * 1024,
    CancellationToken? cancellationToken,
  }) async* {
    for (int i = 0; i < bytes.length; i += chunkSize) {
      cancellationToken?.throwIfCancelled();
      final int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      yield bytes.sublist(i, end);
    }
  }

  final chunks = <List<int>>[];
  await for (final chunk in createChunkedStream(dummyBytes)) {
    chunks.add(chunk);
  }

  report('160 KB payload produces exactly 3 chunks (64KB + 64KB + 32KB)', chunks.length == 3);
  report('Chunk 1 is 64 KB', chunks[0].length == 64 * 1024);
  report('Chunk 2 is 64 KB', chunks[1].length == 64 * 1024);
  report('Chunk 3 is 32 KB', chunks[2].length == 32 * 1024);
  final accumulatedSize = chunks.fold<int>(0, (sum, c) => sum + c.length);
  report('Accumulated chunk bytes match original payload size', accumulatedSize == totalBytes);

  // 6. Test CancellationToken interruption of stream generator
  final cancelStreamToken = CancellationToken();
  final cancelledChunks = <List<int>>[];
  bool streamAborted = false;
  try {
    await for (final chunk in createChunkedStream(dummyBytes, cancellationToken: cancelStreamToken)) {
      cancelledChunks.add(chunk);
      if (cancelledChunks.length == 1) {
        cancelStreamToken.cancel();
      }
    }
  } on UploadCancelledException {
    streamAborted = true;
  }
  report('CancellationToken immediately aborts chunk generator loop', streamAborted && cancelledChunks.length == 1);

  // 7. Static Architectural Audit
  print('\n-> Running Static Architecture & Anti-Regression Audit:');

  final chatRepoContent = File('lib/repositories/chat_repository.dart').readAsStringSync();
  report('chat_repository.dart contains CancellationToken check before start', chatRepoContent.contains('cancellationToken?.throwIfCancelled()'));
  report('chat_repository.dart implements _createChunkedStream', chatRepoContent.contains('_createChunkedStream('));
  report('chat_repository.dart closes HTTP client on cancellation', chatRepoContent.contains('client.close()'));
  report('chat_repository.dart does NOT fall back to WS when cancelled', chatRepoContent.contains('e is UploadCancelledException'));

  final uploadQueueContent = File('lib/providers/upload_queue_provider.dart').readAsStringSync();
  report('upload_queue_provider.dart manages _cancellationTokens', uploadQueueContent.contains('_cancellationTokens'));
  report('upload_queue_provider.dart preserves e2eeFileKey in copyWith', uploadQueueContent.contains('e2eeFileKey: e2eeFileKey ?? this.e2eeFileKey'));
  report('upload_queue_provider.dart allows clearing error via clearError: true', uploadQueueContent.contains('clearError ? null : (error ?? this.error)'));
  report('upload_queue_provider.dart caps network progress at 99%', uploadQueueContent.contains('0.99'));
  report('upload_queue_provider.dart defines uploadQueuePositionProvider', uploadQueueContent.contains('uploadQueuePositionProvider'));
  report('upload_queue_provider.dart clears error on retry', uploadQueueContent.contains('clearError: true'));

  final messageBubbleContent = File('lib/widgets/message_bubble.dart').readAsStringSync();
  report('message_bubble.dart accepts uploadTask & uploadQueuePosition', messageBubbleContent.contains('uploadQueuePosition'));
  report('message_bubble.dart shows clock icon for isSending in time badge', messageBubbleContent.contains('Icons.access_time_rounded'));
  report('message_bubble.dart does NOT wrap rectangular media overlay in ClipOval', !messageBubbleContent.contains('child: ClipOval(\n                  child: _UploadProgressOverlay'));
  report('_UploadProgressOverlay renders bottom linear progress bar', messageBubbleContent.contains('LinearProgressIndicator('));

  // Summary
  print('\n========================================');
  print('Upload Pipeline Verification Summary:');
  print('  PASSED: $passed');
  print('  FAILED: $failed');
  print('========================================\n');

  if (failed > 0) {
    exit(1);
  }
}
