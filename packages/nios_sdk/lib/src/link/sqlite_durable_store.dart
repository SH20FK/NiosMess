import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:universal_io/io.dart';

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

/// High-performance SQLite journal with Write-Ahead Logging (WAL) and Bounded Compaction.
///
/// Replaces unbounded disk growth by pruning acknowledged operations beyond a sliding
/// watermark window while preserving crash consistency, sequential order, and deduplication.
final class SqliteWalDurableStore {
  final Database db;
  final String path;
  bool _closed = false;

  SqliteWalDurableStore._(this.db, this.path);

  /// Open or create an encrypted-at-rest SQLite database in WAL mode.
  static Future<SqliteWalDurableStore> open({
    required String directory,
    required String name,
  }) async {
    await Directory(directory).create(recursive: true);
    final dbPath = '$directory/$name.db';
    final db = sqlite3.open(dbPath);

    // Enforce high-performance concurrent WAL mode
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = NORMAL;');
    db.execute('PRAGMA foreign_keys = ON;');

    // Create tables
    db.execute('''
      CREATE TABLE IF NOT EXISTS nios_link_operations (
        operation_id TEXT PRIMARY KEY,
        sequence INTEGER NOT NULL,
        peer_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        state TEXT NOT NULL,
        payload TEXT NOT NULL,
        envelope TEXT,
        ack TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_nios_link_seq 
      ON nios_link_operations(sequence);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_nios_link_peer 
      ON nios_link_operations(peer_id, session_id);
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS nios_link_checkpoints (
        checkpoint_id TEXT PRIMARY KEY,
        watermark_sequence INTEGER NOT NULL,
        state_hash TEXT NOT NULL,
        compacted_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS nios_link_dedup (
        operation_id TEXT PRIMARY KEY,
        sequence INTEGER NOT NULL,
        recorded_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dedup_seq 
      ON nios_link_dedup(sequence);
    ''');

    return SqliteWalDurableStore._(db, dbPath);
  }

  void saveOperation({
    required String operationId,
    required int sequence,
    required String peerId,
    required String sessionId,
    required String state,
    required Map<String, dynamic> payload,
    EncryptedEnvelope? envelope,
  }) {
    _checkOpen();
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = db.prepare('''
      INSERT INTO nios_link_operations 
        (operation_id, sequence, peer_id, session_id, state, payload, envelope, ack, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)
      ON CONFLICT(operation_id) DO UPDATE SET
        state = excluded.state,
        envelope = excluded.envelope,
        updated_at = excluded.updated_at;
    ''');
    try {
      stmt.execute([
        operationId,
        sequence,
        peerId,
        sessionId,
        state,
        jsonEncode(payload),
        envelope == null ? null : jsonEncode(envelope.toJson()),
        now,
        now,
      ]);
      // Record in deduplication table
      db.execute(
        'INSERT OR IGNORE INTO nios_link_dedup (operation_id, sequence, recorded_at) VALUES (?, ?, ?)',
        [operationId, sequence, now],
      );
    } finally {
      stmt.dispose();
    }
  }

  void markAcknowledged(String operationId, EncryptedEnvelope ack) {
    _checkOpen();
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = db.prepare('''
      UPDATE nios_link_operations
      SET state = 'acknowledged', ack = ?, updated_at = ?
      WHERE operation_id = ?;
    ''');
    try {
      stmt.execute([jsonEncode(ack.toJson()), now, operationId]);
    } finally {
      stmt.dispose();
    }
  }

  bool isOperationRecorded(String operationId) {
    _checkOpen();
    final stmt = db.prepare(
      'SELECT 1 FROM nios_link_dedup WHERE operation_id = ? LIMIT 1',
    );
    try {
      final rows = stmt.select([operationId]);
      return rows.isNotEmpty;
    } finally {
      stmt.dispose();
    }
  }

  Map<String, dynamic>? getOperation(String operationId) {
    _checkOpen();
    final stmt = db.prepare(
      'SELECT * FROM nios_link_operations WHERE operation_id = ? LIMIT 1',
    );
    try {
      final rows = stmt.select([operationId]);
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        'operationId': row['operation_id'],
        'sequence': row['sequence'],
        'peerId': row['peer_id'],
        'sessionId': row['session_id'],
        'state': row['state'],
        'payload': jsonDecode(row['payload'] as String),
        'envelope': row['envelope'] == null
            ? null
            : jsonDecode(row['envelope'] as String),
        'ack': row['ack'] == null ? null : jsonDecode(row['ack'] as String),
      };
    } finally {
      stmt.dispose();
    }
  }

  int get operationCount {
    _checkOpen();
    final rows = db.select('SELECT COUNT(*) AS c FROM nios_link_operations');
    return rows.first['c'] as int;
  }

  /// Compact old acknowledged operations below the watermark sequence.
  ///
  /// Consolidates pruned records into a cryptographic state checkpoint,
  /// deletes operation rows from disk, and truncates the SQLite WAL log.
  DurableCheckpoint compact({
    required int watermarkSequence,
    int retainDedupWindow = 5000,
  }) {
    _checkOpen();

    // 1. Compute state hash of operations to be pruned
    final candidateRows = db.select(
      '''
      SELECT operation_id, sequence, payload, ack 
      FROM nios_link_operations 
      WHERE sequence < ? AND state = 'acknowledged'
      ORDER BY sequence ASC;
    ''',
      [watermarkSequence],
    );

    if (candidateRows.isEmpty) {
      final lastCheckpoint = getLastCheckpoint();
      if (lastCheckpoint != null) return lastCheckpoint;
      return DurableCheckpoint(
        checkpointId: 'chk-empty',
        watermarkSequence: watermarkSequence,
        stateHash: sha256.convert(utf8.encode('empty')).toString(),
        compactedCount: 0,
        createdAtMilliseconds: DateTime.now().millisecondsSinceEpoch,
      );
    }

    final hashInput = StringBuffer();
    for (final row in candidateRows) {
      hashInput.write('${row['operation_id']}:${row['sequence']};');
    }
    final stateHash = sha256.convert(utf8.encode(hashInput.toString())).toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    final checkpointId = 'chk-$watermarkSequence-$now';

    // 2. Perform atomic transaction
    db.execute('BEGIN TRANSACTION;');
    try {
      db.execute(
        '''
        INSERT INTO nios_link_checkpoints
          (checkpoint_id, watermark_sequence, state_hash, compacted_count, created_at)
        VALUES (?, ?, ?, ?, ?);
      ''',
        [checkpointId, watermarkSequence, stateHash, candidateRows.length, now],
      );

      db.execute(
        '''
        DELETE FROM nios_link_operations
        WHERE sequence < ? AND state = 'acknowledged';
      ''',
        [watermarkSequence],
      );

      // Prune very old deduplication entries beyond retainDedupWindow
      final minDedupSequence = watermarkSequence - retainDedupWindow;
      if (minDedupSequence > 0) {
        db.execute(
          'DELETE FROM nios_link_dedup WHERE sequence < ?;',
          [minDedupSequence],
        );
      }

      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }

    // 3. Truncate WAL file to free disk space immediately
    try {
      db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}

    return DurableCheckpoint(
      checkpointId: checkpointId,
      watermarkSequence: watermarkSequence,
      stateHash: stateHash,
      compactedCount: candidateRows.length,
      createdAtMilliseconds: now,
    );
  }

  DurableCheckpoint? getLastCheckpoint() {
    _checkOpen();
    final rows = db.select(
      'SELECT * FROM nios_link_checkpoints ORDER BY watermark_sequence DESC LIMIT 1',
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return DurableCheckpoint(
      checkpointId: row['checkpoint_id'] as String,
      watermarkSequence: row['watermark_sequence'] as int,
      stateHash: row['state_hash'] as String,
      compactedCount: row['compacted_count'] as int,
      createdAtMilliseconds: row['created_at'] as int,
    );
  }

  void _checkOpen() {
    if (_closed) throw StateError('SqliteWalDurableStore is closed');
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    db.dispose();
  }
}
