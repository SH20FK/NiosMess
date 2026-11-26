import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

/// Describes an incoming or ongoing call notification.
class IncomingCallData {
  const IncomingCallData({
    required this.callId,
    required this.roomId,
    required this.chatId,
    required this.isVideo,
    this.isGroup = false,
    required this.initiatorId,
    required this.initiatorName,
  });

  final int callId;
  final String roomId;
  final int chatId;
  final bool isVideo;
  final bool isGroup;
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

/// Describes an active call in a chat (used to show the join banner in groups).
class ActiveChatCall {
  const ActiveChatCall({
    required this.chatId,
    required this.roomId,
    required this.callId,
    this.isVideo = false,
    this.isGroup = true,
    this.participantsCount = 1,
    this.status = 'active',
  });

  final int chatId;
  final String roomId;
  final int callId;
  final bool isVideo;
  final bool isGroup;
  final int participantsCount;
  final String status;

  ActiveChatCall copyWith({
    int? participantsCount,
    String? status,
  }) => ActiveChatCall(
    chatId: chatId,
    roomId: roomId,
    callId: callId,
    isVideo: isVideo,
    isGroup: isGroup,
    participantsCount: participantsCount ?? this.participantsCount,
    status: status ?? this.status,
  );
}

class ActiveChatCallsNotifier extends Notifier<Map<int, ActiveChatCall>> {
  @override
  Map<int, ActiveChatCall> build() {
    ref.watch(
      authProvider.select((s) => (s.session?.userId, s.session?.accessToken)),
    );
    return const <int, ActiveChatCall>{};
  }

  void upsert(ActiveChatCall call) {
    state = <int, ActiveChatCall>{...state, call.chatId: call};
  }

  void updateCount(int chatId, String roomId, int count) {
    final existing = state[chatId];
    if (existing == null || existing.roomId != roomId) return;
    if (count <= 0) {
      remove(chatId, roomId: roomId);
    } else {
      upsert(existing.copyWith(participantsCount: count, status: 'active'));
    }
  }

  void remove(int chatId, {String? roomId}) {
    final existing = state[chatId];
    if (existing == null) return;
    if (roomId != null && existing.roomId != roomId) return;
    final next = Map<int, ActiveChatCall>.of(state)..remove(chatId);
    state = next;
  }
}

final activeChatCallsProvider =
    NotifierProvider<ActiveChatCallsNotifier, Map<int, ActiveChatCall>>(
      ActiveChatCallsNotifier.new,
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
