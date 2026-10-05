import 'package:flutter/foundation.dart';

@immutable
class SessionCapabilities {
  const SessionCapabilities({
    this.calls = true,
    this.secretChats = true,
  });

  final bool calls;
  final bool secretChats;

  factory SessionCapabilities.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SessionCapabilities();
    return SessionCapabilities(
      calls: map['calls'] as bool? ?? true,
      secretChats: map['secret_chats'] as bool? ?? true,
    );
  }
}

@immutable
class AccountSession {
  const AccountSession({
    required this.id,
    required this.isCurrent,
    required this.deviceName,
    required this.platform,
    this.osVersion,
    this.appName = 'NiosMess',
    this.appVersion = '',
    required this.ipAddress,
    this.approximateRegion,
    required this.createdAt,
    required this.lastActiveAt,
    this.capabilities = const SessionCapabilities(),
  });

  final int id;
  final bool isCurrent;
  final String deviceName;
  final String platform;
  final String? osVersion;
  final String appName;
  final String appVersion;
  final String ipAddress;
  final String? approximateRegion;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final SessionCapabilities capabilities;

  factory AccountSession.fromJson(Map<String, dynamic> json, {int? currentSessionId}) {
    final int id = json['id'] as int? ?? 0;
    final bool isCurrent = json['is_current'] as bool? ?? (currentSessionId != null && id == currentSessionId);
    final String rawDevice = json['device_info']?.toString() ?? json['device_name']?.toString() ?? 'Неизвестное устройство';
    final String ip = json['ip_address']?.toString() ?? '127.0.0.1';
    
    DateTime created = DateTime.now();
    if (json['created_at'] != null) {
      try {
        created = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    DateTime active = created;
    if (json['last_active'] != null || json['last_active_at'] != null) {
      try {
        active = DateTime.parse((json['last_active_at'] ?? json['last_active']).toString());
      } catch (_) {}
    }

    String platform = 'unknown';
    final String lower = rawDevice.toLowerCase();
    if (lower.contains('android')) {
      platform = 'Android';
    } else if (lower.contains('ios') || lower.contains('iphone') || lower.contains('ipad')) {
      platform = 'iOS';
    } else if (lower.contains('windows') || lower.contains('win32')) {
      platform = 'Windows';
    } else if (lower.contains('mac') || lower.contains('darwin')) {
      platform = 'macOS';
    } else if (lower.contains('linux')) {
      platform = 'Linux';
    } else if (lower.contains('web') || lower.contains('chrome') || lower.contains('firefox')) {
      platform = 'Web';
    }

    return AccountSession(
      id: id,
      isCurrent: isCurrent,
      deviceName: rawDevice,
      platform: platform,
      osVersion: json['os_version']?.toString(),
      appName: json['app_name']?.toString() ?? 'NiosMess',
      appVersion: json['app_version']?.toString() ?? '',
      ipAddress: ip,
      approximateRegion: json['approximate_region']?.toString(),
      createdAt: created,
      lastActiveAt: active,
      capabilities: SessionCapabilities.fromMap(json['capabilities'] as Map<String, dynamic>?),
    );
  }
}
