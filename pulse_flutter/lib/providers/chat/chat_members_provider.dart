import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

class ChatMembersNotifier extends AsyncNotifier<List<ApiChatMember>> {
  ChatMembersNotifier(this._chatId);

  final int _chatId;

  @override
  Future<List<ApiChatMember>> build() async {
    final bool authenticated = ref.watch(
      authProvider.select((AuthState state) => state.isAuthenticated),
    );
    if (!authenticated) return const <ApiChatMember>[];
    return _fetch();
  }

  Future<List<ApiChatMember>> _fetch() {
    return ref.read(chatRepositoryProvider).getMembers(_chatId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}

final chatMembersProvider =
    AsyncNotifierProvider.family<ChatMembersNotifier, List<ApiChatMember>, int>(
      ChatMembersNotifier.new,
    );

final myChatRoleProvider = Provider.family<String, int>((Ref ref, int chatId) {
  final int myUserId = ref.watch(
    authProvider.select((AuthState s) => s.session?.userId ?? -1),
  );
  final AsyncValue<List<ApiChatMember>> membersAsync = ref.watch(
    chatMembersProvider(chatId),
  );
  final List<ApiChatMember> members =
      membersAsync.value ?? const <ApiChatMember>[];
  for (final ApiChatMember m in members) {
    if (m.userId == myUserId) return m.role;
  }
  return 'member';
});
