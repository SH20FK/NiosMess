import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/chat/chat_list_provider.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_presenter.dart';
import 'package:pulse_flutter/widgets/message_context_menu_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

/// The read-only plumbing the chat screen lends to
/// [ChatMessageActionController].
///
/// A small value object, like the controllers it feeds: no `ref`, no stored
/// `BuildContext`, no widgets. The screen builds it in `initState` out of live
/// getters, so a language switch, a chat change or an account change is picked
/// up at call time, never captured at construction.
class ChatDetailPorts {
  const ChatDetailPorts({
    required this.read,
    required this.l10n,
    required this.chatId,
    required this.onError,
    required this.onSuccess,
    required this.onInfo,
    required this.push,
    required this.scrollToBottom,
    required this.haptics,
  });

  /// `ref.read`, at call time — the controller never keeps a [Ref].
  final T Function<T>(ProviderListenable<T> provider) read;

  /// Live localization: the next toast or sheet must use the current locale.
  final AppLocalizations Function() l10n;

  /// The chat this screen shows; `null` when the route id does not parse.
  final int? Function() chatId;

  /// Reports a failed action (the screen decides whether a toast is possible).
  final void Function(Object error) onError;

  /// A completed action ("forwarded", "saved", "report sent").
  final void Function(String message) onSuccess;

  /// A neutral confirmation ("text copied").
  final void Function(String message) onInfo;

  /// `context.push(location, extra: extra)`, for the comments route.
  final void Function(String location, {Object? extra}) push;

  /// The screen's scroll hook, kept here so an action that moves the list can
  /// bring the newest message into view without owning a scroll controller.
  final void Function() scrollToBottom;

  /// The user's haptics preference, read at call time.
  final bool Function() haptics;
}

/// Owns the message context menu and everything it can do to a message:
/// the twelve [MessageActionType] outcomes that used to live on the screen.
///
/// A plain class, like `ChatComposerController` and `ChatMediaController`: no
/// `ref` and no stored `BuildContext`. Reads go through [ChatDetailPorts];
/// writes, sheets and repository calls arrive as narrow function seams the
/// screen wires to its own `ref` / `context` / `setState`, which keeps every
/// branch testable without a widget tree.
///
/// Behaviour carried over verbatim from `_ChatDetailScreenState`:
/// * Media forward is `fetchAndDecryptMedia` -> `base64Decode(e2eeFileKey)` ->
///   `uploadAndSend(attachCurrentReply: false)` — the order and the `false`
///   are load-bearing: a forward never inherits the composer's reply target.
/// * `saveToSaved` and `remind` append `?highlight=<id>`, and only a message
///   with media gets the link appended to the saved text.
/// * `remind` goes through `showScheduledMessageComposer` (delayed sending).
/// * `comments` pushes `/channel/<chatId>/post/<messageId>/comments`.
/// * `copy` copies `ChatMessagePresenter.displayText`, never raw `content`:
///   a live location or an interactive message copies its preview.
/// * Delete is gated by "mine or admin/owner", and the confirmation dialog is
///   shown before the repository is touched.
/// * `report` sends `messageIds: [message.id]` and
///   `reportedUserId: message.senderId`.
class ChatMessageActionController {
  ChatMessageActionController({
    required ChatDetailPorts ports,
    required Future<bool> Function() confirmDelete,
    required Future<void> Function(int messageId) deleteMessage,
    required Future<void> Function(int messageId, String emoji) toggleReaction,
    required Future<String?> Function(ApiMessage message) pickReaction,
    required Future<String?> Function(ApiMessage message) pickReportReason,
    required Future<void> Function(int chatId, String text) sendText,
    required Future<void> Function(ApiMessage message, String text) saveToSaved,
    required Future<void> Function({
      required int chatId,
      required int reportedUserId,
      required List<int> messageIds,
      required ApiMessage selectedMessage,
      required String reason,
    })
    report,
    required Future<void> Function({
      required int chatId,
      required String text,
      required ApiMessage reminder,
    })
    showScheduledComposer,
    required Future<void> Function({
      required int chatId,
      Uint8List? bytes,
      String? filePath,
      required String filename,
      required String mediaSubtype,
      required int fileSize,
      required String text,
      required bool attachCurrentReply,
    })
    uploadAndSend,
    required Future<Uint8List> Function({
      required String filePath,
      Uint8List? e2eeFileKey,
    })
    fetchMedia,
    required void Function(ApiMessage message) setReply,
    required Future<void> Function(ApiMessage message) beginEdit,
    required Future<void> Function(ApiMessage message) requestFile,
    required Future<void> Function(ApiMessage message) requestForward,
  }) : _ports = ports,
       _confirmDelete = confirmDelete,
       _deleteMessageWrite = deleteMessage,
       _toggleReaction = toggleReaction,
       _pickReaction = pickReaction,
       _pickReportReason = pickReportReason,
       _sendText = sendText,
       _saveToSaved = saveToSaved,
       _report = report,
       _showScheduledComposer = showScheduledComposer,
       _uploadAndSend = uploadAndSend,
       _fetchMedia = fetchMedia,
       _setReply = setReply,
       _beginEdit = beginEdit,
       _requestFile = requestFile,
       _requestForward = requestForward;

  final ChatDetailPorts _ports;
  final Future<bool> Function() _confirmDelete;
  final Future<void> Function(int messageId) _deleteMessageWrite;
  final Future<void> Function(int messageId, String emoji) _toggleReaction;
  final Future<String?> Function(ApiMessage message) _pickReaction;
  final Future<String?> Function(ApiMessage message) _pickReportReason;
  final Future<void> Function(int chatId, String text) _sendText;
  final Future<void> Function(ApiMessage message, String text) _saveToSaved;
  final Future<void> Function({
    required int chatId,
    required int reportedUserId,
    required List<int> messageIds,
    required ApiMessage selectedMessage,
    required String reason,
  })
  _report;
  final Future<void> Function({
    required int chatId,
    required String text,
    required ApiMessage reminder,
  })
  _showScheduledComposer;
  final Future<void> Function({
    required int chatId,
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required String text,
    required bool attachCurrentReply,
  })
  _uploadAndSend;
  final Future<Uint8List> Function({
    required String filePath,
    Uint8List? e2eeFileKey,
  })
  _fetchMedia;
  final void Function(ApiMessage message) _setReply;
  final Future<void> Function(ApiMessage message) _beginEdit;
  final Future<void> Function(ApiMessage message) _requestFile;
  final Future<void> Function(ApiMessage message) _requestForward;

  ChatMessagePresenter get _presenter => ChatMessagePresenter(_ports.l10n());

  /// The long-press menu. [context] is the screen's, used only to show the
  /// sheet; every outcome is dispatched by [handleAction].
  Future<void> showMessageActions(
    BuildContext context,
    ApiMessage message, {
    required bool isMine,
    required bool isChannel,
    required bool amAdminOrOwner,
  }) async {
    final MessageActionResult?
    result = await AppModal.showSheet<MessageActionResult>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: MessageContextMenuSheet(
          message: message,
          isMine: isMine,
          isChannel: isChannel,
          amAdminOrOwner: amAdminOrOwner,
          isSecret:
              _ports.read(chatByIdProvider(_ports.chatId() ?? 0))?.isSecret ==
              true,
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    await handleAction(
      message,
      result,
      isMine: isMine,
      amAdminOrOwner: amAdminOrOwner,
    );
  }

  /// One action per [MessageActionType]; Dart 3 ends each `case` implicitly,
  /// so exactly one branch runs and nothing falls through.
  Future<void> handleAction(
    ApiMessage message,
    MessageActionResult result, {
    required bool isMine,
    required bool amAdminOrOwner,
  }) async {
    switch (result.type) {
      case MessageActionType.react:
        await react(message, result.emoji);
      case MessageActionType.showAllReactions:
        await showAllReactionsPicker(message);
      case MessageActionType.reply:
        _setReply(message);
      case MessageActionType.requestFile:
        await requestFile(message);
      case MessageActionType.copy:
        copyText(message);
      case MessageActionType.saveToSaved:
        await saveToSaved(message);
      case MessageActionType.remind:
        await remind(message);
      case MessageActionType.forward:
        await _requestForward(message);
      case MessageActionType.comments:
        openComments(message);
      case MessageActionType.edit:
        await _beginEdit(message);
      case MessageActionType.delete:
        await deleteMessage(
          message,
          isMine: isMine,
          amAdminOrOwner: amAdminOrOwner,
        );
      case MessageActionType.report:
        await requestReport(message);
    }
  }

  /// Toggles [emoji] on [message]. A quick-reaction tap always has an emoji;
  /// a `null` one (defensive) does nothing, exactly as the screen did.
  Future<void> react(ApiMessage message, String? emoji) async {
    if (_ports.chatId() == null) return;
    if (emoji == null || emoji.isEmpty) return;
    try {
      await _toggleReaction(message.id, emoji);
    } catch (error) {
      _ports.onError(error);
    }
  }

  /// Opens the full reaction picker and toggles the chosen emoji. The toggle
  /// is not wrapped on purpose: the screen never caught it either.
  Future<void> showAllReactionsPicker(ApiMessage message) async {
    if (_ports.chatId() == null) return;
    final String? emoji = await _pickReaction(message);
    if (emoji == null) return;
    if (_ports.haptics()) HapticService.reaction();
    await _toggleReaction(message.id, emoji);
  }

  /// Deletes after confirmation. [isMine] / [amAdminOrOwner] are passed by the
  /// context menu; when both are `false` the write never happens. Media menus
  /// already hide delete behind the same permission and pass neither.
  Future<void> deleteMessage(
    ApiMessage message, {
    bool? isMine,
    bool? amAdminOrOwner,
  }) async {
    if (isMine == false && amAdminOrOwner == false) return;
    if (_ports.chatId() == null) return;
    final bool confirmed = await _confirmDelete();
    if (!confirmed) return;
    try {
      await _deleteMessageWrite(message.id);
    } catch (error) {
      _ports.onError(error);
    }
  }

  /// Copies what the bubble shows, not the raw payload.
  void copyText(ApiMessage message) {
    Clipboard.setData(ClipboardData(text: _presenter.displayText(message)));
    _ports.onInfo(_ports.l10n().chatMessageTextCopied);
  }

  /// Saves the message to "Saved". A media message also gets a deep link with
  /// `?highlight=<id>` so the saved entry opens the original.
  Future<void> saveToSaved(ApiMessage message) async {
    try {
      String text = _presenter.displayText(message);
      if (message.hasMedia) {
        text = '$text\n${_highlightLink(message)}';
      }
      await _saveToSaved(message, text);
      _ports.onSuccess('Сохранено в Избранное');
    } catch (error) {
      _ports.onError(error);
    }
  }

  /// Hands the message (plus its highlight link) to the schedule composer.
  Future<void> remind(ApiMessage message) async {
    await _showScheduledComposer(
      chatId: message.chatId,
      reminder: message,
      text: '${_presenter.displayText(message)}\n${_highlightLink(message)}',
    );
  }

  /// The forum/comments route of a channel post.
  void openComments(ApiMessage message) {
    final int? chatId = _ports.chatId();
    if (chatId == null) return;
    _ports.push('/channel/$chatId/post/${message.id}/comments');
  }

  /// Asks for a file from the other side and reports the outcome.
  Future<void> requestFile(ApiMessage message) async {
    try {
      await _requestFile(message);
      _ports.onSuccess('Запрос отправлен');
    } catch (error) {
      _ports.onError(error);
    }
  }

  /// Asks for a reason, then files the report.
  Future<void> requestReport(ApiMessage message) async {
    final String? reason = await _pickReportReason(message);
    if (reason == null) return;
    await submitReport(message, reason);
  }

  /// Reports this one message against its sender.
  Future<void> submitReport(ApiMessage message, String reason) async {
    try {
      await _report(
        chatId: message.chatId,
        reportedUserId: message.senderId,
        messageIds: <int>[message.id],
        selectedMessage: message,
        reason: reason,
      );
      _ports.onSuccess(_ports.l10n().reportSent);
    } catch (error) {
      _ports.onError(error);
    }
  }

  /// The forward picker: chats from `chatsProvider`, the sheet, then the
  /// transfer. [context] is the screen's and is only used to show the sheet.
  Future<void> forwardMessage(BuildContext context, ApiMessage message) async {
    final AsyncValue<List<ApiChatSummary>> chatsAsync = _ports.read(
      chatsProvider,
    );
    final List<ApiChatSummary> chats =
        chatsAsync.value ?? const <ApiChatSummary>[];
    if (chats.isEmpty) return;

    final AppLocalizations l10n = _ports.l10n();
    final ApiChatSummary? target = await AppModal.showSheet<ApiChatSummary>(
      context: context,
      builder: (BuildContext ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.chatForwardTo,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...chats.map(
              (ApiChatSummary c) => ListTile(
                leading: PulseAvatar(
                  radius: 18,
                  name: c.name,
                  avatarUrl: c.avatarUrl,
                ),
                title: Text(c.name),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
            ),
          ],
        );
      },
    );

    if (target == null) return;
    await forwardTo(message, target);
  }

  /// Transfers [message] into [target].
  ///
  /// Media is fetched and decrypted, the E2EE key is base64-decoded, and the
  /// bytes go up with `attachCurrentReply: false` — the reply target belongs to
  /// the composer, not to the forwarded copy. Text messages are re-sent as-is.
  Future<void> forwardTo(ApiMessage message, ApiChatSummary target) async {
    try {
      if (message.hasMedia && message.mediaUrl != null) {
        final Uint8List mediaBytes = await _fetchMedia(
          filePath: message.mediaUrl!,
          e2eeFileKey: message.e2eeFileKey != null
              ? base64Decode(message.e2eeFileKey!)
              : null,
        );
        final String filename = (message.mediaName ?? '').isNotEmpty
            ? message.mediaName!
            : 'forward_${DateTime.now().millisecondsSinceEpoch}';
        final FileTypeInfo typeInfo = FileTypeDetector.detect(
          fileName: filename,
        );
        final String? mediaType = message.mediaType;
        final String subtype = message.msgType == 'voice'
            ? 'voice'
            : message.msgType == 'circle'
            ? 'circle'
            : mediaType == 'image' ||
                  mediaType == 'video' ||
                  mediaType == 'audio'
            ? mediaType!
            : (typeInfo.isImage
                  ? 'image'
                  : typeInfo.isVideo
                  ? 'video'
                  : typeInfo.isAudio
                  ? 'audio'
                  : 'document');
        await _uploadAndSend(
          chatId: target.id,
          bytes: mediaBytes,
          filename: filename,
          mediaSubtype: subtype,
          fileSize: message.mediaSize ?? mediaBytes.length,
          text: message.content,
          attachCurrentReply: false,
        );
      } else {
        await _sendText(target.id, message.content);
      }
      _ports.onSuccess(_ports.l10n().chatMessageForwarded);
    } catch (error) {
      _ports.onError(error);
    }
  }

  String _highlightLink(ApiMessage message) =>
      '${ApiConstants.origin}/web/#/chat/${message.chatId}?highlight=${message.id}';
}
