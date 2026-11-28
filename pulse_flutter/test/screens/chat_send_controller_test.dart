// Tests for `lib/screens/chat_detail/chat_send_controller.dart`.
//
// A.9 moved both text-send paths out of `_ChatDetailScreenState`. These tests
// freeze the seven invariants the split had to keep:
//   1. Empty input is never sent.
//   2. Chat metadata that never arrives times out into an error, not a send.
//   3. The spam-block gate and the partner-block gate stop the send.
//   4. The secret chat and the ordinary chat use their own write path, and one
//      shared `_savingSecretMessage` flag keeps a second entry from sending
//      twice.
//   5. `onLocalSaved` fires once, only from the local save, and clears the
//      composer.
//   6. A late failure never replaces text typed in the meantime, but restores
//      the original text and reply when nothing changed.
//   7. A partner-restriction failure marks the chat blocked by the user.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/l10n/app_localizations_ru.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_send_controller.dart';

const int _myUserId = 7;
const int _chatId = 42;
const int _partnerId = 9;

ApiChatSummary _chat({
  String chatType = 'direct',
  bool isSecret = false,
  bool isPrivate = false,
  bool isBlockedByMe = false,
}) => ApiChatSummary(
  id: _chatId,
  chatType: chatType,
  name: 'Fixture',
  unreadCount: 0,
  membersCount: 2,
  partnerUserId: chatType == 'direct' ? _partnerId : null,
  isSecret: isSecret,
  isPrivate: isPrivate,
  isBlockedByMe: isBlockedByMe,
);

/// Stands in for the screen: owns the composer field and records every port.
class _Harness {
  _Harness({
    this.chat,
    this.metadataTimeout = const Duration(seconds: 8),
  }) {
    controller = ChatSendController(
      chatId: () => _chatId,
      textController: text,
      l10n: () => _l10n,
      chat: (int id) => chat,
      ensureChats: () => chats,
      messages: () => messages,
      myUserId: () => _myUserId,
      isAccountSpamBlocked: () => spamBlocked,
      isSecret: () => secret,
      isUserBlocked: blockedUsers.contains,
      haptics: () => false,
      replyToMessageId: () => replyToMessageId,
      replyPreviewText: () => replyPreviewText,
      sendSecret: (int chatId, String text, {int? replyToId}) {
        secretCalls.add((text, replyToId));
        final Completer<void> completer = Completer<void>();
        pendingSecret = completer;
        if (!holdSecret) {
          if (secretError != null) {
            completer.completeError(secretError!);
          } else {
            completer.complete();
          }
        }
        return completer.future;
      },
      send:
          (
            int chatId,
            String text, {
            int? replyToId,
            void Function()? onLocalSaved,
          }) {
            sendCalls.add((text, replyToId));
            localSave = onLocalSaved;
            final Completer<void> completer = Completer<void>();
            pendingSend = completer;
            if (!hold) {
              onLocalSaved?.call();
              if (sendError != null) {
                completer.completeError(sendError!);
              } else {
                completer.complete();
              }
            }
            return completer.future;
          },
      clearReply: () {
        clears++;
        replyToMessageId = null;
        replyPreviewText = null;
      },
      restoreReply: (int replyId, String preview) {
        restores++;
        replyToMessageId = replyId;
        replyPreviewText = preview;
      },
      scrollToBottom: () => scrolls++,
      markBlockedByUser: blockedChats.add,
      onError: errors.add,
      metadataTimeout: metadataTimeout,
    );
  }

  final AppLocalizations _l10n = AppLocalizationsRu();
  final TextEditingController text = TextEditingController();
  final List<Object> errors = <Object>[];
  final List<(String, int?)> sendCalls = <(String, int?)>[];
  final List<(String, int?)> secretCalls = <(String, int?)>[];
  final List<int> blockedChats = <int>[];
  final Set<int> blockedUsers = <int>{};
  final List<ApiMessage> messages = <ApiMessage>[];
  final Duration metadataTimeout;

  ApiChatSummary? chat;
  Future<void> chats = Future<void>.value();
  bool spamBlocked = false;
  bool secret = false;
  int? replyToMessageId;
  String? replyPreviewText;
  int clears = 0;
  int restores = 0;
  int scrolls = 0;

  bool hold = false;
  bool holdSecret = false;
  Object? sendError;
  Object? secretError;
  Completer<void>? pendingSend;
  Completer<void>? pendingSecret;
  void Function()? localSave;

  late final ChatSendController controller;

  /// Completes the pending ordinary send, optionally after a local save.
  void finishSend({bool localSaved = false, Object? error}) {
    if (localSaved) localSave?.call();
    final Completer<void> completer = pendingSend!;
    pendingSend = null;
    if (error != null) {
      completer.completeError(error);
    } else {
      completer.complete();
    }
  }

  void finishSecret({Object? error}) {
    final Completer<void> completer = pendingSecret!;
    pendingSecret = null;
    if (error != null) {
      completer.completeError(error);
    } else {
      completer.complete();
    }
  }

  void dispose() {
    controller.dispose();
    text.dispose();
  }
}

/// Lets `catchError` / `whenComplete` microtasks run.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  final AppLocalizations l10n = AppLocalizationsRu();

  group('ChatSendController gates', () {
    test('empty and whitespace-only input never sends', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      await harness.controller.send();
      harness.text.text = '   \n ';
      await harness.controller.send();
      expect(harness.sendCalls, isEmpty);
      expect(harness.secretCalls, isEmpty);
    });

    test('unavailable chat metadata times out into an error, no send', () async {
      final harness = _Harness(
        metadataTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(harness.dispose);
      harness.chats = Completer<void>().future;
      harness.text.text = 'hello';
      await harness.controller.send();
      expect(harness.sendCalls, isEmpty);
      expect(harness.secretCalls, isEmpty);
      expect(harness.errors.single, l10n.secretSaveFailed);
    });

    test('spam block stops the send with the restricted toast', () async {
      final harness = _Harness(chat: _chat(chatType: 'group'));
      addTearDown(harness.dispose);
      harness.spamBlocked = true;
      harness.text.text = 'hello';
      await harness.controller.send();
      expect(harness.sendCalls, isEmpty);
      expect(harness.errors.single, l10n.chatAccountRestricted);
    });

    test('a partner blocked by me stops the send', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.blockedUsers.add(_partnerId);
      harness.text.text = 'hello';
      await harness.controller.send();
      expect(harness.sendCalls, isEmpty);
      expect(harness.errors.single, l10n.chatUnblockToSend);
    });
  });

  group('ChatSendController paths', () {
    test('a secret chat uses the secret write path and clears the field', () async {
      final harness = _Harness(chat: _chat(isSecret: true));
      addTearDown(harness.dispose);
      harness.secret = true;
      harness.text.text = 'secret hello';
      await harness.controller.send();
      expect(harness.secretCalls.single, ('secret hello', null));
      expect(harness.sendCalls, isEmpty);
      expect(harness.text.text, isEmpty);
    });

    test('onLocalSaved clears the composer exactly once', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.hold = true;
      harness.text.text = 'hello';
      await harness.controller.send();
      expect(harness.sendCalls, hasLength(1));
      // Nothing is cleared before the local save.
      expect(harness.text.text, 'hello');
      harness.finishSend(localSaved: true);
      await _settle();
      expect(harness.text.text, isEmpty);
      expect(harness.scrolls, 1);
      // A second call from a leaky provider cannot clear the field again.
      harness.localSave?.call();
      expect(harness.text.text, isEmpty);
      expect(harness.controller.isSending, isFalse);
    });
  });

  group('ChatSendController late failures', () {
    test('a late failure never replaces text typed in the meantime', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.hold = true;
      harness.text.text = 'original';
      await harness.controller.send();
      harness.text.text = 'retyped by hand';
      harness.finishSend(error: StateError('network down'));
      await _settle();
      expect(harness.text.text, 'retyped by hand');
      // Preserved from the screen: a failure superseded by new typing is
      // silent — the text is the user's, not the send's to report.
      expect(harness.errors, isEmpty);
      expect(harness.restores, 0);
      expect(harness.controller.isSending, isFalse);
    });

    test('a late failure restores the text and the same reply', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.hold = true;
      harness.text.text = 'original';
      harness.replyToMessageId = 5;
      harness.replyPreviewText = 'Preview';
      await harness.controller.send();
      harness.finishSend(error: StateError('network down'));
      await _settle();
      expect(harness.text.text, 'original');
      expect(harness.replyToMessageId, 5);
      expect(harness.replyPreviewText, 'Preview');
      expect(harness.restores, 1);
    });

    test('the failure does not restore a reply the user changed', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.hold = true;
      harness.text.text = 'original';
      harness.replyToMessageId = 5;
      harness.replyPreviewText = 'Preview';
      await harness.controller.send();
      harness.replyToMessageId = 6;
      harness.replyPreviewText = 'Other';
      harness.finishSend(error: StateError('network down'));
      await _settle();
      expect(harness.replyToMessageId, 6);
      expect(harness.restores, 0);
    });
  });

  group('ChatSendController shared fence', () {
    test('a second ordinary entry while sending does not send twice', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.hold = true;
      harness.text.text = 'hello';
      await harness.controller.send();
      await harness.controller.send();
      expect(harness.sendCalls, hasLength(1));
      expect(harness.controller.isSending, isTrue);
      harness.finishSend(localSaved: true);
      await _settle();
      expect(harness.controller.isSending, isFalse);
    });

    test('a second secret entry while sending does not send twice', () async {
      final harness = _Harness(chat: _chat(isSecret: true));
      addTearDown(harness.dispose);
      harness.secret = true;
      harness.holdSecret = true;
      harness.text.text = 'hello';
      unawaited(harness.controller.send());
      await _settle();
      await harness.controller.send();
      expect(harness.secretCalls, hasLength(1));
      harness.finishSecret();
      await _settle();
      expect(harness.controller.isSending, isFalse);
    });
  });

  group('ChatSendController partner restriction', () {
    for (final substring in [
      'not accept direct messages',
      'unavailable between these users',
      'restricted by user',
    ]) {
      test('"$substring" marks the chat blocked by the user', () async {
        final harness = _Harness(chat: _chat());
        addTearDown(harness.dispose);
        harness.hold = true;
        harness.text.text = 'hello';
        await harness.controller.send();
        harness.finishSend(error: StateError('Server: $substring'));
        await _settle();
        expect(harness.blockedChats, [_chatId]);
        expect(harness.errors.single, l10n.chatMessagesRestrictedByUser);
        expect(harness.text.text, 'hello');
      });
    }

    test('an unrelated failure does not mark the chat blocked', () async {
      final harness = _Harness(chat: _chat());
      addTearDown(harness.dispose);
      harness.hold = true;
      harness.text.text = 'hello';
      await harness.controller.send();
      harness.finishSend(error: StateError('network down'));
      await _settle();
      expect(harness.blockedChats, isEmpty);
    });
  });
}
