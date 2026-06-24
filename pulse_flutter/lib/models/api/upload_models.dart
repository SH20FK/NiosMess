class UploadInitResult {
  const UploadInitResult({required this.uploadId, required this.chunkSize});

  final String uploadId;
  final int chunkSize;

  factory UploadInitResult.fromJson(Map<String, dynamic> json) {
    return UploadInitResult(
      uploadId: json['upload_id'] as String? ?? '',
      chunkSize: json['chunk_size'] as int? ?? 262144,
    );
  }
}

class UploadChunkResult {
  const UploadChunkResult({
    required this.uploadId,
    required this.chunkIndex,
    required this.received,
    required this.total,
    required this.complete,
  });

  final String uploadId;
  final int chunkIndex;
  final int received;
  final int total;
  final bool complete;

  factory UploadChunkResult.fromJson(Map<String, dynamic> json) {
    return UploadChunkResult(
      uploadId: json['upload_id'] as String? ?? '',
      chunkIndex: json['chunk_index'] as int? ?? 0,
      received: json['received'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      complete: json['complete'] as bool? ?? false,
    );
  }
}
