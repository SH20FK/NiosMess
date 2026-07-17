import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';

class UploadTask {
  const UploadTask({
    required this.localId,
    required this.chatId,
    required this.filePath,
    required this.filename,
    required this.mediaSubtype,
    required this.fileSize,
    required this.progress,
    required this.status,
    this.text = '',
    this.replyToId,
    this.error,
  });

  final String localId;
  final int chatId;
  final String filePath;
  final String filename;
  final String mediaSubtype;
  final int fileSize;
  final double progress;
  final UploadStatus status;
  final String text;
  final int? replyToId;
  final String? error;

  UploadTask copyWith({
    double? progress,
    UploadStatus? status,
    String? error,
  }) {
    return UploadTask(
      localId: localId,
      chatId: chatId,
      filePath: filePath,
      filename: filename,
      mediaSubtype: mediaSubtype,
      fileSize: fileSize,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      text: text,
      replyToId: replyToId,
      error: error ?? this.error,
    );
  }
}

enum UploadStatus { pending, uploading, success, error }

class UploadQueueNotifier extends StateNotifier<Map<String, UploadTask>> {
  UploadQueueNotifier(this._ref) : super(const <String, UploadTask>{});

  final Ref _ref;

  void enqueue({
    required String localId,
    required int chatId,
    required String filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    String text = '',
    int? replyToId,
  }) {
    final task = UploadTask(
      localId: localId,
      chatId: chatId,
      filePath: filePath,
      filename: filename,
      mediaSubtype: mediaSubtype,
      fileSize: fileSize,
      progress: 0.0,
      status: UploadStatus.pending,
      text: text,
      replyToId: replyToId,
    );

    state = {...state, localId: task};
    _startUpload(localId);
  }

  Future<void> _startUpload(String localId) async {
    final task = state[localId];
    if (task == null) return;

    state = {
      ...state,
      localId: task.copyWith(status: UploadStatus.uploading, progress: 0.0),
    };

    try {
      final uploadId = await _ref.read(chatRepositoryProvider).uploadStreamInChunks(
        filePath: task.filePath,
        filename: task.filename,
        mediaSubtype: task.mediaSubtype,
        fileSize: task.fileSize,
        onProgress: (sent, total) {
          final currentTask = state[localId];
          if (currentTask != null && total > 0) {
            state = {
              ...state,
              localId: currentTask.copyWith(progress: sent / total),
            };
          }
        },
      );

      final currentTask = state[localId];
      if (currentTask != null) {
        state = {
          ...state,
          localId: currentTask.copyWith(status: UploadStatus.success, progress: 1.0),
        };

        // Send actual message via WS
        await _ref.read(chatMessagesProvider(task.chatId).notifier).send(
          task.text,
          replyToId: task.replyToId,
          uploadId: uploadId,
          msgType: task.mediaSubtype == 'voice' 
              ? 'voice' 
              : (task.mediaSubtype == 'circle' ? 'circle' : 'media'),
          localId: localId, // Pass localId so we can clean up if we want
        );
      }
    } catch (e) {
      final currentTask = state[localId];
      if (currentTask != null) {
        state = {
          ...state,
          localId: currentTask.copyWith(status: UploadStatus.error, error: e.toString()),
        };
        // Mark optimistic message as failed
        _ref.read(chatMessagesProvider(task.chatId).notifier).markLocalMessageFailed(localId);
      }
    }
  }

  void retry(String localId) {
    final task = state[localId];
    if (task != null) {
      _startUpload(localId);
    }
  }
}

final uploadQueueProvider = StateNotifierProvider<UploadQueueNotifier, Map<String, UploadTask>>((ref) {
  return UploadQueueNotifier(ref);
});

final uploadTaskProvider = Provider.family<UploadTask?, String>((ref, localId) {
  return ref.watch(uploadQueueProvider)[localId];
});
