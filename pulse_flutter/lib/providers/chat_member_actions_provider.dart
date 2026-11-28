import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/chat/chat_members_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

/// Member mutations for a single chat.
///
/// Every write goes through the repository and then refreshes
/// [chatMembersProvider], so the screen never keeps its own copy of the list
/// and never has to invalidate anything by hand.
class ChatMemberActionsNotifier extends Notifier<void> {
  ChatMemberActionsNotifier(this.chatId);

  final int chatId;

  @override
  void build() {}

  Future<void> invite(int userId) async {
    await ref.read(chatRepositoryProvider).inviteUser(chatId, userId);
    await refreshMembers();
  }

  Future<void> promote(int userId, String role) async {
    await ref.read(chatRepositoryProvider).promoteUser(chatId, userId, role);
    await refreshMembers();
  }

  Future<void> ban(int userId, {bool ban = true}) async {
    await ref.read(chatRepositoryProvider).banUser(chatId, userId, ban);
    await refreshMembers();
  }

  Future<void> refreshMembers() {
    return ref.read(chatMembersProvider(chatId).notifier).refresh();
  }
}

final chatMemberActionsProvider =
    NotifierProvider.family<ChatMemberActionsNotifier, void, int>(
      ChatMemberActionsNotifier.new,
    );
