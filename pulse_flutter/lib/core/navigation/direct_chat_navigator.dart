import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';

/// Interactive phase of a navigation action button.
enum ActionPhase { idle, pending, error }

/// Opens a direct chat instantly if known or cached, or resolves it asynchronously
/// without full-screen interstitial loading screens or blocking [list_chats] requests.
Future<int?> navigateToDirectChat(
  BuildContext context,
  WidgetRef ref, {
  required String username,
  int? userId,
  int? knownChatId,
  bool isSecret = false,
}) async {
  final String cleanUsername = username.trim().toLowerCase();

  String? myPublicKey;
  if (isSecret) {
    try {
      myPublicKey = await ref.read(e2eeServiceProvider).getPublicKeyBase64();
    } catch (_) {}
  }

  // 1. Fast path: chat ID already known or found in local chats list
  final int? fastId = isSecret
      ? ref.read(chatsProvider).value?.where((ApiChatSummary c) {
          final String? partnerKey = c.partnerPublicKey;
          final bool usableKey = partnerKey != null &&
              partnerKey.isNotEmpty &&
              partnerKey != myPublicKey;
          return c.chatType == 'direct' &&
              c.isSecret &&
              usableKey &&
              c.username?.trim().toLowerCase() == cleanUsername;
        }).firstOrNull?.id
      : ((knownChatId != null && knownChatId > 0)
          ? knownChatId
          : ref.read(chatsProvider).value?.where((ApiChatSummary c) {
              return c.chatType == 'direct' &&
                  !c.isSecret &&
                  c.username?.trim().toLowerCase() == cleanUsername;
            }).firstOrNull?.id);

  if (fastId != null && fastId > 0) {
    if (context.mounted) {
      context.push('/chat/$fastId');
    }
    return fastId;
  }

  // 2. Slow path: resolve asynchronously without full-screen interstitial
  try {
    String? publicKey;
    String? targetPublicKey;
    if (isSecret) {
      publicKey = myPublicKey ??
          await ref.read(e2eeServiceProvider).getPublicKeyBase64();
      if (publicKey.isNotEmpty) {
        try {
          await ref.read(authRepositoryProvider).setPublicKey(publicKey);
        } catch (_) {}
      }

      if (userId == null || userId <= 0) {
        debugPrint('[navigateToDirectChat] secret chat needs a target user id');
        return null;
      }
      final ApiPublicKeyResult keys =
          await ref.read(authRepositoryProvider).getPublicKey(userId);
      final List<ApiKeyDevice> candidates = keys.devices
          .where((ApiKeyDevice d) => d.publicKey.isNotEmpty)
          .toList()
        ..sort((ApiKeyDevice a, ApiKeyDevice b) =>
            b.sessionId.compareTo(a.sessionId));
      final Set<String> knownKeys = <String>{
        for (final ApiChatSummary c in ref.read(chatsProvider).value ?? const <ApiChatSummary>[])
          if (c.chatType == 'direct' &&
              c.isSecret &&
              c.username?.trim().toLowerCase() == cleanUsername &&
              (c.partnerPublicKey ?? '').isNotEmpty &&
              c.partnerPublicKey != publicKey)
            c.partnerPublicKey!,
      };
      targetPublicKey = candidates
              .where((ApiKeyDevice d) => knownKeys.contains(d.publicKey))
              .firstOrNull
              ?.publicKey ??
          candidates.firstOrNull?.publicKey;
      if (targetPublicKey == null) {
        debugPrint('[navigateToDirectChat] user $userId has no E2EE device key');
        return null;
      }
    }

    final DirectChatOpenResult? result = await ref.read(chatRepositoryProvider).openDirectChat(
      username: username,
      userId: userId,
      isSecret: isSecret,
      publicKey: publicKey,
      targetPublicKey: targetPublicKey,
    );

    if (result == null || result.chatId <= 0) {
      return null;
    }

    final withUser = result.withUser;
    final ApiChatSummary? existingChat = ref.read(chatByIdProvider(result.chatId));
    final ApiChatSummary syntheticChat = (existingChat ??
            ApiChatSummary(
              id: result.chatId,
              chatType: 'direct',
              name: (withUser?.displayName.isNotEmpty == true
                  ? withUser!.displayName
                  : (withUser?.username ?? username)),
              username: (withUser?.username.isNotEmpty == true
                  ? withUser!.username
                  : username),
              unreadCount: 0,
              membersCount: 2,
              partnerUserId: withUser?.id ?? userId,
              isSecret: result.isSecret || isSecret,
              partnerPublicKey: withUser?.publicKey,
            ))
        .copyWith(
      name: (withUser?.displayName.isNotEmpty == true
              ? withUser!.displayName
              : existingChat?.name) ??
          username,
      username: (withUser?.username.isNotEmpty == true
              ? withUser!.username
              : existingChat?.username) ??
          username,
      partnerUserId: withUser?.id ?? existingChat?.partnerUserId ?? userId,
      isSecret: result.isSecret || isSecret,
      partnerPublicKey: withUser?.publicKey ?? existingChat?.partnerPublicKey,
    );

    ref.read(chatsProvider.notifier).upsertChat(syntheticChat);

    // Full list_chats refresh happens strictly in the background without blocking navigation
    unawaited(ref.read(chatsProvider.notifier).refresh());

    if (context.mounted) {
      context.push('/chat/${result.chatId}');
    }
    return result.chatId;
  } catch (e, st) {
    debugPrint('[navigateToDirectChat] failed: $e\n$st');
    return null;
  }
}

/// Convenience alias for [navigateToDirectChat].
Future<int?> openDirectChat(
  BuildContext context,
  WidgetRef ref, {
  required String username,
  int? userId,
  int? knownChatId,
  bool isSecret = false,
}) =>
    navigateToDirectChat(
      context,
      ref,
      username: username,
      userId: userId,
      knownChatId: knownChatId,
      isSecret: isSecret,
    );

