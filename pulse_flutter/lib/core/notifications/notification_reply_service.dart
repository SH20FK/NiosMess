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
  AccountNotificationReplyService(this.ref)
    : _accountId = ref.read(authProvider).session?.userId,
      _token = ref.read(authProvider).session?.accessToken;
  final Ref ref;
  final int? _accountId;
  final String? _token;

  int _requireCurrentAccount() {
    if (!ref.mounted || _accountId == null || _token == null) {
      throw StateError('NOTIFICATION_ACCOUNT_CHANGED');
    }
    final auth = ref.read(authProvider);
    if (auth.session?.userId != _accountId ||
        auth.session?.accessToken != _token ||
        ref.read(authProvider.notifier).isLoggingOut) {
      throw StateError('NOTIFICATION_ACCOUNT_CHANGED');
    }
    return _accountId;
  }

  @override
  Future<String> loadDraft(int chatId) async {
    final account = _requireCurrentAccount();
    final draft = await NotificationHistoryStore.forAccount(
      account,
    ).readReplyDraft(chatId);
    _requireCurrentAccount();
    return draft;
  }

  @override
  Future<void> saveDraft(int chatId, String text) async {
    final account = _requireCurrentAccount();
    await NotificationHistoryStore.forAccount(
      account,
    ).saveReplyDraft(chatId, text);
    _requireCurrentAccount();
  }

  @override
  Future<void> send(int chatId, String text, {required String localId}) async {
    _requireCurrentAccount();
    // This path owns ordinary E2EE, secret persistence and outgoing state.
    // Never issue send_message directly from an alert or send plaintext to FCM.
    await ref
        .read(chatMessagesProvider(chatId).notifier)
        .sendNotificationReply(text, localId: localId);
    _requireCurrentAccount();
  }
}

final notificationReplyServiceProvider = Provider<NotificationReplyService>((
  ref,
) {
  ref.watch(
    authProvider.select(
      (state) => (state.session?.userId, state.session?.accessToken),
    ),
  );
  return AccountNotificationReplyService(ref);
});
