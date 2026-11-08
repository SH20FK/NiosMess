import 'models.dart';

/// Checkpoint metadata created when old acknowledged operations are compacted.
final class DurableCheckpoint {
  final String checkpointId;
  final int watermarkSequence;
  final String stateHash;
  final int compactedCount;
  final int createdAtMilliseconds;

  const DurableCheckpoint({
    required this.checkpointId,
    required this.watermarkSequence,
    required this.stateHash,
    required this.compactedCount,
    required this.createdAtMilliseconds,
  });

  Map<String, dynamic> toJson() => {
    'checkpointId': checkpointId,
    'watermarkSequence': watermarkSequence,
    'stateHash': stateHash,
    'compactedCount': compactedCount,
    'createdAt': createdAtMilliseconds,
  };
}

/// Web / non-FFI in-memory stub for SQLite WAL store.
final class SqliteWalDurableStore {
  final String path;

  SqliteWalDurableStore._(this.path);

  static Future<SqliteWalDurableStore> open({
    required String directory,
    required String name,
  }) async {
    return SqliteWalDurableStore._('$directory/$name.db');
  }

  void saveOperation({
    required String operationId,
    required int sequence,
    required String peerId,
    required String sessionId,
    required String state,
    required Map<String, dynamic> payload,
    EncryptedEnvelope? envelope,
  }) {}

  void markAcknowledged(String operationId, EncryptedEnvelope ack) {}

  bool isOperationRecorded(String operationId) => false;

  Map<String, dynamic>? getOperation(String operationId) => null;

  int get operationCount => 0;

  DurableCheckpoint compact({
    required int watermarkSequence,
    int retainDedupWindow = 5000,
  }) {
    return DurableCheckpoint(
      checkpointId: 'web-stub',
      watermarkSequence: watermarkSequence,
      stateHash: 'web-hash',
      compactedCount: 0,
      createdAtMilliseconds: DateTime.now().millisecondsSinceEpoch,
    );
  }

  DurableCheckpoint? getLastCheckpoint() => null;

  Future<void> close() async {}
}
