import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class ReportRepository {
  const ReportRepository(this._ref);

  final Ref _ref;

  Future<void> report({
    required int chatId,
    required int reportedUserId,
    required String reason,
    List<int>? messageIds,
  }) async {
    await _ref.read(webSocketClientProvider).request(
      'report',
      payload: <String, dynamic>{
        'chat_id': chatId,
        'reported_user_id': reportedUserId,
        'reason': reason,
        if (messageIds != null && messageIds.isNotEmpty) 'message_ids': messageIds,
      },
    );
  }
}

final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>((Ref ref) {
  return ReportRepository(ref);
});
