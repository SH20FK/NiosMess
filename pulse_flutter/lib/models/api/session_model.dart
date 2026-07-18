import 'package:pulse_flutter/core/utils/datetime_helpers.dart';

class ApiSession {
  const ApiSession({
    required this.id,
    required this.deviceInfo,
    required this.ipAddress,
    required this.createdAt,
    required this.lastActive,
  });

  final int id;
  final String deviceInfo;
  final String ipAddress;
  final DateTime createdAt;
  final DateTime lastActive;

  factory ApiSession.fromJson(Map<String, dynamic> json) {
    return ApiSession(
      id: json['id'] as int? ?? 0,
      deviceInfo: json['device_info'] as String? ?? '',
      ipAddress: json['ip_address'] as String? ?? '',
      createdAt: parseApiDateTime(json['created_at'] as String?),
      lastActive: parseApiDateTime(json['last_active'] as String?),
    );
  }
}
