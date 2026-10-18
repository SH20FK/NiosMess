import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/report_repository.dart';

class _Socket extends WebSocketClient {
  _Socket() : super(baseUrl: 'wss://test.invalid', readToken: () => null);
  Map<String, dynamic>? captured;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    captured = payload;
    return {};
  }
}

void main() {
  test(
    'only the selected readable message is attached to the report',
    () async {
      final socket = _Socket();
      final container = ProviderContainer(
        overrides: [webSocketClientProvider.overrideWithValue(socket)],
      );
      addTearDown(container.dispose);
      final repository = container.read(reportRepositoryProvider);
      Future<void> send(Map<String, dynamic> fields) => repository.report(
        chatId: 7,
        reportedUserId: 9,
        reason: 'spam',
        messageIds: [11],
        selectedMessage: ApiMessage.fromJson({
          'id': 11,
          'chat_id': 7,
          'sender_id': 9,
          'content': 'Выбранный текст',
          'is_e2ee': true,
          'is_decrypted': true,
          ...fields,
        }),
      );
      await send({});
      expect(socket.captured!['message_evidence'], [
        {'message_id': 11, 'content': 'Выбранный текст'},
      ]);
      for (final fields in [
        {'is_decrypted': false},
        {'id': 12},
        {'chat_id': 8},
        {'sender_id': 10},
        {'is_deleted': true},
      ]) {
        await send(fields);
        expect(socket.captured!.containsKey('message_evidence'), isFalse);
      }
    },
  );
}
