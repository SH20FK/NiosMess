import 'dart:async';
import 'dart:convert';
import 'package:universal_io/io.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/invite_models.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/upload_models.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/api_provider.dart';

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
      return Uri.decodeComponent(segments.last);
    }

    final int joinPart = trimmed.indexOf('/join/');
    if (joinPart >= 0) {
      return trimmed.substring(joinPart + '/join/'.length).trim();
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

  Future<DirectChatOpenResult?> openDirectChatByUsername(
    String username, {
    bool isSecret = false,
    String? publicKey,
  }) async {
    final String trimmed = username.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'username': trimmed,
      'is_secret': isSecret,
    };
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

  Future<ChatCreateResult?> createChat({
    required String name,
    required String chatType,
    String? description,
    String? username,
    bool? commentsEnabled,
  }) async {
    final String normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return null;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'name': normalizedName,
      'chat_type': chatType,
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

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('get_invite_info', payload: <String, dynamic>{'slug': slug});

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

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('join_chat', payload: <String, dynamic>{'slug': slug});

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
      return ApiMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        chatId: chatId,
        senderId: 0,
        senderUsername: 'me',
        senderDisplayName: 'Me',
        senderBadges: const [],
        content: normalizedContent,
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
        isE2ee: e2eeContent != null && e2eeContent.isNotEmpty,
        e2eeContent: e2eeContent,
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
        );

    final Map<String, dynamic> map = asStringMap(response);
    return UploadChunkResult.fromJson(map);
  }

  Future<String> uploadStreamInChunks({
    Stream<List<int>>? readStream,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required void Function(int sent, int total) onProgress,
  }) async {
    if (fileSize <= 0) {
      throw Exception('File is empty');
    }

    final token = await _ref.read(apiProvider).getToken();
    if (token == null) {
      throw Exception('Unauthorized: No session token');
    }

    final uploadUrl = '${ApiConstants.origin}/api/files/upload';
    final uri = Uri.parse(uploadUrl);

    final request = http.MultipartRequest('POST', uri);
    request.fields['token'] = token;
    request.fields['media_subtype'] = mediaSubtype;

    if (filePath != null && filePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: filename));
    } else if (readStream != null) {
      final bytes = await readStream.reduce((a, b) => a + b);
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    } else {
      throw Exception('No stream or file path provided for upload');
    }

    onProgress(0, 100);
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 'success') {
      throw Exception('Upload failed: ${response.body}');
    }

    onProgress(100, 100);
    return body['upload_id'] as String;
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
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{'chat_id': chatId};
    if (name != null && name.trim().isNotEmpty) payload['name'] = name.trim();
    if (description != null) payload['description'] = description;
    if (username != null && username.trim().isNotEmpty) {
      payload['username'] = username.trim();
    }
    if (commentsEnabled != null) payload['comments_enabled'] = commentsEnabled;

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

  Future<void> banUser(int chatId, int userId, bool ban) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'ban_member',
          payload: <String, dynamic>{'chat_id': chatId, 'user_id': userId, 'ban': ban},
        );
  }

  Future<void> muteUser(int chatId, int userId, bool mute) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'mute_member',
          payload: <String, dynamic>{'chat_id': chatId, 'user_id': userId, 'mute': mute},
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
    return _ref.read(apiClientProvider).postBytes(
      '/media/download',
      body: <String, dynamic>{'file_path': filePath},
    );
  }

  Future<String?> resolveShortLink(String slug) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('resolve_short_link', payload: <String, dynamic>{'slug': slug});
    if (response is Map && response['path'] != null) {
      return response['path'] as String;
    }
    if (response is String && response.isNotEmpty) {
      return response;
    }
    return null;
  }
}

final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>((Ref ref) {
      return ChatRepository(ref);
    });
