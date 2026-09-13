import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';

enum CallType {
  incoming,
  outgoing,
  missed,
}

class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.chatId,
    required this.peerUsername,
    required this.peerDisplayName,
    this.peerId,
    this.peerAvatarUrl,
    this.isVideo = false,
    this.isOutgoing = false,
    this.isMissed = false,
    this.durationSeconds = 0,
    required this.timestamp,
  });

  final String id;
  final int chatId;
  final int? peerId;
  final String peerUsername;
  final String peerDisplayName;
  final String? peerAvatarUrl;
  final bool isVideo;
  final bool isOutgoing;
  final bool isMissed;
  final int durationSeconds;
  final DateTime timestamp;

  CallType get callType {
    if (isMissed) return CallType.missed;
    if (isOutgoing) return CallType.outgoing;
    return CallType.incoming;
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final int minutes = durationSeconds ~/ 60;
    final int seconds = durationSeconds % 60;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
    return '$seconds с';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'chat_id': chatId,
        'peer_id': peerId,
        'peer_username': peerUsername,
        'peer_display_name': peerDisplayName,
        'peer_avatar_url': peerAvatarUrl,
        'is_video': isVideo,
        'is_outgoing': isOutgoing,
        'is_missed': isMissed,
        'duration_seconds': durationSeconds,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CallLogEntry.fromJson(Map<String, dynamic> json) {
    return CallLogEntry(
      id: json['id'] as String? ?? '',
      chatId: (json['chat_id'] as num?)?.toInt() ?? 0,
      peerId: (json['peer_id'] as num?)?.toInt(),
      peerUsername: json['peer_username'] as String? ?? '',
      peerDisplayName: json['peer_display_name'] as String? ??
          json['peer_username'] as String? ??
          'Unknown',
      peerAvatarUrl: json['peer_avatar_url'] as String?,
      isVideo: json['is_video'] == true,
      isOutgoing: json['is_outgoing'] == true,
      isMissed: json['is_missed'] == true,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class CallHistoryNotifier extends Notifier<List<CallLogEntry>> {
  static const String _storageKey = 'niosmess_call_history_v1';

  @override
  List<CallLogEntry> build() {
    _loadFromStorage();
    return const <CallLogEntry>[];
  }

  Future<void> _loadFromStorage() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List) {
          final List<CallLogEntry> list = decoded
              .whereType<Map>()
              .map((Map m) =>
                  CallLogEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList(growable: false);
          state = list;
        }
      }
    } catch (_) {}

    // Auto-sync with current chat list
    final List<ApiChatSummary>? chats = ref.read(chatsProvider).value;
    final int myUserId = ref.read(authProvider).session?.userId ?? 0;
    if (chats != null && chats.isNotEmpty) {
      syncFromChats(chats, myUserId);
    }
  }

  Future<void> addEntry(CallLogEntry entry) async {
    // Prevent duplicate entries with same ID or same chat within 5 seconds
    final List<CallLogEntry> updated = <CallLogEntry>[
      entry,
      ...state.where((CallLogEntry e) => e.id != entry.id),
    ];
    // Keep max 150 items
    final List<CallLogEntry> capped =
        updated.take(150).toList(growable: false);
    state = capped;
    await _saveToStorage(capped);
  }

  Future<void> removeEntry(String id) async {
    final List<CallLogEntry> updated =
        state.where((CallLogEntry e) => e.id != id).toList(growable: false);
    state = updated;
    await _saveToStorage(updated);
  }

  Future<void> clearHistory() async {
    state = const <CallLogEntry>[];
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  /// Extracts call records from chat messages and merges with local log
  void syncFromChats(List<ApiChatSummary> chats, int currentUserId) {
    final List<CallLogEntry> current = List<CallLogEntry>.from(state);
    final Set<String> existingIds = current.map((CallLogEntry e) => e.id).toSet();
    bool changed = false;

    for (final ApiChatSummary chat in chats) {
      if (chat.chatType != 'direct') continue;
      final ApiMessage? msg = chat.lastMessage;
      if (msg == null || !msg.isCallEvent) continue;

      final String entryId = 'chat_${chat.id}_msg_${msg.id}';
      if (existingIds.contains(entryId)) continue;

      final String content = msg.content.toLowerCase();
      final bool isVideo = msg.content.contains('Видеозвонок') ||
          msg.content.startsWith('📹') ||
          (msg.mediaType?.contains('video') ?? false);
      final bool isMissed =
          content.contains('пропущен') || content.contains('отклон');
      final bool isOutgoing =
          currentUserId > 0 && msg.senderId == currentUserId;

      current.add(CallLogEntry(
        id: entryId,
        chatId: chat.id,
        peerId: isOutgoing ? null : msg.senderId,
        peerUsername: chat.username ?? '',
        peerDisplayName: chat.name,
        peerAvatarUrl: chat.avatarUrl,
        isVideo: isVideo,
        isOutgoing: isOutgoing,
        isMissed: isMissed,
        durationSeconds: msg.mediaDuration ?? 0,
        timestamp: msg.sentAt,
      ));
      existingIds.add(entryId);
      changed = true;
    }

    if (changed) {
      current.sort((CallLogEntry a, CallLogEntry b) =>
          b.timestamp.compareTo(a.timestamp));
      state = current.take(150).toList(growable: false);
      _saveToStorage(state);
    }
  }

  Future<void> _saveToStorage(List<CallLogEntry> list) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String encoded =
          jsonEncode(list.map((CallLogEntry e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }
}

final NotifierProvider<CallHistoryNotifier, List<CallLogEntry>>
    callHistoryProvider =
    NotifierProvider<CallHistoryNotifier, List<CallLogEntry>>(
  CallHistoryNotifier.new,
);

final Provider<int> missedCallsCountProvider = Provider<int>((Ref ref) {
  final List<CallLogEntry> list = ref.watch(callHistoryProvider);
  return list.where((CallLogEntry e) => e.isMissed).length;
});
