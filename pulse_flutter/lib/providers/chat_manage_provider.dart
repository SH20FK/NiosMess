import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/chat/chat_list_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

/// Chat settings mutations for a single chat.
///
/// The screen calls these methods instead of touching [chatRepositoryProvider]:
/// each write also refreshes [chatsProvider] so the inbox and every watcher of
/// [chatByIdProvider] see the new name/avatar/link right away.
class ChatManageNotifier extends Notifier<void> {
  ChatManageNotifier(this.chatId);

  final int chatId;

  @override
  void build() {}

  Future<Map<String, dynamic>?> loadInviteLink() {
    return ref.read(chatRepositoryProvider).getInviteLink(chatId);
  }

  Future<Map<String, dynamic>?> rotateInviteLink() async {
    final Map<String, dynamic>? result =
        await ref.read(chatRepositoryProvider).rotateInviteLink(chatId);
    await ref.read(chatsProvider.notifier).refresh();
    return result;
  }

  Future<void> updateChat({
    required String name,
    required String description,
    required String? username,
    bool? commentsEnabled,
  }) async {
    await ref
        .read(chatRepositoryProvider)
        .updateChat(
          chatId,
          name: name,
          description: description,
          username: username,
          commentsEnabled: commentsEnabled,
        );
    await ref.read(chatsProvider.notifier).refresh();
  }

  Future<void> uploadAvatar(List<int> bytes, String filename) async {
    await ref
        .read(chatRepositoryProvider)
        .uploadChatAvatar(chatId, bytes, filename);
    await ref.read(chatsProvider.notifier).refresh();
  }

  Future<void> leaveChat() async {
    await ref.read(chatRepositoryProvider).leaveChat(chatId);
    await ref.read(chatsProvider.notifier).refresh();
  }
}

final chatManageProvider =
    NotifierProvider.family<ChatManageNotifier, void, int>(
      ChatManageNotifier.new,
    );
