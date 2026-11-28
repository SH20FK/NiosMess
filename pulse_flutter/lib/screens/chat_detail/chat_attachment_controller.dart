import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/clipboard/pasted_image.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/media/media_album.dart';
import 'package:pulse_flutter/core/services/desktop_pasteboard_service.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/widgets/m3_file_picker_bottom_sheet.dart';

/// Owns every attachment path: composer attachment, pasted images, desktop
/// files, voice, circle video and stickers.
///
/// A plain class, like `ChatSendController`: no `ref` and no `BuildContext`.
/// The screen reads its providers and hands in plain callbacks; live values
/// (chat metadata, identity, reply target, composer text) are function getters,
/// read at call time, never captured in the constructor.
///
/// Invariants carried over verbatim from `_ChatDetailScreenState`:
/// 1. The secret branch returns **before** any optimistic message is created:
///    the engine queue is the only writer.
/// 2. The ordinary branch is `localId = -(ms + Random(1000))` → optimistic
///    `ApiMessage(isSending: true)` → `addOptimisticLocalMessage` → upload
///    enqueue, in exactly that order.
/// 3. `type` is `voice` / `circle` / `media`; anything else is media.
/// 4. Empty bytes on the secret branch is `StateError('Empty attachment')`.
/// 5. `localId` is negative and parsed as-is — the sign is what tells the
///    message list this row is local; never `abs`.
/// 6. The composer is cleared only while its text still equals the text the
///    upload carried.
/// 7. An album is packed by `compute` into `NiosMess-Album.niosalbum.zip` and
///    uploaded as a `document`.
/// 8. Desktop paste ignores a second paste inside 400 ms, and the same file
///    list inside the deduplicator's cooldown.
class ChatAttachmentController {
  ChatAttachmentController({
    required int? Function() chatId,
    required TextEditingController textController,
    required AppLocalizations Function() l10n,
    required ApiChatSummary? Function(int chatId) chat,
    required Future<void> Function() ensureChats,
    required bool Function() isSecret,
    required bool Function() isEditingMessage,
    required ({int userId, String username, String displayName}) Function()
    identity,
    required int? Function() replyToMessageId,
    required Future<void> Function(
      int chatId,
      String filePath, {
      required String filename,
      required String type,
      required String text,
      int? replyToId,
    })
    enqueueSecretFile,
    required Future<void> Function(
      int chatId,
      Uint8List bytes, {
      required String filename,
      required String type,
      required String text,
      int? replyToId,
    })
    enqueueSecretBytes,
    required void Function(int chatId, ApiMessage message) addOptimistic,
    required void Function({
      required String localId,
      required int chatId,
      required String filePath,
      required Uint8List? bytes,
      required String filename,
      required String mediaSubtype,
      required int fileSize,
      required String text,
      required int? replyToId,
    })
    enqueueUpload,
    required void Function() clearReply,
    required void Function() scrollToBottom,
    required void Function(Object error) showError,
    required Future<List<M3FilePickerResult>?> Function(
      Future<void> Function(String kind) onOpenInteractive,
    )
    pickFiles,
    required Future<String?> Function(String kind) showInteractive,
    required Future<void> Function(int chatId, String content) sendInteractive,
    required Future<void> Function({
      required List<PastedImage> images,
      required String caption,
      required Future<void> Function(List<PastedImage> images, String caption)
      onSendAlbum,
      required Future<void> Function(PastedImage image, String caption) onSend,
    })
    showImagesDialog,
    required void Function() requestInputFocus,
    required bool Function() isDesktop,
    required Future<List<String>> Function() readClipboardFiles,
    required Future<void> Function(int chatId, int stickerId, {int? replyToId})
    sendSticker,
    DateTime Function()? now,
    DesktopPasteDeduplicator? pasteDeduplicator,
    this.metadataTimeout = const Duration(seconds: 8),
    this.pasteWindow = const Duration(milliseconds: 400),
    bool? isWeb,
  }) : _chatId = chatId,
       _textController = textController,
       _l10n = l10n,
       _chat = chat,
       _ensureChats = ensureChats,
       _isSecret = isSecret,
       _isEditingMessage = isEditingMessage,
       _identity = identity,
       _replyToMessageId = replyToMessageId,
       _enqueueSecretFile = enqueueSecretFile,
       _enqueueSecretBytes = enqueueSecretBytes,
       _addOptimistic = addOptimistic,
       _enqueueUpload = enqueueUpload,
       _clearReply = clearReply,
       _scrollToBottom = scrollToBottom,
       _showError = showError,
       _pickFiles = pickFiles,
       _showInteractive = showInteractive,
       _sendInteractive = sendInteractive,
       _showImagesDialog = showImagesDialog,
       _requestInputFocus = requestInputFocus,
       _isDesktop = isDesktop,
       _readClipboardFiles = readClipboardFiles,
       _sendSticker = sendSticker,
       _now = now ?? DateTime.now,
       _pasteDeduplicator = pasteDeduplicator ?? DesktopPasteDeduplicator(),
       _isWeb = isWeb ?? kIsWeb;

  final int? Function() _chatId;
  final TextEditingController _textController;
  final AppLocalizations Function() _l10n;
  final ApiChatSummary? Function(int chatId) _chat;
  final Future<void> Function() _ensureChats;
  final bool Function() _isSecret;
  final bool Function() _isEditingMessage;
  final ({int userId, String username, String displayName}) Function()
  _identity;
  final int? Function() _replyToMessageId;
  final Future<void> Function(
    int chatId,
    String filePath, {
    required String filename,
    required String type,
    required String text,
    int? replyToId,
  })
  _enqueueSecretFile;
  final Future<void> Function(
    int chatId,
    Uint8List bytes, {
    required String filename,
    required String type,
    required String text,
    int? replyToId,
  })
  _enqueueSecretBytes;
  final void Function(int chatId, ApiMessage message) _addOptimistic;
  final void Function({
    required String localId,
    required int chatId,
    required String filePath,
    required Uint8List? bytes,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required String text,
    required int? replyToId,
  })
  _enqueueUpload;
  final void Function() _clearReply;
  final void Function() _scrollToBottom;
  final void Function(Object error) _showError;
  final Future<List<M3FilePickerResult>?> Function(
    Future<void> Function(String kind) onOpenInteractive,
  )
  _pickFiles;
  final Future<String?> Function(String kind) _showInteractive;
  final Future<void> Function(int chatId, String content) _sendInteractive;
  final Future<void> Function({
    required List<PastedImage> images,
    required String caption,
    required Future<void> Function(List<PastedImage> images, String caption)
    onSendAlbum,
    required Future<void> Function(PastedImage image, String caption) onSend,
  })
  _showImagesDialog;
  final void Function() _requestInputFocus;
  final bool Function() _isDesktop;
  final Future<List<String>> Function() _readClipboardFiles;
  final Future<void> Function(int chatId, int stickerId, {int? replyToId})
  _sendSticker;
  final DateTime Function() _now;
  final DesktopPasteDeduplicator _pasteDeduplicator;

  bool _desktopPasteInFlight = false;
  DateTime? _lastDesktopPasteAt;

  /// How long an upload waits for chat metadata before giving up.
  final Duration metadataTimeout;

  /// How close two desktop pastes may be before the second is swallowed.
  final Duration pasteWindow;

  /// Whether the platform is web. Defaults to [kIsWeb]; overridable for tests.
  final bool _isWeb;

  bool _isDisposed = false;

  /// Uploads one attachment to [chatId] and sends it.
  ///
  /// The secret branch awaits the engine queue and returns. The ordinary branch
  /// adds the optimistic row and hands the bytes to the upload queue.
  Future<void> uploadAndSend({
    required int chatId,
    String? filePath,
    Uint8List? bytes,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    String text = '',
    bool showSentSnackBar = false,
    bool attachCurrentReply = true,
  }) async {
    final int? replyToId = attachCurrentReply ? _replyToMessageId() : null;
    if (_chat(chatId) == null && !_isSecret()) {
      try {
        await _ensureChats().timeout(metadataTimeout);
      } catch (_) {}
      if (_isDisposed) return;
      if (_chat(chatId) == null) {
        _showError(_l10n().errorFileUploadFailed);
        throw StateError('Conversation metadata unavailable');
      }
    }
    if (_chat(chatId)?.isSecret == true || _isSecret()) {
      try {
        final String type = mediaSubtype == 'voice'
            ? 'voice'
            : mediaSubtype == 'circle'
            ? 'circle'
            : 'media';
        if (!_isWeb && filePath != null && filePath.isNotEmpty) {
          await _enqueueSecretFile(
            chatId,
            filePath,
            filename: filename,
            type: type,
            text: text,
            replyToId: replyToId,
          );
        } else {
          if (bytes == null || bytes.isEmpty) {
            throw StateError('Empty attachment');
          }
          await _enqueueSecretBytes(
            chatId,
            bytes,
            filename: filename,
            type: type,
            text: text,
            replyToId: replyToId,
          );
        }
        if (!_isDisposed && attachCurrentReply) {
          if (_textController.text == text) _textController.clear();
          _clearReply();
          _scrollToBottom();
        }
        // Returns before any optimistic row: the engine queue is the writer.
        return;
      } catch (_) {
        if (!_isDisposed) _showError(_l10n().secretAttachmentSaveFailed);
        rethrow;
      }
    }

    final ({int userId, String username, String displayName}) me = _identity();
    final String localId =
        (-(DateTime.now().millisecondsSinceEpoch + Random().nextInt(1000)))
            .toString();
    // Negative on purpose: the message list treats a negative id as local.
    final int tempIntId = int.parse(localId);

    final Uint8List? effectiveBytes = (bytes != null && bytes.isNotEmpty)
        ? bytes
        : null;
    final String effectiveFilePath = filePath ?? '';

    final String myDisplayName = me.displayName.trim();
    final String effectiveDisplayName = myDisplayName.isNotEmpty
        ? myDisplayName
        : (me.username.isNotEmpty ? me.username : _l10n().chatSenderYou);
    final ApiMessage optimisticMessage = ApiMessage(
      id: tempIntId,
      chatId: chatId,
      senderId: me.userId,
      senderUsername: me.username,
      senderDisplayName: effectiveDisplayName,
      senderBadges: const [],
      content: text,
      msgType: mediaSubtype == 'voice'
          ? 'voice'
          : (mediaSubtype == 'circle' ? 'circle' : 'media'),
      replyToId: replyToId,
      mediaUrl: filePath ?? 'local://$localId',
      mediaType: 'file',
      mediaName: filename,
      mediaSize: fileSize,
      mediaDuration: null,
      commentsCount: 0,
      reactions: const {},
      sentAt: DateTime.now(),
      editedAt: null,
      isDeleted: false,
      isSending: true,
      isFailed: false,
    );

    _addOptimistic(chatId, optimisticMessage);
    if (attachCurrentReply) {
      _clearReply();
      _scrollToBottom();
    }

    _enqueueUpload(
      localId: localId,
      chatId: chatId,
      filePath: effectiveFilePath,
      bytes: effectiveBytes,
      filename: filename,
      mediaSubtype: mediaSubtype,
      fileSize: fileSize,
      text: text,
      replyToId: replyToId,
    );
  }

  /// Previews [images] and sends them, one by one or as an album.
  ///
  /// The album is encoded off the UI isolate by [compute] and uploaded as a
  /// `document`. The composer keeps its text unless it still equals the text
  /// the dialog opened with.
  Future<void> previewPastedImages(
    List<PastedImage> images, {
    String? initialCaption,
  }) async {
    final int? chatId = _chatId();
    if (_isDisposed || chatId == null || _isEditingMessage()) return;
    final String originalText = _textController.text;
    await _showImagesDialog(
      images: images,
      caption: initialCaption ?? originalText,
      onSendAlbum: (List<PastedImage> album, String caption) async {
        if (_isDisposed || _chatId() != chatId) {
          throw StateError('Conversation closed');
        }
        final Uint8List bytes = await compute(_encodeAlbum, album);
        if (_isDisposed || _chatId() != chatId) {
          throw StateError('Conversation closed');
        }
        await uploadAndSend(
          chatId: chatId,
          bytes: bytes,
          filename: 'NiosMess-Album.niosalbum.zip',
          mediaSubtype: 'document',
          fileSize: bytes.length,
          text: caption,
        );
        if (!_isDisposed && _textController.text == originalText) {
          _textController.clear();
        }
      },
      onSend: (PastedImage image, String caption) async {
        if (_isDisposed || _chatId() != chatId) {
          throw StateError('Conversation closed');
        }
        await uploadAndSend(
          chatId: chatId,
          bytes: image.bytes,
          filename: image.name,
          mediaSubtype: MediaAlbum.imageExtension(image.bytes) != null
              ? 'image'
              : 'document',
          fileSize: image.bytes.length,
          text: caption,
        );
        if (!_isDisposed && _textController.text == originalText) {
          _textController.clear();
        }
      },
    );
    if (!_isDisposed) _requestInputFocus();
  }

  /// Opens the attachment sheet and uploads what it returns.
  ///
  /// Several images become an album preview; everything else is uploaded one
  /// by one, the first carrying the composer's text.
  Future<void> pickAndUploadMedia() async {
    final int? chatId = _chatId();
    if (chatId == null) return;

    final List<M3FilePickerResult>? results = await _pickFiles((
      String kind,
    ) async {
      final int accountId = _identity().userId;
      final String? content = await _showInteractive(kind);
      if (_isDisposed || content == null || _identity().userId != accountId) {
        return;
      }
      try {
        await _sendInteractive(chatId, content);
      } catch (_) {
        if (_isDisposed) return;
        _showError(_l10n().interactiveSendFailed);
      }
    });
    if (results == null || results.isEmpty || _isDisposed) {
      return;
    }

    if (results.length > 1 &&
        results.length <= 10 &&
        results.every((r) => !r.sendAsDocument && r.mediaSubtype == 'image')) {
      final List<PastedImage> images = <PastedImage>[];
      for (final M3FilePickerResult result in results) {
        final Uint8List? bytes =
            result.fileBytes ??
            (result.filePath != null
                ? await File(result.filePath!).readAsBytes()
                : null);
        if (bytes == null) return;
        images.add(
          PastedImage(
            bytes: bytes,
            name: result.fileName,
            mimeType: 'image/unknown',
          ),
        );
      }
      if (!_isDisposed) {
        await previewPastedImages(
          images,
          initialCaption: results.first.caption,
        );
      }
      return;
    }

    final String initialText = _textController.text;
    if (!_isDisposed && !_isSecret() && _chat(chatId)?.isSecret != true) {
      _textController.clear();
    }

    for (int i = 0; i < results.length; i++) {
      final M3FilePickerResult result = results[i];
      final String caption =
          (result.caption != null && result.caption!.isNotEmpty)
          ? result.caption!
          : (i == 0 ? initialText : '');

      await uploadAndSend(
        chatId: chatId,
        filePath: result.filePath,
        bytes: result.fileBytes,
        filename: result.fileName,
        mediaSubtype: result.sendAsDocument ? 'document' : result.mediaSubtype,
        fileSize: result.fileSize,
        text: caption,
        showSentSnackBar: false,
      );
    }
  }

  /// Reads the desktop clipboard and uploads the files it holds.
  ///
  /// Two pastes closer than [pasteWindow] are the same gesture observed twice.
  Future<void> handleDesktopPaste() async {
    if (!_isDesktop() || _isDisposed) return;
    final DateTime now = _now();
    if (_desktopPasteInFlight) return;
    if (_lastDesktopPasteAt != null &&
        now.difference(_lastDesktopPasteAt!) < pasteWindow) {
      return;
    }
    _desktopPasteInFlight = true;
    _lastDesktopPasteAt = now;
    try {
      final List<String> files = await _readClipboardFiles();
      if (files.isNotEmpty && !_isDisposed) {
        await uploadDesktopFiles(files);
      }
    } finally {
      _desktopPasteInFlight = false;
    }
  }

  /// Uploads dropped or pasted [filePaths].
  ///
  /// The same list inside [DesktopPasteDeduplicator.cooldown] is dropped, so a
  /// drag and a paste of one gesture never double-send.
  Future<void> uploadDesktopFiles(
    List<String> filePaths, {
    bool sendAsDocument = false,
  }) async {
    final int? chatId = _chatId();
    if (chatId == null || filePaths.isEmpty) return;
    if (!_pasteDeduplicator.shouldAccept(filePaths)) return;
    final String initialText = _textController.text;
    if (!_isDisposed && !_isSecret() && _chat(chatId)?.isSecret != true) {
      _textController.clear();
    }

    for (int i = 0; i < filePaths.length; i++) {
      final String filePath = filePaths[i];
      final File file = File(filePath);
      if (!await file.exists()) continue;
      final int size = await file.length();
      final String filename = filePath.split(RegExp(r'[/\\]')).last;
      final FileTypeInfo typeInfo = FileTypeDetector.detect(fileName: filename);
      final String mediaSubtype = sendAsDocument
          ? 'document'
          : (typeInfo.isImage
                ? 'image'
                : (typeInfo.isVideo
                      ? 'video'
                      : (typeInfo.isAudio ? 'audio' : 'document')));

      await uploadAndSend(
        chatId: chatId,
        filePath: filePath,
        bytes: null,
        filename: filename,
        mediaSubtype: mediaSubtype,
        fileSize: size,
        text: i == 0 ? initialText : '',
        showSentSnackBar: false,
      );
    }
  }

  /// Sends the recorded voice note at [filePath].
  Future<void> sendVoiceMessage(String filePath) async {
    final int? chatId = _chatId();
    if (chatId == null) return;

    final File file = File(filePath);
    final int fileSize = await file.length();
    final String filename = filePath.split('/').last;

    await uploadAndSend(
      chatId: chatId,
      filePath: filePath,
      filename: filename,
      mediaSubtype: 'voice',
      fileSize: fileSize,
    );
  }

  /// Sends the recorded circle video at [filePath].
  ///
  /// Temp captures are renamed `.mp4`: the recorder writes `.temp`, and a
  /// nameless file would reach the receiver without a video extension.
  Future<void> sendCircleVideo(String filePath) async {
    final int? chatId = _chatId();
    if (chatId == null) return;

    final File file = File(filePath);
    final int fileSize = await file.length();
    String filename = filePath.split(RegExp(r'[/\\]')).last.trim();
    if (filename.toLowerCase().endsWith('.temp')) {
      filename = '${filename.substring(0, filename.length - 5)}.mp4';
    } else if (!filename.contains('.')) {
      filename = '$filename.mp4';
    }

    await uploadAndSend(
      chatId: chatId,
      filePath: filePath,
      filename: filename,
      mediaSubtype: 'circle',
      fileSize: fileSize,
    );
  }

  /// Sends [sticker] to the current chat, replying to the composer's target.
  Future<void> sendSticker(ApiSticker sticker) async {
    final int? chatId = _chatId();
    if (chatId == null) return;
    try {
      await _sendSticker(chatId, sticker.id, replyToId: _replyToMessageId());
      _clearReply();
    } catch (error) {
      if (!_isDisposed) _showError(_l10n().chatStickerSendFailed(error));
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
  }
}

Uint8List _encodeAlbum(List<PastedImage> images) => MediaAlbum.encode(
  <AlbumImage>[
    for (final PastedImage image in images) AlbumImage(image.name, image.bytes),
  ],
);
