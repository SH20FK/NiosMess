import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/features/chats/domain/create_group_draft.dart';
import 'package:pulse_flutter/features/chats/domain/member_candidate.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

@immutable
class CreateGroupState {
  const CreateGroupState({
    this.draft = const CreateGroupDraft(),
    this.isSubmitting = false,
    this.errorMessage,
  });

  final CreateGroupDraft draft;
  final bool isSubmitting;
  final String? errorMessage;

  CreateGroupState copyWith({
    CreateGroupDraft? draft,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return CreateGroupState(
      draft: draft ?? this.draft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

class CreateGroupController extends Notifier<CreateGroupState> {
  @override
  CreateGroupState build() {
    return const CreateGroupState();
  }

  void reset() {
    state = const CreateGroupState();
  }

  void toggleMember(MemberCandidate candidate) {
    final current = List<MemberCandidate>.from(state.draft.selectedMembers);
    final index = current.indexWhere((m) => m.userId == candidate.userId);
    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.add(candidate);
    }
    state = state.copyWith(
      draft: state.draft.copyWith(selectedMembers: current),
    );
  }

  void removeMember(int userId) {
    final current = state.draft.selectedMembers
        .where((m) => m.userId != userId)
        .toList(growable: false);
    state = state.copyWith(
      draft: state.draft.copyWith(selectedMembers: current),
    );
  }

  void setName(String name) {
    state = state.copyWith(
      draft: state.draft.copyWith(name: name),
      errorMessage: null,
    );
  }

  void setDescription(String description) {
    state = state.copyWith(
      draft: state.draft.copyWith(description: description),
    );
  }

  void setIsPrivate(bool isPrivate) {
    state = state.copyWith(
      draft: state.draft.copyWith(isPrivate: isPrivate),
    );
  }

  Future<ChatCreateResult?> submit() async {
    final name = state.draft.name.trim();
    if (name.length < 2) {
      state = state.copyWith(
        errorMessage: 'Название группы должно содержать не менее 2 символов',
      );
      return null;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final memberIds = state.draft.selectedMembers
          .map((m) => m.userId)
          .where((id) => id > 0)
          .toList(growable: false);

      final result = await repo.createChat(
        name: name,
        chatType: 'group',
        description: state.draft.description.trim().isNotEmpty
            ? state.draft.description.trim()
            : null,
        isPrivate: state.draft.isPrivate,
        memberUserIds: memberIds,
      );

      if (result == null) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Не удалось создать группу. Попробуйте снова.',
        );
        return null;
      }

      // Invalidate chat list cache
      ref.invalidate(chatsProvider);

      state = state.copyWith(isSubmitting: false);
      return result;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Ошибка при создании группы: $e',
      );
      return null;
    }
  }
}

final createGroupControllerProvider =
    NotifierProvider<CreateGroupController, CreateGroupState>(
  CreateGroupController.new,
);
