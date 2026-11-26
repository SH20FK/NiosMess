import 'package:pulse_flutter/core/utils/datetime_helpers.dart';

class ApiCallGatewayInfo {
  const ApiCallGatewayInfo({
    required this.callAccessToken,
    required this.signalUrl,
    required this.iceServers,
    this.maxVideoHeight = 480,
    this.maxScreenHeight = 480,
    this.maxFps = 30,
    this.isPlus = false,
    this.isGroup = false,
    this.maxDurationSeconds = 1800,
  });

  final String callAccessToken;
  final String signalUrl;
  final List<Map<String, dynamic>> iceServers;
  final int maxVideoHeight;
  final int maxScreenHeight;
  final int maxFps;
  final bool isPlus;
  final bool isGroup;
  final int? maxDurationSeconds;

  factory ApiCallGatewayInfo.defaultFor({
    bool isCallsTester = false,
    bool isNiosPlus = false,
    bool isGroup = false,
    String token = '',
    String signalUrl = '',
  }) {
    final int defaultHeight = isNiosPlus ? 1440 : (isCallsTester ? 720 : 480);
    return ApiCallGatewayInfo(
      callAccessToken: token,
      signalUrl: signalUrl,
      iceServers: const <Map<String, dynamic>>[
        <String, dynamic>{'urls': 'stun:c.ni-os.ru:3478'},
        <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
      ],
      maxVideoHeight: defaultHeight,
      maxScreenHeight: defaultHeight,
      maxFps: isNiosPlus ? 60 : 30,
      isPlus: isNiosPlus,
      isGroup: isGroup,
      maxDurationSeconds: (isCallsTester || isNiosPlus) ? null : 1800,
    );
  }

  factory ApiCallGatewayInfo.fromJson(
    Map<String, dynamic> json, {
    bool isCallsTester = false,
    bool isNiosPlus = false,
    bool isGroup = false,
  }) {
    final dynamic rawIce = json['ice_servers'];
    final List<Map<String, dynamic>> iceList;
    if (rawIce is List) {
      iceList = rawIce
          .whereType<Map>()
          .map(
            (Map m) => m.map(
              (dynamic k, dynamic v) => MapEntry(k.toString(), v),
            ),
          )
          .toList(growable: false);
    } else {
      iceList = const <Map<String, dynamic>>[];
    }

    final bool resolvedPlus = json['is_plus'] as bool? ?? isNiosPlus;
    final bool resolvedGroup = json['is_group'] as bool? ?? isGroup;
    final int defaultHeight = resolvedPlus ? 1440 : (isCallsTester ? 720 : 480);
    final int? defaultDuration = (isCallsTester || resolvedPlus) ? null : 1800;
    final int parsedHeight =
        (json['max_video_height'] as num?)?.toInt() ?? defaultHeight;

    return ApiCallGatewayInfo(
      callAccessToken: json['call_access_token'] as String? ?? '',
      signalUrl: json['signal_url'] as String? ?? '',
      iceServers: iceList,
      maxVideoHeight: parsedHeight,
      maxScreenHeight:
          (json['max_screen_height'] as num?)?.toInt() ?? parsedHeight,
      maxFps: (json['max_fps'] as num?)?.toInt() ?? (resolvedPlus ? 60 : 30),
      isPlus: resolvedPlus,
      isGroup: resolvedGroup,
      maxDurationSeconds: json.containsKey('max_duration_seconds')
          ? (json['max_duration_seconds'] as num?)?.toInt()
          : defaultDuration,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'call_access_token': callAccessToken,
        'signal_url': signalUrl,
        'ice_servers': iceServers,
        'max_video_height': maxVideoHeight,
        'max_screen_height': maxScreenHeight,
        'max_fps': maxFps,
        'is_plus': isPlus,
        'is_group': isGroup,
        if (maxDurationSeconds != null)
          'max_duration_seconds': maxDurationSeconds,
      };
}

class ApiCallInitiateResult {
  const ApiCallInitiateResult({
    required this.callId,
    required this.chatId,
    required this.status,
    required this.callType,
    required this.message,
    this.gatewayInfo,
  });

  final int callId;
  final int chatId;
  final String status;
  final String callType;
  final String message;
  final ApiCallGatewayInfo? gatewayInfo;

  factory ApiCallInitiateResult.fromJson(
    Map<String, dynamic> json, {
    bool isCallsTester = false,
  }) {
    final Map<String, dynamic> payload = json['payload'] is Map
        ? (json['payload'] as Map).map(
            (dynamic k, dynamic v) => MapEntry(k.toString(), v),
          )
        : json;

    final bool hasGateway = payload.containsKey('call_access_token') ||
        payload.containsKey('signal_url') ||
        payload.containsKey('ice_servers');

    final dynamic rawMessage = json['message'] ?? payload['message'];
    final String parsedMessage;
    if (rawMessage is String) {
      parsedMessage = rawMessage;
    } else if (rawMessage is Map) {
      parsedMessage = rawMessage['content']?.toString() ??
          rawMessage['id']?.toString() ??
          '';
    } else {
      parsedMessage = rawMessage?.toString() ?? '';
    }

    final int parsedCallId = (json['call_id'] as num?)?.toInt() ??
        (payload['message_id'] as num?)?.toInt() ??
        (payload['call_id'] as num?)?.toInt() ??
        0;
    final int parsedChatId = (json['chat_id'] as num?)?.toInt() ??
        (payload['chat_id'] as num?)?.toInt() ??
        0;
    final String parsedStatus = json['status']?.toString() ??
        payload['status']?.toString() ??
        'ringing';
    final String parsedCallType = json['call_type']?.toString() ??
        payload['call_type']?.toString() ??
        'voice';

    return ApiCallInitiateResult(
      callId: parsedCallId,
      chatId: parsedChatId,
      status: parsedStatus,
      callType: parsedCallType,
      message: parsedMessage,
      gatewayInfo: hasGateway
          ? ApiCallGatewayInfo.fromJson(payload, isCallsTester: isCallsTester)
          : null,
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
