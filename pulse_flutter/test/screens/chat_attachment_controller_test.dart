// Tests for `lib/screens/chat_detail/chat_attachment_controller.dart`.
//
// A.10 moved the four attachment paths out of `_ChatDetailScreenState`. These
// tests freeze the invariants the split had to keep:
//   1. The secret branch writes through the engine queue and returns **before**
//      any optimistic row exists.
//   2. Secret + path uses `enqueueAttachmentFile`; secret + bytes uses
//      `enqueueAttachment`; on web a path is never used.
//   3. Empty bytes on the secret branch is `StateError('Empty attachment')`.
//   4. The ordinary branch adds the optimistic `isSending: true` message first
//      and enqueues the upload second, with a negative id.
//   5. `attachCurrentReply: false` (a forward) attaches no reply and clears
//      nothing.
//   6. An album goes up as a `document` named `NiosMess-Album.niosalbum.zip`.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/clipboard/pasted_image.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/media/media_album.dart';
import 'package:pulse_flutter/core/services/desktop_pasteboard_service.dart';
import 'package:pulse_flutter/l10n/app_localizations_ru.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_attachment_controller.dart';
import 'package:pulse_flutter/widgets/m3_file_picker_bottom_sheet.dart';

const int _chatId = 42;
const int _myUserId = 7;

ApiChatSummary _chat({bool isSecret = false}) => ApiChatSummary(
  id: _chatId,
  chatType: 'direct',
  name: 'Fixture',
  unreadCount: 0,
  membersCount: 2,
  partnerUserId: 9,
  isSecret: isSecret,
);

/// Stands in for the screen: owns the composer field and records every port.
class _Harness {
  _Harness({
    this.chat,
    this.metadataTimeout = const Duration(seconds: 8),
    this.isWeb,
    this.deduplicator,
  }) {
    controller = ChatAttachmentController(
      chatId: () => _chatId,
      textController: text,
      l10n: () => _l10n,
      chat: (int id) => chat,
      ensureChats: () => chats,
      isSecret: () => secret,
      isEditingMessage: () => isEditing,
      identity: () =>
          (userId: _myUserId, username: 'me', displayName: 'Me Myself'),
      replyToMessageId: () => replyToMessageId,
      enqueueSecretFile:
          (
            int chatId,
            String filePath, {
            required String filename,
            required String type,
            required String text,
            int? replyToId,
          }) async {
            events.add('secretFile');
            secretFiles.add((
              path: filePath,
              filename: filename,
              type: type,
              text: text,
              replyToId: replyToId,
            ));
            if (secretError != null) throw secretError!;
          },
      enqueueSecretBytes:
          (
            int chatId,
            Uint8List bytes, {
            required String filename,
            required String type,
            required String text,
            int? replyToId,
          }) async {
            events.add('secretBytes');
            secretBytes.add((
              length: bytes.length,
              filename: filename,
              type: type,
              text: text,
              replyToId: replyToId,
            ));
            if (secretError != null) throw secretError!;
          },
      addOptimistic: (int chatId, ApiMessage message) {
        events.add('optimistic');
        optimistic.add(message);
      },
      enqueueUpload:
          ({
            required String localId,
            required int chatId,
            required String filePath,
            required Uint8List? bytes,
            required String filename,
            required String mediaSubtype,
            required int fileSize,
            required String text,
            required int? replyToId,
          }) {
            events.add('enqueue');
            uploads.add((
              localId: localId,
              filePath: filePath,
              bytes: bytes,
              filename: filename,
              mediaSubtype: mediaSubtype,
              fileSize: fileSize,
              text: text,
              replyToId: replyToId,
            ));
          },
      clearReply: () {
        clears++;
        replyToMessageId = null;
      },
      scrollToBottom: () => scrolls++,
      showError: errors.add,
      pickFiles: (Future<void> Function(String kind) onOpenInteractive) async =>
          pickResults,
      showInteractive: (String kind) async {
        interactiveKinds.add(kind);
        return interactiveContent;
      },
      sendInteractive: (int chatId, String content) async {
        interactiveSends.add(content);
      },
      showImagesDialog:
          ({
            required List<PastedImage> images,
            required String caption,
            required Future<void> Function(
              List<PastedImage> images,
              String caption,
            )
            onSendAlbum,
            required Future<void> Function(PastedImage image, String caption)
            onSend,
          }) async {
            dialogs.add((count: images.length, caption: caption));
            if (sendAlbum) {
              await onSendAlbum(images, caption);
            }
            if (sendSingle != null) {
              await onSend(images.first, caption);
            }
          },
      requestInputFocus: () => focuses++,
      isDesktop: () => isDesktop,
      readClipboardFiles: () async => clipboard,
      now: () => clock,
      pasteDeduplicator: deduplicator,
      sendSticker: (int chatId, int stickerId, {int? replyToId}) async {
        stickerSends.add((
          chatId: chatId,
          stickerId: stickerId,
          replyToId: replyToId,
        ));
        if (stickerError != null) throw stickerError!;
      },
      metadataTimeout: metadataTimeout,
      isWeb: isWeb,
    );
  }

  final AppLocalizations _l10n = AppLocalizationsRu();
  final TextEditingController text = TextEditingController();
  final List<Object> errors = <Object>[];
  final List<String> events = <String>[];
  final List<ApiMessage> optimistic = <ApiMessage>[];
  final List<
    ({
      String localId,
      String filePath,
      Uint8List? bytes,
      String filename,
      String mediaSubtype,
      int fileSize,
      String text,
      int? replyToId,
    })
  >
  uploads =
      <
        ({
          String localId,
          String filePath,
          Uint8List? bytes,
          String filename,
          String mediaSubtype,
          int fileSize,
          String text,
          int? replyToId,
        })
      >[];
  final List<
    ({String path, String filename, String type, String text, int? replyToId})
  >
  secretFiles =
      <
        ({
          String path,
          String filename,
          String type,
          String text,
          int? replyToId,
        })
      >[];
  final List<
    ({int length, String filename, String type, String text, int? replyToId})
  >
  secretBytes =
      <
        ({
          int length,
          String filename,
          String type,
          String text,
          int? replyToId,
        })
      >[];

  final Duration metadataTimeout;

  ApiChatSummary? chat;
  Future<void> chats = Future<void>.value();
  bool secret = false;
  bool? isWeb;
  bool isEditing = false;
  bool isDesktop = false;
  int? replyToMessageId;
  Object? secretError;
  int clears = 0;
  int scrolls = 0;
  int focuses = 0;

  /// 10b ports.
  List<M3FilePickerResult>? pickResults;
  String? interactiveContent;
  final List<String> interactiveKinds = <String>[];
  final List<String> interactiveSends = <String>[];
  final List<({int count, String caption})> dialogs =
      <({int count, String caption})>[];
  bool sendAlbum = false;
  PastedImage? sendSingle;
  List<String> clipboard = <String>[];
  DateTime clock = DateTime.utc(2026, 11, 28, 12);
  DesktopPasteDeduplicator? deduplicator;

  /// 10c ports.
  final List<({int chatId, int stickerId, int? replyToId})> stickerSends =
      <({int chatId, int stickerId, int? replyToId})>[];
  Object? stickerError;

  late final ChatAttachmentController controller;

  void dispose() {
    controller.dispose();
    text.dispose();
  }
}

void main() {
  final AppLocalizations l10n = AppLocalizationsRu();

  group('ChatAttachmentController secret path', () {
    test('a secret chat with a path uses enqueueAttachmentFile', () async {
      final harness = _Harness(chat: _chat(isSecret: true));
      addTearDown(harness.dispose);
      harness.secret = true;
      harness.text.text = 'caption';
      harness.replyToMessageId = 5;

      await harness.controller.uploadAndSend(
        chatId: _chatId,
        filePath: r'C:\tmp\clip.mp4',
        filename: 'clip.mp4',
        mediaSubtype: 'video',
        fileSize: 10,
        text: 'caption',
      );

      expect(harness.secretFiles.single.path, r'C:\tmp\clip.mp4');
      expect(harness.secretFiles.single.type, 'media');
      expect(harness.secretFiles.single.text, 'caption');
      expect(harness.secretFiles.single.replyToId, 5);
      expect(harness.secretBytes, isEmpty);
    });

    test('a secret chat with bytes uses enqueueAttachment', () async {
      final harness = _Harness(chat: _chat(isSecret: true));
      addTearDown(harness.dispose);
      harness.secret = true;

      await harness.controller.uploadAndSend(
        chatId: _chatId,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        filename: 'a.png',
        mediaSubtype: 'image',
        fileSize: 3,
      );

      expect(harness.secretBytes.single.length, 3);
      expect(harness.secretBytes.single.type, 'media');
      expect(harness.secretFiles, isEmpty);
    });

    test(
      'on web a path is ignored and the secret bytes path is used',
      () async {
        final harness = _Harness(chat: _chat(isSecret: true), isWeb: true);
        addTearDown(harness.dispose);
        harness.secret = true;

        await harness.controller.uploadAndSend(
          chatId: _chatId,
          filePath: r'C:\tmp\a.png',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          filename: 'a.png',
          mediaSubtype: 'image',
          fileSize: 3,
        );

        expect(harness.secretFiles, isEmpty);
        expect(harness.secretBytes.single.length, 3);
      },
    );

    test('the secret path returns before any optimistic message', () async {
      final harness = _Harness(chat: _chat(isSecret: true));
      addTearDown(harness.dispose);
      harness.secret = true;

      await harness.controller.uploadAndSend(
        chatId: _chatId,
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'a.png',
        mediaSubtype: 'image',
        fileSize: 1,
      );

      expect(harness.events, <String>['secretBytes']);
      expect(harness.optimistic, isEmpty);
      expect(harness.uploads, isEmpty);
    });

    test('voice and circle keep their type', () async {
      final harness = _Harness(chat: _chat(isSecret: true));
      addTearDown(harness.dispose);
      harness.secret = true;

      await harness.controller.uploadAndSend(
        chatId: _chatId,
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'v.m4a',
        mediaSubtype: 'voice',
        fileSize: 1,
      );
      await harness.controller.uploadAndSend(
        chatId: _chatId,
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'c.mp4',
        mediaSubtype: 'circle',
        fileSize: 1,
      );

      expect(harness.secretBytes[0].type, 'voice');
      expect(harness.secretBytes[1].type, 'circle');
    });

    test('empty bytes is a StateError and toasts', () async {
      final harness = _Harness(chat: _chat(isSecret: true));
      addTearDown(harness.dispose);
      harness.secret = true;

      await expectLater(
        harness.controller.uploadAndSend(
          chatId: _chatId,
          bytes: Uint8List(0),
          filename: 'a.png',
          mediaSubtype: 'image',
          fileSize: 0,
        ),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            'Empty attachment',
          ),
        ),
      );
      expect(harness.errors.single, l10n.secretAttachmentSaveFailed);
      expect(harness.optimistic, isEmpty);
    });

    test('a failing secret enqueue toasts and rethrows', () async {
      final harness = _Harness(chat: _chat(isSecret: true));
      addTearDown(harness.dispose);
      harness.secret = true;
      harness.secretError = StateError('engine closed');

      await expectLater(
        harness.controller.uploadAndSend(
          chatId: _chatId,
          bytes: Uint8List.fromList(<int>[1]),
          filename: 'a.png',
          mediaSubtype: 'image',
          fileSize: 1,
        ),
        throwsA(isA<StateError>()),
      );
      expect(harness.errors.single, l10n.secretAttachmentSaveFailed);
    });
  });

  group('ChatAttachmentController ordinary path', () {
    test('adds the optimistic row first, then enqueues the upload', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.text.text = 'hi';

      await harness.controller.uploadAndSend(
        chatId: _chatId,
        filePath: '/tmp/a.png',
        filename: 'a.png',
        mediaSubtype: 'image',
        fileSize: 4,
        text: 'hi',
      );

      expect(harness.events, <String>['optimistic', 'enqueue']);
      final ApiMessage message = harness.optimistic.single;
      expect(message.id, isNegative);
      expect(message.isSending, isTrue);
      expect(message.isFailed, isFalse);
      expect(message.msgType, 'media');
      expect(message.content, 'hi');
      expect(message.mediaUrl, '/tmp/a.png');
      expect(message.mediaName, 'a.png');
      expect(message.mediaSize, 4);
      expect(message.senderDisplayName, 'Me Myself');
    });

    test('the local id is negative and parsed as-is', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);

      await harness.controller.uploadAndSend(
        chatId: _chatId,
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'a.png',
        mediaSubtype: 'image',
        fileSize: 1,
      );

      final String localId = harness.uploads.single.localId;
      expect(localId.startsWith('-'), isTrue);
      expect(harness.optimistic.single.id, int.parse(localId));
    });

    test('bytes-only uploads get a local:// url and the reply', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.replyToMessageId = 11;

      await harness.controller.uploadAndSend(
        chatId: _chatId,
        bytes: Uint8List.fromList(<int>[1, 2]),
        filename: 'a.png',
        mediaSubtype: 'image',
        fileSize: 2,
      );

      final String localId = harness.uploads.single.localId;
      expect(harness.optimistic.single.mediaUrl, 'local://$localId');
      expect(harness.optimistic.single.replyToId, 11);
      expect(harness.uploads.single.replyToId, 11);
      expect(harness.clears, 1);
      expect(harness.scrolls, 1);
    });

    test('an empty byte list enqueues a null payload, not a crash', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);

      await harness.controller.uploadAndSend(
        chatId: _chatId,
        bytes: Uint8List(0),
        filename: 'a.png',
        mediaSubtype: 'image',
        fileSize: 0,
      );

      expect(harness.uploads.single.bytes, isNull);
      expect(harness.uploads.single.filePath, isEmpty);
    });

    test('a forward attaches no reply and clears nothing', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.replyToMessageId = 11;
      harness.text.text = 'typed now';

      await harness.controller.uploadAndSend(
        chatId: _chatId,
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'a.png',
        mediaSubtype: 'image',
        fileSize: 1,
        text: 'forwarded',
        attachCurrentReply: false,
      );

      expect(harness.optimistic.single.replyToId, isNull);
      expect(harness.uploads.single.replyToId, isNull);
      expect(harness.replyToMessageId, 11);
      expect(harness.clears, 0);
      expect(harness.scrolls, 0);
      expect(harness.text.text, 'typed now');
    });

    test('missing metadata times out into an error, no message', () async {
      final harness = _Harness(
        metadataTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(harness.dispose);
      harness.chats = Completer<void>().future;

      await expectLater(
        harness.controller.uploadAndSend(
          chatId: _chatId,
          bytes: Uint8List.fromList(<int>[1]),
          filename: 'a.png',
          mediaSubtype: 'image',
          fileSize: 1,
        ),
        throwsA(isA<StateError>()),
      );
      expect(harness.errors.single, l10n.errorFileUploadFailed);
      expect(harness.optimistic, isEmpty);
      expect(harness.uploads, isEmpty);
    });

    test('the composer is cleared only while its text still matches', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.text.text = 'caption';

      await harness.controller.uploadAndSend(
        chatId: _chatId,
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'a.png',
        mediaSubtype: 'image',
        fileSize: 1,
        text: 'other caption',
      );

      expect(harness.text.text, 'caption');
    });
  });

  group('ChatAttachmentController pasted images', () {
    test('two images go up as one document album', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.sendAlbum = true;
      final List<PastedImage> images = <PastedImage>[
        PastedImage(bytes: _png(1), name: 'a.png', mimeType: 'image/png'),
        PastedImage(bytes: _png(2), name: 'b.png', mimeType: 'image/png'),
      ];

      await harness.controller.previewPastedImages(
        images,
        initialCaption: 'album caption',
      );

      expect(harness.dialogs.single, (count: 2, caption: 'album caption'));
      final upload = harness.uploads.single;
      expect(upload.filename, 'NiosMess-Album.niosalbum.zip');
      expect(upload.mediaSubtype, 'document');
      expect(upload.text, 'album caption');
      expect(upload.bytes, isNotNull);
      expect(upload.bytes!.length, upload.fileSize);
      // The bytes are a real STORE zip the reader accepts.
      expect(MediaAlbum.decode(upload.bytes!), hasLength(2));
      expect(harness.optimistic.single.msgType, 'media');
      expect(harness.focuses, 1);
      expect(harness.text.text, isEmpty);
    });

    test('a single image keeps its own name and goes as an image', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.sendSingle = PastedImage(
        bytes: _png(3),
        name: 'one.png',
        mimeType: 'image/png',
      );

      await harness.controller.previewPastedImages(<PastedImage>[
        harness.sendSingle!,
      ]);

      expect(harness.uploads.single.filename, 'one.png');
      expect(harness.uploads.single.mediaSubtype, 'image');
    });

    test('an edit in progress opens no dialog', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.isEditing = true;

      await harness.controller.previewPastedImages(<PastedImage>[
        PastedImage(bytes: _png(4), name: 'a.png', mimeType: 'image/png'),
      ]);

      expect(harness.dialogs, isEmpty);
      expect(harness.uploads, isEmpty);
    });
  });

  group('ChatAttachmentController desktop paste', () {
    late Directory temp;
    late String filePath;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('nios_paste_');
      final File file = File('${temp.path}/note.png');
      file.writeAsBytesSync(<int>[1, 2, 3, 4]);
      filePath = file.path;
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('a second paste inside 400 ms is dropped', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.isDesktop = true;
      harness.clipboard = <String>[filePath];

      await harness.controller.handleDesktopPaste();
      harness.clock = harness.clock.add(const Duration(milliseconds: 100));
      await harness.controller.handleDesktopPaste();

      expect(harness.uploads, hasLength(1));
      expect(harness.uploads.single.mediaSubtype, 'image');
    });

    test('a later paste is accepted again', () async {
      final harness = _Harness(
        chat: _chat(),
        deduplicator: DesktopPasteDeduplicator(cooldown: Duration.zero),
      );
      addTearDown(harness.dispose);
      harness.isDesktop = true;
      harness.clipboard = <String>[filePath];

      await harness.controller.handleDesktopPaste();
      harness.clock = harness.clock.add(const Duration(milliseconds: 500));
      await harness.controller.handleDesktopPaste();

      expect(harness.uploads, hasLength(2));
    });

    test(
      'the same file list inside the deduplicator cooldown is dropped',
      () async {
        final harness = _Harness(chat: _chat());
        addTearDown(harness.dispose);

        await harness.controller.uploadDesktopFiles(<String>[filePath]);
        await harness.controller.uploadDesktopFiles(<String>[filePath]);

        expect(harness.uploads, hasLength(1));
      },
    );
  });

  group('ChatAttachmentController voice and circle', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('nios_rec_'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('a voice note goes up as voice with its own name', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      final File file = File('${temp.path}/note.m4a')
        ..writeAsBytesSync(<int>[1, 2, 3]);

      await harness.controller.sendVoiceMessage(file.path);

      final upload = harness.uploads.single;
      expect(upload.mediaSubtype, 'voice');
      expect(upload.filename, 'note.m4a');
      expect(upload.fileSize, 3);
      expect(harness.optimistic.single.msgType, 'voice');
    });

    test('a .temp circle capture is renamed to .mp4', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      final File file = File('${temp.path}/circle.temp')
        ..writeAsBytesSync(<int>[1, 2]);

      await harness.controller.sendCircleVideo(file.path);

      final upload = harness.uploads.single;
      expect(upload.mediaSubtype, 'circle');
      expect(upload.filename, 'circle.mp4');
      expect(harness.optimistic.single.msgType, 'circle');
    });

    test('an extensionless circle capture gets .mp4', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      final File file = File('${temp.path}/recording')
        ..writeAsBytesSync(<int>[1]);

      await harness.controller.sendCircleVideo(file.path);

      expect(harness.uploads.single.filename, 'recording.mp4');
    });
  });

  group('ChatAttachmentController stickers', () {
    test('a sticker carries the reply and clears it', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.replyToMessageId = 3;

      await harness.controller.sendSticker(
        ApiSticker(id: 77, url: 'https://cdn/77.webp'),
      );

      expect(harness.stickerSends.single, (
        chatId: _chatId,
        stickerId: 77,
        replyToId: 3,
      ));
      expect(harness.clears, 1);
      expect(harness.errors, isEmpty);
    });

    test('a failed sticker toasts and keeps the reply', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.replyToMessageId = 3;
      harness.stickerError = StateError('offline');

      await harness.controller.sendSticker(
        ApiSticker(id: 77, url: 'https://cdn/77.webp'),
      );

      expect(
        harness.errors.single,
        l10n.chatStickerSendFailed(harness.stickerError!),
      );
      expect(harness.replyToMessageId, 3);
    });
  });
}

Uint8List _png(int seed) => Uint8List.fromList(<int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  seed,
  seed,
  seed,
  seed,
]);
