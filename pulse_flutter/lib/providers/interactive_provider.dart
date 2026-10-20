import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

/// A full, cursor-paged event history. Never silently compute a partial result
/// from the 300-message visible window. The server returns only ciphertext in DM.
final interactiveEventsProvider = FutureProvider.autoDispose
    .family<List<ApiMessage>, (int, int, int)>((ref, key) async {
      final (accountId, chatId, rootId) = key;
      final active = ref.watch(authProvider.select((a) => a.session?.userId));
      if (active != accountId) {
        throw StateError('Сеанс изменился');
      }
      if (rootId <= 0) return [];
      final socket = ref.read(webSocketClientProvider);
      final pushes = socket.pushStream.listen((event) {
        final payload = event['payload'];
        if (payload is! Map || payload['chat_id'] != chatId) return;
        if ((event['action'] == 'interactive_changed' &&
                payload['message_id'] == rootId) ||
            event['action'] == 'message_deleted' ||
            event['action'] == 'message_edited') {
          ref.invalidateSelf();
        }
      });
      final connections = socket.onConnected.listen(
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(() {
        unawaited(pushes.cancel());
        unawaited(connections.cancel());
      });
      final ordinary = ref.read(ordinaryE2eeProvider);
      final result = <ApiMessage>[];
      var cursor = 0;
      // Bound memory/network use; an oversized thread is explicitly unavailable,
      // rather than reporting incorrect counts or allowing unsafe changes.
      for (var page = 0; page < 100; page++) {
        final response = await socket.request(
          'message_replies',
          payload: {
            'chat_id': chatId,
            'message_id': rootId,
            'after_id': cursor,
          },
        );
        if (!ref.mounted) return [];
        if (response is! Map || response['messages'] is! List) {
          throw StateError('Не удалось загрузить ответы');
        }
        for (final raw in response['messages'] as List) {
          if (raw is! Map) throw const FormatException('Некорректный ответ');
          var message = ApiMessage.fromJson(Map<String, dynamic>.from(raw));
          if (message.chatId != chatId ||
              message.replyToId != rootId ||
              message.id <= cursor) {
            throw const FormatException('Некорректный порядок ответов');
          }
          if (message.isE2ee && ordinary != null) {
            message = await ordinary.decrypt(message);
          }
          if (message.isE2ee && !message.isDecrypted) {
            throw StateError('Не удалось расшифровать изменения');
          }
          result.add(message);
        }
        if (response['has_more'] != true) return result;
        final next = response['next_cursor'];
        if (next is! int || next <= cursor) {
          throw const FormatException('Некорректный курсор');
        }
        cursor = next;
      }
      throw StateError('Слишком много ответов для загрузки');
    }, retry: (_, _) => null);
