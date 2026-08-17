import 'dart:async';
import 'dart:convert';
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
  final UploadStatus status;
  final String text;
  final int? replyToId;

  /// Per-file AES key for secret chats (bytes are already encrypted).
  final Uint8List? e2eeFileKey;
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
  static const int _maxConcurrentUploads = 3;

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
        .where((UploadTask t) => t.status == UploadStatus.uploading)
        .length;
    final List<String> pending = state.entries
        .where((MapEntry<String, UploadTask> e) =>
            e.value.status == UploadStatus.pending)
        .map((MapEntry<String, UploadTask> e) => e.key)
        .toList();
    for (int i = active;
        i < _maxConcurrentUploads && pending.isNotEmpty;
        i++) {
      _startUpload(pending.removeAt(0));
    }
  }

  Future<void> _startUpload(String localId) async {
    final task = state[localId];
    if (task == null || task.status == UploadStatus.uploading) return;

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
        String? e2eePlaintext;
        if (task.e2eeFileKey != null) {
          e2eePlaintext = jsonEncode(<String, dynamic>{
            'e2ee_file': true,
            'fk': base64Encode(task.e2eeFileKey!),
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
        // The server message replaced the optimistic one, so the task has
        // served its purpose — drop it to keep the map bounded.
        state = {
          ...state,
        }..remove(localId);
        _pump();
      }
    } catch (e) {
      final currentTask = state[localId];
      if (currentTask != null) {
        state = {
          ...state,
          localId: currentTask.copyWith(status: UploadStatus.error, error: e.toString()),
        };
        ref.read(chatMessagesProvider(task.chatId).notifier).markLocalMessageFailed(localId);
        _pump();
      }
    }
  }

  void retry(String localId) {
    final task = state[localId];
    if (task == null || task.status == UploadStatus.uploading) return;
    state = {
      ...state,
      localId: task.copyWith(status: UploadStatus.pending, progress: 0.0, error: null),
    };
    _pump();
  }

  void retryAllErrors() {
    for (final MapEntry<String, UploadTask> entry in state.entries) {
      if (entry.value.status == UploadStatus.error) {
        state = {
          ...state,
          entry.key: entry.value.copyWith(status: UploadStatus.pending, progress: 0.0, error: null),
        };
      }
    }
    _pump();
  }
}

final uploadQueueProvider = NotifierProvider<UploadQueueNotifier, Map<String, UploadTask>>(
  UploadQueueNotifier.new,
);

final uploadTaskProvider = Provider.family<UploadTask?, String>((ref, localId) {
  return ref.watch(uploadQueueProvider)[localId];
});

/// Tasks of one chat that are still pending or transferring.
final activeChatUploadsProvider = Provider.family<List<UploadTask>, int>((ref, chatId) {
  return ref
      .watch(uploadQueueProvider)
      .values
      .where((UploadTask t) => t.chatId == chatId && !_isTerminal(t.status))
      .toList();
});

/// Finished transfers are pruned so the state map does not grow forever.
bool _isTerminal(UploadStatus status) =>
    status == UploadStatus.success || status == UploadStatus.error;
