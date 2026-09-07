import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/inline_query_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class BotRepository {
  const BotRepository(this._ref);

  final Ref _ref;

  Future<InlineQueryResponse> sendInlineQuery({
    int? chatId,
    required String botUsername,
    required String query,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'chat_id': ?chatId,
      'bot_username': botUsername,
      'query': query,
    };

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('inline_query', payload: payload);

    if (response is Map<String, dynamic>) {
      return InlineQueryResponse.fromJson(response);
    }
    if (response is Map) {
      return InlineQueryResponse.fromJson(
        response.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
      );
    }
    return const InlineQueryResponse(inlineQueryId: '');
  }
}

final Provider<BotRepository> botRepositoryProvider =
    Provider<BotRepository>((Ref ref) => BotRepository(ref));
