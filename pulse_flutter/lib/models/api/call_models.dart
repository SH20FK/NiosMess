import 'package:pulse_flutter/core/utils/datetime_helpers.dart';

class ApiCallInitiateResult {
  const ApiCallInitiateResult({
    required this.callId,
    required this.chatId,
    required this.status,
    required this.callType,
    required this.message,
  });

  final int callId;
  final int chatId;
  final String status;
  final String callType;
  final String message;

  factory ApiCallInitiateResult.fromJson(Map<String, dynamic> json) {
    return ApiCallInitiateResult(
      callId: json['call_id'] as int? ?? 0,
      chatId: json['chat_id'] as int? ?? 0,
      status: json['status'] as String? ?? 'ringing',
      callType: json['call_type'] as String? ?? 'voice',
      message: json['message'] as String? ?? '',
    );
  }
}

class ApiCallEndResult {
  const ApiCallEndResult({
    required this.callId,
    required this.status,
    this.durationSeconds,
  });

  final int callId;
  final String status;
  final int? durationSeconds;

  factory ApiCallEndResult.fromJson(Map<String, dynamic> json) {
    return ApiCallEndResult(
      callId: json['call_id'] as int? ?? 0,
      status: json['status'] as String? ?? 'ended',
      durationSeconds: json['duration_seconds'] as int?,
    );
  }
}

class ApiCallParticipant {
  const ApiCallParticipant({required this.userId, required this.joinedAt});

  final int userId;
  final DateTime joinedAt;

  factory ApiCallParticipant.fromJson(Map<String, dynamic> json) {
    return ApiCallParticipant(
      userId: json['user_id'] as int? ?? 0,
      joinedAt: parseApiDateTime(json['joined_at'] as String?),
    );
  }
}

class ApiCallStatus {
  const ApiCallStatus({
    required this.callId,
    required this.chatId,
    required this.initiatorId,
    required this.isVideo,
    required this.status,
    required this.participants,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
  });

  final int callId;
  final int chatId;
  final int initiatorId;
  final bool isVideo;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final List<ApiCallParticipant> participants;

  factory ApiCallStatus.fromJson(Map<String, dynamic> json) {
    final dynamic rawParticipants = json['participants'];
    final List<ApiCallParticipant> participants;
    if (rawParticipants is List) {
      participants = rawParticipants
          .whereType<Map>()
          .map(
            (Map item) => ApiCallParticipant.fromJson(
              item.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .toList(growable: false);
    } else {
      participants = const <ApiCallParticipant>[];
    }

    return ApiCallStatus(
      callId: json['call_id'] as int? ?? 0,
      chatId: json['chat_id'] as int? ?? 0,
      initiatorId: json['initiator_id'] as int? ?? 0,
      isVideo: json['is_video'] as bool? ?? false,
      status: json['status'] as String? ?? 'ringing',
      startedAt: parseApiDateTimeNullable(json['started_at'] as String?),
      endedAt: parseApiDateTimeNullable(json['ended_at'] as String?),
      durationSeconds: json['duration_seconds'] as int?,
      participants: participants,
    );
  }
}
