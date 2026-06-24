import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class AiRepository {
  const AiRepository(this._ref);

  final Ref _ref;

  Future<String> processText({
    required String text,
    required String action,
    String? targetLanguage,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'text': text,
      'action': action,
    };
    if (targetLanguage != null) {
      payload['target_language'] = targetLanguage;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('ai_process_text', payload: payload);

    if (response is Map<String, dynamic>) {
      return response['result_text'] as String? ?? text;
    }
    if (response is Map) {
      return response['result_text']?.toString() ?? text;
    }
    return text;
  }
}

final Provider<AiRepository> aiRepositoryProvider =
    Provider<AiRepository>((Ref ref) {
  return AiRepository(ref);
});
