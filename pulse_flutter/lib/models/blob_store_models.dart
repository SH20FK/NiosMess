import 'package:flutter/foundation.dart';

/// Request payload sent to server to check if an identical file blob already exists.
@immutable
class BlobCheckRequest {
  const BlobCheckRequest({
    required this.contentHash,
    required this.size,
    required this.mimeType,
    required this.chunkSize,
    required this.chunkCount,
    this.encryptionVersion = 0,
    this.token,
  });

  final String contentHash;
  final int size;
  final String mimeType;
  final int chunkSize;
  final int chunkCount;
  final int encryptionVersion;
  final String? token;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'content_hash': contentHash,
        'size': size,
        'mime_type': mimeType,
        'chunk_size': chunkSize,
        'chunk_count': chunkCount,
        'encryption_version': encryptionVersion,
        if (token != null) 'token': token,
      };
}

/// Server response for deduplication check and missing chunks query.
@immutable
class BlobCheckResult {
  const BlobCheckResult({
    required this.alreadyExists,
    required this.blobId,
    required this.status,
    required this.missingChunks,
  });

  final bool alreadyExists;
  final String blobId;
  final String status;
  final List<int> missingChunks;

  factory BlobCheckResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> missingRaw =
        (json['missing_chunks'] as List<dynamic>?) ?? <dynamic>[];
    final List<int> missing = missingRaw.map((dynamic e) => (e as num).toInt()).toList();

    return BlobCheckResult(
      alreadyExists: (json['already_exists'] as bool?) ?? false,
      blobId: (json['blob_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      missingChunks: missing,
    );
  }
}

/// Server response upon committing all chunks into the final assembled CAS blob.
@immutable
class BlobCommitResult {
  const BlobCommitResult({
    required this.blobId,
    required this.status,
    required this.size,
    required this.contentHash,
  });

  final String blobId;
  final String status;
  final int size;
  final String contentHash;

  factory BlobCommitResult.fromJson(Map<String, dynamic> json) {
    return BlobCommitResult(
      blobId: (json['blob_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'ready',
      size: (json['size'] as num?)?.toInt() ?? 0,
      contentHash: (json['content_hash'] as String?) ?? '',
    );
  }
}

/// Result returned from attaching a blob to a chat message or post.
@immutable
class BlobAttachResult {
  const BlobAttachResult({
    required this.refId,
    required this.blobId,
    required this.filename,
    required this.size,
    required this.mimeType,
  });

  final String refId;
  final String blobId;
  final String filename;
  final int size;
  final String mimeType;

  factory BlobAttachResult.fromJson(Map<String, dynamic> json) {
    return BlobAttachResult(
      refId: (json['ref_id'] as String?) ?? '',
      blobId: (json['blob_id'] as String?) ?? '',
      filename: (json['filename'] as String?) ?? 'file.bin',
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimeType: (json['mime_type'] as String?) ?? 'application/octet-stream',
    );
  }
}
