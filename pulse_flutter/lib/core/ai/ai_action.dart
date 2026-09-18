import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

/// Canonical AI actions supported by the backend rewrite and bot processing APIs.
enum AiAction {
  /// Fix spelling, punctuation, and grammar without changing meaning or tone.
  correct,

  /// Rewrite text in formal, business style.
  rewriteFormal,

  /// Translate text into a specified target language.
  translate,
}

extension AiActionWireExtension on AiAction {
  /// Wire mode identifier used for FastAPI SSE `/api/ai/rewrite/stream`.
  String toSseMode() {
    switch (this) {
      case AiAction.correct:
        return 'correct';
      case AiAction.rewriteFormal:
        return 'formalize';
      case AiAction.translate:
        return 'translate';
    }
  }

  /// Wire action identifier used for WebSocket `ai_process_text`.
  String toWsAction() {
    switch (this) {
      case AiAction.correct:
        return 'correct';
      case AiAction.rewriteFormal:
        return 'formalize';
      case AiAction.translate:
        return 'translate';
    }
  }

  /// User-facing label using app localizations.
  String label(BuildContext context) {
    switch (this) {
      case AiAction.correct:
        return context.l10n.chatAiFixErrors;
      case AiAction.rewriteFormal:
        return context.l10n.chatAiFormal;
      case AiAction.translate:
        return context.l10n.chatAiTranslate;
    }
  }
}
