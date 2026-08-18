import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/services/calls/nios_calls_api.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/services/permission_service.dart';

/// Why [startOutgoingCall] or [startIncomingCall] refused to start.
enum CallStartFailure { permissions }

class CallStartException implements Exception {
  const CallStartException(this.failure, {this.cause});

  final CallStartFailure failure;
  final Object? cause;

  @override
  String toString() => 'CallStartException($failure${cause == null ? '' : ': $cause'})';
}

/// Derives the shared fallback media key for a call from the ECDH secret
/// with the chat partner. Falls back to a random key for chats without a
/// known partner key — real per-sender media keys come from the in-call
/// ECDH exchange anyway.
Future<Uint8List> deriveCallMediaKey(
  WidgetRef ref, {
  required int chatId,
  required int callId,
}) async {
  final E2eeService e2ee = ref.read(e2eeServiceProvider);
  final String? partnerKey =
      ref.read(chatByIdProvider(chatId))?.partnerPublicKey;
  try {
    if (partnerKey != null && partnerKey.isNotEmpty) {
      final SecretKey key = await e2ee.deriveCallKey(
        callId,
        theirPublicKeyBase64: partnerKey,
      );
      return Uint8List.fromList(await key.extractBytes());
    }
  } catch (_) {}
  final SecretKey random = await AesGcm.with256bits().newSecretKey();
  return Uint8List.fromList(await random.extractBytes());
}

/// Shared bootstrap for outgoing calls (chat screen and /call/dm/:username
/// deep route). Requests permissions, signals the server, creates the SFU
/// room, derives the media key and registers the session in
/// [callSessionProvider]. Returns the server-side call (message) id.
Future<int> startOutgoingCall({
  required WidgetRef ref,
  required int chatId,
  required bool isVideo,
}) async {
  final bool perm =
      await PermissionService().requestCallPermissions(video: isVideo);
  if (!perm) {
    throw const CallStartException(CallStartFailure.permissions);
  }

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

  final int callId =
      (result['payload']?['message_id'] ?? result['message_id'] ?? 0) as int;

  // SFU room creation is best-effort: the transport falls back to WS when the
  // SFU is unreachable.
  try {
    final NiosCallsApi api = NiosCallsApi();
    await api.createRoom(roomId: roomId);
    api.dispose();
  } catch (_) {}

  final Uint8List aesKeyBytes = await deriveCallMediaKey(
    ref,
    chatId: chatId,
    callId: callId,
  );

  final CallSessionManager manager = CallSessionManager(
    ref: ref,
    chatId: chatId,
    callId: callId,
    roomId: roomId,
    isVideo: isVideo,
    direction: CallDirection.outgoing,
    displayName: nickname,
    aesKeyBytes: aesKeyBytes,
  )..start();

  ref.read(callSessionProvider.notifier).setSession(manager);
  return callId;
}

/// Shared bootstrap for accepting and joining incoming calls.
Future<void> startIncomingCall({
  required WidgetRef ref,
  required int chatId,
  required int callId,
  required String roomId,
  required bool isVideo,
}) async {
  final bool perm =
      await PermissionService().requestCallPermissions(video: isVideo);
  if (!perm) {
    throw const CallStartException(CallStartFailure.permissions);
  }

  final String nickname =
      ref.read(authProvider).session?.displayName ?? 'User';

  final Uint8List aesKeyBytes = await deriveCallMediaKey(
    ref,
    chatId: chatId,
    callId: callId,
  );

  final CallSessionManager manager = CallSessionManager(
    ref: ref,
    chatId: chatId,
    callId: callId,
    roomId: roomId,
    isVideo: isVideo,
    direction: CallDirection.incoming,
    displayName: nickname,
    aesKeyBytes: aesKeyBytes,
  )..start();

  ref.read(callSessionProvider.notifier).setSession(manager);
}
