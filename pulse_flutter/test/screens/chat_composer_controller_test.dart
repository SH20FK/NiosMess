// Tests for `lib/screens/chat_detail/chat_composer_controller.dart`.
//
// The controller took the composer's reply / edit state out of
// `_ChatDetailScreenState` and became the owner of its `ValueNotifier`.
// These tests freeze the invariants the split had to keep:
//   1. `ChatComposerState.copyWith` keeps its writer-function fields: a writer
//      returning `null` clears a field, omitting it leaves the field alone.
//   2. The account fence compares the whole record identity, not one half.
//   3. `commitEdit` keeps all four outcomes — unchanged text, success, success
//      after an account switch, and failure (restored only while the text and
//      the edited message are unchanged).
//   4. Editing an `InteractiveMessage` is refused.
//   5. `cancelEdit` clears the composer field — by design.
//   6. `setReply` truncates the preview at 80 characters.
//   7. `editLastMessage` takes the last own, non-empty `text` message and
//      skips deleted / failed / non-text ones.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_composer_controller.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_input_area.dart';

const int _myUserId = 7;

ApiMessage _msg({
  int id = 1,
  int senderId = _myUserId,
  String content = 'hello',
  String msgType = 'text',
  bool isDeleted = false,
  bool isFailed = false,
}) => ApiMessage(
  id: id,
  chatId: 9001,
  senderId: senderId,
  senderUsername: 'user$senderId',
  senderDisplayName: 'User $senderId',
  senderBadges: const [],
  content: content,
  msgType: msgType,
  replyToId: null,
  mediaUrl: null,
  mediaType: null,
  mediaName: null,
  mediaSize: null,
  mediaDuration: null,
  commentsCount: 0,
  reactions: const <String, int>{},
  sentAt: DateTime.utc(2026, 11, 28, 10),
  editedAt: null,
  isDeleted: isDeleted,
  isFailed: isFailed,
);

/// Stands in for the screen: owns the composer field, records the side effects.
class _Harness {
  _Harness({List<ApiMessage> messages = const <ApiMessage>[]})
    : messages = messages {
    controller = ChatComposerController(
      chatId: 9001,
      textController: text,
      editMessage: (int id, String text) async {
        if (onWrite != null) onWrite!(text);
        writes.add((id, text));
        if (writeFailure != null) throw writeFailure!;
      },
      identity: () => identity,
      haptics: () => false,
      onError: errors.add,
      info: infos.add,
      myUserId: () => _myUserId,
      messages: () => messages,
      replyAuthor: (ApiMessage message) => 'Author',
      replySnippet: (ApiMessage message) => message.content,
    );
  }

  final TextEditingController text = TextEditingController();
  final List<(int, String)> writes = <(int, String)>[];
  final List<Object> errors = <Object>[];
  final List<String> infos = <String>[];
  List<ApiMessage> messages;
  ChatComposerIdentity identity = (userId: 7, accessToken: 'token-a');
  Object? writeFailure;

  /// Runs inside the write, before it resolves or throws.
  void Function(String text)? onWrite;

  late final ChatComposerController controller;

  void dispose() => text.dispose();
}

void main() {
  group('ChatComposerState.copyWith', () {
    test('a writer returning null clears a field', () {
      const ChatComposerState state = ChatComposerState(
        replyToMessageId: 5,
        replyPreviewText: 'preview',
      );
      final ChatComposerState cleared = state.copyWith(
        replyToMessageId: () => null,
        replyPreviewText: () => null,
      );
      expect(cleared.replyToMessageId, isNull);
      expect(cleared.replyPreviewText, isNull);
    });

    test('omitting a field leaves it alone', () {
      const ChatComposerState state = ChatComposerState(
        replyToMessageId: 5,
        replyPreviewText: 'preview',
        editingMessageId: 9,
      );
      final ChatComposerState next = state.copyWith(isAiProcessing: true);
      expect(next.replyToMessageId, 5);
      expect(next.replyPreviewText, 'preview');
      expect(next.editingMessageId, 9);
      expect(next.isAiProcessing, isTrue);
    });
  });

  group('editMessage', () {
    test('refuses an InteractiveMessage', () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);

      await harness.controller.editMessage(
        _msg(
          content:
              'Pick one\n\u2063nios-interactive-v1:'
              '{"v":1,"document":"abcdefgh","kind":"list",'
              '"title":"Title","items":["one"]}',
        ),
      );

      expect(harness.infos, hasLength(1));
      expect(harness.controller.editingMessageId, isNull);
      expect(harness.text.text, isEmpty);
    });

    test('enters edit mode, drops the reply and fills the composer', () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      harness.controller.setReply(_msg(id: 3, content: 'quoted'));

      await harness.controller.editMessage(_msg(id: 4, content: 'old text'));

      expect(harness.controller.editingMessageId, 4);
      expect(harness.controller.editingOriginalText, 'old text');
      expect(harness.controller.replyToMessageId, isNull);
      expect(harness.text.text, 'old text');
    });
  });

  group('commitEdit', () {
    test('success: writes, leaves edit mode and clears the field', () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.controller.editMessage(_msg(id: 42, content: 'old'));
      harness.text.text = 'new';

      await harness.controller.commitEdit();

      expect(harness.writes, <(int, String)>[(42, 'new')]);
      expect(harness.controller.editingMessageId, isNull);
      expect(harness.controller.editingOriginalText, isNull);
      expect(harness.text.text, isEmpty);
      expect(harness.errors, isEmpty);
    });

    test('unchanged text: cancels without a write', () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.controller.editMessage(_msg(id: 42, content: 'old'));

      await harness.controller.commitEdit();

      expect(harness.writes, isEmpty);
      expect(harness.controller.editingMessageId, isNull);
      expect(harness.text.text, isEmpty);
    });

    test('success after an account switch: stays in edit mode', () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.controller.editMessage(_msg(id: 42, content: 'old'));
      harness.text.text = 'new';
      harness.onWrite = (_) =>
          harness.identity = (userId: 8, accessToken: 'token-b');

      await harness.controller.commitEdit();

      expect(harness.writes, <(int, String)>[(42, 'new')]);
      expect(harness.controller.editingMessageId, 42);
      expect(harness.text.text, 'new');
      expect(harness.errors, isEmpty);
    });

    test('failure with unchanged text: reports and keeps edit mode', () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.controller.editMessage(_msg(id: 42, content: 'old'));
      harness.text.text = 'new';
      harness.writeFailure = StateError('offline');

      await harness.controller.commitEdit();

      expect(harness.errors, hasLength(1));
      expect(harness.controller.editingMessageId, 42);
      expect(harness.controller.editingOriginalText, 'old');
      expect(harness.text.text, 'new');
    });

    test('failure after the text changed: reports without restoring', () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.controller.editMessage(_msg(id: 42, content: 'old'));
      harness.text.text = 'new';
      harness.writeFailure = StateError('offline');
      harness.onWrite = (_) => harness.text.text = 'typed meanwhile';

      await harness.controller.commitEdit();

      expect(harness.errors, hasLength(1));
      // The draft typed while the write was in flight survives.
      expect(harness.text.text, 'typed meanwhile');
      expect(harness.controller.editingMessageId, 42);
    });

    test('failure after the account switched: silent', () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.controller.editMessage(_msg(id: 42, content: 'old'));
      harness.text.text = 'new';
      harness.writeFailure = StateError('offline');
      harness.onWrite = (_) =>
          harness.identity = (userId: 8, accessToken: 'token-b');

      await harness.controller.commitEdit();

      expect(harness.errors, isEmpty);
      expect(harness.controller.editingMessageId, 42);
    });
  });

  group('cancelEdit', () {
    test('leaves edit mode and clears the composer field', () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.controller.editMessage(_msg(id: 42, content: 'old'));

      harness.controller.cancelEdit();

      expect(harness.controller.editingMessageId, isNull);
      expect(harness.controller.editingOriginalText, isNull);
      expect(harness.text.text, isEmpty);
    });
  });

  group('editLastMessage', () {
    test('takes the last own non-empty text, skipping the rest', () async {
      final _Harness harness = _Harness(
        messages: <ApiMessage>[
          _msg(id: 1, content: 'pick me'),
          _msg(id: 2, content: '   '),
          _msg(id: 3, content: 'media', msgType: 'media'),
          _msg(id: 4, content: 'deleted', isDeleted: true),
          _msg(id: 5, content: 'failed', isFailed: true),
          _msg(id: 6, senderId: 99, content: 'theirs'),
        ],
      );
      addTearDown(harness.dispose);

      harness.controller.editLastMessage();

      expect(harness.controller.editingMessageId, 1);
      expect(harness.text.text, 'pick me');
    });

    test('does nothing when no own text message exists', () async {
      final _Harness harness = _Harness(
        messages: <ApiMessage>[
          _msg(id: 1, senderId: 99, content: 'theirs'),
          _msg(id: 2, content: 'deleted', isDeleted: true),
        ],
      );
      addTearDown(harness.dispose);

      harness.controller.editLastMessage();

      expect(harness.controller.editingMessageId, isNull);
      expect(harness.text.text, isEmpty);
    });
  });

  group('reply', () {
    test('setReply truncates the preview at 80 characters', () {
      final _Harness harness = _Harness(
        messages: <ApiMessage>[_msg(id: 3, content: 'a' * 100)],
      );
      addTearDown(harness.dispose);

      harness.controller.setReply(harness.messages.single);

      final String preview = harness.controller.replyPreviewText!;
      expect(preview, 'Author: ${'a' * 80}...');
      expect(harness.controller.replyToMessageId, 3);
    });

    test('clearReply clears through the writer functions', () {
      final _Harness harness = _Harness(
        messages: <ApiMessage>[_msg(id: 3, content: 'short')],
      );
      addTearDown(harness.dispose);

      harness.controller.setReply(harness.messages.single);
      expect(harness.controller.replyToMessageId, 3);

      // A copyWith without the writers does not touch the reply at all.
      harness.controller.notifier.value = harness.controller.state.copyWith(
        isAiProcessing: true,
      );
      expect(harness.controller.replyToMessageId, 3);
      expect(harness.controller.replyPreviewText, 'Author: short');

      harness.controller.clearReply();

      expect(harness.controller.replyToMessageId, isNull);
      expect(harness.controller.replyPreviewText, isNull);
    });
  });
}
