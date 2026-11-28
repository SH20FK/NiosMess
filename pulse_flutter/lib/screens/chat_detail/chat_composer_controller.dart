import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_input_area.dart';

/// The account the screen acts as, read at call time.
///
/// A record so the comparison is by whole identity
/// (`identity != (userId, accessToken)`), never by one half: A.7 must keep the
/// "the account changed while the edit was in flight" fence.
typedef ChatComposerIdentity = ({int? userId, String? accessToken});

/// Owns the composer's reply / edit state: the [ValueNotifier] the composer
/// widget listens to, and the six operations that used to live on the screen.
///
/// A plain class, like `ChatScrollCoordinator` and `ChatAiRewriteController`:
/// no `ref`, no `BuildContext`. The screen hands in the [TextEditingController],
/// the message-list `editMessage` write, and the side effects it owns (toasts,
/// haptics gate). Live values — identity, the message list, the current user —
/// are function getters, read at call time, never captured in the constructor.
///
/// Behaviour carried over verbatim from the screen:
/// * [ChatComposerState.copyWith] keeps its writer-function fields: passing
///   `() => null` clears a field, omitting it leaves the field alone.
/// * Editing an `InteractiveMessage` is refused with an info toast.
/// * [commitEdit] has four outcomes: nothing changed (silent cancel), success,
///   success after an account switch (silent no-op), and failure — which only
///   restores the composer while the text and the edited message are unchanged.
/// * [cancelEdit] clears the composer **field** — that is the design, not a bug.
/// * [setReply] truncates the preview at 80 characters.
/// * [editLastMessage] walks the list backwards for the last own, non-empty
///   `text` message, skipping deleted / failed / non-text ones.
class ChatComposerController {
  ChatComposerController({
    required this.chatId,
    required TextEditingController textController,
    required Future<void> Function(int id, String text) editMessage,
    required ChatComposerIdentity Function() identity,
    required bool Function() haptics,
    required void Function(Object error) onError,
    required void Function(String message) info,
    required int Function() myUserId,
    required List<ApiMessage> Function() messages,
    required String Function(ApiMessage message) replyAuthor,
    required String Function(ApiMessage message) replySnippet,
  }) : _textController = textController,
       _editMessageWrite = editMessage,
       _identity = identity,
       _haptics = haptics,
       _onError = onError,
       _info = info,
       _myUserId = myUserId,
       _messages = messages,
       _replyAuthor = replyAuthor,
       _replySnippet = replySnippet;

  final int? chatId;
  final TextEditingController _textController;
  final Future<void> Function(int id, String text) _editMessageWrite;
  final ChatComposerIdentity Function() _identity;
  final bool Function() _haptics;
  final void Function(Object error) _onError;
  final void Function(String message) _info;
  final int Function() _myUserId;
  final List<ApiMessage> Function() _messages;
  final String Function(ApiMessage message) _replyAuthor;
  final String Function(ApiMessage message) _replySnippet;

  /// The composer state. The screen reads it and hands it to the composer
  /// widget; only this controller writes reply / edit fields, while the screen
  /// still writes `isAiProcessing` (it owns the AI pass).
  final ValueNotifier<ChatComposerState> notifier =
      ValueNotifier<ChatComposerState>(const ChatComposerState());

  bool _isDisposed = false;

  ChatComposerState get state => notifier.value;

  int? get replyToMessageId => state.replyToMessageId;
  String? get replyPreviewText => state.replyPreviewText;
  int? get editingMessageId => state.editingMessageId;
  String? get editingOriginalText => state.editingOriginalText;
  bool get isAiProcessing => state.isAiProcessing;

  /// Enters inline edit mode for [message].
  Future<void> editMessage(ApiMessage message) async {
    if (InteractiveMessage.parse(message.content) != null) {
      _info('После отправки опрос или список можно завершить либо создать новый.');
      return;
    }
    if (chatId == null || _isDisposed) return;
    notifier.value = notifier.value.copyWith(
      editingMessageId: () => message.id,
      editingOriginalText: () => message.content,
      replyToMessageId: () => null,
      replyPreviewText: () => null,
    );
    _textController.text = message.content;
    // Put cursor at end.
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }

  /// Writes the edited text and leaves edit mode.
  ///
  /// Four outcomes, all preserved from the screen:
  /// 1. empty or unchanged text — cancel silently;
  /// 2. success — leave edit mode, but only while the message and the draft are
  ///    still the ones the write started with;
  /// 3. success after the account changed — do nothing at all;
  /// 4. failure — report it; restore the composer only while the text and the
  ///    edited message are unchanged.
  Future<void> commitEdit() async {
    if (_haptics()) HapticService.confirm();
    final int? id = chatId;
    final int? editId = editingMessageId;
    if (id == null || editId == null) return;
    final ChatComposerIdentity identity = _identity();
    final String edited = _textController.text.trim();
    final String originalDraft = _textController.text;
    final String? originalText = editingOriginalText;
    if (edited.isEmpty || edited == (originalText ?? '').trim()) {
      cancelEdit();
      return;
    }
    try {
      await _editMessageWrite(editId, edited);
      if (_isDisposed) return;
      if (identity != _identity()) return;
      if (editingMessageId == editId &&
          _textController.text == originalDraft) {
        cancelEdit();
      }
    } catch (error) {
      if (_isDisposed) return;
      if (identity != _identity()) return;
      if (editingMessageId != editId ||
          _textController.text != originalDraft) {
        _onError(error);
        return;
      }
      notifier.value = notifier.value.copyWith(
        editingMessageId: () => editId,
        editingOriginalText: () => originalText,
      );
      _textController.text = originalDraft;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: originalDraft.length),
      );
      _onError(error);
    }
  }

  /// Leaves edit mode and clears the composer text.
  void cancelEdit() {
    if (_haptics()) HapticService.reaction();
    notifier.value = notifier.value.copyWith(
      editingMessageId: () => null,
      editingOriginalText: () => null,
    );
    _textController.clear();
  }

  /// Enters edit mode on the last own, non-empty text message of the chat.
  void editLastMessage() {
    if (chatId == null || _isDisposed) return;
    final int myId = _myUserId();
    for (final ApiMessage message in _messages().reversed) {
      if (message.senderId == myId &&
          !message.isDeleted &&
          !message.isFailed &&
          message.msgType == 'text' &&
          message.content.trim().isNotEmpty) {
        unawaited(editMessage(message));
        break;
      }
    }
  }

  /// Sets a reply target and its preview, truncated at 80 characters.
  void setReply(ApiMessage message) {
    final String author = _replyAuthor(message);
    final String snippet = _replySnippet(message);
    notifier.value = notifier.value.copyWith(
      replyToMessageId: () => message.id,
      replyPreviewText: () =>
          '$author: ${snippet.length > 80 ? "${snippet.substring(0, 80)}..." : snippet}',
    );
  }

  /// Drops the reply target and its preview.
  void clearReply() {
    if (_haptics()) HapticService.reaction();
    notifier.value = notifier.value.copyWith(
      replyToMessageId: () => null,
      replyPreviewText: () => null,
    );
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    notifier.dispose();
  }
}
