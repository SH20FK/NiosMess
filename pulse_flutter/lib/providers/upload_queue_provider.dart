import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';

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
    required this.status,
    this.text = '',
    this.replyToId,
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
      bytes: bytes,
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

class UploadQueueNotifier extends Notifier<Map<String, UploadTask>> {
  @override
  Map<String, UploadTask> build() {
    ref.listen(connectivityProvider, (AsyncValue<bool>? prev, AsyncValue<bool> next) {
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
      final uploadId = await ref.read(chatRepositoryProvider).uploadStreamInChunks(
        filePath: task.filePath.isNotEmpty ? task.filePath : null,
        bytes: task.bytes,
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

        await ref.read(chatMessagesProvider(task.chatId).notifier).send(
          task.text,
          replyToId: task.replyToId,
          uploadId: uploadId,
          msgType: task.mediaSubtype == 'voice' 
              ? 'voice' 
              : (task.mediaSubtype == 'circle' ? 'circle' : 'media'),
          localId: localId,
        );
      }
    } catch (e) {
      final currentTask = state[localId];
      if (currentTask != null) {
        state = {
          ...state,
          localId: currentTask.copyWith(status: UploadStatus.error, error: e.toString()),
        };
        ref.read(chatMessagesProvider(task.chatId).notifier).markLocalMessageFailed(localId);
      }
    }
  }

  void retry(String localId) {
    final task = state[localId];
    if (task != null) {
      _startUpload(localId);
    }
  }

  void retryAllErrors() {
    for (final MapEntry<String, UploadTask> entry in state.entries) {
      if (entry.value.status == UploadStatus.error) {
        _startUpload(entry.key);
      }
    }
  }
}

final uploadQueueProvider = NotifierProvider<UploadQueueNotifier, Map<String, UploadTask>>(
  UploadQueueNotifier.new,
);

final uploadTaskProvider = Provider.family<UploadTask?, String>((ref, localId) {
  return ref.watch(uploadQueueProvider)[localId];
});
