import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

Map<String, dynamic> asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((dynamic key, dynamic val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

class BotRepository {
  const BotRepository(this._ref);
  final Ref _ref;

  Future<Map<String, dynamic>> createBot({
    required String name,
    required String username,
    String? description,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'name': name,
      'username': username,
    };
    if (description != null && description.isNotEmpty) {
      payload['description'] = description;
    }
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('create_bot', payload: payload);
    return asStringMap(response);
  }

  Future<List<Map<String, dynamic>>> getBotUpdates(String botToken) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('get_bot_updates', payload: <String, dynamic>{});
    if (response is! Map) return const <Map<String, dynamic>>[];
    final dynamic updatesRaw = response['updates'];
    if (updatesRaw is! List) return const <Map<String, dynamic>>[];
    return updatesRaw
        .whereType<Map>()
        .map((Map item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }

  Future<void> answerCallbackQuery({
    required String botToken,
    required String callbackId,
    String? text,
    bool alert = false,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'callback_id': callbackId,
      'alert': alert,
    };
    if (text != null && text.isNotEmpty) {
      payload['text'] = text;
    }
    await _ref
        .read(webSocketClientProvider)
        .request('answer_callback_query', payload: payload);
  }
}

final Provider<BotRepository> botRepositoryProvider = Provider<BotRepository>((Ref ref) {
  return BotRepository(ref);
});
