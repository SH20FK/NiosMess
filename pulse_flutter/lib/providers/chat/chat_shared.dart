import 'package:pulse_flutter/models/api/message_model.dart';

/// Chronological ordering shared by the chat history window and the post
/// comment thread.
int compareMessages(ApiMessage a, ApiMessage b) {
  final bool aPending = a.id < 0 || a.isSending;
  final bool bPending = b.id < 0 || b.isSending;

  if (aPending != bPending) {
    final int timeCmp = a.resolvedSentAt.compareTo(b.resolvedSentAt);
    if (timeCmp != 0) return timeCmp;
    return aPending ? 1 : -1;
  }

  final int timeCmp = a.resolvedSentAt.compareTo(b.resolvedSentAt);
  if (timeCmp != 0) return timeCmp;

  if (!aPending && !bPending) {
    return a.id.compareTo(b.id);
  }

  return a.id.abs().compareTo(b.id.abs());
}
