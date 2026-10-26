import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';

class CallPushHandler extends Notifier<void> {
  StreamSubscription<dynamic>? _sub;
  StreamSubscription<Map<String, dynamic>>? _pushSub;
  StreamSubscription<Map<String, dynamic>>? _controlSub;
  final _endedRooms = <String>{};
  int _generation = 0;

  @override
  void build() {
    ref.watch(
      authProvider.select((s) => (s.session?.userId, s.session?.accessToken)),
    );
    final generation = ++_generation;
    _endedRooms.clear();
    _sub = ref.read(webSocketClientProvider).pushStream.listen(_dispatch);
    _pushSub = PushNotificationService.incomingCalls.listen((data) {
      _dispatch({'action': 'incoming_call_push', 'payload': data});
    });
    _controlSub = PushNotificationService.messages.listen((data) {
      if (data['type'] == 'call_ended') {
        final account = ref.read(authProvider).session?.userId;
        if (account == null ||
            int.tryParse(data['account_id']?.toString() ?? '') != account) {
          return;
        }
        _dispatch({'action': 'call_ended', 'payload': data});
      }
    });
    ref.onDispose(() {
      if (_generation == generation) _generation++;
      unawaited(_controlSub?.cancel());
      unawaited(_sub?.cancel());
      unawaited(_pushSub?.cancel());
    });
  }

  void _dispatch(dynamic event) {
    unawaited(
      _handlePush(event).catchError((Object _) {
        // Optional preference/plugin failures must not escape Stream.listen.
        debugPrint('[CallPushHandler] INCOMING_EVENT_UNAVAILABLE');
      }),
    );
  }

  Future<void> _handlePush(dynamic event) async {
    if (!ref.mounted || event is! Map) return;
    final generation = _generation;
    final Map<String, dynamic> msg = asStringMap(event);
    final String action = msg['action'] as String? ?? '';

    if (action == 'end_call' ||
        action == 'call_ended' ||
        action == 'decline_call') {
      _handleEndCall(msg);
      return;
    }

    if (action == 'call_joined') {
      _handleCallJoined(msg);
      return;
    }

    if (action != 'new_call' &&
        action != 'incoming_call' &&
        action != 'incoming_call_push' &&
        action != 'start_call') {
      return;
    }

    final Map<String, dynamic> payload = msg['payload'] is Map
        ? asStringMap(msg['payload'] as Map)
        : msg;

    final int messageId =
        int.tryParse(payload['message_id']?.toString() ?? '') ??
        int.tryParse(payload['call_id']?.toString() ?? '') ??
        int.tryParse(payload['id']?.toString() ?? '') ??
        0;
    final int? chatId = int.tryParse(payload['chat_id']?.toString() ?? '');
    final String? roomId = payload['room_id']?.toString();
    final int initiatorId =
        int.tryParse(payload['caller_id']?.toString() ?? '') ??
        int.tryParse(payload['initiator_id']?.toString() ?? '') ??
        0;
    final bool isVideo =
        payload['is_video'] == true ||
        payload['is_video'] == 'true' ||
        payload['is_video'] == 1 ||
        payload['is_video'] == '1';
    final String initiatorName =
        payload['caller_nickname']?.toString() ??
        payload['caller_name']?.toString() ??
        payload['initiator_name']?.toString() ??
        'Собеседник';

    if (chatId == null || roomId == null || roomId.trim().isEmpty) return;
    final session = ref.read(authProvider).session;
    final account = session?.userId;
    final token = session?.accessToken;
    if (account == null || ref.read(authProvider.notifier).isLoggingOut) return;
    if (payload.containsKey('account_id') &&
        int.tryParse(payload['account_id']?.toString() ?? '') != account) {
      return;
    }
    final preferences = await ref.read(notificationPreferencesProvider.future);
    if (!_isCurrent(generation, account, token)) return;
    final muted = await ref.read(chatMutedProvider(chatId).future);
    if (!_isCurrent(generation, account, token) ||
        !ref.read(uiSettingsProvider).notifications ||
        !preferences.calls ||
        muted ||
        _endedRooms.contains(roomId)) {
      return;
    }
    if (initiatorId != 0 &&
        initiatorId == ref.read(authProvider).session?.userId) {
      return;
    }

    // Deduplication (Rule 8): if already connected to this call, ignore duplicate push
    final CallSessionManager? currentSession = ref.read(callSessionProvider);
    if (currentSession != null && currentSession.roomId == roomId) {
      debugPrint(
        '[CallPushHandler] Duplicate call push for current session ignored',
      );
      return;
    }

    final IncomingCallData? currentIncoming = ref.read(incomingCallProvider);
    if (currentIncoming != null && currentIncoming.roomId == roomId) {
      debugPrint('[CallPushHandler] Duplicate incoming call push ignored');
      return;
    }

    // Busy check: if currently in another call, reject the new incoming call
    if (currentSession?.isActive ?? false) {
      debugPrint(
        '[CallPushHandler] User busy: declining new incoming call $roomId',
      );
      unawaited(
        ref
            .read(callRepositoryProvider)
            .decline(chatId: chatId, roomId: roomId, messageId: messageId),
      );
      return;
    }

    final IncomingCallData incomingData = IncomingCallData(
      callId: messageId,
      roomId: roomId,
      chatId: chatId,
      isVideo: isVideo,
      initiatorId: initiatorId,
      initiatorName: initiatorName,
    );

    ref.read(incomingCallProvider.notifier).set(incomingData);

    // Show actionable system notification
    unawaited(
      PushNotificationService.showIncomingCallNotification(
        chatId: chatId,
        callId: messageId,
        roomId: roomId,
        callerName: initiatorName,
        isVideo: isVideo,
      ).catchError((Object _) {
        // Notification plugins may be unavailable on desktop/web. The incoming
        // overlay must still work and the stream listener must not throw.
        debugPrint('[CallPushHandler] System notification unavailable');
      }),
    );
  }

  bool _isCurrent(int generation, int account, String? token) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(authProvider).session?.userId == account &&
      ref.read(authProvider).session?.accessToken == token &&
      !ref.read(authProvider.notifier).isLoggingOut;

  void _handleCallJoined(Map<String, dynamic> msg) {
    final Map<String, dynamic> payload = msg['payload'] is Map
        ? asStringMap(msg['payload'] as Map)
        : msg;
    final String? roomId = payload['room_id']?.toString();

    final CallSessionManager? manager = ref.read(callSessionProvider);
    if (manager != null && roomId != null && manager.roomId == roomId) {
      debugPrint(
        '[CallPushHandler] Received call_joined for room $roomId. Connecting media...',
      );
      unawaited(manager.onCallJoined(payload));
    }
  }

  /// The other side ended/cancelled the call: dismiss the ringing banner,
  /// cancel call notification, and tear down active session if it matches.
  void _rememberEnded(String room) {
    _endedRooms.add(room);
    if (_endedRooms.length > 128) _endedRooms.remove(_endedRooms.first);
  }

  void _handleEndCall(Map<String, dynamic> msg) {
    final Map<String, dynamic> payload = msg['payload'] is Map
        ? asStringMap(msg['payload'] as Map)
        : msg;
    final String? roomId = payload['room_id']?.toString();
    if (roomId == null || roomId.trim().isEmpty) return;
    _rememberEnded(roomId);

    final IncomingCallData? incoming = ref.read(incomingCallProvider);
    if (incoming != null && incoming.roomId == roomId) {
      ref.read(incomingCallProvider.notifier).set(null);
    }

    // Cancel system call notification
    if (incoming != null && incoming.roomId == roomId) {
      unawaited(PushNotificationService.cancelCallNotification());
    }

    final CallSessionManager? manager = ref.read(callSessionProvider);
    if (manager != null && manager.roomId == roomId) {
      unawaited(manager.remoteEnd(payload: payload));
    }
  }
}

final Provider<void> callPushHandlerProvider = Provider<void>(
  (Ref ref) => ref.watch(callPushHandlerNotifierProvider),
);

final NotifierProvider<CallPushHandler, void> callPushHandlerNotifierProvider =
    NotifierProvider<CallPushHandler, void>(CallPushHandler.new);
