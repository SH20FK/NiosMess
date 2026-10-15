import 'dart:collection';

import 'package:pulse_flutter/models/api/message_model.dart';

/// A producer-owned immutable history snapshot with an exact, bounded delta.
///
/// [rows] ownership is transferred: producers must never mutate it after this
/// wrapper is published. The previous snapshot is represented by an opaque
/// identity, so a long run of appends cannot retain a chain of old histories.
class MessageHistorySnapshot extends UnmodifiableListView<ApiMessage> {
  MessageHistorySnapshot({
    required List<ApiMessage> previous,
    required List<ApiMessage> rows,
    Iterable<ApiMessage> appended = const [],
    Map<int, ApiMessage> replacements = const {},
  }) : previousIdentity = identityOf(previous),
       previousLength = previous.length,
       appended = List.unmodifiable(appended),
       replacements = Map.unmodifiable(replacements),
       super(rows);

  static final Expando<Object> _identities = Expando(
    'history snapshot identity',
  );
  static Object identityOf(List<ApiMessage> rows) =>
      _identities[rows] ??= Object();

  /// An out-of-order insert remains a full snapshot; existing indexes shifted.
  static List<ApiMessage> afterInsert({
    required List<ApiMessage> previous,
    required List<ApiMessage> rows,
    required ApiMessage inserted,
  }) => rows.length == previous.length + 1 && identical(rows.last, inserted)
      ? MessageHistorySnapshot(
          previous: previous,
          rows: rows,
          appended: [inserted],
        )
      : rows;

  static List<ApiMessage> afterUpdate({
    required List<ApiMessage> previous,
    required List<ApiMessage> rows,
    required int index,
  }) => rows.length == previous.length && index >= 0 && index < rows.length
      ? MessageHistorySnapshot(
          previous: previous,
          rows: rows,
          replacements: {index: rows[index]},
        )
      : rows;

  /// Common tail acknowledgement. Reordered/deduplicated acknowledgements use
  /// the safe full snapshot instead of declaring an incorrect index delta.
  static List<ApiMessage> afterAcknowledgement({
    required List<ApiMessage> previous,
    required List<ApiMessage> rows,
    required int pendingId,
    required ApiMessage confirmed,
  }) =>
      previous.isNotEmpty &&
          previous.last.id == pendingId &&
          rows.length == previous.length &&
          identical(rows.last, confirmed)
      ? afterUpdate(previous: previous, rows: rows, index: previous.length - 1)
      : rows;

  final Object previousIdentity;
  final int previousLength;
  final List<ApiMessage> appended;

  /// Exact indexes in the previous snapshot, including pending → server ID.
  final Map<int, ApiMessage> replacements;
}
