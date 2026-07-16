import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';

class CallSignalService {
  CallSignalService(this._ref);

  final Ref _ref;

  CallRepository get _repository => _ref.read(callRepositoryProvider);

  Future<Map<String, dynamic>> startCall({
    required int chatId,
    required String roomId,
    required String callerNickname,
    required bool isVideo,
  }) {
    return _repository.initiate(
      chatId: chatId,
      roomId: roomId,
      callerNickname: callerNickname,
      isVideo: isVideo,
    );
  }

  Future<void> joinCall({
    required int chatId,
    required String roomId,
    required int messageId,
  }) {
    return _repository.join(
      chatId: chatId,
      roomId: roomId,
      messageId: messageId,
    );
  }

  Future<void> endCall({
    required int chatId,
    required String roomId,
    required int messageId,
    required int duration,
    required bool wasMissed,
  }) {
    return _repository.end(
      chatId: chatId,
      roomId: roomId,
      messageId: messageId,
      duration: duration,
      wasMissed: wasMissed,
    );
  }
}

final Provider<CallSignalService> callSignalServiceProvider =
    Provider<CallSignalService>((ref) => CallSignalService(ref));
