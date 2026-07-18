import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
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

  Future<void> join({
    required int chatId,
    required String roomId,
    required int messageId,
  }) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'join_call',
          payload: <String, dynamic>{
            'chat_id': chatId,
            'room_id': roomId,
            'message_id': messageId,
          },
        );
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

  Future<ApiCallStatus> status(int callId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'get_call',
          payload: <String, dynamic>{'call_id': callId},
        );
    return ApiCallStatus.fromJson(asStringMap(response));
  }
}

final Provider<CallRepository> callRepositoryProvider =
    Provider<CallRepository>((Ref ref) {
      return CallRepository(ref);
    });
