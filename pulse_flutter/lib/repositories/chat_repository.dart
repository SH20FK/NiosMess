import 'dart:async';
import 'dart:convert';
import 'package:universal_io/io.dart';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/invite_models.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/upload_models.dart';
import 'package:pulse_flutter/services/public_media_upload_service.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class ChatRepository {
  const ChatRepository(this._ref);

  final Ref _ref;

  String? normalizeJoinSlug(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final Uri? uri = Uri.tryParse(trimmed);
      if (uri == null) {
        return null;
      }
      final List<String> segments = uri.pathSegments
          .where((String part) => part.trim().isNotEmpty)
          .toList(growable: false);
      if (segments.isEmpty) {
        return null;
      }
      final int joinIndex = segments.indexOf('join');
      if (joinIndex != -1 && joinIndex + 1 < segments.length) {
        return Uri.decodeComponent(segments[joinIndex + 1]);
      }
      final int uIndex = segments.indexOf('u');
      if (uIndex != -1 && uIndex + 1 < segments.length) {
        return Uri.decodeComponent(segments[uIndex + 1]);
      }
      final int cIndex = segments.indexOf('c');
      if (cIndex != -1 && cIndex + 1 < segments.length) {
        return Uri.decodeComponent(segments[cIndex + 1]);
      }
      return Uri.decodeComponent(segments.last);
    }

    final int joinPart = trimmed.indexOf('/join/');
    if (joinPart >= 0) {
      return trimmed.substring(joinPart + '/join/'.length).trim();
    }
    final int uPart = trimmed.indexOf('/u/');
    if (uPart >= 0) {
      return trimmed.substring(uPart + '/u/'.length).trim();
    }
    final int cPart = trimmed.indexOf('/c/');
    if (cPart >= 0) {
      return trimmed.substring(cPart + '/c/'.length).trim();
    }

    return trimmed.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  Future<List<ApiChatSummary>> listChats({String? publicKey}) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'include_topics': true,
    };
    if (publicKey != null && publicKey.isNotEmpty) {
      payload['public_key'] = publicKey;
    }
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('list_chats', payload: payload);

    if (response is! List) {
      return const <ApiChatSummary>[];
    }

    final List<ApiChatSummary> chats = response
        .whereType<Map>()
        .map(
          (Map item) => ApiChatSummary.fromJson(
            item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);

    chats.sort((ApiChatSummary a, ApiChatSummary b) {
      return b.lastActivity.compareTo(a.lastActivity);
    });
    return chats;
  }

  Future<ApiChatSummary?> getChat(int chatId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('get_chat', payload: <String, dynamic>{'chat_id': chatId});

    if (response is! Map) {
      return null;
    }
    return ApiChatSummary.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<DirectChatOpenResult?> openDirectChat({
    String? username,
    int? userId,
    bool isSecret = false,
    String? publicKey,
    String? targetPublicKey,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'is_secret': isSecret,
    };
    if (userId != null && userId > 0) {
      payload['user_id'] = userId;
    } else if (username != null && username.trim().isNotEmpty) {
      payload['username'] = username.trim().replaceFirst(RegExp(r'^@'), '');
    } else {
      return null;
    }
    if (publicKey != null && publicKey.isNotEmpty) {
      payload['public_key'] = publicKey;
    }
    if (targetPublicKey != null && targetPublicKey.isNotEmpty) {
      payload['target_public_key'] = targetPublicKey;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('open_direct', payload: payload);

    if (response is! Map) {
      return null;
    }

    return DirectChatOpenResult.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<DirectChatOpenResult?> openDirectChatByUsername(
    String username, {
    bool isSecret = false,
    String? publicKey,
  }) {
    return openDirectChat(
      username: username,
      isSecret: isSecret,
      publicKey: publicKey,
    );
  }

  Future<ChatCreateResult?> createChat({
    required String name,
    required String chatType,
    String? description,
    String? username,
    bool? commentsEnabled,
    bool isPrivate = false,
    List<int>? memberUserIds,
  }) async {
    final String normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return null;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'name': normalizedName,
      'chat_type': chatType,
      'is_private': isPrivate,
    };

    if (description != null && description.trim().isNotEmpty) {
      payload['description'] = description.trim();
    }
    if (username != null && username.trim().isNotEmpty) {
      payload['username'] = username.trim();
    }
    if (commentsEnabled != null) {
      payload['comments_enabled'] = commentsEnabled;
    }
    if (memberUserIds != null && memberUserIds.isNotEmpty) {
      payload['member_user_ids'] = memberUserIds;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('create_group', payload: payload);

    if (response is! Map) {
      return null;
    }

    ChatCreateResult result = ChatCreateResult.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );

    // Fallback: If server created chat but did not process member_user_ids atomically,
    // invite them via inviteUsers.
    if (memberUserIds != null &&
        memberUserIds.isNotEmpty &&
        result.chatId > 0 &&
        result.invitedUserIds.isEmpty &&
        result.failedUserIds.isEmpty) {
      final batch = await inviteUsers(result.chatId, memberUserIds);
      result = ChatCreateResult(
        chatId: result.chatId,
        name: result.name,
        username: result.username,
        inviteLink: result.inviteLink,
        shareLink: result.shareLink,
        commentsChatId: result.commentsChatId,
        inviteToken: result.inviteToken,
        invitedUserIds: batch.invitedUserIds,
        failedUserIds: batch.failedUserIds,
      );
    }

    return result;
  }

  Future<ApiInvitePreview?> getInvitePreview(String slugOrUrl) async {
    final String? slug = normalizeJoinSlug(slugOrUrl);
    if (slug == null || slug.isEmpty) {
      return null;
    }

    final Map<String, dynamic> payload = <String, dynamic>{'slug': slug};
    if (slug.startsWith('+')) {
      payload['invite_token'] = slug.substring(1);
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('get_invite_info', payload: payload);

    if (response is! Map) {
      return null;
    }

    return ApiInvitePreview.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<ApiJoinBySlugResult?> joinBySlug(String slugOrUrl) async {
    final String? slug = normalizeJoinSlug(slugOrUrl);
    if (slug == null || slug.isEmpty) {
      return null;
    }

    final Map<String, dynamic> payload = <String, dynamic>{'slug': slug};
    if (slug.startsWith('+')) {
      payload['invite_token'] = slug.substring(1);
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('join_chat', payload: payload);

    if (response is! Map) {
      return null;
    }

    return ApiJoinBySlugResult.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<List<ApiMessage>> getHistory(
    int chatId, {
    int page = 1,
    int pageSize = 50,
    int? beforeId,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'chat_id': chatId,
      'page': page,
      'page_size': pageSize,
    };
    if (beforeId != null) {
      payload['before_id'] = beforeId;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('history', payload: payload);

    if (response is! Map) {
      return const <ApiMessage>[];
    }

    final dynamic messagesRaw = response['messages'];
    if (messagesRaw is! List) {
      return const <ApiMessage>[];
    }

    final List<ApiMessage> messages = messagesRaw
        .whereType<Map>()
        .map(
          (Map item) => ApiMessage.fromJson(
            item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);

    messages.sort((ApiMessage a, ApiMessage b) => a.id.compareTo(b.id));
    return messages;
  }

  Future<ApiMessage> sendMessage(
    int chatId, {
    String? content,
    int? replyToId,
    String? uploadId,
    String? e2eeContent,
    bool interactiveUpdate = false,
  }) async {
    final String normalizedContent = (content ?? '').trim();
    final Map<String, dynamic> payload = <String, dynamic>{
      'chat_id': chatId,
      if (interactiveUpdate) 'interactive_update': true,
    };
    if (replyToId != null) {
      payload['reply_to_id'] = replyToId;
    }
    if (uploadId != null) {
      if (uploadId.startsWith('blb_')) {
        payload['blob_id'] = uploadId;
      } else {
        payload['upload_id'] = uploadId;
      }
    }

    if (e2eeContent != null && e2eeContent.isNotEmpty) {
      payload['e2ee_content'] = e2eeContent;
    } else if (normalizedContent.isNotEmpty) {
      payload['content'] = normalizedContent;
    } else if (uploadId == null) {
      payload['content'] = '';
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          interactiveUpdate ? 'interactive_update' : 'send_message',
          payload: payload,
        );

    if (response is! Map) {
      throw const ApiException(
        statusCode: 500,
        message: 'Не удалось отправить сообщение: неверный ответ сервера',
      );
    }

    return ApiMessage.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<ApiMessage> sendSticker(
    int chatId,
    int stickerId, {
    int? replyToId,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'chat_id': chatId,
      'sticker_id': stickerId,
    };
    if (replyToId != null) {
      payload['reply_to_id'] = replyToId;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('send_sticker', payload: payload);

    if (response is! Map) {
      throw ApiException(
        statusCode: 500,
        message: 'Invalid server response for send_sticker',
      );
    }

    return ApiMessage.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<UploadInitResult> initUpload({
    required String filename,
    required int totalChunks,
    required int fileSize,
    required String mediaSubtype,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'init_upload',
          payload: <String, dynamic>{
            'filename': filename,
            'total_chunks': totalChunks,
            'file_size': fileSize,
            'media_subtype': mediaSubtype,
          },
        );

    final Map<String, dynamic> map = asStringMap(response);
    return UploadInitResult.fromJson(map);
  }

  Future<UploadChunkResult> uploadChunk({
    required String uploadId,
    required int chunkIndex,
    required List<int> chunk,
    required String filename,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'upload_chunk',
          payload: <String, dynamic>{
            'upload_id': uploadId,
            'chunk_index': chunkIndex,
            'chunk_base64': base64Encode(chunk),
          },
          timeout: const Duration(seconds: 60),
        );

    final Map<String, dynamic> map = asStringMap(response);
    return UploadChunkResult.fromJson(map);
  }

  static Stream<List<int>> _createChunkedStream(
    Uint8List bytes, {
    int chunkSize = 64 * 1024,
    CancellationToken? cancellationToken,
  }) async* {
    for (int i = 0; i < bytes.length; i += chunkSize) {
      cancellationToken?.throwIfCancelled();
      final int end = (i + chunkSize < bytes.length)
          ? i + chunkSize
          : bytes.length;
      yield bytes.sublist(i, end);
    }
  }

  static const int _parallelThresholdBytes = 4 * 1024 * 1024;

  /// Chunk size both chunked transports declare to the server. It matches
  /// `MIN_PARALLEL_CHUNK_SIZE` (262144) in the deployed `fast_uploads.py`.
  static const int _uploadChunkSize = 256 * 1024;

  Future<String> uploadStreamInChunks({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required void Function(int sent, int total) onProgress,
    void Function(UploadStage stage)? onStageChanged,
    CancellationToken? cancellationToken,
    String? localId,
  }) async {
    cancellationToken?.throwIfCancelled();
    final int actualSize = (filePath != null && filePath.isNotEmpty)
        ? await File(filePath).length()
        : (bytes?.length ?? fileSize);
    if (actualSize <= 0) {
      throw Exception('File is empty');
    }

    final token = _ref.read(webSocketClientProvider).readToken();
    if (token == null) {
      throw Exception('Unauthorized: No session token');
    }

    // Server accepts only "media", "voice", or "circle". Map "photo", "video", "document" to "media".
    final String serverSubtype =
        (mediaSubtype == 'voice' || mediaSubtype == 'circle')
        ? mediaSubtype
        : 'media';

    if (actualSize <= _parallelThresholdBytes) {
      try {
        return await _httpMultipartUpload(
          bytes: bytes,
          filePath: filePath,
          filename: filename,
          mediaSubtype: serverSubtype,
          fileSize: actualSize,
          token: token,
          onProgress: onProgress,
          onStageChanged: onStageChanged,
          cancellationToken: cancellationToken,
          localId: localId,
        );
      } catch (e) {
        if (cancellationToken?.isCancelled == true ||
            e is UploadCancelledException) {
          throw const UploadCancelledException();
        }
        debugPrint(
          '[chat_repository] Fast HTTP upload failed ($e), falling back to WS chunked upload...',
        );
        return await _wsChunkedUpload(
          bytes: bytes,
          filePath: filePath,
          filename: filename,
          mediaSubtype: serverSubtype,
          fileSize: actualSize,
          onProgress: onProgress,
          onStageChanged: onStageChanged,
          cancellationToken: cancellationToken,
        );
      }
    }

    try {
      return await _parallelBinaryUpload(
        bytes: bytes,
        filePath: filePath,
        filename: filename,
        mediaSubtype: serverSubtype,
        fileSize: actualSize,
        token: token,
        onProgress: onProgress,
        onStageChanged: onStageChanged,
        cancellationToken: cancellationToken,
      );
    } catch (e) {
      if (cancellationToken?.isCancelled == true ||
          e is UploadCancelledException) {
        throw const UploadCancelledException();
      }
      debugPrint(
        '[chat_repository] Parallel upload failed ($e), falling back to single HTTP upload...',
      );
      try {
        return await _httpMultipartUpload(
          bytes: bytes,
          filePath: filePath,
          filename: filename,
          mediaSubtype: serverSubtype,
          fileSize: actualSize,
          token: token,
          onProgress: onProgress,
          onStageChanged: onStageChanged,
          cancellationToken: cancellationToken,
          localId: localId,
        );
      } catch (e2) {
        if (cancellationToken?.isCancelled == true ||
            e2 is UploadCancelledException) {
          throw const UploadCancelledException();
        }
        debugPrint(
          '[chat_repository] HTTP fallback failed ($e2), falling back to WS chunked upload...',
        );
        return await _wsChunkedUpload(
          bytes: bytes,
          filePath: filePath,
          filename: filename,
          mediaSubtype: serverSubtype,
          fileSize: actualSize,
          onProgress: onProgress,
          onStageChanged: onStageChanged,
          cancellationToken: cancellationToken,
        );
      }
    }
  }

  Future<String> _parallelBinaryUpload({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required String token,
    required void Function(int sent, int total) onProgress,
    void Function(UploadStage stage)? onStageChanged,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final releaseWork = BackgroundService.retainWork();
    final client = http.Client();
    void cancelHandler() => client.close();
    cancellationToken?.addListener(cancelHandler);
    RandomAccessFile? raf;
    try {
      onStageChanged?.call(UploadStage.checking);
      final initResp = await client
          .post(
            Uri.parse('${ApiConstants.origin}/api/files/uploads/init'),
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'filename': filename,
              'file_size': fileSize,
              'media_subtype': mediaSubtype,
            }),
          )
          .timeout(const Duration(seconds: 30));

      cancellationToken?.throwIfCancelled();
      if (initResp.statusCode != 200) {
        throw Exception(
          'Parallel init failed: ${initResp.statusCode} ${initResp.body}',
        );
      }
      final initJson = jsonDecode(initResp.body) as Map<String, dynamic>;
      final String uploadId = initJson['upload_id'] as String;
      final int chunkSize = initJson['chunk_size'] as int? ?? (2 * 1024 * 1024);
      final int totalChunks =
          initJson['total_chunks'] as int? ?? ((fileSize + chunkSize - 1) ~/ chunkSize);
      final int concurrency =
          (initJson['max_concurrency'] as int? ?? 4).clamp(1, 4);

      if (filePath != null && filePath.isNotEmpty) {
        raf = await File(filePath).open(mode: FileMode.read);
      } else if (bytes == null || bytes.isEmpty) {
        throw Exception('No file path or bytes provided');
      }

      onStageChanged?.call(UploadStage.uploading);
      onProgress(0, fileSize);

      int nextIdx = 0;
      int sentBytes = 0;
      bool readLocked = false;
      final List<Completer<void>> readWaiters = <Completer<void>>[];

      Future<Uint8List> readSlice(int offset, int len) async {
        if (bytes != null && raf == null) {
          return Uint8List.sublistView(bytes, offset, offset + len);
        }
        while (readLocked) {
          final c = Completer<void>();
          readWaiters.add(c);
          await c.future;
        }
        readLocked = true;
        try {
          final rafHandle = raf!;
          await rafHandle.setPosition(offset);
          final Uint8List buf = Uint8List(len);
          int pos = 0;
          while (pos < len) {
            final int n = await rafHandle.readInto(buf, pos, len);
            if (n <= 0) {
              throw Exception('Unexpected EOF slicing chunk');
            }
            pos += n;
          }
          return buf;
        } finally {
          readLocked = false;
          if (readWaiters.isNotEmpty) {
            readWaiters.removeAt(0).complete();
          }
        }
      }

      Future<void> worker() async {
        while (true) {
          cancellationToken?.throwIfCancelled();
          final int idx = nextIdx;
          if (idx >= totalChunks) return;
          nextIdx++;

          final int offset = idx * chunkSize;
          final int len = (offset + chunkSize > fileSize)
              ? (fileSize - offset)
              : chunkSize;
          final Uint8List slice = await readSlice(offset, len);
          final String shaHex = crypto.sha256.convert(slice).toString();

          int attempt = 0;
          while (true) {
            cancellationToken?.throwIfCancelled();
            try {
              final resp = await client
                  .put(
                    Uri.parse(
                      '${ApiConstants.origin}/api/files/uploads/$uploadId/chunks/$idx',
                    ),
                    headers: <String, String>{
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/octet-stream',
                      'X-Chunk-SHA256': shaHex,
                    },
                    body: slice,
                  )
                  .timeout(const Duration(seconds: 60));
              if (resp.statusCode != 200) {
                throw Exception(
                  'Chunk $idx failed (${resp.statusCode}): ${resp.body}',
                );
              }
              break;
            } catch (err) {
              if (cancellationToken?.isCancelled == true) {
                throw const UploadCancelledException();
              }
              attempt++;
              if (attempt >= 3) rethrow;
              await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
            }
          }

          sentBytes += len;
          if (sentBytes > fileSize) sentBytes = fileSize;
          onProgress(sentBytes, fileSize);
        }
      }

      await Future.wait(
        List<Future<void>>.generate(concurrency, (_) => worker()),
      );

      cancellationToken?.throwIfCancelled();
      onStageChanged?.call(UploadStage.processing);
      final completeResp = await client
          .post(
            Uri.parse(
              '${ApiConstants.origin}/api/files/uploads/$uploadId/complete',
            ),
            headers: <String, String>{'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));

      if (completeResp.statusCode != 200) {
        throw Exception(
          'Upload complete failed (${completeResp.statusCode}): ${completeResp.body}',
        );
      }
      onProgress(fileSize, fileSize);
      return uploadId;
    } finally {
      cancellationToken?.removeListener(cancelHandler);
      try {
        await raf?.close();
      } catch (_) {}
      client.close();
      releaseWork();
    }
  }

  /// Secret uploads always use the deployed opaque-file endpoint, never CAS
  /// deduplication or a fallback that could receive the original plaintext.
  Future<String> uploadSecretCiphertext({
    Uint8List? bytes,
    String? filePath,
    required String mediaSubtype,
    required String localId,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final token = _ref.read(webSocketClientProvider).readToken();
    if (token == null) throw StateError('No session');
    if ((filePath == null || filePath.isEmpty) &&
        (bytes == null || bytes.isEmpty)) {
      throw StateError('Secret ciphertext unavailable');
    }
    final size = filePath != null && filePath.isNotEmpty
        ? await File(filePath).length()
        : bytes!.length;
    final cleanSubtype = (mediaSubtype == 'voice' || mediaSubtype == 'circle')
        ? mediaSubtype
        : 'media';
    if (size > _parallelThresholdBytes) {
      try {
        return await _parallelBinaryUpload(
          bytes: bytes,
          filePath: filePath,
          filename: 'encrypted.bin',
          mediaSubtype: cleanSubtype,
          fileSize: size,
          token: token,
          cancellationToken: cancellationToken,
          onProgress: (sent, total) {},
        );
      } catch (e) {
        if (cancellationToken?.isCancelled == true ||
            e is UploadCancelledException) {
          throw const UploadCancelledException();
        }
      }
    }
    return _httpMultipartUpload(
      bytes: bytes,
      filePath: filePath,
      filename: 'encrypted.bin',
      mediaSubtype: cleanSubtype,
      fileSize: size,
      token: token,
      localId: localId,
      cancellationToken: cancellationToken,
      onProgress: (sent, total) {},
    );
  }

  Future<String> _httpMultipartUpload({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required String token,
    required void Function(int sent, int total) onProgress,
    void Function(UploadStage stage)? onStageChanged,
    CancellationToken? cancellationToken,
    String? localId,
  }) async {
    final release = BackgroundService.retainWork();
    try {
      return await _httpMultipartUploadOwned(
        bytes: bytes,
        filePath: filePath,
        filename: filename,
        mediaSubtype: mediaSubtype,
        fileSize: fileSize,
        token: token,
        onProgress: onProgress,
        onStageChanged: onStageChanged,
        cancellationToken: cancellationToken,
        localId: localId,
      );
    } finally {
      release();
    }
  }

  Future<String> _httpMultipartUploadOwned({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required String token,
    required void Function(int sent, int total) onProgress,
    void Function(UploadStage stage)? onStageChanged,
    CancellationToken? cancellationToken,
    String? localId,
  }) async {
    cancellationToken?.throwIfCancelled();
    final uploadUrl = '${ApiConstants.origin}/api/files/upload';
    final uri = Uri.parse(uploadUrl);

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    // The server accepts either `Authorization: Bearer` or a multipart `token`
    // field (`extract_bearer_or_token` in app/main.py), so the header is enough.
    if (localId != null && localId.isNotEmpty) {
      request.headers['X-Upload-Local-Id'] = localId;
    }
    request.fields['media_subtype'] = mediaSubtype;

    if (filePath != null && filePath.isNotEmpty) {
      final File file = File(filePath);
      final int actualSize = (await file.exists())
          ? await file.length()
          : fileSize;
      if (actualSize == 0 && bytes != null && bytes.isNotEmpty) {
        // Fall back to chunked bytes if file is empty/inaccessible
        final Stream<List<int>> source = _createChunkedStream(
          bytes,
          cancellationToken: cancellationToken,
        );
        int sent = 0;
        final Stream<List<int>> counted = source.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (List<int> chunk, EventSink<List<int>> sink) {
              if (cancellationToken?.isCancelled == true) {
                sink.addError(const UploadCancelledException());
                sink.close();
                return;
              }
              sent += chunk.length;
              onProgress(sent, bytes.length);
              sink.add(chunk);
            },
          ),
        );
        request.files.add(
          http.MultipartFile('file', counted, bytes.length, filename: filename),
        );
      } else {
        final Stream<List<int>> source = file.openRead();
        int sent = 0;
        final Stream<List<int>> counted = source.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (List<int> chunk, EventSink<List<int>> sink) {
              if (cancellationToken?.isCancelled == true) {
                sink.addError(const UploadCancelledException());
                sink.close();
                return;
              }
              sent += chunk.length;
              onProgress(sent, actualSize);
              sink.add(chunk);
            },
          ),
        );
        request.files.add(
          http.MultipartFile('file', counted, actualSize, filename: filename),
        );
      }
    } else if (bytes != null && bytes.isNotEmpty) {
      final Stream<List<int>> source = _createChunkedStream(
        bytes,
        cancellationToken: cancellationToken,
      );
      int sent = 0;
      final Stream<List<int>> counted = source.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (List<int> chunk, EventSink<List<int>> sink) {
            if (cancellationToken?.isCancelled == true) {
              sink.addError(const UploadCancelledException());
              sink.close();
              return;
            }
            sent += chunk.length;
            onProgress(sent, bytes.length);
            sink.add(chunk);
          },
        ),
      );
      request.files.add(
        http.MultipartFile('file', counted, bytes.length, filename: filename),
      );
    } else {
      throw Exception('No file path or bytes provided for upload');
    }

    onProgress(0, fileSize > 0 ? fileSize : 1);
    final client = http.Client();
    void cancelHandler() {
      client.close();
    }

    cancellationToken?.addListener(cancelHandler);

    try {
      final streamedResponse = await client.send(request);
      cancellationToken?.throwIfCancelled();
      onStageChanged?.call(UploadStage.processing);
      final response = await http.Response.fromStream(streamedResponse);
      cancellationToken?.throwIfCancelled();

      if (response.statusCode != 200) {
        throw Exception(
          'Upload failed: ${response.statusCode} ${response.body}',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'success') {
        throw Exception('Upload failed: ${response.body}');
      }

      onProgress(fileSize, fileSize);
      return body['upload_id'] as String;
    } finally {
      cancellationToken?.removeListener(cancelHandler);
      client.close();
    }
  }

  Future<String> _wsChunkedUpload({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required void Function(int sent, int total) onProgress,
    void Function(UploadStage stage)? onStageChanged,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    RandomAccessFile? raf;
    final int actualFileSize;
    if (filePath != null && filePath.isNotEmpty) {
      final File file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }
      actualFileSize = await file.length();
      raf = await file.open(mode: FileMode.read);
    } else if (bytes != null && bytes.isNotEmpty) {
      actualFileSize = bytes.length;
    } else {
      throw Exception('No file path or bytes provided for upload');
    }

    try {
      cancellationToken?.throwIfCancelled();
      if (actualFileSize <= 0) {
        throw Exception('File data is empty');
      }

      const int requestChunkSize = _uploadChunkSize;
      final int initialChunks = (actualFileSize / requestChunkSize).ceil();

      final UploadInitResult init = await initUpload(
        filename: filename,
        totalChunks: initialChunks,
        fileSize: actualFileSize,
        mediaSubtype: mediaSubtype,
      );
      cancellationToken?.throwIfCancelled();

      final int chunkSize = init.chunkSize > 0
          ? init.chunkSize
          : requestChunkSize;
      final int totalChunks = (actualFileSize / chunkSize).ceil();

      for (int i = 0; i < totalChunks; i++) {
        cancellationToken?.throwIfCancelled();
        final int start = i * chunkSize;
        final int end = (start + chunkSize > actualFileSize)
            ? actualFileSize
            : start + chunkSize;
        final int len = end - start;
        final List<int> chunk;
        if (raf != null) {
          await raf.setPosition(start);
          final Uint8List buf = Uint8List(len);
          int pos = 0;
          while (pos < len) {
            final int n = await raf.readInto(buf, pos, len);
            if (n <= 0) throw Exception('Unexpected EOF during WS upload');
            pos += n;
          }
          chunk = buf;
        } else {
          chunk = Uint8List.sublistView(bytes!, start, end);
        }
        await uploadChunk(
          uploadId: init.uploadId,
          chunkIndex: i,
          chunk: chunk,
          filename: filename,
        );
        cancellationToken?.throwIfCancelled();
        onProgress(end, actualFileSize);
      }

      onStageChanged?.call(UploadStage.processing);
      onProgress(actualFileSize, actualFileSize);
      return init.uploadId;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  Future<ApiMessage?> editMessage(
    int chatId,
    int messageId, {
    required String content,
    String? e2eeContent,
  }) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'chat_id': chatId,
      'message_id': messageId,
    };
    if (e2eeContent != null && e2eeContent.isNotEmpty) {
      payload['e2ee_content'] = e2eeContent;
    } else {
      payload['content'] = trimmed;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('edit_message', payload: payload);

    if (response is! Map) {
      return null;
    }

    return ApiMessage.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<void> deleteMessage(int chatId, int messageId) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'delete_message',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'message_id': messageId,
          },
        );
  }

  Future<void> sendCallbackQuery(int chatId, int messageId, String data) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'callback_query',
          maxRetries: 0,
          payload: <String, dynamic>{
            'chat_id': chatId,
            'message_id': messageId,
            'data': data,
          },
        );
  }

  Future<Map<String, dynamic>> toggleReaction(
    int chatId,
    int messageId, {
    required String emoji,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'react',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'message_id': messageId,
            'emoji': emoji,
          },
        );

    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is Map) {
      return response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  Future<ApiMessage> sendComment(
    int channelId,
    int postId, {
    required String content,
    int? replyToId,
    int senderId = 0,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'post_id': postId,
      'content': content,
      'reply_to_id': replyToId,
    };
    if (channelId > 0) {
      payload['channel_id'] = channelId;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          channelId > 0 ? 'post_comment' : 'comment_post',
          payload: payload,
        );

    if (response is! Map) {
      return ApiMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        chatId: channelId,
        senderId: senderId,
        senderUsername: 'me',
        senderDisplayName: 'Me',
        senderBadges: const [],
        content: content,
        msgType: 'text',
        replyToId: replyToId,
        mediaUrl: null,
        mediaType: null,
        mediaName: null,
        mediaSize: null,
        mediaDuration: null,
        commentsCount: 0,
        reactions: const <String, int>{},
        sentAt: DateTime.now(),
        editedAt: null,
        isDeleted: false,
        isE2ee: false,
        e2eeContent: null,
      );
    }

    return ApiMessage.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<List<ApiMessage>> getComments(
    int channelId,
    int postId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'post_id': postId,
      'page': page,
      'page_size': pageSize,
    };
    if (channelId > 0) {
      payload['channel_id'] = channelId;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          channelId > 0 ? 'get_comments' : 'get_post_comments',
          payload: payload,
        );

    if (response is! Map) {
      return const <ApiMessage>[];
    }

    final dynamic commentsRaw = response['comments'];
    if (commentsRaw is! List) {
      return const <ApiMessage>[];
    }

    final List<ApiMessage> comments = commentsRaw
        .whereType<Map>()
        .map((Map item) {
          final Map<String, dynamic> flat = <String, dynamic>{};
          item.forEach((dynamic k, dynamic v) {
            flat[k.toString()] = v;
          });
          if (flat['author'] is Map) {
            final Map author = flat['author'] as Map;
            flat['sender_username'] = author['username'] ?? '';
            flat['sender_display_name'] =
                author['display_name'] ?? author['username'] ?? 'Unknown';
            flat['sender_avatar_url'] = author['avatar_url'];
          }
          return ApiMessage.fromJson(flat);
        })
        .toList(growable: false);

    comments.sort((ApiMessage a, ApiMessage b) => a.id.compareTo(b.id));
    return comments;
  }

  Future<int> markRead(int chatId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('mark_read', payload: <String, dynamic>{'chat_id': chatId});

    if (response is Map<String, dynamic>) {
      return response['unread_count'] as int? ?? 0;
    }
    return 0;
  }

  /// Sets the account-wide inbox state of [chatIds]: pin, archive, notification
  /// mute, manual unread. Only the flags that are passed change. Returns the
  /// state rows the server stored (`chat_id`, `pinned_at`, `is_archived`,
  /// `notifications_muted`, `marked_unread`), in the order of the request.
  Future<List<Map<String, dynamic>>> setChatState(
    List<int> chatIds, {
    bool? pinned,
    bool? archived,
    bool? muted,
    bool? unread,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'set_chat_state',
          payload: <String, dynamic>{
            'chat_ids': chatIds,
            'pinned': ?pinned,
            'archived': ?archived,
            'muted': ?muted,
            'unread': ?unread,
          },
        );
    final dynamic rows = response is Map ? response['chats'] : null;
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map(
          (Map item) => item.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ApiChatMember>> getMembers(int chatId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('get_members', payload: <String, dynamic>{'chat_id': chatId});
    if (response is! List) {
      return const <ApiChatMember>[];
    }
    return response
        .whereType<Map>()
        .map(
          (Map item) => ApiChatMember.fromJson(
            item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<ApiChatSummary?> updateChat(
    int chatId, {
    String? name,
    String? description,
    String? username,
    bool? commentsEnabled,
    int? autoDeleteSeconds,
    bool clearAutoDelete = false,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{'chat_id': chatId};
    if (name != null && name.trim().isNotEmpty) payload['name'] = name.trim();
    if (description != null) payload['description'] = description;
    if (username != null && username.trim().isNotEmpty) {
      payload['username'] = username.trim();
    }
    if (commentsEnabled != null) payload['comments_enabled'] = commentsEnabled;
    if (clearAutoDelete) {
      payload['auto_delete_seconds'] = null;
    } else if (autoDeleteSeconds != null) {
      payload['auto_delete_seconds'] = autoDeleteSeconds;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('update_chat', payload: payload);
    if (response is! Map) return null;
    return ApiChatSummary.fromJson(asStringMap(response));
  }

  Future<String> uploadChatAvatar(
    int chatId,
    List<int> bytes,
    String filename,
  ) async {
    final uploadId = await _ref
        .read(publicMediaUploadServiceProvider)
        .upload(Uint8List.fromList(bytes), filename: filename);
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'chat_avatar_upload',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'upload_id': uploadId,
            'filename': filename,
          },
          timeout: const Duration(seconds: 45),
          maxRetries: 0,
        );
    return asStringMap(response)['avatar_url'] as String? ?? '';
  }

  Future<void> inviteUser(int chatId, int userId) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'invite_user',
          payload: <String, dynamic>{'chat_id': chatId, 'user_id': userId},
        );
  }

  Future<ChatInviteBatchResult> inviteUsers(
    int chatId,
    List<int> userIds,
  ) async {
    final List<int> invited = <int>[];
    final List<int> failed = <int>[];

    for (final int uid in userIds) {
      try {
        await inviteUser(chatId, uid);
        invited.add(uid);
      } catch (_) {
        failed.add(uid);
      }
    }

    return ChatInviteBatchResult(
      chatId: chatId,
      invitedUserIds: invited,
      failedUserIds: failed,
    );
  }

  Future<void> banUser(
    int chatId,
    int userId,
    bool ban, {
    int? durationSeconds,
    String? reason,
  }) async {
    if (userId == 1) {
      throw Exception('Нельзя заблокировать пользователя Support');
    }
    final Map<String, dynamic> payload = <String, dynamic>{
      'chat_id': chatId,
      'user_id': userId,
      'ban': ban,
      'banned': ban,
    };
    if (durationSeconds != null && durationSeconds > 0) {
      payload['duration_seconds'] = durationSeconds;
    }
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }

    await _ref
        .read(webSocketClientProvider)
        .request('ban_member', payload: payload);
  }

  Future<void> muteUser(
    int chatId,
    int userId,
    bool mute, {
    int? durationSeconds,
    String? reason,
  }) async {
    if (userId == 1) {
      throw Exception('Нельзя заглушить пользователя Support');
    }
    final Map<String, dynamic> payload = <String, dynamic>{
      'chat_id': chatId,
      'user_id': userId,
      'mute': mute,
      'muted': mute,
    };
    if (durationSeconds != null && durationSeconds > 0) {
      payload['duration_seconds'] = durationSeconds;
    }
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }

    await _ref
        .read(webSocketClientProvider)
        .request('mute_member', payload: payload);
  }

  Future<void> promoteUser(int chatId, int userId, String role) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'promote_member',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'user_id': userId,
            'role': role,
          },
        );
  }

  Future<void> leaveChat(int chatId) async {
    await _ref
        .read(webSocketClientProvider)
        .request('leave_chat', payload: <String, dynamic>{'chat_id': chatId});
  }

  Future<List<int>> downloadMedia(String filePath) async {
    final token = _ref.read(webSocketClientProvider).readToken();
    if (token == null) {
      throw Exception('Unauthorized: No session token');
    }

    final String cleanPath = WsMediaFetcher.cleanFilePath(filePath);
    final String downloadUrl = '${ApiConstants.origin}/api/files/download';
    final http.Response response = await http.post(
      Uri.parse(downloadUrl),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'file_path': cleanPath}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Download failed with status code ${response.statusCode}: ${response.body}',
      );
    }

    return response.bodyBytes;
  }

  Future<String?> resolveShortLink(String slug) async {
    try {
      final Map<String, dynamic> payload = <String, dynamic>{'slug': slug};
      if (slug.startsWith('+')) {
        payload['invite_token'] = slug.substring(1);
      }
      final dynamic response = await _ref
          .read(webSocketClientProvider)
          .request('get_invite_info', payload: payload);
      if (response is Map && response['slug'] != null) {
        return '/join?slug=${response['slug']}';
      }
      if (response is Map && response['path'] != null) {
        return response['path'] as String;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getInviteLink(int chatId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'get_invite_link',
          payload: <String, dynamic>{'chat_id': chatId},
        );
    if (response is! Map) return null;
    return asStringMap(response);
  }

  Future<Map<String, dynamic>?> rotateInviteLink(int chatId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'rotate_invite_link',
          payload: <String, dynamic>{'chat_id': chatId},
        );
    if (response is! Map) return null;
    return asStringMap(response);
  }
}

final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>((Ref ref) {
      return ChatRepository(ref);
    });
