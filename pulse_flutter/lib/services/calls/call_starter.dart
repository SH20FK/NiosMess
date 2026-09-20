import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/bot_detector.dart';
import 'package:pulse_flutter/models/api/call_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/services/permission_service.dart';

/// Why [startOutgoingCall] or [startIncomingCall] refused to start.
enum CallStartFailure { permissions, botForbidden }

class CallStartException implements Exception {
  const CallStartException(this.failure, {this.cause});

  final CallStartFailure failure;
  final Object? cause;

  @override
  String toString() => 'CallStartException($failure${cause == null ? '' : ': $cause'})';
}

/// Shared bootstrap for outgoing calls (chat screen and /call/dm/:username
/// deep route). Requests permissions, signals the server, creates the SFU
/// room, derives the media key and registers the session in
/// [callSessionProvider]. Returns the server-side call (message) id.
Future<int> startOutgoingCall({
  required WidgetRef ref,
  required int chatId,
  required bool isVideo,
  String? peerName,
  String? peerAvatarUrl,
  String? peerUsername,
  void Function(bool isListener)? onPermissionResult,
}) async {
  final chat = ref.read(chatByIdProvider(chatId));
  final bool isBot = BotDetector.isBot(
    peerName ?? chat?.username,
    isBotChat: chat?.isBotChat ?? false,
  );
  if (isBot) {
    throw const CallStartException(CallStartFailure.botForbidden);
  }

  bool isListener = false;
  final bool perm =
      await PermissionService().requestCallPermissions(video: false);
  if (!perm) {
    // Spec: "Если микрофон и камера недоступны, клиент всё равно подключается слушателем."
    isListener = true;
  }
  onPermissionResult?.call(isListener);

  final Random random = Random.secure();
  final String roomId =
      List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
  final String nickname =
      ref.read(authProvider).session?.displayName ?? 'User';

  final Map<String, dynamic> result = await ref
      .read(callRepositoryProvider)
      .initiate(
        chatId: chatId,
        roomId: roomId,
        callerNickname: nickname,
        isVideo: isVideo,
      );

  final bool isCallsTester =
      ref.read(authProvider).profile?.isCallsTester ?? false;
  final ApiCallInitiateResult initResult =
      ApiCallInitiateResult.fromJson(result, isCallsTester: isCallsTester);
  final ApiCallGatewayInfo gatewayInfo = initResult.gatewayInfo ??
      ApiCallGatewayInfo.defaultFor(isCallsTester: isCallsTester);

  int? parseId(dynamic val) {
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }
  final dynamic payload = result['payload'];
  final int callId = parseId(payload is Map ? payload['message_id'] : null) ??
      parseId(payload is Map ? payload['call_id'] : null) ??
      parseId(result['message_id']) ??
      parseId(result['call_id']) ??
      (initResult.callId > 0 ? initResult.callId : 0);
  if (callId <= 0) {
    throw Exception('Failed to obtain a valid call session ID from server');
  }

  final CallSessionManager manager = CallSessionManager(
    ref: ref.read(callRefProvider),
    chatId: chatId,
    callId: callId,
    roomId: roomId,
    isVideo: false,
    direction: CallDirection.outgoing,
    displayName: nickname,
    peerName: peerName ?? chat?.name,
    peerAvatarUrl: peerAvatarUrl ?? chat?.avatarUrl,
    peerUsername: peerUsername ?? chat?.username,
    isListener: isListener,
    gatewayInfo: gatewayInfo,
  );
  ref.read(callSessionProvider.notifier).setSession(manager);
  final Map<String, dynamic> startResponse =
      payload is Map ? Map<String, dynamic>.from(payload) : result;
  unawaited(manager.start(
    startResponse: startResponse,
    peerDisplayName: peerName ?? chat?.name,
  ));
  return callId;
}

/// Shared bootstrap for accepting and joining incoming calls.
Future<void> startIncomingCall({
  required WidgetRef ref,
  required int chatId,
  required int callId,
  required String roomId,
  required bool isVideo,
  String? peerName,
  String? peerAvatarUrl,
  String? peerUsername,
  void Function(bool isListener)? onPermissionResult,
}) async {
  bool isListener = false;
  final bool perm =
      await PermissionService().requestCallPermissions(video: false);
  if (!perm) {
    isListener = true;
  }
  onPermissionResult?.call(isListener);

  final bool isCallsTester =
      ref.read(authProvider).profile?.isCallsTester ?? false;
  final ApiCallGatewayInfo gatewayInfo =
      ApiCallGatewayInfo.defaultFor(isCallsTester: isCallsTester);

  final String nickname =
      ref.read(authProvider).session?.displayName ?? 'User';
  final chat = ref.read(chatByIdProvider(chatId));

  final CallSessionManager manager = CallSessionManager(
    ref: ref.read(callRefProvider),
    chatId: chatId,
    callId: callId,
    roomId: roomId,
    isVideo: false,
    direction: CallDirection.incoming,
    displayName: nickname,
    peerName: peerName ?? chat?.name,
    peerAvatarUrl: peerAvatarUrl ?? chat?.avatarUrl,
    peerUsername: peerUsername ?? chat?.username,
    isListener: isListener,
    gatewayInfo: gatewayInfo,
  );
  ref.read(callSessionProvider.notifier).setSession(manager);
  await manager.accept();
}
