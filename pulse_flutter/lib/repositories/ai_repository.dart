import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class AiRepository {
  const AiRepository(this._ref);

  final Ref _ref;

  /// Streaming AI text rewrite using Server-Sent Events (SSE).
  /// Emits incremental text deltas as received from the LLM.
  Stream<String> streamRewriteText({
    required String text,
    required String mode,
    String? targetLanguage,
    void Function(ApiAiUsage usage)? onUsage,
  }) async* {
    final String? token = _ref.read(authProvider).session?.accessToken;
    if (token == null || token.isEmpty || text.trim().length <= 10) {
      // Fall back to WebSocket request if token is missing or text is too short for SSE
      final String fullResult = await processText(
        text: text,
        action: mode,
        targetLanguage: targetLanguage,
      );
      yield fullResult;
      return;
    }

    String normalizedMode = mode.toLowerCase();
    if (normalizedMode == 'correct' || normalizedMode == 'fix_errors') {
      normalizedMode = 'correct';
    } else if (normalizedMode == 'formalize' || normalizedMode == 'formal') {
      normalizedMode = 'formalize';
    }

    String? normalizedLang = targetLanguage;
    if (targetLanguage != null && targetLanguage.isNotEmpty) {
      final String lower = targetLanguage.trim().toLowerCase();
      const Map<String, String> langToCode = <String, String>{
        'english': 'en',
        'spanish': 'es',
        'chinese': 'zh',
        'russian': 'ru',
        'german': 'de',
        'french': 'fr',
        'italian': 'it',
        'portuguese': 'pt',
        'turkish': 'tr',
        'ukrainian': 'uk',
        'polish': 'pl',
        'japanese': 'ja',
        'korean': 'ko',
        'arabic': 'ar',
      };
      normalizedLang = langToCode[lower] ?? lower;
    }

    final http.Client client = http.Client();
    try {
      final Uri uri = Uri.parse('${AppConstants.webOrigin}/api/ai/rewrite/stream');
      final http.Request request = http.Request('POST', uri)
        ..headers.addAll(<String, String>{
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode(<String, dynamic>{
          'token': token,
          'text': text,
          'mode': normalizedMode,
          if (normalizedLang != null && normalizedLang.isNotEmpty)
            'target_language': normalizedLang,
        });

      final http.StreamedResponse response = await client.send(request);

      if (response.statusCode != 200) {
        // Fallback to WebSocket on non-200
        final String fallbackResult = await processText(
          text: text,
          action: mode,
          targetLanguage: targetLanguage,
        );
        yield fallbackResult;
        return;
      }

      String currentEvent = 'message';
      await for (final String line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final String trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('event:')) {
          currentEvent = trimmed.substring(6).trim();
        } else if (trimmed.startsWith('data:')) {
          final String jsonStr = trimmed.substring(5).trim();
          try {
            final dynamic data = jsonDecode(jsonStr);
            if (data is Map) {
              final Map<String, dynamic> map = asStringMap(data);
              if (currentEvent == 'delta' && map.containsKey('delta')) {
                final String delta = map['delta']?.toString() ?? '';
                if (delta.isNotEmpty) yield delta;
              } else if (currentEvent == 'complete') {
                final dynamic rawUsage = map['ai_usage'];
                if (rawUsage is Map) {
                  final ApiAiUsage usage =
                      ApiAiUsage.fromJson(asStringMap(rawUsage));
                  _ref.read(authProvider.notifier).updateAiUsage(usage);
                  onUsage?.call(usage);
                }
              } else if (currentEvent == 'error') {
                throw Exception(map['error']?.toString() ?? 'AI streaming error');
              }
            }
          } catch (e) {
            if (currentEvent == 'error') rethrow;
          }
        }
      }
    } catch (e) {
      // Fall back to single WebSocket request on network failure
      final String fallback = await processText(
        text: text,
        action: mode,
        targetLanguage: targetLanguage,
      );
      yield fallback;
    } finally {
      client.close();
    }
  }

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

    if (response is Map) {
      final Map<String, dynamic> map = asStringMap(response);
      final dynamic rawUsage = map['ai_usage'];
      if (rawUsage is Map) {
        final ApiAiUsage usage = ApiAiUsage.fromJson(asStringMap(rawUsage));
        _ref.read(authProvider.notifier).updateAiUsage(usage);
      }
      return map['result_text']?.toString() ?? text;
    }
    return text;
  }
}

final Provider<AiRepository> aiRepositoryProvider =
    Provider<AiRepository>((Ref ref) {
  return AiRepository(ref);
});
