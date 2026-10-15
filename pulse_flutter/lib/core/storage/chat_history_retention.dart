import 'dart:async';
import 'dart:collection';

/// Bounded retention for *unobserved* UI histories. In-flight deliveries keep
/// their own leases and are never cancelled by this cache policy.
class ChatHistoryRetention {
  ChatHistoryRetention({
    this.maxIdleChats = 6,
    this.idleTtl = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int maxIdleChats;
  final Duration idleTtl;
  final DateTime Function() _now;
  final LinkedHashMap<Object, _RetainedHistory> _idle = LinkedHashMap();
  Timer? _expiry;

  int get idleCount => _idle.length;

  void retain(Object owner, void Function() release) {
    _idle.remove(owner);
    _idle[owner] = _RetainedHistory(_now().add(idleTtl), release);
    while (_idle.length > maxIdleChats) {
      _idle.remove(_idle.keys.first)!.release();
    }
    _schedule();
  }

  void resume(Object owner) {
    _idle.remove(owner);
    _schedule();
  }

  void _schedule() {
    _expiry?.cancel();
    _expiry = null;
    if (_idle.isEmpty) return;
    final delay = _idle.values.first.deadline.difference(_now());
    _expiry = Timer(delay.isNegative ? Duration.zero : delay, _expire);
  }

  void _expire() {
    final now = _now();
    while (_idle.isNotEmpty && !_idle.values.first.deadline.isAfter(now)) {
      _idle.remove(_idle.keys.first)!.release();
    }
    _schedule();
  }

  void dispose() {
    _expiry?.cancel();
    _expiry = null;
    final pending = _idle.values.toList(growable: false);
    _idle.clear();
    for (final entry in pending) {
      entry.release();
    }
  }
}

class _RetainedHistory {
  const _RetainedHistory(this.deadline, this.release);
  final DateTime deadline;
  final void Function() release;
}
