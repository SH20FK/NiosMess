import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories/api_repository.dart';
import 'session_provider.dart';
import 'storage/offline_cache.dart';

class OutboxItem {
  OutboxItem({
    required this.id,
    required this.chatId,
    required this.chatType,
    required this.text,
    required this.createdAt,
    this.replyTo,
    this.msgType,
    this.lat,
    this.lon,
    this.contactData,
  });

  final String id;
  final String chatId;
  final String chatType;
  final String text;
  final String? replyTo;
  final String? msgType;
  final double? lat;
  final double? lon;
  final String? contactData;
  final int createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'chat_id': chatId,
        'chat_type': chatType,
        'text': text,
        'reply_to': replyTo,
        'msg_type': msgType,
        'lat': lat,
        'lon': lon,
        'contact_data': contactData,
        'created_at': createdAt,
      };

  factory OutboxItem.fromJson(Map<String, dynamic> json) {
    return OutboxItem(
      id: json['id']?.toString() ?? '',
      chatId: json['chat_id']?.toString() ?? '',
      chatType: json['chat_type']?.toString() ?? 'user',
      text: json['text']?.toString() ?? '',
      replyTo: json['reply_to']?.toString(),
      msgType: json['msg_type']?.toString(),
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      contactData: json['contact_data']?.toString(),
      createdAt: (json['created_at'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class SendQueueController extends StateNotifier<List<OutboxItem>> {
  SendQueueController(this.ref) : super(const []) {
    _load();
    _scheduleRetry();
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next.isAuthed) {
        _retryDelay = _initialRetryDelay;
        _flush();
      }
    });
  }

  static const _initialRetryDelay = Duration(seconds: 10);
  static const _maxRetryDelay = Duration(minutes: 5);

  final Ref ref;
  final ApiRepository _api = ApiRepository();
  Timer? _timer;
  bool _sending = false;
  final Set<String> _failedIds = {};
  Duration _retryDelay = _initialRetryDelay;

  Future<void> _load() async {
    final raw = await OfflineCache.loadOutbox();
    state = raw.map(OutboxItem.fromJson).toList();
  }

  Future<void> _save() async {
    await OfflineCache.saveOutbox(state.map((e) => e.toJson()).toList());
  }

  Future<void> enqueue(OutboxItem item) async {
    state = [...state, item];
    await _save();
  }

  bool isFailed(String id) => _failedIds.contains(id);

  Future<void> retry(String id) async {
    _failedIds.remove(id);
    await _save();
    await _flush();
  }

  Future<void> retryChat(String chatId) async {
    for (final item in state.where((e) => e.chatId == chatId)) {
      _failedIds.remove(item.id);
    }
    await _save();
    await _flush();
  }

  void _scheduleRetry() {
    _timer?.cancel();
    _timer = Timer(_retryDelay, () {
      _flush();
      _scheduleRetry();
    });
  }

  Future<void> clearAll() async {
    _failedIds.clear();
    state = const [];
    await _save();
  }

  Future<void> _flush() async {
    if (_sending || state.isEmpty) return;
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    _sending = true;
    bool hadSuccess = false;
    bool hadFailure = false;
    try {
      final queue = List<OutboxItem>.from(state);
      for (final item in queue) {
        try {
          if (item.chatType == 'group' || item.chatType == 'channel') {
            await _api.sendCollective(
              item.chatId,
              session.username!,
              item.text,
              session.token!,
              replyTo: item.replyTo,
              msgType: item.msgType,
              lat: item.lat,
              lon: item.lon,
              contactData: item.contactData,
            );
          } else {
            await _api.sendMessageUser(
              session.username!,
              item.chatId,
              item.text,
              session.token!,
              replyTo: item.replyTo,
              msgType: item.msgType,
              lat: item.lat,
              lon: item.lon,
              contactData: item.contactData,
            );
          }
          state = state.where((e) => e.id != item.id).toList();
          _failedIds.remove(item.id);
          hadSuccess = true;
          await _save();
        } catch (e) {
          _failedIds.add(item.id);
          hadFailure = true;
          debugPrint('SendQueue: failed to send ${item.id}: $e');
        }
      }
    } finally {
      _sending = false;
      // Exponential backoff on failure, reset on success
      if (hadSuccess && !hadFailure) {
        _retryDelay = _initialRetryDelay;
      } else if (hadFailure) {
        _retryDelay = Duration(
          seconds: (_retryDelay.inSeconds * 2).clamp(
            _initialRetryDelay.inSeconds,
            _maxRetryDelay.inSeconds,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sendQueueProvider =
    StateNotifierProvider<SendQueueController, List<OutboxItem>>(
  (ref) => SendQueueController(ref),
);
