import 'dart:async';
import 'dart:convert';
import 'package:universal_io/io.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/invite_models.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/upload_models.dart';
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
    final Map<String, dynamic> payload = <String, dynamic>{};
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
      payload['target_public_key'] = publicKey;
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

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('create_group', payload: payload);

    if (response is! Map) {
      return null;
    }

    return ChatCreateResult.fromJson(
      response.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
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
  }) async {
    final String normalizedContent = (content ?? '').trim();
    final Map<String, dynamic> payload = <String, dynamic>{
      'chat_id': chatId,
    };
    if (replyToId != null) {
      payload['reply_to_id'] = replyToId;
    }
    if (uploadId != null) {
      payload['upload_id'] = uploadId;
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
        .request('send_message', payload: payload);

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

  Future<String> uploadStreamInChunks({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required void Function(int sent, int total) onProgress,
  }) async {
    if (fileSize <= 0 && (bytes == null || bytes.isEmpty)) {
      throw Exception('File is empty');
    }

    final token = _ref.read(webSocketClientProvider).readToken();
    if (token == null) {
      throw Exception('Unauthorized: No session token');
    }

    // Server accepts only "media", "voice", or "circle". Map "photo", "video", "document" to "media".
    final String serverSubtype = (mediaSubtype == 'voice' || mediaSubtype == 'circle')
        ? mediaSubtype
        : 'media';

    try {
      return await _httpMultipartUpload(
        bytes: bytes,
        filePath: filePath,
        filename: filename,
        mediaSubtype: serverSubtype,
        fileSize: fileSize,
        token: token,
        onProgress: onProgress,
      );
    } catch (e) {
      debugPrint('[chat_repository] HTTP upload failed: $e, falling back to WS chunked upload...');
      return await _wsChunkedUpload(
        bytes: bytes,
        filePath: filePath,
        filename: filename,
        mediaSubtype: serverSubtype,
        fileSize: fileSize,
        onProgress: onProgress,
      );
    }
  }

  Future<String> _httpMultipartUpload({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required String token,
    required void Function(int sent, int total) onProgress,
  }) async {
    final uploadUrl = '${ApiConstants.origin}/api/files/upload';
    final uri = Uri.parse(uploadUrl);

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['media_subtype'] = mediaSubtype;

    if (filePath != null && filePath.isNotEmpty) {
      final File file = File(filePath);
      final int actualSize = (await file.exists()) ? await file.length() : fileSize;
      if (actualSize == 0 && bytes != null && bytes.isNotEmpty) {
        // Fall back to bytes if file is empty/inaccessible
        final Stream<List<int>> source = Stream.fromIterable([bytes]);
        int sent = 0;
        final Stream<List<int>> counted = source.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (List<int> chunk, EventSink<List<int>> sink) {
              sent += chunk.length;
              onProgress(sent, bytes.length);
              sink.add(chunk);
            },
          ),
        );
        request.files.add(
          http.MultipartFile(
            'file',
            counted,
            bytes.length,
            filename: filename,
          ),
        );
      } else {
        final Stream<List<int>> source = file.openRead();
        int sent = 0;
        final Stream<List<int>> counted = source.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (List<int> chunk, EventSink<List<int>> sink) {
              sent += chunk.length;
              onProgress(sent, actualSize);
              sink.add(chunk);
            },
          ),
        );
        request.files.add(
          http.MultipartFile(
            'file',
            counted,
            actualSize,
            filename: filename,
          ),
        );
      }
    } else if (bytes != null && bytes.isNotEmpty) {
      final Stream<List<int>> source = Stream.fromIterable([bytes]);
      int sent = 0;
      final Stream<List<int>> counted = source.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (List<int> chunk, EventSink<List<int>> sink) {
            sent += chunk.length;
            onProgress(sent, bytes.length);
            sink.add(chunk);
          },
        ),
      );
      request.files.add(
        http.MultipartFile(
          'file',
          counted,
          bytes.length,
          filename: filename,
        ),
      );
    } else {
      throw Exception('No file path or bytes provided for upload');
    }

    onProgress(0, fileSize > 0 ? fileSize : 1);
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 'success') {
      throw Exception('Upload failed: ${response.body}');
    }

    onProgress(fileSize, fileSize);
    return body['upload_id'] as String;
  }

  Future<String> _wsChunkedUpload({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required void Function(int sent, int total) onProgress,
  }) async {
    final Uint8List fileBytes;
    if (bytes != null && bytes.isNotEmpty) {
      fileBytes = bytes;
    } else if (filePath != null && filePath.isNotEmpty) {
      final File file = File(filePath);
      if (await file.exists()) {
        fileBytes = await file.readAsBytes();
      } else {
        throw Exception('File does not exist: $filePath');
      }
    } else {
      throw Exception('No file path or bytes provided for upload');
    }

    final int actualFileSize = fileBytes.length;
    if (actualFileSize <= 0) {
      throw Exception('File data is empty');
    }

    const int chunkSize = 256 * 1024; // 256 KiB
    final int totalChunks = (actualFileSize / chunkSize).ceil();

    final UploadInitResult init = await initUpload(
      filename: filename,
      totalChunks: totalChunks,
      fileSize: actualFileSize,
      mediaSubtype: mediaSubtype,
    );

    for (int i = 0; i < totalChunks; i++) {
      final int start = i * chunkSize;
      final int end = (start + chunkSize > actualFileSize) ? actualFileSize : start + chunkSize;
      final List<int> chunk = fileBytes.sublist(start, end);
      await uploadChunk(
        uploadId: init.uploadId,
        chunkIndex: i,
        chunk: chunk,
        filename: filename,
      );
      onProgress(end, actualFileSize);
    }

    onProgress(actualFileSize, actualFileSize);
    return init.uploadId;
  }

  Future<ApiMessage?> editMessage(
    int chatId,
    int messageId, {
    required String content,
  }) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'edit_message',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'message_id': messageId,
            'content': trimmed,
          },
        );

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
          payload: <String, dynamic>{'chat_id': chatId, 'message_id': messageId},
        );
  }

  Future<void> sendCallbackQuery(int chatId, int messageId, String data) async {
    await _ref.read(webSocketClientProvider).request(
      'callback_query',
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
        .map(
          (Map item) {
            final Map<String, dynamic> flat = <String, dynamic>{};
            item.forEach((dynamic k, dynamic v) {
              flat[k.toString()] = v;
            });
            if (flat['author'] is Map) {
              final Map author = flat['author'] as Map;
              flat['sender_username'] = author['username'] ?? '';
              flat['sender_display_name'] = author['display_name'] ??
                  author['username'] ??
                  'Unknown';
              flat['sender_avatar_url'] = author['avatar_url'];
            }
            return ApiMessage.fromJson(flat);
          },
        )
        .toList(growable: false);

    comments.sort((ApiMessage a, ApiMessage b) => a.id.compareTo(b.id));
    return comments;
  }

  Future<int> markRead(int chatId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'mark_read',
          payload: <String, dynamic>{'chat_id': chatId},
        );

    if (response is Map<String, dynamic>) {
      return response['unread_count'] as int? ?? 0;
    }
    return 0;
  }

  Future<List<ApiChatMember>> getMembers(int chatId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'get_members',
          payload: <String, dynamic>{'chat_id': chatId},
        );
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
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'chat_avatar_upload',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'data_base64': base64Encode(bytes),
            'filename': filename,
          },
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

  Future<void> inviteUsers(int chatId, List<int> userIds) async {
    for (final int uid in userIds) {
      try {
        await inviteUser(chatId, uid);
      } catch (_) {}
    }
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
        .request(
          'ban_member',
          payload: payload,
        );
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
        .request(
          'mute_member',
          payload: payload,
        );
  }

  Future<void> promoteUser(int chatId, int userId, String role) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'promote_member',
          payload: <String, dynamic>{'chat_id': chatId, 'user_id': userId, 'role': role},
        );
  }

  Future<void> leaveChat(int chatId) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'leave_chat',
          payload: <String, dynamic>{'chat_id': chatId},
        );
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
        .request('get_invite_link', payload: <String, dynamic>{'chat_id': chatId});
    if (response is! Map) return null;
    return asStringMap(response);
  }

  Future<Map<String, dynamic>?> rotateInviteLink(int chatId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('rotate_invite_link', payload: <String, dynamic>{'chat_id': chatId});
    if (response is! Map) return null;
    return asStringMap(response);
  }
}

final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>((Ref ref) {
      return ChatRepository(ref);
    });
