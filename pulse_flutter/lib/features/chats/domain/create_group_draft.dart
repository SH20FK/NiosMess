import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/features/chats/domain/member_candidate.dart';

@immutable
class CreateGroupDraft {
  const CreateGroupDraft({
    this.name = '',
    this.description = '',
    this.isPrivate = false,
    this.selectedMembers = const <MemberCandidate>[],
  });

  final String name;
  final String description;
  final bool isPrivate;
  final List<MemberCandidate> selectedMembers;

  int get memberCount => selectedMembers.length;
  bool get hasMembers => selectedMembers.isNotEmpty;

  CreateGroupDraft copyWith({
    String? name,
    String? description,
    bool? isPrivate,
    List<MemberCandidate>? selectedMembers,
  }) {
    return CreateGroupDraft(
      name: name ?? this.name,
      description: description ?? this.description,
      isPrivate: isPrivate ?? this.isPrivate,
      selectedMembers: selectedMembers ?? this.selectedMembers,
    );
  }
}
