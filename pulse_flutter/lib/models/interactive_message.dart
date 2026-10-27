import 'dart:convert';
import 'package:pulse_flutter/models/api/custom_emoji_model.dart';
import 'package:crypto/crypto.dart';

import 'package:pulse_flutter/models/api/message_model.dart';

/// Carried inside the normal message text, and therefore inside ordinary E2E.
/// No sender identity or plaintext state is trusted from the JSON payload.
class InteractiveMessage {
  const InteractiveMessage(this.data, this.preview);
  static const marker = '\n\u2063nios-interactive-v1:';
  final Map<String, dynamic> data;
  final String preview;
  String get kind => data['kind'] as String;
  String get document => data['document'] as String;
  String get fingerprint {
    final keys = data.keys.toList()..sort();
    return sha256
        .convert(utf8.encode(jsonEncode({for (final k in keys) k: data[k]})))
        .toString();
  }

  bool get isDocument => kind != 'update';
  String get title => (data['title'] as String?) ?? '';
  List<String> get items => (data['items'] as List).cast<String>();
  bool get multiple => data['multiple'] == true;
  int? get correct => data['correct'] as int?;
  String get explanation => (data['explanation'] as String?) ?? '';
  int repeatSeconds(int index) => data['repeat_seconds'] is List
      ? (data['repeat_seconds'] as List)[index] as int
      : 0;
  DateTime? get closesAt => data['closes_at'] is int
      ? DateTime.fromMillisecondsSinceEpoch(
          data['closes_at'] as int,
          isUtc: true,
        )
      : null;

  static InteractiveMessage? parse(String text) {
    if (text.length > 12000) return null;
    final start = text.lastIndexOf(marker);
    if (start < 0) return null;
    try {
      final raw = jsonDecode(text.substring(start + marker.length));
      if (raw is! Map<String, dynamic> || raw['v'] != 1) return null;
      final id = raw['document'];
      if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]{8,64}$').hasMatch(id)) {
        return null;
      }
      final kind = raw['kind'];
      if (!{'poll', 'quiz', 'list', 'update'}.contains(kind)) return null;
      if (kind == 'update') {
        if (raw['definition'] is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(raw['definition'])) {
          return null;
        }
        if (raw['root'] is! int || (raw['root'] as int) <= 0) return null;
        if (!{'vote', 'check', 'close', 'assign'}.contains(raw['action'])) {
          return null;
        }
        if (raw['action'] == 'assign' &&
            (raw['item'] is! int ||
                raw['item'] < 0 ||
                raw['item'] >= 20 ||
                (raw['assignee'] != null &&
                    (raw['assignee'] is! int || raw['assignee'] <= 0)))) {
          return null;
        }
        if (raw['action'] == 'vote') {
          final choices = raw['choices'];
          if (choices is! List ||
              choices.length > 10 ||
              choices.any((v) => v is! int || v < 0 || v >= 10)) {
            return null;
          }
        }
        if (raw['action'] == 'check' &&
            (raw['item'] is! int ||
                raw['item'] < 0 ||
                raw['item'] >= 20 ||
                raw['checked'] is! bool)) {
          return null;
        }
      } else {
        if (raw['closes_at'] != null &&
            (kind == 'list' ||
                raw['closes_at'] is! int ||
                raw['closes_at'] <= 0 ||
                raw['closes_at'] > 8640000000000000)) {
          return null;
        }
        final title = raw['title'], items = raw['items'];
        if (title is! String ||
            title.trim().isEmpty ||
            customEmojiLength(title) > 180 ||
            items is! List ||
            items.length < (kind == 'list' ? 1 : 2) ||
            items.length > (kind == 'list' ? 20 : 10) ||
            items.any(
              (v) =>
                  v is! String ||
                  v.trim().isEmpty ||
                  customEmojiLength(v) > 100,
            ) ||
            items.toSet().length != items.length) {
          return null;
        }
        if (raw['multiple'] != null && raw['multiple'] is! bool) return null;
        final repeats = raw['repeat_seconds'];
        if (repeats != null &&
            (kind != 'list' ||
                repeats is! List ||
                repeats.length != items.length ||
                repeats.any(
                  (v) => v is! int || !{0, 86400, 604800}.contains(v),
                ))) {
          return null;
        }
        if (kind == 'quiz' &&
            (raw['correct'] is! int ||
                raw['correct'] < 0 ||
                raw['correct'] >= items.length)) {
          return null;
        }
        if (raw['explanation'] != null &&
            (raw['explanation'] is! String ||
                customEmojiLength(raw['explanation'] as String) > 500)) {
          return null;
        }
      }
      return InteractiveMessage(
        Map.unmodifiable(raw),
        text.substring(0, start),
      );
    } catch (_) {
      return null;
    }
  }

  static String encode(Map<String, dynamic> data, String preview) {
    final text = '$preview$marker${jsonEncode({'v': 1, ...data})}';
    if (parse(text) == null) {
      throw const FormatException('Некорректное интерактивное сообщение');
    }
    return text;
  }
}

class InteractiveState {
  InteractiveState(
    this.definition,
    this.ownerId,
    List<ApiMessage> events, {
    required int rootId,
    bool requireE2ee = false,
    DateTime? now,
    DateTime? rootSentAt,
  }) {
    // The server IDs establish one order across devices; provisional messages
    // never vote twice. Sender and reply binding come from authenticated messages.
    final fingerprint = definition.fingerprint;
    final itemCount = definition.items.length;
    final ordered =
        events
            .where(
              (m) =>
                  m.id > rootId &&
                  !m.isDeleted &&
                  !m.isSending &&
                  !m.isFailed &&
                  m.replyToId == rootId &&
                  (!m.isE2ee || m.isDecrypted) &&
                  (!requireE2ee || m.isE2ee),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final seen = <int>{};
    for (final message in ordered) {
      if (!seen.add(message.id) || closed) continue;
      final update = InteractiveMessage.parse(message.content);
      if (update == null ||
          update.kind != 'update' ||
          update.document != definition.document ||
          update.data['root'] != rootId ||
          update.data['definition'] != fingerprint) {
        continue;
      }
      final data = update.data;
      final deadline = definition.closesAt;
      if (deadline != null && !message.sentAt.toUtc().isBefore(deadline)) {
        continue;
      }
      if (data['action'] == 'close' && message.senderId == ownerId) {
        closed = true;
      } else if (data['action'] == 'vote' && definition.kind != 'list') {
        final choices = (data['choices'] as List).cast<int>().toSet();
        if (choices.any((i) => i >= itemCount) ||
            (!definition.multiple && choices.length > 1)) {
          continue;
        }
        if (definition.kind == 'quiz' &&
            (choices.length != 1 || votes.containsKey(message.senderId))) {
          continue;
        }
        votes[message.senderId] = choices;
        names[message.senderId] = message.senderDisplayName;
        avatars[message.senderId] = message.senderAvatarUrl;
      } else if (data['action'] == 'check' && definition.kind == 'list') {
        final item = data['item'] as int;
        if (item >= itemCount) continue;
        final interval = definition.repeatSeconds(item);
        if (interval > 0 && rootSentAt != null) {
          final anchor = rootSentAt.toUtc().millisecondsSinceEpoch;
          final current = (now ?? DateTime.now())
              .toUtc()
              .millisecondsSinceEpoch;
          final period = interval * 1000;
          final cycleStart =
              anchor +
              ((current - anchor).clamp(0, 8640000000000000) ~/ period) *
                  period;
          if (message.sentAt.toUtc().millisecondsSinceEpoch < cycleStart) {
            continue;
          }
        }
        checked[item] = data['checked'] as bool;
        checkedBy[item] = message.senderDisplayName;
        checkedByAvatar[item] = message.senderAvatarUrl;
      } else if (data['action'] == 'assign' && definition.kind == 'list') {
        final item = data['item'] as int;
        if (item < itemCount) assigned[item] = data['assignee'] as int?;
      }
    }
    final deadline = definition.closesAt;
    if (deadline != null &&
        !(now ?? DateTime.now()).toUtc().isBefore(deadline)) {
      closed = true;
    }
    for (final choices in votes.values) {
      for (final choice in choices) {
        _counts.update(choice, (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }
  final _counts = <int, int>{};
  final InteractiveMessage definition;
  final int ownerId;
  bool closed = false;
  final votes = <int, Set<int>>{};
  final names = <int, String>{};
  final avatars = <int, String?>{};
  final checked = <int, bool>{};
  final assigned = <int, int?>{};
  final checkedBy = <int, String>{};
  final checkedByAvatar = <int, String?>{};
  int get voters => votes.values.where((v) => v.isNotEmpty).length;
  int count(int item) => _counts[item] ?? 0;
}
