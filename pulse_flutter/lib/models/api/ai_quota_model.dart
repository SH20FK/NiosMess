import 'package:flutter/foundation.dart';

@immutable
class AiQuota {
  const AiQuota({
    required this.limitChars,
    required this.usedChars,
    required this.remainingChars,
    required this.usedPercent,
    required this.windowHours,
    this.resetsAt,
  });

  /// Total character quota available in the rolling window (e.g. 50,000 or 200,000 for Plus).
  final int limitChars;

  /// Number of characters used in the current window.
  final int usedChars;

  /// Remaining characters available in the current window.
  final int remainingChars;

  /// Usage percentage (0.0 to 100.0).
  final double usedPercent;

  /// Rolling window duration in hours (default 72h on backend).
  final int windowHours;

  /// Timestamp when the current usage window resets.
  final DateTime? resetsAt;

  /// Backwards-compatibility getters for legacy token nomenclature.
  int get limitTokens => limitChars;
  int get usedTokens => usedChars;
  int get remainingTokens => remainingChars;

  /// True if the user has an active, valid character quota configured.
  bool get isAvailable => limitChars > 0;

  /// Percentage of remaining quota (0.0 to 100.0).
  double get remainingPercent => (100.0 - usedPercent).clamp(0.0, 100.0);

  factory AiQuota.fromJson(Map<String, dynamic> json) {
    final int limit = (json['limit_chars'] as num?)?.toInt() ??
        (json['limit_tokens'] as num?)?.toInt() ??
        0;
    final int used = (json['used_chars'] as num?)?.toInt() ??
        (json['used_tokens'] as num?)?.toInt() ??
        0;
    final int remaining = (json['remaining_chars'] as num?)?.toInt() ??
        (json['remaining_tokens'] as num?)?.toInt() ??
        (limit > used ? limit - used : 0);

    final double rawPercent = (json['used_percent'] as num?)?.toDouble() ??
        (limit > 0 ? (used / limit) * 100.0 : 0.0);

    final int windowHours = (json['window_hours'] as num?)?.toInt() ?? 72;

    DateTime? resetsAt;
    if (json['resets_at'] != null) {
      resetsAt = DateTime.tryParse(json['resets_at'].toString());
    }

    return AiQuota(
      limitChars: limit,
      usedChars: used,
      remainingChars: remaining,
      usedPercent: rawPercent.clamp(0.0, 100.0),
      windowHours: windowHours,
      resetsAt: resetsAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'limit_chars': limitChars,
        'used_chars': usedChars,
        'remaining_chars': remainingChars,
        'used_percent': usedPercent,
        'window_hours': windowHours,
        if (resetsAt != null) 'resets_at': resetsAt!.toIso8601String(),
      };

  AiQuota copyWith({
    int? limitChars,
    int? usedChars,
    int? remainingChars,
    double? usedPercent,
    int? windowHours,
    DateTime? resetsAt,
    // Support legacy copyWith parameter names:
    int? limitTokens,
    int? usedTokens,
    int? remainingTokens,
  }) {
    return AiQuota(
      limitChars: limitChars ?? limitTokens ?? this.limitChars,
      usedChars: usedChars ?? usedTokens ?? this.usedChars,
      remainingChars: remainingChars ?? remainingTokens ?? this.remainingChars,
      usedPercent: usedPercent ?? this.usedPercent,
      windowHours: windowHours ?? this.windowHours,
      resetsAt: resetsAt ?? this.resetsAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiQuota &&
          runtimeType == other.runtimeType &&
          limitChars == other.limitChars &&
          usedChars == other.usedChars &&
          remainingChars == other.remainingChars &&
          usedPercent == other.usedPercent &&
          windowHours == other.windowHours &&
          resetsAt == other.resetsAt;

  @override
  int get hashCode => Object.hash(
        limitChars,
        usedChars,
        remainingChars,
        usedPercent,
        windowHours,
        resetsAt,
      );
}

/// Backwards compatibility alias for legacy code referencing ApiAiUsage.
typedef ApiAiUsage = AiQuota;
