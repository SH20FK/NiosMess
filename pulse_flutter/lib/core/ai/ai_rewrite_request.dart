import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/core/ai/ai_action.dart';

@immutable
class AiRewriteRequest {
  const AiRewriteRequest({
    required this.text,
    required this.action,
    this.targetLanguage,
  });

  final String text;
  final AiAction action;
  final String? targetLanguage;

  /// Returns normalized 2-letter ISO 639-1 language code or lowercase code
  /// required by backend AI endpoints.
  String? get normalizedLanguageCode {
    if (targetLanguage == null || targetLanguage!.trim().isEmpty) {
      return null;
    }
    final String lower = targetLanguage!.trim().toLowerCase();
    const Map<String, String> langMap = <String, String>{
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
    return langMap[lower] ?? lower;
  }

  AiRewriteRequest copyWith({
    String? text,
    AiAction? action,
    String? targetLanguage,
  }) {
    return AiRewriteRequest(
      text: text ?? this.text,
      action: action ?? this.action,
      targetLanguage: targetLanguage ?? this.targetLanguage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiRewriteRequest &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          action == other.action &&
          targetLanguage == other.targetLanguage;

  @override
  int get hashCode => Object.hash(text, action, targetLanguage);
}
