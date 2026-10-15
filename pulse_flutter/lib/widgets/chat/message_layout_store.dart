import 'dart:collection';
import 'package:pulse_flutter/core/storage/message_history_snapshot.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

class MessageLayoutData {
  const MessageLayoutData({
    required this.showDateSep,
    required this.isPrevSame,
    required this.isNextSame,
  });

  final bool showDateSep;
  final bool isPrevSame;
  final bool isNextSame;
}

/// Maintains layout only for changed rows and their neighbours. Stable logical
/// positions make reverse-index lookup O(1), without rewriting every map entry
/// when a new message arrives or an older page is prepended.
class MessageLayoutStore {
  final List<ApiMessage> messages = <ApiMessage>[];
  final List<MessageLayoutData> layout = <MessageLayoutData>[];
  final Map<int, ApiMessage> byId = <int, ApiMessage>{};
  final Map<int, int> _positions = <int, int>{};
  int _origin = 0;
  Object? _sourceIdentity;
  late final Map<int, int> idToIndex = _ReverseMessageIndex(this);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  MessageLayoutData _computeSingle(int i) {
    final msg = messages[i];
    final showDateSep =
        i == 0 ||
        !_isSameDay(msg.resolvedSentAt, messages[i - 1].resolvedSentAt);
    return MessageLayoutData(
      showDateSep: showDateSep,
      isPrevSame:
          i > 0 &&
          !showDateSep &&
          messages[i - 1].senderId == msg.senderId &&
          !messages[i - 1].isDeleted,
      isNextSame:
          i < messages.length - 1 &&
          _isSameDay(messages[i + 1].resolvedSentAt, msg.resolvedSentAt) &&
          messages[i + 1].senderId == msg.senderId &&
          !messages[i + 1].isDeleted,
    );
  }

  void reset(List<ApiMessage> next) {
    messages.clear();
    layout.clear();
    byId.clear();
    _positions.clear();
    _origin = 0;
    _sourceIdentity = MessageHistorySnapshot.identityOf(next);
    messages.addAll(next);
    for (var i = 0; i < next.length; i++) {
      layout.add(_computeSingle(i));
      byId[next[i].id] = next[i];
      _positions[next[i].id] = i;
    }
  }

  /// Known tail append: only the new row and its previous neighbour relayout.
  void append(ApiMessage message) {
    if (byId.containsKey(message.id)) {
      throw ArgumentError('Message identity already exists');
    }
    final index = messages.length;
    messages.add(message);
    byId[message.id] = message;
    _positions[message.id] = _origin + index;
    layout.add(_computeSingle(index));
    if (index > 0) layout[index - 1] = _computeSingle(index - 1);
    _sourceIdentity = null;
  }

  /// Known ID update: lookup and grouping touch at most three rows.
  bool update(ApiMessage message) {
    final position = _positions[message.id];
    if (position == null) return false;
    replaceAt(position - _origin, message);
    return true;
  }

  /// Exact producer index also supports an acknowledgement replacing a temp ID.
  void replaceAt(int index, ApiMessage message) {
    RangeError.checkValidIndex(index, messages);
    final old = messages[index];
    if (old.id != message.id && byId.containsKey(message.id)) {
      throw ArgumentError('Message identity already exists');
    }
    byId.remove(old.id);
    _positions.remove(old.id);
    messages[index] = message;
    byId[message.id] = message;
    _positions[message.id] = _origin + index;
    for (var i = index - 1; i <= index + 1; i++) {
      if (i >= 0 && i < messages.length) layout[i] = _computeSingle(i);
    }
    _sourceIdentity = null;
  }

  bool _applyKnown(MessageHistorySnapshot next) {
    if (!identical(next.previousIdentity, _sourceIdentity) ||
        next.previousLength != messages.length ||
        next.length != messages.length + next.appended.length) {
      return false;
    }
    // Validate only producer-declared changes before touching the store. A
    // skipped rebuild/unknown snapshot falls back to the complete safe diff.
    final touchedIds = <int>{};
    for (final entry in next.replacements.entries) {
      final index = entry.key;
      if (index < 0 ||
          index >= messages.length ||
          !identical(next[index], entry.value) ||
          !touchedIds.add(entry.value.id)) {
        return false;
      }
      final previousIndex = _positions[entry.value.id];
      if (previousIndex != null && previousIndex - _origin != index) {
        return false;
      }
    }
    for (var i = 0; i < next.appended.length; i++) {
      final row = next.appended[i];
      if (!identical(next[messages.length + i], row) ||
          byId.containsKey(row.id) ||
          !touchedIds.add(row.id)) {
        return false;
      }
    }
    for (final entry in next.replacements.entries) {
      replaceAt(entry.key, entry.value);
    }
    for (final row in next.appended) {
      append(row);
    }
    _sourceIdentity = MessageHistorySnapshot.identityOf(next);
    return true;
  }

  void sync(List<ApiMessage> next) {
    if (next is MessageHistorySnapshot && _applyKnown(next)) return;
    final oldLength = messages.length;
    if (oldLength == 0 || next.isEmpty || next.length < oldLength) {
      reset(next);
      return;
    }
    final added = next.length - oldLength;
    int offset = 0;
    if (added > 0 && next.first.id != messages.first.id) {
      if (next[added].id != messages.first.id) {
        reset(next);
        return;
      }
      offset = added;
    }
    // Verify all retained identities. A concurrent edit plus append must not
    // silently discard the edit just because the first/last IDs still match.
    for (var i = 0; i < oldLength; i++) {
      if (next[i + offset].id != messages[i].id) {
        reset(next);
        return;
      }
    }
    final dirty = <int>{};
    if (offset > 0) {
      _origin -= offset;
      messages.insertAll(0, next.take(offset));
      layout.insertAll(
        0,
        List.generate(
          offset,
          (_) => const MessageLayoutData(
            showDateSep: false,
            isPrevSame: false,
            isNextSame: false,
          ),
        ),
      );
      for (var i = 0; i < offset; i++) {
        final message = next[i];
        byId[message.id] = message;
        _positions[message.id] = _origin + i;
        dirty.add(i);
      }
      dirty.add(offset);
    } else if (added > 0) {
      for (var i = oldLength; i < next.length; i++) {
        final message = next[i];
        messages.add(message);
        layout.add(
          const MessageLayoutData(
            showDateSep: false,
            isPrevSame: false,
            isNextSame: false,
          ),
        );
        byId[message.id] = message;
        _positions[message.id] = _origin + i;
        dirty.add(i);
      }
      dirty.add(oldLength - 1);
    }
    for (var i = offset; i < oldLength + offset; i++) {
      if (!identical(messages[i], next[i])) {
        messages[i] = next[i];
        byId[next[i].id] = next[i];
        dirty.addAll([i - 1, i, i + 1]);
      }
    }
    for (final i in dirty) {
      if (i >= 0 && i < messages.length) layout[i] = _computeSingle(i);
    }
    _sourceIdentity = MessageHistorySnapshot.identityOf(next);
  }
}

class _ReverseMessageIndex extends MapBase<int, int> {
  _ReverseMessageIndex(this.store);
  final MessageLayoutStore store;
  @override
  int? operator [](Object? key) {
    final position = store._positions[key];
    return position == null
        ? null
        : store.messages.length - 1 - (position - store._origin);
  }

  @override
  Iterable<int> get keys => store._positions.keys;
  @override
  void operator []=(int key, int value) =>
      throw UnsupportedError('Read-only message index');
  @override
  void clear() => throw UnsupportedError('Read-only message index');
  @override
  int? remove(Object? key) => throw UnsupportedError('Read-only message index');
}
