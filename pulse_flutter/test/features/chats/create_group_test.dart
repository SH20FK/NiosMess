import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/features/chats/application/create_group_controller.dart';
import 'package:pulse_flutter/features/chats/domain/create_group_draft.dart';
import 'package:pulse_flutter/features/chats/domain/member_candidate.dart';

void main() {
  group('CreateGroupDraft', () {
    test('default values are empty and safe', () {
      const draft = CreateGroupDraft();
      expect(draft.name, isEmpty);
      expect(draft.description, isEmpty);
      expect(draft.isPrivate, isFalse);
      expect(draft.selectedMembers, isEmpty);
      expect(draft.memberCount, 0);
      expect(draft.hasMembers, isFalse);
    });

    test('memberCount and hasMembers reflect selected candidates', () {
      const candidate1 = MemberCandidate(
        userId: 101,
        displayName: 'Alice',
        username: 'alice',
      );
      const candidate2 = MemberCandidate(
        userId: 102,
        displayName: 'Bob',
        username: 'bob',
      );

      final draft = const CreateGroupDraft().copyWith(
        selectedMembers: const <MemberCandidate>[candidate1, candidate2],
      );

      expect(draft.memberCount, 2);
      expect(draft.hasMembers, isTrue);
    });
  });

  group('CreateGroupController', () {
    test('toggling members adds and removes candidates correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(createGroupControllerProvider.notifier);

      const candidate1 = MemberCandidate(
        userId: 101,
        displayName: 'Alice',
        username: 'alice',
      );

      notifier.toggleMember(candidate1);
      var state = container.read(createGroupControllerProvider);
      expect(state.draft.selectedMembers.length, 1);
      expect(state.draft.selectedMembers.first.userId, 101);

      // Toggle again to remove
      notifier.toggleMember(candidate1);
      state = container.read(createGroupControllerProvider);
      expect(state.draft.selectedMembers, isEmpty);
    });

    test('removeMember removes candidate by userId', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(createGroupControllerProvider.notifier);

      const candidate1 = MemberCandidate(userId: 101, displayName: 'Alice', username: 'alice');
      const candidate2 = MemberCandidate(userId: 102, displayName: 'Bob', username: 'bob');

      notifier.toggleMember(candidate1);
      notifier.toggleMember(candidate2);
      expect(container.read(createGroupControllerProvider).draft.memberCount, 2);

      notifier.removeMember(101);
      final state = container.read(createGroupControllerProvider);
      expect(state.draft.memberCount, 1);
      expect(state.draft.selectedMembers.first.userId, 102);
    });

    test('submit rejects names shorter than 2 characters without calling repository', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(createGroupControllerProvider.notifier);
      notifier.setName('A');

      final result = await notifier.submit();
      expect(result, isNull);

      final state = container.read(createGroupControllerProvider);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('не менее 2'));
    });
  });
}
