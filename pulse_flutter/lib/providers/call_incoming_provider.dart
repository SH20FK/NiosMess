import 'package:flutter_riverpod/legacy.dart';

/// Describes an incoming or ongoing call notification.
class IncomingCallData {
  const IncomingCallData({
    required this.callId,
    required this.roomId,
    required this.chatId,
    required this.isVideo,
    required this.initiatorId,
    required this.initiatorName,
  });

  final int callId;
  final String roomId;
  final int chatId;
  final bool isVideo;
  final int initiatorId;
  final String initiatorName;
}

/// Tracks incoming call events from the main WebSocket.
final StateProvider<IncomingCallData?> incomingCallProvider =
    StateProvider<IncomingCallData?>((_) => null);

/// Tracks whether the active call screen is currently showing.
final StateProvider<bool> isCallScreenVisibleProvider =
    StateProvider<bool>((_) => false);
