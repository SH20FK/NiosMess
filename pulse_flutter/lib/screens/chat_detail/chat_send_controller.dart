import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/chat/spamblock_banner.dart';

/// Owns sending a composer's text: the four gates, and both write paths
/// (secret `chatMessages.send` and the ordinary `send(..., onLocalSaved: ...)`).
///
/// A plain class, like `ChatComposerController` and `ChatMediaController`: no
/// `ref`, no `BuildContext`. The screen reads its providers and hands in plain
/// callbacks; live values (chat, messages, identity, reply target) are function
/// getters, read at call time, never captured in the constructor.
///
/// Behaviour carried over verbatim from the screen — all seven invariants:
/// 1. [_savingSecretMessage] is shared by **both** paths, so a second entry
///    while a send is in flight cannot create a second message.
/// 2. The ordinary path only releases that flag from `onLocalSaved` /
///    `whenComplete`, and `onLocalSaved` fires **once** — after local save.
/// 3. The composer text is restored only while it still equals the text the
///    send started with; a late failure must never replace new typing.
/// 4. A failure whose message names the partner's restriction marks the chat
///    blocked by the user.
/// 5. The reply target is restored only while it is still the same [replyId].
/// 6. Chat metadata that never arrives within [metadataTimeout] is an error
///    toast, never a send into the void.
/// 7. Empty input is not sent at all.
class ChatSendController {
  ChatSendController({
    required int? Function() chatId,
    required TextEditingController textController,
    required AppLocalizations Function() l10n,
    required ApiChatSummary? Function(int chatId) chat,
    required Future<void> Function() ensureChats,
    required List<ApiMessage> Function() messages,
    required int? Function() myUserId,
    required bool Function() isAccountSpamBlocked,
    required bool Function() isSecret,
    required bool Function(int userId) isUserBlocked,
    required bool Function() haptics,
    required int? Function() replyToMessageId,
    required String? Function() replyPreviewText,
    required Future<void> Function(int chatId, String text, {int? replyToId})
    sendSecret,
    required Future<void> Function(
      int chatId,
      String text, {
      int? replyToId,
      void Function()? onLocalSaved,
    })
    send,
    required void Function() clearReply,
    required void Function(int replyId, String preview) restoreReply,
    required void Function() scrollToBottom,
    required void Function(int chatId) markBlockedByUser,
    required void Function(Object error) onError,
    this.metadataTimeout = const Duration(seconds: 8),
  }) : _chatId = chatId,
       _textController = textController,
       _l10n = l10n,
       _chat = chat,
       _ensureChats = ensureChats,
       _messages = messages,
       _myUserId = myUserId,
       _isAccountSpamBlocked = isAccountSpamBlocked,
       _isSecret = isSecret,
       _isUserBlocked = isUserBlocked,
       _haptics = haptics,
       _replyToMessageId = replyToMessageId,
       _replyPreviewText = replyPreviewText,
       _sendSecret = sendSecret,
       _send = send,
       _clearReply = clearReply,
       _restoreReply = restoreReply,
       _scrollToBottom = scrollToBottom,
       _markBlockedByUser = markBlockedByUser,
       _onError = onError;

  final int? Function() _chatId;
  final TextEditingController _textController;
  final AppLocalizations Function() _l10n;
  final ApiChatSummary? Function(int chatId) _chat;
  final Future<void> Function() _ensureChats;
  final List<ApiMessage> Function() _messages;
  final int? Function() _myUserId;
  final bool Function() _isAccountSpamBlocked;
  final bool Function() _isSecret;
  final bool Function(int userId) _isUserBlocked;
  final bool Function() _haptics;
  final int? Function() _replyToMessageId;
  final String? Function() _replyPreviewText;
  final Future<void> Function(int chatId, String text, {int? replyToId})
  _sendSecret;
  final Future<void> Function(
    int chatId,
    String text, {
    int? replyToId,
    void Function()? onLocalSaved,
  })
  _send;
  final void Function() _clearReply;
  final void Function(int replyId, String preview) _restoreReply;
  final void Function() _scrollToBottom;
  final void Function(int chatId) _markBlockedByUser;
  final void Function(Object error) _onError;

  /// How long the first send waits for the chat list before giving up.
  final Duration metadataTimeout;

  /// Shared by the secret and the ordinary path: one guard, one message.
  bool _savingSecretMessage = false;

  bool _isDisposed = false;

  /// Whether a send is in flight (the screen's double-tap fence).
  bool get isSending => _savingSecretMessage;

  /// Sends [TextEditingController.text] of the current chat.
  ///
  /// The secret path is awaited; the ordinary path fires and forgets and
  /// returns right after dispatch, exactly as the screen did.
  Future<void> send() async {
    if (_haptics()) HapticService.confirm();
    final int? chatId = _chatId();
    if (chatId == null) {
      return;
    }

    final String text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    ApiChatSummary? currentChat = _chat(chatId);
    if (currentChat == null && !_isSecret()) {
      try {
        await _ensureChats().timeout(metadataTimeout);
      } catch (_) {}
      if (_isDisposed) return;
      currentChat = _chat(chatId);
      if (currentChat == null) {
        _onError(_l10n().secretSaveFailed);
        return;
      }
    }
    final int? myUserId = _myUserId();
    final bool hasPartnerReply =
        currentChat?.chatType == 'direct' &&
        myUserId != null &&
        _messages().any((m) => m.senderId != myUserId);
    if (isChatRestrictedBySpamBlock(
      isAccountSpamBlocked: _isAccountSpamBlocked(),
      chat: currentChat,
      myUserId: myUserId,
      hasPartnerReply: hasPartnerReply,
    )) {
      _onError(_l10n().chatAccountRestricted);
      return;
    }
    if (currentChat != null && currentChat.chatType == 'direct') {
      final int? partnerId = currentChat.partnerUserId;
      final bool isBlockedByMe =
          (partnerId != null && _isUserBlocked(partnerId)) ||
          currentChat.isBlockedByMe;
      if (isBlockedByMe) {
        _onError(_l10n().chatUnblockToSend);
        return;
      }
    }

    final int? replyId = _replyToMessageId();
    final String originalText = _textController.text;
    final String? originalReplyPreview = _replyPreviewText();

    if (currentChat?.isSecret == true || _isSecret()) {
      if (_savingSecretMessage) return;
      _savingSecretMessage = true;
      try {
        await _sendSecret(chatId, text, replyToId: replyId);
        if (_isDisposed) return;
        if (_textController.text == originalText) _textController.clear();
        if (_replyToMessageId() == replyId) _clearReply();
        _scrollToBottom();
      } catch (_) {
        if (!_isDisposed) _onError(_l10n().secretSaveFailed);
      } finally {
        _savingSecretMessage = false;
      }
      return;
    }

    if (_savingSecretMessage) return;
    _savingSecretMessage = true;
    var savedLocally = false;
    void clearSavedComposer() {
      savedLocally = true;
      _savingSecretMessage = false;
      if (_isDisposed) return;
      if (_textController.text == originalText) _textController.clear();
      if (_replyToMessageId() == replyId) _clearReply();
      _scrollToBottom();
    }

    unawaited(
      _send(
            chatId,
            text,
            replyToId: replyId,
            onLocalSaved: clearSavedComposer,
          )
          .catchError((Object error) {
            if (_isDisposed) {
              return;
            }
            if (!savedLocally) _savingSecretMessage = false;
            // A delayed failure must never replace text typed in the meantime.
            if (savedLocally || _textController.text != originalText) return;
            _textController.text = originalText;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: originalText.length),
            );
            if (replyId != null &&
                originalReplyPreview != null &&
                _replyToMessageId() == replyId) {
              _restoreReply(replyId, originalReplyPreview);
            }
            final String errorStr = error.toString().toLowerCase();
            if (errorStr.contains('not accept direct messages') ||
                errorStr.contains('unavailable between these users') ||
                errorStr.contains('restricted by user')) {
              _markBlockedByUser(chatId);
              _onError(_l10n().chatMessagesRestrictedByUser);
            } else {
              _onError(error);
            }
          })
          .whenComplete(() {
            if (!savedLocally) _savingSecretMessage = false;
          }),
    );
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
  }
}
