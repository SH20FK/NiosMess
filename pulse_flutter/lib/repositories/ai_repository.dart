import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/ai/ai_action.dart';
import 'package:pulse_flutter/core/ai/ai_rewrite_request.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/ai_quota_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

export 'package:pulse_flutter/core/ai/ai_action.dart';
export 'package:pulse_flutter/core/ai/ai_rewrite_request.dart';
export 'package:pulse_flutter/models/api/ai_quota_model.dart';

class AiRepository {
  const AiRepository(this._ref);

  final Ref _ref;

  /// High-level non-streaming text rewrite using the canonical [AiRewriteRequest].
  /// Hides transport details (SSE stream buffering with automatic WebSocket fallback).
  Future<String> rewriteText(AiRewriteRequest request) async {
    final StringBuffer buffer = StringBuffer();
    try {
      await for (final String chunk in streamRewriteText(request: request)) {
        buffer.write(chunk);
      }
      final String result = buffer.toString().trim();
      return result.isNotEmpty ? result : request.text;
    } catch (_) {
      // Fall back to direct WebSocket execution
      return processText(
        text: request.text,
        action: request.action.toWsAction(),
        targetLanguage: request.normalizedLanguageCode,
      );
    }
  }

  /// Streaming AI text rewrite using Server-Sent Events (SSE) with automatic
  /// WebSocket fallback. Emits incremental text deltas as received from the LLM.
  Stream<String> streamRewriteText({
    AiRewriteRequest? request,
    String? text,
    String? mode,
    String? targetLanguage,
    void Function(AiQuota usage)? onUsage,
  }) async* {
    // Resolve canonical request from either request object or legacy parameters
    final String resolvedText = (request?.text ?? text ?? '').trim();
    final AiAction resolvedAction = request?.action ?? _resolveLegacyAction(mode);
    final String? resolvedLang =
        request?.normalizedLanguageCode ?? _normalizeLanguageCode(targetLanguage);

    final String? token = _ref.read(authProvider).session?.accessToken;
    if (token == null || token.isEmpty || resolvedText.length <= 10) {
      // Fall back to WebSocket request if token is missing or text is too short for SSE
      final String fullResult = await processText(
        text: resolvedText,
        action: resolvedAction.toWsAction(),
        targetLanguage: resolvedLang,
      );
      yield fullResult;
      return;
    }

    final http.Client client = http.Client();
    try {
      final Uri uri =
          Uri.parse('${AppConstants.webOrigin}/api/ai/rewrite/stream');
      final http.Request httpRequest = http.Request('POST', uri)
        ..headers.addAll(<String, String>{
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode(<String, dynamic>{
          'token': token,
          'text': resolvedText,
          'mode': resolvedAction.toSseMode(),
          if (resolvedLang != null && resolvedLang.isNotEmpty)
            'target_language': resolvedLang,
        });

      final http.StreamedResponse response = await client.send(httpRequest);

      if (response.statusCode != 200) {
        // Fallback to WebSocket on non-200
        final String fallbackResult = await processText(
          text: resolvedText,
          action: resolvedAction.toWsAction(),
          targetLanguage: resolvedLang,
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
                  final AiQuota usage =
                      AiQuota.fromJson(asStringMap(rawUsage));
                  _ref.read(authProvider.notifier).updateAiUsage(usage);
                  onUsage?.call(usage);
                }
              } else if (currentEvent == 'error') {
                throw Exception(
                    map['error']?.toString() ?? 'AI streaming error');
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
        text: resolvedText,
        action: resolvedAction.toWsAction(),
        targetLanguage: resolvedLang,
      );
      yield fallback;
    } finally {
      client.close();
    }
  }

  /// Low-level WebSocket fallback method calling `ai_process_text`.
  Future<String> processText({
    required String text,
    required String action,
    String? targetLanguage,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'text': text,
      'action': action,
    };
    if (targetLanguage != null && targetLanguage.isNotEmpty) {
      payload['target_language'] = targetLanguage;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('ai_process_text', payload: payload);

    if (response is Map) {
      final Map<String, dynamic> map = asStringMap(response);
      final dynamic rawUsage = map['ai_usage'];
      if (rawUsage is Map) {
        final AiQuota usage = AiQuota.fromJson(asStringMap(rawUsage));
        _ref.read(authProvider.notifier).updateAiUsage(usage);
      }
      return map['result_text']?.toString() ?? text;
    }
    return text;
  }

  static AiAction _resolveLegacyAction(String? mode) {
    if (mode == null) return AiAction.correct;
    final String clean = mode.trim().toLowerCase();
    if (clean == 'formalize' || clean == 'formal' || clean == 'rewrite_formal') {
      return AiAction.rewriteFormal;
    }
    if (clean == 'translate') {
      return AiAction.translate;
    }
    return AiAction.correct;
  }

  static String? _normalizeLanguageCode(String? lang) {
    if (lang == null || lang.trim().isEmpty) return null;
    final String lower = lang.trim().toLowerCase();
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
    return langToCode[lower] ?? lower;
  }
}

final Provider<AiRepository> aiRepositoryProvider =
    Provider<AiRepository>((Ref ref) {
  return AiRepository(ref);
});
