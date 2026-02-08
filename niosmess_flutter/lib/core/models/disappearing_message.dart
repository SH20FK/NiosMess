enum DisappearingDuration {
  off('Выключено', 0),
  fiveSeconds('5 секунд', 5),
  oneMinute('1 минута', 60),
  oneHour('1 час', 3600),
  oneDay('1 день', 86400),
  oneWeek('1 неделя', 604800);

  final String label;
  final int seconds;

  const DisappearingDuration(this.label, this.seconds);

  bool get isEnabled => seconds > 0;

  static DisappearingDuration fromSeconds(int seconds) {
    return values.firstWhere(
      (d) => d.seconds == seconds,
      orElse: () => DisappearingDuration.off,
    );
  }
}

class DisappearingMessage {
  final String messageId;
  final int ttlSeconds;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const DisappearingMessage({
    required this.messageId,
    required this.ttlSeconds,
    required this.createdAt,
    this.expiresAt,
  });

  factory DisappearingMessage.fromJson(Map<String, dynamic> json) {
    return DisappearingMessage(
      messageId: json['message_id'] as String,
      ttlSeconds: json['ttl_seconds'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'ttl_seconds': ttlSeconds,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  // Вычислить оставшееся время
  Duration? get remainingTime {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (expiresAt!.isBefore(now)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  // Форматировать оставшееся время для отображения
  String get remainingTimeText {
    final remaining = remainingTime;
    if (remaining == null) return '';
    if (remaining.inDays > 0) return '${remaining.inDays}д';
    if (remaining.inHours > 0) return '${remaining.inHours}ч';
    if (remaining.inMinutes > 0) return '${remaining.inMinutes}м';
    return '${remaining.inSeconds}с';
  }

  // Прогресс исчезновения (0.0 - 1.0)
  double get disappearanceProgress {
    if (ttlSeconds == 0) return 0.0;
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return (elapsed / ttlSeconds).clamp(0.0, 1.0);
  }
}
