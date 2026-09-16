import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class ReportRepository {
  const ReportRepository(this._ref);

  final Ref _ref;

  Future<void> report({
    int? chatId,
    required int reportedUserId,
    required String reason,
    List<int>? messageIds,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'reported_user_id': reportedUserId,
      'reason': reason,
      if (chatId != null && chatId > 0) 'chat_id': chatId,
      if (messageIds != null && messageIds.isNotEmpty) 'message_ids': messageIds,
    };
    await _ref.read(webSocketClientProvider).request(
      'report',
      payload: payload,
    );
  }
}

final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>((Ref ref) {
  return ReportRepository(ref);
});
