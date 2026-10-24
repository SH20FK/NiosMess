import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'notification_history_store.dart';

abstract class NotificationReplyService {
  Future<String> loadDraft(int chatId);
  Future<void> saveDraft(int chatId, String text);
  Future<void> send(int chatId, String text, {required String localId});
}

class AccountNotificationReplyService implements NotificationReplyService {
  AccountNotificationReplyService(this.ref);
  final Ref ref;
  int get _account =>
      ref.read(authProvider).session?.userId ??
      (throw StateError('NOTIFICATION_ACCOUNT_UNAVAILABLE'));
  @override
  Future<String> loadDraft(int chatId) =>
      NotificationHistoryStore.forAccount(_account).readReplyDraft(chatId);
  @override
  Future<void> saveDraft(int chatId, String text) =>
      NotificationHistoryStore.forAccount(
        _account,
      ).saveReplyDraft(chatId, text);
  @override
  Future<void> send(int chatId, String text, {required String localId}) =>
      // This path owns ordinary E2EE, secret-chat persistence and outgoing state.
      // Never call send_message directly from an alert or pass plaintext to FCM.
      ref
          .read(chatMessagesProvider(chatId).notifier)
          .sendNotificationReply(text, localId: localId);
}

final notificationReplyServiceProvider = Provider<NotificationReplyService>(
  AccountNotificationReplyService.new,
);
