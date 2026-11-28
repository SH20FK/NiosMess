// Tests for `lib/screens/chat_detail/chat_message_action_controller.dart`.
//
// A.8 took the message context menu and its twelve outcomes out of
// `_ChatDetailScreenState`. These tests freeze the invariants the split had to
// keep:
//   1. Exactly one action per `MessageActionType` — a case never falls through
//      into its neighbour.
//   2. `copy` copies `ChatMessagePresenter.displayText`, so a live location
//      copies its preview, never the raw `nios:location:` payload.
//   3. A media forward is fetch -> base64-decode -> upload with
//      `attachCurrentReply: false`: a forward never inherits the composer's
//      reply target.
//   4. `report` sends `messageIds: [id]` and `reportedUserId: senderId`.
//   5. Delete without "mine or admin/owner" never confirms and never reaches
//      the repository.
//   6. "Saved" and "remind" append the `?highlight=<id>` deep link, and only a
//      media message gets it appended to the saved text.
//   7. Comments push the channel post route.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/live_location.dart';
import 'package:pulse_flutter/providers/chat/chat_list_provider.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_action_controller.dart';
import 'package:pulse_flutter/widgets/message_context_menu_sheet.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('ru'));

const int _chatId = 42;
const int _messageId = 501;
const int _senderId = 9;
const int _targetChatId = 77;

ApiMessage _message({
  String content = 'hello',
  String msgType = 'text',
  String? mediaUrl,
  String? mediaType,
  String? mediaName,
  int? mediaSize,
  String? e2eeFileKey,
}) => ApiMessage(
  id: _messageId,
  chatId: _chatId,
  senderId: _senderId,
  senderUsername: 'sender',
  senderDisplayName: 'Sender',
  senderBadges: const [],
  content: content,
  msgType: msgType,
  replyToId: null,
  mediaUrl: mediaUrl,
  mediaType: mediaType,
  mediaName: mediaName,
  mediaSize: mediaSize,
  mediaDuration: null,
  commentsCount: 0,
  reactions: const <String, int>{},
  sentAt: DateTime.utc(2026, 11, 28, 10),
  editedAt: null,
  isDeleted: false,
  e2eeFileKey: e2eeFileKey,
);

ApiChatSummary _chat(int id) => ApiChatSummary(
  id: id,
  chatType: 'direct',
  name: 'Chat $id',
  unreadCount: 0,
  membersCount: 2,
);

typedef ReportCall = ({
  int chatId,
  int reportedUserId,
  List<int> messageIds,
  String reason,
});

typedef ScheduleCall = ({int chatId, String text, ApiMessage reminder});

typedef UploadCall = ({
  int chatId,
  Uint8List? bytes,
  String filename,
  String mediaSubtype,
  int fileSize,
  String text,
  bool attachCurrentReply,
});

/// Records every seam the controller reaches, in order.
class _Probe {
  final Map<String, int> calls = <String, int>{};
  final List<String> sequence = <String>[];

  int operator [](String name) => calls[name] ?? 0;

  void hit(String name) {
    calls[name] = (calls[name] ?? 0) + 1;
    sequence.add(name);
  }

  int get total => calls.values.fold(0, (int sum, int n) => sum + n);
}

/// Stands in for the screen: owns the ports and every write seam.
class _Harness {
  _Harness({List<ApiChatSummary> chats = const <ApiChatSummary>[]})
    : chats = chats {
    controller = ChatMessageActionController(
      ports: ChatDetailPorts(
        read: <T>(ProviderListenable<T> provider) {
          if (identical(provider, chatsProvider)) {
            return AsyncValue<List<ApiChatSummary>>.data(chats) as T;
          }
          // `chatByIdProvider(...)`: the screen shows a non-secret chat.
          return null as T;
        },
        l10n: () => _l10n,
        chatId: () => _chatId,
        onError: (Object error) {
          probe.hit('onError');
          errors.add(error);
        },
        onSuccess: (String message) {
          probe.hit('onSuccess');
          successes.add(message);
        },
        onInfo: (String message) {
          probe.hit('onInfo');
          infos.add(message);
        },
        push: (String location, {Object? extra}) {
          probe.hit('push');
          pushes.add(location);
        },
        scrollToBottom: () => probe.hit('scrollToBottom'),
        haptics: () {
          probe.hit('haptics');
          return hapticsEnabled;
        },
      ),
      confirmDelete: () async {
        probe.hit('confirmDelete');
        return confirm;
      },
      deleteMessage: (int messageId) async {
        probe.hit('deleteMessage');
        deletedIds.add(messageId);
      },
      toggleReaction: (int messageId, String emoji) async {
        probe.hit('toggleReaction');
        reactions.add((messageId, emoji));
      },
      pickReaction: (ApiMessage message) async {
        probe.hit('pickReaction');
        return pickedReaction;
      },
      pickReportReason: (ApiMessage message) async {
        probe.hit('pickReportReason');
        return reportReason;
      },
      sendText: (int chatId, String text) async {
        probe.hit('sendText');
        sentTexts.add((chatId, text));
      },
      saveToSaved: (ApiMessage message, String text) async {
        probe.hit('saveToSaved');
        saved.add((message.id, text));
      },
      report:
          ({
            required int chatId,
            required int reportedUserId,
            required List<int> messageIds,
            required ApiMessage selectedMessage,
            required String reason,
          }) async {
            probe.hit('report');
            reports.add((
              chatId: chatId,
              reportedUserId: reportedUserId,
              messageIds: messageIds,
              reason: reason,
            ));
          },
      showScheduledComposer:
          ({
            required int chatId,
            required String text,
            required ApiMessage reminder,
          }) async {
            probe.hit('showScheduledComposer');
            schedules.add((chatId: chatId, text: text, reminder: reminder));
          },
      uploadAndSend:
          ({
            required int chatId,
            Uint8List? bytes,
            String? filePath,
            required String filename,
            required String mediaSubtype,
            required int fileSize,
            required String text,
            required bool attachCurrentReply,
          }) async {
            probe.hit('uploadAndSend');
            uploads.add((
              chatId: chatId,
              bytes: bytes,
              filename: filename,
              mediaSubtype: mediaSubtype,
              fileSize: fileSize,
              text: text,
              attachCurrentReply: attachCurrentReply,
            ));
          },
      fetchMedia: ({required String filePath, Uint8List? e2eeFileKey}) async {
        probe.hit('fetchMedia');
        fetched.add((filePath: filePath, e2eeFileKey: e2eeFileKey));
        if (fetchError != null) throw fetchError!;
        return mediaBytes;
      },
      setReply: (ApiMessage message) => probe.hit('setReply'),
      beginEdit: (ApiMessage message) async => probe.hit('beginEdit'),
      requestFile: (ApiMessage message) async => probe.hit('requestFile'),
      requestForward: (ApiMessage message) async => probe.hit('requestForward'),
    );
  }

  final List<ApiChatSummary> chats;
  late final ChatMessageActionController controller;

  final _Probe probe = _Probe();
  bool confirm = true;
  bool hapticsEnabled = true;
  String? pickedReaction = '❤️';
  String? reportReason = 'spam';
  Object? fetchError;
  Uint8List mediaBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

  final List<Object> errors = <Object>[];
  final List<String> successes = <String>[];
  final List<String> infos = <String>[];
  final List<String> pushes = <String>[];
  final List<int> deletedIds = <int>[];
  final List<(int, String)> reactions = <(int, String)>[];
  final List<(int, String)> sentTexts = <(int, String)>[];
  final List<(int, String)> saved = <(int, String)>[];
  final List<ReportCall> reports = <ReportCall>[];
  final List<ScheduleCall> schedules = <ScheduleCall>[];
  final List<UploadCall> uploads = <UploadCall>[];
  final List<({String filePath, Uint8List? e2eeFileKey})> fetched =
      <({String filePath, Uint8List? e2eeFileKey})>[];
}

MessageActionResult _action(MessageActionType type, {String? emoji}) =>
    MessageActionResult(type, emoji: emoji);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> clipboardWrites = <String>[];
  setUp(() {
    clipboardWrites.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            final Map<Object?, Object?> args =
                call.arguments as Map<Object?, Object?>;
            clipboardWrites.add(args['text']! as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('handleAction dispatch', () {
    // The expected seams per action. If any case falls through, the next
    // case's seam fires too and the map comparison fails.
    const Map<MessageActionType, Map<String, int>> expected =
        <MessageActionType, Map<String, int>>{
          MessageActionType.react: <String, int>{'toggleReaction': 1},
          MessageActionType.showAllReactions: <String, int>{
            'pickReaction': 1,
            'haptics': 1,
            'toggleReaction': 1,
          },
          MessageActionType.reply: <String, int>{'setReply': 1},
          MessageActionType.requestFile: <String, int>{
            'requestFile': 1,
            'onSuccess': 1,
          },
          MessageActionType.copy: <String, int>{'onInfo': 1},
          MessageActionType.saveToSaved: <String, int>{
            'saveToSaved': 1,
            'onSuccess': 1,
          },
          MessageActionType.remind: <String, int>{'showScheduledComposer': 1},
          MessageActionType.forward: <String, int>{'requestForward': 1},
          MessageActionType.comments: <String, int>{'push': 1},
          MessageActionType.edit: <String, int>{'beginEdit': 1},
          MessageActionType.delete: <String, int>{
            'confirmDelete': 1,
            'deleteMessage': 1,
          },
          MessageActionType.report: <String, int>{
            'pickReportReason': 1,
            'report': 1,
            'onSuccess': 1,
          },
        };

    test('the enum still has twelve actions', () {
      expect(MessageActionType.values.length, 12);
      expect(expected.length, 12);
    });

    for (final MapEntry<MessageActionType, Map<String, int>> entry
        in expected.entries) {
      test('${entry.key.name} runs exactly its own action', () async {
        final _Harness harness = _Harness();
        await harness.controller.handleAction(
          _message(),
          _action(entry.key, emoji: '🔥'),
          isMine: true,
          amAdminOrOwner: false,
        );

        expect(harness.probe.calls, entry.value);
      });
    }

    test('react without an emoji does nothing', () async {
      final _Harness harness = _Harness();
      await harness.controller.handleAction(
        _message(),
        _action(MessageActionType.react),
        isMine: true,
        amAdminOrOwner: false,
      );
      expect(harness.probe.total, 0);
    });
  });

  test('copy uses the presenter text, not the raw content', () async {
    final String encoded = LiveLocation(
      id: '11111111-2222-3333-4444-555555555555',
      latitude: 55.75,
      longitude: 37.61,
      accuracy: 5,
      createdAt: DateTime.utc(2026, 11, 28, 10),
      updatedAt: DateTime.utc(2026, 11, 28, 10),
      expiresAt: DateTime.utc(2026, 11, 28, 11),
      active: true,
    ).encode();
    final _Harness harness = _Harness();

    await harness.controller.handleAction(
      _message(content: encoded),
      _action(MessageActionType.copy),
      isMine: true,
      amAdminOrOwner: false,
    );

    expect(clipboardWrites, <String>['Геопозиция']);
    expect(clipboardWrites.single, isNot(encoded));
    expect(harness.infos.single, _l10n.chatMessageTextCopied);
  });

  group('media forward', () {
    test(
      'fetches, decodes the key, uploads without the reply target',
      () async {
        final String key = base64Encode(<int>[10, 20, 30]);
        final _Harness harness = _Harness();
        final ApiMessage message = _message(
          content: 'look',
          msgType: 'media',
          mediaUrl: 'nios-media://file-1',
          mediaType: 'image',
          mediaName: 'photo.jpg',
          mediaSize: 2048,
          e2eeFileKey: key,
        );

        await harness.controller.forwardTo(message, _chat(_targetChatId));

        expect(harness.probe.sequence.take(2), <String>[
          'fetchMedia',
          'uploadAndSend',
        ]);
        expect(harness.fetched.single.filePath, 'nios-media://file-1');
        expect(harness.fetched.single.e2eeFileKey, <int>[10, 20, 30]);

        final UploadCall upload = harness.uploads.single;
        expect(upload.chatId, _targetChatId);
        expect(upload.attachCurrentReply, isFalse);
        expect(upload.bytes, harness.mediaBytes);
        expect(upload.filename, 'photo.jpg');
        expect(upload.mediaSubtype, 'image');
        expect(upload.fileSize, 2048);
        expect(upload.text, 'look');
        expect(harness.successes.single, _l10n.chatMessageForwarded);
        expect(harness.errors, isEmpty);
      },
    );

    test('a text message is re-sent as-is, with no media work', () async {
      final _Harness harness = _Harness();

      await harness.controller.forwardTo(
        _message(content: 'hello'),
        _chat(_targetChatId),
      );

      expect(harness.probe.calls, <String, int>{'sendText': 1, 'onSuccess': 1});
      expect(harness.sentTexts.single, (_targetChatId, 'hello'));
    });

    test('a fetch failure is reported, and nothing is uploaded', () async {
      final _Harness harness = _Harness()
        ..fetchError = StateError('decrypt failed');

      await harness.controller.forwardTo(
        _message(msgType: 'media', mediaUrl: 'nios-media://broken'),
        _chat(_targetChatId),
      );

      expect(harness.probe['fetchMedia'], 1);
      expect(harness.probe['uploadAndSend'], 0);
      expect(harness.probe['onError'], 1);
      expect(harness.errors, hasLength(1));
      expect(harness.successes, isEmpty);
    });
  });

  group('report', () {
    test('reports this one message against its sender', () async {
      final _Harness harness = _Harness();

      await harness.controller.submitReport(_message(), 'spam');

      final ReportCall call = harness.reports.single;
      expect(call.messageIds, <int>[_messageId]);
      expect(call.reportedUserId, _senderId);
      expect(call.chatId, _chatId);
      expect(call.reason, 'spam');
      expect(harness.successes.single, _l10n.reportSent);
    });

    test('a cancelled reason sheet never files the report', () async {
      final _Harness harness = _Harness()..reportReason = null;

      await harness.controller.handleAction(
        _message(),
        _action(MessageActionType.report),
        isMine: true,
        amAdminOrOwner: false,
      );

      expect(harness.reports, isEmpty);
      expect(harness.probe['pickReportReason'], 1);
      expect(harness.probe['report'], 0);
    });
  });

  group('delete permission', () {
    test('without rights the repository is never reached', () async {
      final _Harness harness = _Harness();

      await harness.controller.deleteMessage(
        _message(),
        isMine: false,
        amAdminOrOwner: false,
      );

      expect(harness.probe['confirmDelete'], 0);
      expect(harness.probe['deleteMessage'], 0);
      expect(harness.deletedIds, isEmpty);
    });

    test('an admin may delete a foreign message', () async {
      final _Harness harness = _Harness();

      await harness.controller.deleteMessage(
        _message(),
        isMine: false,
        amAdminOrOwner: true,
      );

      expect(harness.probe['confirmDelete'], 1);
      expect(harness.deletedIds, <int>[_messageId]);
    });

    test('a cancelled confirmation never deletes', () async {
      final _Harness harness = _Harness()..confirm = false;

      await harness.controller.deleteMessage(_message(), isMine: true);

      expect(harness.probe['deleteMessage'], 0);
      expect(harness.deletedIds, isEmpty);
    });
  });

  group('highlight links', () {
    const String link =
        '${ApiConstants.origin}/web/#/chat/$_chatId?highlight=$_messageId';

    test('a media message saved to "Saved" gets the deep link', () async {
      final _Harness harness = _Harness();

      await harness.controller.saveToSaved(
        _message(
          content: 'caption',
          msgType: 'media',
          mediaUrl: 'nios-media://x',
          mediaType: 'image',
          mediaName: 'a.jpg',
        ),
      );

      expect(harness.saved.single.$2, 'caption\n$link');
    });

    test('a text message saved to "Saved" is stored as-is', () async {
      final _Harness harness = _Harness();

      await harness.controller.saveToSaved(_message(content: 'hello'));

      expect(harness.saved.single.$2, 'hello');
    });

    test('remind hands the composer the text plus the deep link', () async {
      final _Harness harness = _Harness();

      await harness.controller.remind(_message(content: 'later'));

      final ScheduleCall call = harness.schedules.single;
      expect(call.chatId, _chatId);
      expect(call.text, 'later\n$link');
      expect(call.reminder.id, _messageId);
    });
  });

  test('comments open the channel post route', () async {
    final _Harness harness = _Harness();

    await harness.controller.handleAction(
      _message(),
      _action(MessageActionType.comments),
      isMine: true,
      amAdminOrOwner: false,
    );

    expect(
      harness.pushes.single,
      '/channel/$_chatId/post/$_messageId/comments',
    );
  });

  test('a failed action reports through the error port', () async {
    final _Probe probe = _Probe();
    final ChatMessageActionController controller = ChatMessageActionController(
      ports: ChatDetailPorts(
        read: <T>(ProviderListenable<T> provider) => null as T,
        l10n: () => _l10n,
        chatId: () => _chatId,
        onError: (Object error) => probe.hit('onError'),
        onSuccess: (String message) => probe.hit('onSuccess'),
        onInfo: (String message) => probe.hit('onInfo'),
        push: (String location, {Object? extra}) => probe.hit('push'),
        scrollToBottom: () => probe.hit('scrollToBottom'),
        haptics: () => false,
      ),
      confirmDelete: () async => true,
      deleteMessage: (int messageId) async {
        probe.hit('deleteMessage');
        throw StateError('offline');
      },
      toggleReaction: (int messageId, String emoji) async =>
          probe.hit('toggleReaction'),
      pickReaction: (ApiMessage message) async => null,
      pickReportReason: (ApiMessage message) async => null,
      sendText: (int chatId, String text) async => probe.hit('sendText'),
      saveToSaved: (ApiMessage message, String text) async =>
          probe.hit('saveToSaved'),
      report:
          ({
            required int chatId,
            required int reportedUserId,
            required List<int> messageIds,
            required ApiMessage selectedMessage,
            required String reason,
          }) async => probe.hit('report'),
      showScheduledComposer:
          ({
            required int chatId,
            required String text,
            required ApiMessage reminder,
          }) async => probe.hit('showScheduledComposer'),
      uploadAndSend:
          ({
            required int chatId,
            Uint8List? bytes,
            String? filePath,
            required String filename,
            required String mediaSubtype,
            required int fileSize,
            required String text,
            required bool attachCurrentReply,
          }) async => probe.hit('uploadAndSend'),
      fetchMedia: ({required String filePath, Uint8List? e2eeFileKey}) async =>
          Uint8List(0),
      setReply: (ApiMessage message) {},
      beginEdit: (ApiMessage message) async {},
      requestFile: (ApiMessage message) async {},
      requestForward: (ApiMessage message) async {},
    );

    await controller.deleteMessage(_message(), isMine: true);

    expect(probe['deleteMessage'], 1);
    expect(probe['onError'], 1);
  });
}
