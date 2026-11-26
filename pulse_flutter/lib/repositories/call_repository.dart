import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class CallRepository {
  const CallRepository(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> initiate({
    required int chatId,
    required String roomId,
    required String callerNickname,
    required bool isVideo,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'start_call',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'room_id': roomId,
            'caller_nickname': callerNickname,
            'is_video': isVideo,
          },
        );
    return asStringMap(response);
  }

  Future<Map<String, dynamic>> join({
    required int chatId,
    required String roomId,
    required int messageId,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'join_call',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'room_id': roomId,
            'message_id': messageId,
          },
        );
    return asStringMap(response);
  }

  Future<void> end({
    required int chatId,
    required String roomId,
    required int messageId,
    required int duration,
    required bool wasMissed,
  }) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'end_call',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'room_id': roomId,
            'message_id': messageId,
            'duration': duration,
            'was_missed': wasMissed,
          },
        );
  }

  /// Callee rejected the call: finalize it server-side; the server
  /// broadcasts end_call so the caller hangs up immediately.
  Future<void> decline({
    required int chatId,
    required String roomId,
    required int messageId,
  }) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'decline_call',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'room_id': roomId,
            'message_id': messageId,
          },
        );
  }

  Future<Map<String, dynamic>?> getActiveCall(int chatId) async {
    try {
      final dynamic response = await _ref
          .read(webSocketClientProvider)
          .request(
            'get_active_call',
            payload: <String, dynamic>{'chat_id': chatId},
          );
      final map = asStringMap(response);
      final rawActive = map['active_call'];
      if (rawActive is Map) {
        return asStringMap(rawActive);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> refreshCallToken({
    required int chatId,
    required String roomId,
  }) async {
    try {
      final dynamic response = await _ref
          .read(webSocketClientProvider)
          .request(
            'refresh_call_token',
            payload: <String, dynamic>{'chat_id': chatId, 'room_id': roomId},
          );
      final map = asStringMap(response);
      if (map.containsKey('call_access_token')) {
        return map;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final Provider<CallRepository> callRepositoryProvider =
    Provider<CallRepository>((Ref ref) {
      return CallRepository(ref);
    });
