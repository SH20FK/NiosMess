import 'package:pulse_flutter/models/api/message_model.dart';
import '../ordinary_e2ee/ordinary_e2ee_codec.dart';

String? meshOperation(ApiMessage message) {
  if (message.e2eeContent == null) return null;
  try {
    if (!OrdinaryCodec.recognises(message.e2eeContent!)) return null;
    final h = OrdinaryCodec.header(message.e2eeContent!);
    if (h['edit'] != null) return null;
    return '${message.chatId}:${message.senderId}:${h['id']}';
  } catch (_) {
    return null;
  }
}

/// One immutable operation can arrive over radio, a server push and history.
/// A positive server ID replaces its negative local ID, preserving newer edits.
List<ApiMessage> mergeMeshHistory(
  Iterable<ApiMessage> history,
  Iterable<ApiMessage> radio,
) {
  final byId = <int, ApiMessage>{for (final m in history) m.id: m};
  final operations = <String, int>{};
  for (final m in byId.values.toList()) {
    final op = meshOperation(m);
    if (op == null) continue;
    final prior = operations[op];
    if (prior != null) {
      if (prior > 0 && m.id < 0) {
        byId.remove(m.id);
        continue;
      }
      byId.remove(prior);
    }
    operations[op] = m.id;
  }
  for (final m in radio) {
    final op = meshOperation(m), prior = op == null ? null : operations[op];
    if (prior != null && prior > 0) continue;
    if (prior != null) byId.remove(prior);
    byId[m.id] = m;
    if (op != null) operations[op] = m.id;
  }
  return byId.values.toList()..sort((a, b) {
    final time = a.sentAt.compareTo(b.sentAt);
    return time == 0 ? a.id.compareTo(b.id) : time;
  });
}
