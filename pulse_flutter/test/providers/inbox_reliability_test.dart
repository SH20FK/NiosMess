import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 42,
      username: 'fixture',
      displayName: 'Fixture',
    ),
  );
}

class _FailingRepo extends ChatRepository {
  _FailingRepo(super.ref);
  @override
  Future<List<ApiChatSummary>> listChats({String? publicKey}) async =>
      throw const ApiException(statusCode: 0, message: 'offline');
  @override
  Future<int> markRead(int chatId) async =>
      throw const ApiException(statusCode: 0, message: 'offline');
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const [
    ApiChatSummary(
      id: 1,
      chatType: 'direct',
      name: 'Saved',
      unreadCount: 2,
      membersCount: 2,
    ),
  ];
}

class _Messages extends ChatMessagesNotifier {
  _Messages(super.chatId);
  @override
  Future<List<ApiMessage>> build() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'failed manual refresh preserves the visible inbox and surfaces failure',
    () async {
      final container = ProviderContainer(
        overrides: [
          chatsProvider.overrideWith(_Chats.new),
          secretChatCoordinatorProvider.overrideWith((ref) async => null),
          chatRepositoryProvider.overrideWith(_FailingRepo.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(chatsProvider.future);
      await expectLater(
        container.read(chatsProvider.notifier).refreshOrThrow(),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(chatsProvider).requireValue.single.name, 'Saved');
      expect(container.read(chatsProvider).requireValue.single.unreadCount, 2);
    },
  );
  test(
    'manual read receipt reports failure while automatic receipts stay best effort',
    () async {
      final container = ProviderContainer(
        overrides: [
          chatMessagesProvider(1).overrideWith(() => _Messages(1)),
          chatRepositoryProvider.overrideWith(_FailingRepo.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(chatMessagesProvider(1).future);
      final messages = container.read(chatMessagesProvider(1).notifier);
      await expectLater(
        messages.markRead(reportFailure: true),
        throwsA(isA<ApiException>()),
      );
      await messages.markRead();
    },
  );
  test(
    'draft save and removal update a live inbox projection after storage commit',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(_Auth.new)],
      );
      addTearDown(container.dispose);
      final updated = Completer<void>();
      final removed = Completer<void>();
      var observedSave = false;
      final sub = container.listen(liveDraftMapProvider, (_, next) {
        if (next.value?[1] == 'draft') {
          observedSave = true;
          if (!updated.isCompleted) updated.complete();
        } else if (observedSave &&
            next.hasValue &&
            !next.value!.containsKey(1)) {
          if (!removed.isCompleted) removed.complete();
        }
      });
      addTearDown(sub.close);
      await container.read(liveDraftMapProvider.future);
      final storage = container.read(draftStorageProvider);
      await storage.set(1, 'draft');
      await updated.future;
      expect(await storage.get(1), 'draft');
      await storage.remove(1);
      await removed.future;
      expect(await storage.get(1), isNull);
    },
  );
}
