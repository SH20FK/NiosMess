import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';

enum MemberCandidateSource {
  recentDirect,
  globalSearch,
  usernameLookup,
}

/// Domain model representing a validated participant candidate.
/// Guarantees that [userId] corresponds strictly to a user identity,
/// never a chat ID or placeholder 0.
@immutable
class MemberCandidate {
  const MemberCandidate({
    required this.userId,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.source = MemberCandidateSource.globalSearch,
  });

  final int userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final MemberCandidateSource source;

  bool get isResolved => userId > 0;

  String get semanticLabel => displayName.isNotEmpty ? displayName : username;

  factory MemberCandidate.fromSearchUser(
    ApiSearchUser user, {
    MemberCandidateSource source = MemberCandidateSource.globalSearch,
  }) {
    return MemberCandidate(
      userId: user.id,
      displayName: user.displayName.isNotEmpty ? user.displayName : user.username,
      username: user.username,
      avatarUrl: user.avatarUrl,
      source: source,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberCandidate &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() =>
      'MemberCandidate(userId: $userId, name: $displayName, username: @$username, source: $source)';
}

/// Safely resolves a member candidate from a direct chat summary.
/// Strictly utilizes [ApiChatSummary.partnerUserId] instead of chat ID.
MemberCandidate? candidateFromDirectChat(ApiChatSummary chat) {
  final int? partnerId = chat.partnerUserId;
  if (chat.chatType != 'direct' || partnerId == null || partnerId <= 0) {
    return null;
  }
  return MemberCandidate(
    userId: partnerId,
    displayName: chat.name,
    username: chat.username ?? '',
    avatarUrl: chat.avatarUrl,
    source: MemberCandidateSource.recentDirect,
  );
}
