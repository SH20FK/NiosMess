import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class CallRepository {
  const CallRepository(this._ref);

  final Ref _ref;

  Future<ApiCallInitiateResult> initiate({
    required int chatId,
    required bool isVideo,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'initiate_call',
          payload: <String, dynamic>{'chat_id': chatId, 'is_video': isVideo},
        );
    return ApiCallInitiateResult.fromJson(asStringMap(response));
  }

  Future<void> answer({required int callId, required bool accept}) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'answer_call',
          payload: <String, dynamic>{'call_id': callId, 'accept': accept},
        );
  }

  Future<ApiCallEndResult> end(int callId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'end_call',
          payload: <String, dynamic>{'call_id': callId},
        );
    return ApiCallEndResult.fromJson(asStringMap(response));
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
