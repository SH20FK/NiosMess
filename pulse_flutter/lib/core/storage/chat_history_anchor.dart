/// Geometry only: no message text, media or keys are part of a scroll bookmark.
class ChatHistoryAnchor {
  const ChatHistoryAnchor({
    required this.messageId,
    required this.fraction,
    this.followingLatest = false,
  });
  final int messageId;

  /// Distance from the viewport bottom to the measured row bottom / height.
  final double fraction;
  final bool followingLatest;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'message_id': messageId,
    'fraction': fraction,
    'following_latest': followingLatest,
  };

  static ChatHistoryAnchor? fromJson(Map<String, dynamic> json) {
    final id = json['message_id'];
    final fraction = json['fraction'];
    if (json['version'] != 1 ||
        id is! int ||
        fraction is! num ||
        !fraction.isFinite ||
        fraction.abs() > 1000000) {
      return null;
    }
    return ChatHistoryAnchor(
      messageId: id,
      fraction: fraction.toDouble(),
      followingLatest: json['following_latest'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChatHistoryAnchor &&
      messageId == other.messageId &&
      fraction == other.fraction &&
      followingLatest == other.followingLatest;
  @override
  int get hashCode => Object.hash(messageId, fraction, followingLatest);
}
