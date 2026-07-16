import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class IncomingCallNotifier extends Notifier<IncomingCallData?> {
  @override
  IncomingCallData? build() => null;
  void set(IncomingCallData? data) => state = data;
}

/// Tracks incoming call events from the main WebSocket.
final incomingCallProvider = NotifierProvider<IncomingCallNotifier, IncomingCallData?>(
  IncomingCallNotifier.new,
);

class CallScreenVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool visible) => state = visible;
}

/// Tracks whether the active call screen is currently showing.
final isCallScreenVisibleProvider = NotifierProvider<CallScreenVisibleNotifier, bool>(
  CallScreenVisibleNotifier.new,
);
