import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/models/blob_store_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

final Provider<BlobStoreService> blobStoreServiceProvider =
    Provider<BlobStoreService>((Ref ref) {
  return BlobStoreService(ref);
});

class BlobStoreService {
  BlobStoreService(this._ref, {http.Client? client})
      : _client = client ?? http.Client();

  final Ref _ref;
  final http.Client _client;

  String? _getToken() {
    return _ref.read(authProvider).session?.accessToken;
  }

  /// Probes server whether this file blob already exists under caller's account.
  Future<BlobCheckResult> checkDedup(BlobCheckRequest request) async {
    final String? token = request.token ?? _getToken();
    final Uri uri = Uri.parse('${ApiConstants.origin}/api/blobs/check');

    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Dedup check failed: ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return BlobCheckResult.fromJson(data);
  }

  /// Streams a single chunk of a blob to the server.
  Future<void> uploadChunk({
    required String blobId,
    required int chunkIndex,
    required Uint8List bytes,
    String? chunkHash,
    void Function(int sent, int total)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final String? token = _getToken();
    final Uri uri =
        Uri.parse('${ApiConstants.origin}/api/blobs/$blobId/chunks/$chunkIndex');

    final http.Request request = http.Request('PUT', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (chunkHash != null) {
      request.headers['X-Chunk-Hash'] = chunkHash;
    }
    request.headers['Content-Type'] = 'application/octet-stream';
    request.bodyBytes = bytes;

    if (onProgress != null) {
      onProgress(bytes.length, bytes.length);
    }

    final http.StreamedResponse response = await _client.send(request);
    cancellationToken?.throwIfCancelled();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String body = await response.stream.bytesToString();
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Chunk upload $chunkIndex failed: $body',
      );
    }
  }

  /// Signals server to assemble chunks, verify integrity, and finalize blob.
  Future<BlobCommitResult> commitBlob({
    required String blobId,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final String? token = _getToken();
    final Uri uri =
        Uri.parse('${ApiConstants.origin}/api/blobs/$blobId/commit');

    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Blob commit failed: ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return BlobCommitResult.fromJson(data);
  }

  /// Links a ready blob to a message or post via AttachmentRef.
  Future<BlobAttachResult> attachBlob({
    required String blobId,
    required String filename,
    int? messageId,
    int? postId,
    String? caption,
  }) async {
    final String? token = _getToken();
    final Uri uri = Uri.parse('${ApiConstants.origin}/api/blobs/attach');

    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'blob_id': blobId,
        'filename': filename,
        'message_id': ?messageId,
        'post_id': ?postId,
        'caption': ?caption,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Blob attach failed: ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return BlobAttachResult.fromJson(data);
  }

  /// Utility to slice a specific chunk's bytes from file or memory.
  static Future<Uint8List> sliceChunkBytes({
    String? filePath,
    Uint8List? bytes,
    required int chunkIndex,
    required int chunkSize,
    required int totalSize,
  }) async {
    final int start = chunkIndex * chunkSize;
    final int end = (start + chunkSize) > totalSize ? totalSize : (start + chunkSize);
    final int count = end - start;

    if (count <= 0) return Uint8List(0);

    if (filePath != null && filePath.isNotEmpty) {
      final File file = File(filePath);
      final RandomAccessFile raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(start);
        return await raf.read(count);
      } finally {
        await raf.close();
      }
    } else if (bytes != null) {
      return Uint8List.sublistView(bytes, start, end);
    }

    return Uint8List(0);
  }
}
