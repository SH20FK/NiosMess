import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/comment_thread.dart';

ApiMessage comment(int id, {int? parent, bool deleted = false}) =>
    ApiMessage.fromJson({
      'id': id,
      'sender_id': 1,
      'content': 'Comment $id',
      'reply_to_id': parent,
      'is_deleted': deleted,
    });

void main() {
  test('replies follow their parent even when other roots arrived earlier', () {
    final rows = buildCommentThread([
      comment(1),
      comment(2),
      comment(3, parent: 1),
      comment(4, parent: 3),
    ]);
    expect(rows.map((r) => r.message.id), [1, 3, 4, 2]);
    expect(rows.map((r) => r.depth), [0, 1, 2, 0]);
    expect(rows.map((r) => r.descendants), [2, 1, 0, 0]);
    expect(
      buildCommentThread(
        rows.map((r) => r.message).toList(),
        collapsed: {1},
      ).map((r) => r.message.id),
      [1, 2],
    );
  });
  test('ten thousand nested replies do not exhaust the call stack', () {
    final rows = buildCommentThread([
      for (var id = 1; id <= 10000; id++)
        comment(id, parent: id == 1 ? null : id - 1),
    ]);
    expect(rows.length, 10000);
    expect(rows.last.depth, 9999);
    expect(rows.first.descendants, 9999);
  });
  test('missing, deleted and cyclic parents cannot hide comments', () {
    final rows = buildCommentThread([
      comment(1, deleted: true),
      comment(2, parent: 1),
      comment(3, parent: 999),
      comment(4, parent: 5),
      comment(5, parent: 4),
      comment(6, parent: 6),
    ]);
    expect(rows.map((r) => r.message.id).toSet(), {1, 2, 3, 4, 5, 6});
    expect(rows.where((r) => r.message.id == 2).single.depth, 1);
  });
}
