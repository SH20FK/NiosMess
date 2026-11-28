import 'dart:async';

import 'package:pulse_flutter/models/api/chat_summary_model.dart';

/// Writes the contact list to the local cache only when a contact changed.
///
/// [chatsProvider] emits a new list on every message in any chat, so the
/// contacts screen used to rewrite the whole Hive box per message. The cache is
/// a cold-start fallback for the contact rows, which show the id, name,
/// username, avatar and badges; nothing else has to reach disk. Submissions are
/// debounced and compared by those fields, in an order-insensitive way: the
/// inbox reorders chats on each message, and that is not a contact change.
class ContactsCacheSync {
  ContactsCacheSync({
    required Future<void> Function(List<ApiChatSummary> contacts) save,
    Duration debounce = const Duration(milliseconds: 500),
  }) : _save = save,
       _debounce = debounce;

  final Future<void> Function(List<ApiChatSummary> contacts) _save;
  final Duration _debounce;
  Timer? _timer;
  List<ApiChatSummary>? _pending;
  List<String>? _pendingFingerprint;
  List<String>? _written;
  bool _flushing = false;

  /// Offers the current direct-contact list. Unchanged contacts are dropped
  /// before the timer starts, so a burst of messages costs nothing.
  void submit(List<ApiChatSummary> contacts) {
    final List<String> fingerprint = fingerprintOf(contacts);
    final List<String>? baseline = _pendingFingerprint ?? _written;
    if (baseline != null && _sameFingerprint(baseline, fingerprint)) return;
    _pending = contacts;
    _pendingFingerprint = fingerprint;
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      unawaited(flush().catchError((Object _) {}));
    });
  }

  /// Writes the outstanding change, if any. Safe to call concurrently.
  Future<void> flush() async {
    if (_flushing) return;
    _timer?.cancel();
    _timer = null;
    _flushing = true;
    try {
      while (_pending != null) {
        final List<ApiChatSummary> contacts = _pending!;
        final List<String> fingerprint = _pendingFingerprint!;
        _pending = null;
        _pendingFingerprint = null;
        final List<String>? written = _written;
        if (written != null && _sameFingerprint(written, fingerprint)) continue;
        await _save(contacts);
        _written = fingerprint;
      }
    } finally {
      _flushing = false;
    }
  }

  /// Cancels the debounce and writes an outstanding change.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (_pending != null) {
      unawaited(flush().catchError((Object _) {}));
    }
  }

  /// The fields the contacts list renders, sorted so ordering does not count.
  static List<String> fingerprintOf(List<ApiChatSummary> contacts) {
    final List<String> rows = <String>[
      for (final ApiChatSummary chat in contacts)
        '${chat.id}\u0000${chat.name}\u0000${chat.username ?? ''}\u0000'
            '${chat.avatarUrl ?? ''}\u0000'
            '${chat.partnerBadges.map((badge) => badge.id).join(',')}',
    ];
    rows.sort();
    return rows;
  }

  static bool _sameFingerprint(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
