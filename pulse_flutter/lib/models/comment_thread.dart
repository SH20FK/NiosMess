import 'package:pulse_flutter/models/api/message_model.dart';

class CommentThreadRow {
  const CommentThreadRow(this.message, this.depth, this.descendants);
  final ApiMessage message;
  final int depth;
  final int descendants;
}

/// Iterative traversal keeps even very deep discussions off the Dart call stack.
/// Missing or deleted parents remain readable; malformed cycles cannot hide rows.
List<CommentThreadRow> buildCommentThread(
  List<ApiMessage> messages, {
  Set<int> collapsed = const <int>{},
}) {
  final byId = <int, ApiMessage>{
    for (final message in messages) message.id: message,
  };
  final children = <int, List<int>>{};
  final roots = <int>[];
  for (final message in byId.values) {
    final parent = message.replyToId;
    if (parent != null && parent != message.id && byId.containsKey(parent)) {
      (children[parent] ??= <int>[]).add(message.id);
    } else {
      roots.add(message.id);
    }
  }
  final visited = <int>{};
  final preorder = <(int, int)>[];
  void visit(int root) {
    final pending = <(int, int)>[(root, 0)];
    while (pending.isNotEmpty) {
      final (id, depth) = pending.removeLast();
      if (!visited.add(id)) continue;
      preorder.add((id, depth));
      for (final child in (children[id] ?? const <int>[]).reversed) {
        pending.add((child, depth + 1));
      }
    }
  }

  for (final root in roots) {
    visit(root);
  }
  for (final id in byId.keys) {
    if (!visited.contains(id)) visit(id);
  }
  final counts = <int, int>{};
  for (final (id, _) in preorder.reversed) {
    // Subtree size can be summed in reverse preorder without recursive walks.
    counts[id] = (counts[id] ?? 0);
    final parent = byId[id]!.replyToId;
    if (parent != null && parent != id && byId.containsKey(parent)) {
      counts[parent] = (counts[parent] ?? 0) + counts[id]! + 1;
    }
  }
  final result = <CommentThreadRow>[];
  int? hiddenBelow;
  for (final (id, depth) in preorder) {
    if (hiddenBelow != null && depth > hiddenBelow) continue;
    hiddenBelow = null;
    result.add(CommentThreadRow(byId[id]!, depth, counts[id] ?? 0));
    if (collapsed.contains(id)) hiddenBelow = depth;
  }
  return result;
}
