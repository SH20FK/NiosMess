import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/live_location_platform.dart';
import 'package:pulse_flutter/services/live_location_service.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

final liveLocationProvider = Provider<LiveLocationService?>((ref) {
  final account = ref.watch(
    authProvider.select(
      (state) => (state.session?.userId, state.session?.accessToken),
    ),
  );
  final ordinary = ref.watch(ordinaryE2eeProvider);
  if (account.$1 == null || ordinary == null) return null;
  final knownRoots = <(int, int)>{};
  void check() {
    if (!ref.mounted) throw StateError('Сеанс закрыт');
    final current = ref.read(authProvider).session;
    if (current?.userId != account.$1 ||
        current?.accessToken != account.$2 ||
        ref.read(authProvider.notifier).isLoggingOut) {
      throw StateError('Сеанс закрыт');
    }
  }

  final service = LiveLocationService(
    accountId: account.$1,
    firstPosition: () async {
      check();
      if (!ref.read(webSocketClientProvider).isConnected) {
        throw StateError('Для начала передачи нужен интернет');
      }
      final position = await LiveLocationPlatform.first();
      check();
      return position;
    },
    positions: LiveLocationPlatform.updates,
    send: (chatId, content) async {
      check();
      final chat = ref.read(chatByIdProvider(chatId));
      if (chat == null ||
          chat.chatType != 'direct' ||
          chat.isSecret ||
          chat.isBotChat ||
          chat.isSaved) {
        throw StateError('Геопозиция доступна в личном чате с человеком');
      }
      final sent = await ref
          .read(chatMessagesProvider(chatId).notifier)
          .sendAcknowledged(content, requireE2ee: true);
      check();
      if (!sent.isE2ee ||
          sent.id <= 0 ||
          sent.senderId != account.$1 ||
          sent.chatId != chatId) {
        throw StateError('Не удалось подтвердить зашифрованную отправку');
      }
      knownRoots.add((chatId, sent.id));
      return sent.id;
    },
    edit: (chatId, id, content) async {
      // Stop updates are allowed during logout, before keys and sockets close.
      if (!ref.mounted ||
          ref.read(authProvider).session?.userId != account.$1 ||
          ref.read(authProvider).session?.accessToken != account.$2 ||
          !knownRoots.contains((chatId, id))) {
        throw StateError('Сеанс передачи закрыт');
      }
      final cipher = await ordinary.encrypt(chatId, content, edit: id);
      final ack = await ref
          .read(chatRepositoryProvider)
          .editMessage(chatId, id, content: content, e2eeContent: cipher);
      if (ack == null || ack.id != id || ack.chatId != chatId || !ack.isE2ee) {
        throw StateError('Не удалось подтвердить обновление геопозиции');
      }
    },
  );
  ref.onDispose(() => unawaited(service.close().catchError((Object _) {})));
  return service;
});

final liveLocationChangesProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(liveLocationProvider);
  yield 0;
  if (service == null) return;
  var sequence = 0;
  await for (final _ in service.changes) {
    yield ++sequence;
  }
});
