import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/models/api/upload_models.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

export 'package:pulse_flutter/models/api/upload_models.dart'
    show UploadStage, UploadMetrics, UploadSpeedTracker;

class UploadTask {
  const UploadTask({
    required this.localId,
    required this.chatId,
    required this.filePath,
    this.bytes,
    required this.filename,
    required this.mediaSubtype,
    required this.fileSize,
    required this.progress,
    this.bytesSent = 0,
    required this.status,
    this.stage = UploadStage.queued,
    this.metrics = const UploadMetrics(),
    this.text = '',
    this.replyToId,
    this.e2eeFileKey,
    this.error,
  });

  final String localId;
  final int chatId;
  final String filePath;
  final Uint8List? bytes;
  final String filename;
  final String mediaSubtype;
  final int fileSize;
  final double progress;
  final int bytesSent;
  final UploadStatus status;
  final UploadStage stage;
  final UploadMetrics metrics;
  final String text;
  final int? replyToId;

  /// Per-file AES key for secret chats (bytes are already encrypted).
  final Uint8List? e2eeFileKey;
  final String? error;

  UploadTask copyWith({
    double? progress,
    int? bytesSent,
    UploadStatus? status,
    UploadStage? stage,
    UploadMetrics? metrics,
    String? error,
    bool clearError = false,
    Uint8List? e2eeFileKey,
  }) {
    return UploadTask(
      localId: localId,
      chatId: chatId,
      filePath: filePath,
      bytes: bytes,
      filename: filename,
      mediaSubtype: mediaSubtype,
      fileSize: fileSize,
      progress: progress ?? this.progress,
      bytesSent: bytesSent ?? this.bytesSent,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      metrics: metrics ?? this.metrics,
      text: text,
      replyToId: replyToId,
      e2eeFileKey: e2eeFileKey ?? this.e2eeFileKey,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

enum UploadStatus { pending, uploading, success, error }

class UploadQueueNotifier extends Notifier<Map<String, UploadTask>> {
  static const int _maxConcurrentUploads = 3;

  final Map<String, CancellationToken> _cancellationTokens =
      <String, CancellationToken>{};
  final Map<String, UploadSpeedTracker> _speedTrackers =
      <String, UploadSpeedTracker>{};
  final Map<String, DateTime> _lastUiUpdates = <String, DateTime>{};
  final Map<String, double> _lastReportedProgress = <String, double>{};
  static const Duration _uiProgressInterval = Duration(milliseconds: 80);

  @override
  Map<String, UploadTask> build() {
    ref.listen(connectivityProvider, (
      AsyncValue<bool>? prev,
      AsyncValue<bool> next,
    ) {
      final prevConnected = prev?.asData?.value ?? false;
      final nextConnected = next.asData?.value ?? false;
      if (!prevConnected && nextConnected) {
        retryAllErrors();
      }
    });
    return const <String, UploadTask>{};
  }

  void enqueue({
    required String localId,
    required int chatId,
    required String filePath,
    Uint8List? bytes,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    String text = '',
    int? replyToId,
    Uint8List? e2eeFileKey,
  }) {
    final task = UploadTask(
      localId: localId,
      chatId: chatId,
      filePath: filePath,
      bytes: bytes,
      filename: filename,
      mediaSubtype: mediaSubtype,
      fileSize: fileSize,
      progress: 0.0,
      status: UploadStatus.pending,
      stage: UploadStage.queued,
      metrics: UploadMetrics(totalBytes: fileSize),
      text: text,
      replyToId: replyToId,
      e2eeFileKey: e2eeFileKey,
    );

    state = {...state, localId: task};
    _pump();
  }

  /// Starts pending tasks while staying under the concurrency limit.
  void _pump() {
    final int active = state.values
        .where(
          (UploadTask t) =>
              t.status == UploadStatus.uploading ||
              t.stage == UploadStage.uploading ||
              t.stage == UploadStage.processing ||
              t.stage == UploadStage.sendingMessage,
        )
        .length;
    final List<String> pending = state.entries
        .where(
          (MapEntry<String, UploadTask> e) =>
              e.value.status == UploadStatus.pending ||
              e.value.stage == UploadStage.queued,
        )
        .map((MapEntry<String, UploadTask> e) => e.key)
        .toList();
    for (int i = active; i < _maxConcurrentUploads && pending.isNotEmpty; i++) {
      _startUpload(pending.removeAt(0));
    }
  }

  Future<void> _startUpload(String localId) async {
    final task = state[localId];
    if (task == null ||
        task.status == UploadStatus.uploading ||
        task.stage == UploadStage.uploading) {
      return;
    }

    final CancellationToken cancelToken = CancellationToken();
    _cancellationTokens[localId] = cancelToken;
    final UploadSpeedTracker speedTracker = UploadSpeedTracker();
    _speedTrackers[localId] = speedTracker;

    state = {
      ...state,
      localId: task.copyWith(
        status: UploadStatus.uploading,
        stage: UploadStage.uploading,
        progress: 0.0,
        bytesSent: 0,
        clearError: true,
      ),
    };

    try {
      final uploadId = await ref
          .read(chatRepositoryProvider)
          .uploadStreamInChunks(
            filePath: task.filePath.isNotEmpty ? task.filePath : null,
            bytes: (task.bytes != null && task.bytes!.isNotEmpty)
                ? task.bytes
                : null,
            filename: task.filename,
            mediaSubtype: task.mediaSubtype,
            fileSize: task.fileSize,
            cancellationToken: cancelToken,
            localId: localId,
            onProgress: (sent, total) {
              final currentTask = state[localId];
              if (currentTask != null && total > 0) {
                final metrics = speedTracker.updateProgress(sent, total);
                // Cap network progress at 99% while data is in flight over socket
                final double rawProgress = (sent / total).clamp(0.0, 1.0);
                final double cappedProgress = (rawProgress * 0.99).clamp(
                  0.0,
                  0.99,
                );

                final DateTime now = DateTime.now();
                final DateTime? lastUpdate = _lastUiUpdates[localId];
                final double lastProgress = _lastReportedProgress[localId] ?? 0.0;
                final double progressDelta = (cappedProgress - lastProgress).abs();

                final bool shouldPublish = lastUpdate == null ||
                    now.difference(lastUpdate) >= _uiProgressInterval ||
                    progressDelta >= 0.01 ||
                    cappedProgress >= 0.99;

                if (shouldPublish) {
                  _lastUiUpdates[localId] = now;
                  _lastReportedProgress[localId] = cappedProgress;
                  state = {
                    ...state,
                    localId: currentTask.copyWith(
                      progress: cappedProgress,
                      bytesSent: sent,
                      stage: UploadStage.uploading,
                      metrics: metrics,
                    ),
                  };
                }
              }
            },
            onStageChanged: (UploadStage stage) {
              _lastUiUpdates[localId] = DateTime.now();
              final currentTask = state[localId];
              if (currentTask != null) {
                state = {
                  ...state,
                  localId: currentTask.copyWith(
                    stage: stage,
                    progress: stage == UploadStage.processing
                        ? 0.99
                        : currentTask.progress,
                  ),
                };
              }
            },
          );

      if (cancelToken.isCancelled) {
        _cancellationTokens.remove(localId);
        _speedTrackers.remove(localId);
        _lastUiUpdates.remove(localId);
        _lastReportedProgress.remove(localId);
        return;
      }

      final currentTask = state[localId];
      if (currentTask != null) {
        state = {
          ...state,
          localId: currentTask.copyWith(
            stage: UploadStage.sendingMessage,
            progress: 0.99,
          ),
        };

        String? e2eePlaintext;
        if (task.e2eeFileKey != null) {
          final String keyB64 = base64Encode(task.e2eeFileKey!);
          e2eePlaintext = jsonEncode(<String, dynamic>{
            'type': 'nios_file_key',
            'keyB64': keyB64,
            'e2ee_file': true,
            'fk': keyB64,
            'name': task.filename,
            'size': task.fileSize,
          });
        }
        await ref.read(chatMessagesProvider(task.chatId).notifier).send(
          task.text,
          replyToId: task.replyToId,
          uploadId: uploadId,
          msgType: task.mediaSubtype == 'voice'
              ? 'voice'
              : (task.mediaSubtype == 'circle' ? 'circle' : 'media'),
          localId: localId,
          e2eePlaintext: e2eePlaintext,
          e2eeFileKey: task.e2eeFileKey != null
              ? base64Encode(task.e2eeFileKey!)
              : null,
        );

        _cancellationTokens.remove(localId);
        _speedTrackers.remove(localId);
        _lastUiUpdates.remove(localId);
        _lastReportedProgress.remove(localId);

        unawaited(
          ref.read(appSoundProvider).playEvent(SoundEvent.uploadComplete),
        );
        state = {...state}..remove(localId);
        _pump();
      }
    } catch (e, st) {
      _cancellationTokens.remove(localId);
      _speedTrackers.remove(localId);
      _lastUiUpdates.remove(localId);
      _lastReportedProgress.remove(localId);

      if (cancelToken.isCancelled || e is UploadCancelledException) {
        debugPrint('[UploadQueue] Upload cancelled for $localId');
        state = {...state}..remove(localId);
        _pump();
        return;
      }

      debugPrint('[UploadQueue] Upload failed for $localId: $e\n$st');
      unawaited(ref.read(appSoundProvider).playEvent(SoundEvent.uploadError));
      final currentTask = state[localId];
      if (currentTask != null) {
        state = {
          ...state,
          localId: currentTask.copyWith(
            status: UploadStatus.error,
            stage: UploadStage.failed,
            error: e.toString(),
          ),
        };
        ref
            .read(chatMessagesProvider(task.chatId).notifier)
            .markLocalMessageFailed(localId);
        _pump();
      }
    }
  }

  void retry(String localId) {
    final task = state[localId];
    if (task == null ||
        task.status == UploadStatus.uploading ||
        task.stage == UploadStage.uploading) {
      return;
    }
    state = {
      ...state,
      localId: task.copyWith(
        status: UploadStatus.pending,
        stage: UploadStage.queued,
        progress: 0.0,
        bytesSent: 0,
        clearError: true,
      ),
    };
    final int tempId = int.tryParse(localId) ?? 0;
    if (tempId != 0) {
      ref
          .read(chatMessagesProvider(task.chatId).notifier)
          .markLocalMessageSending(tempId);
    }
    _pump();
  }

  void cancel(String localId) {
    final task = state[localId];
    if (task == null) return;
    _cancellationTokens[localId]?.cancel();
    _cancellationTokens.remove(localId);
    _speedTrackers.remove(localId);
    _lastUiUpdates.remove(localId);
    _lastReportedProgress.remove(localId);
    state = {...state}..remove(localId);
    final int tempId = int.tryParse(localId) ?? 0;
    ref
        .read(chatMessagesProvider(task.chatId).notifier)
        .removeOptimisticMessage(tempId);
    _pump();
  }

  void retryAllErrors() {
    for (final MapEntry<String, UploadTask> entry in state.entries) {
      if (entry.value.status == UploadStatus.error ||
          entry.value.stage == UploadStage.failed) {
        state = {
          ...state,
          entry.key: entry.value.copyWith(
            status: UploadStatus.pending,
            stage: UploadStage.queued,
            progress: 0.0,
            bytesSent: 0,
            clearError: true,
          ),
        };
        final int tempId = int.tryParse(entry.key) ?? 0;
        if (tempId != 0) {
          ref
              .read(chatMessagesProvider(entry.value.chatId).notifier)
              .markLocalMessageSending(tempId);
        }
      }
    }
    _pump();
  }
}

final uploadQueueProvider =
    NotifierProvider<UploadQueueNotifier, Map<String, UploadTask>>(
      UploadQueueNotifier.new,
    );

final uploadTaskProvider = Provider.family<UploadTask?, String>((ref, localId) {
  return ref.watch(uploadQueueProvider.select((queue) => queue[localId]));
});

/// Topology key representing currently pending/queued uploads in FIFO order.
/// String value changes ONLY when tasks enter or exit pending/queued state.
/// Riverpod will NOT notify subscribers on intermediate progress updates!
final uploadQueueTopologyKeyProvider = Provider<String>((ref) {
  return ref.watch(uploadQueueProvider.select((queue) {
    final StringBuffer buffer = StringBuffer();
    for (final MapEntry<String, UploadTask> entry in queue.entries) {
      if (entry.value.status == UploadStatus.pending ||
          entry.value.stage == UploadStage.queued) {
        buffer.write(entry.key);
        buffer.write(',');
      }
    }
    return buffer.toString();
  }));
});

/// 1-based position in queue for pending uploads. Returns 0 if active or not in queue.
final uploadQueuePositionProvider = Provider.family<int, String>((
  ref,
  localId,
) {
  final String topologyKey = ref.watch(uploadQueueTopologyKeyProvider);
  if (topologyKey.isEmpty) return 0;
  final List<String> keys = topologyKey.split(',');
  final int index = keys.indexOf(localId);
  return index >= 0 ? index + 1 : 0;
});

/// Whether the chat has any pending or transferring upload tasks.
/// Returns a primitive bool so consumers (like Composer) don't rebuild on progress updates!
final hasActiveChatUploadsProvider = Provider.family<bool, int>((ref, chatId) {
  return ref.watch(uploadQueueProvider.select((queue) {
    return queue.values.any((UploadTask t) => t.chatId == chatId && !_isTerminal(t));
  }));
});

/// Tasks of one chat that are still pending or transferring.
final activeChatUploadsProvider = Provider.family<List<UploadTask>, int>((
  ref,
  chatId,
) {
  return ref
      .watch(uploadQueueProvider)
      .values
      .where((UploadTask t) => t.chatId == chatId && !_isTerminal(t))
      .toList();
});

/// Finished transfers are pruned so the state map does not grow forever.
bool _isTerminal(UploadTask task) =>
    task.status == UploadStatus.success ||
    task.status == UploadStatus.error ||
    task.stage == UploadStage.completed ||
    task.stage == UploadStage.failed ||
    task.stage == UploadStage.cancelled;
