import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/storage/chat_media_cache.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/secret_chat/secret_chat_engine.dart';
import 'package:pulse_flutter/services/secret_chat/secret_journal.dart';

export 'package:pulse_flutter/services/secret_chat/secret_journal.dart'
    show SecretJson, secretMap;

class SecretChatCoordinator implements SecretTransport {
  SecretChatCoordinator._(this.userId, this.username, this.ws, this.repository);
  final int userId;
  final String username;
  final WebSocketClient ws;
  final ChatRepository repository;
  static const _secure = FlutterSecureStorage();
  static final Map<int, SecretChatCoordinator> _active = {};
  late SecretChatEngine engine;
  late Box<Uint8List> _attachments;
  Timer? _timer;
  StreamSubscription<void>? _connected;
  StreamSubscription<Map<String, dynamic>>? _push;
  bool _closed = false;
  bool _registered = false;
  Future<void>? _registering;
  int _ticks = 0;
  final Set<String> _savingAttachments = {};

  static String _prefix(int id) => 'niosmess.secret.$id.v2';

  static Future<SecretChatCoordinator> open(
    int userId,
    String username,
    WebSocketClient ws,
    ChatRepository repository,
  ) async {
    final coordinator = SecretChatCoordinator._(
      userId,
      username,
      ws,
      repository,
    );
    final prefix = _prefix(userId);
    final rawKey = await _secure.read(key: '$prefix.key');
    final bytes = rawKey == null
        ? await AesGcm.with256bits().newSecretKey().then(
            (k) => k.extractBytes(),
          )
        : base64Decode(rawKey);
    if (rawKey == null) {
      await _secure.write(key: '$prefix.key', value: base64Encode(bytes));
    }
    final box = await Hive.openBox<String>('secret_journal_v2_$userId');
    coordinator._attachments = await Hive.openBox<Uint8List>(
      'secret_attachments_v2_$userId',
    );
    final journal = SecretJournal(
      HiveSecretJournalBackend(box),
      SecretKey(bytes),
      accountId: userId,
    );
    await journal.restore();

    // Only the first proven account may adopt the installation's legacy keys.
    final legacyOwner = await _secure.read(key: 'e2ee.legacy_owner');
    final canMigrate = legacyOwner == null || legacyOwner == '$userId';
    if (legacyOwner == null) {
      await _secure.write(key: 'e2ee.legacy_owner', value: '$userId');
    }
    Future<List<int>> identity(
      String name,
      String legacy,
      KeyExchangeAlgorithm? dh,
    ) async {
      var raw = await _secure.read(key: '$prefix.$name');
      if (raw == null && canMigrate) raw = await _secure.read(key: legacy);
      List<int> seed;
      if (raw != null && base64Decode(raw).length == 32) {
        seed = base64Decode(raw);
      } else {
        final pair = dh == null
            ? await Ed25519().newKeyPair()
            : await dh.newKeyPair();
        seed = (await pair.extract() as SimpleKeyPairData).bytes;
      }
      await _secure.write(key: '$prefix.$name', value: base64Encode(seed));
      return seed;
    }

    coordinator.engine = SecretChatEngine(
      userId: userId,
      username: username,
      journal: journal,
      transport: coordinator,
      staticSeed: await identity('dh', 'e2ee.private_key', X25519()),
      identitySeed: await identity('ed', 'e2ee.ed25519_private', null),
    );
    await coordinator.engine.initialize();
    _active[userId] = coordinator;
    WsMediaFetcher.secretLocalLoader = coordinator.readAttachment;
    await WsMediaFetcher.clearPrivateCache();
    coordinator._connected = ws.onConnected.listen((_) {
      coordinator._registered = false;
      unawaited(coordinator.tick());
    });
    coordinator._push = ws.pushStream.listen((event) {
      if (event['action'] == 'secret_changed') coordinator.engine.wake();
    });
    coordinator._timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(coordinator.tick()),
    );
    unawaited(coordinator.tick());
    return coordinator;
  }

  Future<void> register() async {
    if (_closed || _registered) return;
    if (_registering != null) return _registering;
    final future =
        request('set_public_key', {
          'public_key': engine.publicKey,
          'secret_protocol_version': 2,
        }).then<void>((_) {
          _registered = true;
        });
    _registering = future;
    try {
      await future;
    } finally {
      _registering = null;
    }
  }

  Future<void> tick() async {
    if (_closed) return;
    try {
      await register();
      engine.wake();
      if (++_ticks % 12 == 0) await _collectAttachments();
    } catch (_) {
      /* durable offline queue */
    }
  }

  Future<void> _collectAttachments() async {
    if (_closed) return;
    final retained = <String>{..._savingAttachments};
    for (final chat in engine.journal.conversations) {
      for (final row in engine.journal.messages(chat)) {
        for (final body in [
          row['body'],
          ...((row['operations'] as List? ?? []).map(
            (op) => secretMap(op)['body'],
          )),
        ]) {
          final id = secretMap(secretMap(body)['file'])['attachment_id'];
          if (id is String) retained.add(id);
        }
      }
    }
    final unused = _attachments.keys
        .where((key) => !retained.contains('$key'))
        .toList();
    if (unused.isEmpty || _closed) return;
    await _attachments.deleteAll(unused);
    await _attachments.flush();
    await _attachments.compact();
    await WsMediaFetcher.clearPrivateCache();
  }

  @override
  Future<SecretJson> request(String action, SecretJson payload) async {
    if (_closed) throw StateError('Secret account is closed');
    try {
      final result = await ws.request(action, payload: payload);
      return secretMap(result);
    } on ApiException catch (error) {
      final code = error.message;
      throw SecretTransportException(
        code,
        permanent:
            code.contains('SECRET_RECIPIENT_RESTRICTED') ||
            code.contains('SECRET_DEVICE_MISMATCH') ||
            code.contains('SECRET_MESSAGE_UNAVAILABLE') ||
            code.contains('SECRET_ID_REUSED') ||
            code.contains('SECRET_INVALID_REPLY'),
      );
    }
  }

  Future<void> importChats(List<ApiChatSummary> chats) async {
    for (final chat in chats.where(
      (c) =>
          c.id > 0 && c.isSecret && !c.keyMismatch && c.partnerUserId != null,
    )) {
      final existing = engine.findChat(chat.id);
      if (existing != null &&
          engine.journal.state(existing)['status'] == 'deleted') {
        continue;
      }
      final uiId = await engine.open(
        peerId: chat.partnerUserId!,
        peerName: chat.name,
        remoteId: chat.id,
        peerKey: chat.partnerPublicKey,
        peerProfile: {
          'display_name': chat.name,
          'username': chat.username,
          'avatar_url': chat.avatarUrl,
        },
      );
      if (engine.chat(uiId)['legacy_keys_imported'] != true) {
        final raw = await _secure.read(key: 'e2ee.session.${chat.id}');
        final pinsRaw = await _secure.read(key: 'e2ee.verified_peers');
        final pins = pinsRaw == null
            ? <String, dynamic>{}
            : secretMap(jsonDecode(pinsRaw));
        await engine.importLegacySession(
          uiId,
          raw == null ? null : secretMap(jsonDecode(raw)),
          pins['${chat.id}'] as String?,
        );
      }
      final draft = await const DraftStorage().get(chat.id);
      if (draft != null && draft.isNotEmpty) {
        if (engine.chat(uiId)['draft'] == null) {
          await engine.saveDraft(uiId, draft);
        }
        if (engine.chat(uiId)['draft'] == draft) {
          await const DraftStorage().remove(chat.id);
        }
      }
      if (engine.chat(uiId)['legacy_imported'] == true) continue;
      final cached = await EncryptedMessageCache.loadMessages(
        chat.id,
        userId: userId,
        strict: true,
      );
      final media = await ChatMediaCache.getCachedMedia(chat.id);
      final byId = <int, ApiMessage>{
        for (final m in [...cached, ...media]) m.id: m,
      };
      for (final entry in EncryptedMessageCache.senderPlaintextsForMigration(
        chat.id,
        userId,
      ).entries) {
        if (byId.containsKey(entry.key)) continue;
        byId[entry.key] = ApiMessage.fromJson({
          'id': entry.key,
          'chat_id': chat.id,
          'sender_id': userId,
          'sender_username': username,
          'content': entry.value,
          'msg_type': 'text',
          'sent_at': DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          ).toIso8601String(),
          'is_e2ee': true,
          'is_decrypted': true,
        });
      }
      final migrated = byId.values
          .map((message) {
            if (message.senderId == userId && message.content.isEmpty) {
              final own = EncryptedMessageCache.getSenderPlaintext(
                chatId: chat.id,
                messageId: message.id,
                userId: userId,
              );
              if (own != null) {
                return message.copyWith(content: own, isDecrypted: true);
              }
            }
            return message;
          })
          .where((m) => !m.content.startsWith('{"dh"'))
          .map((m) => m.toJson())
          .toList();
      await engine.importHistory(uiId, migrated);
      // Remove legacy plaintext media only after the authenticated journal flush.
      final saved = engine.journal
          .messages(engine.findChat(uiId)!)
          .map((row) => secretMap(row['message']));
      if (!migrated.every(
        (source) => saved.any(
          (row) =>
              row['id'] == source['id'] &&
              row['content'] == (source['content'] ?? ''),
        ),
      )) {
        continue;
      }
      await ChatMediaCache.clearChatMedia(chat.id);
      await EncryptedMessageCache.clearMigratedSecretChat(
        chat.id,
        userId: userId,
      );
    }
    engine.wake();
  }

  List<ApiChatSummary> mergeChats(List<ApiChatSummary> remote) {
    final result = remote.where((c) => !c.isSecret).toList();
    for (final key in engine.journal.conversations) {
      final data = engine.journal.state(key);
      if (data['status'] == 'deleted') continue;
      final uiId = data['ui_id'] as int;
      final server = remote.where((c) => c.id == data['remote_id']).firstOrNull;
      final messages = engine.messages(uiId);
      final profile = secretMap(data['peer_profile']);
      result.add(
        (server ??
                ApiChatSummary(
                  id: uiId,
                  chatType: 'direct',
                  name:
                      profile['display_name'] as String? ??
                      data['peer_name'] as String? ??
                      '',
                  username: profile['username'] as String?,
                  avatarUrl: profile['avatar_url'] as String?,
                  unreadCount: 0,
                  membersCount: 2,
                  isSecret: true,
                  partnerUserId: data['peer_id'] as int?,
                  partnerPublicKey: data['peer_key'] as String?,
                ))
            .copyWith(
              id: uiId,
              lastMessage: messages.isEmpty
                  ? null
                  : ApiMessage.fromJson(messages.last),
            ),
      );
    }
    // Chats belonging to a different device remain visibly unavailable and are
    // never silently rebound or used to initialize new ratchets.
    result.addAll(remote.where((c) => c.isSecret && c.keyMismatch));
    result.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return result;
  }

  Future<void> deleteConversation(int uiId) async {
    await engine.deleteConversation(uiId);
    await _collectAttachments();
  }

  Future<void> enqueueAttachment(
    int chatId,
    Uint8List bytes, {
    required String filename,
    required String type,
    String text = '',
    int? replyToId,
  }) async {
    final id = const Uuid().v4();
    _savingAttachments.add(id);
    try {
      final fileKey = E2eeFileCrypto.generateFileKey();
      final encrypted = await E2eeFileCrypto.encrypt(bytes, fileKey);
      await _attachments.put(id, encrypted);
      await _attachments.flush();
      final extension = filename.split('.').last.toLowerCase();
      final mime = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'mp4' => 'video/mp4',
        'ogg' => 'audio/ogg',
        'm4a' => 'audio/mp4',
        'mp3' => 'audio/mpeg',
        _ => 'application/octet-stream',
      };
      await engine.enqueue(chatId, {
        'text': text,
        'type': type,
        'file': {
          'attachment_id': id,
          'key': base64Encode(fileKey),
          'name': filename,
          'size': bytes.length,
          'mime': mime,
          'subtype': type,
        },
      }, replyToId: replyToId);
    } finally {
      _savingAttachments.remove(id);
    }
  }

  Future<Uint8List> readAttachment(String id) async {
    if (_closed) throw StateError('Secret account is closed');
    final bytes = _attachments.get(id);
    if (bytes == null) throw StateError('Secret attachment unavailable');
    return bytes;
  }

  @override
  Future<String> upload(String attachmentId, SecretJson file) async {
    final bytes = await readAttachment(attachmentId);
    return repository.uploadSecretCiphertext(
      bytes: bytes,
      mediaSubtype: file['subtype'] as String? ?? 'media',
      localId: attachmentId,
    );
  }

  Future<void> close({bool erase = false}) async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    await _connected?.cancel();
    await _push?.cancel();
    WsMediaFetcher.secretLocalLoader = null;
    await engine.stop(erase: erase);
    if (erase) {
      await _attachments.clear();
      await _attachments.flush();
    }
    await _attachments.close();
    _active.remove(userId);
    if (erase) {
      final prefix = _prefix(userId);
      // Retain only device identity in secure storage; all conversation keys and
      // history keys are erased. A subsequent login starts fresh sessions.
      await _secure.delete(key: '$prefix.key');
    }
    await WsMediaFetcher.clearPrivateCache();
  }

  static Future<void> suspendAccount(int userId) async {
    await _active[userId]?.close();
    await WsMediaFetcher.clearPrivateCache();
  }

  static Future<void> eraseAccount(int userId) async {
    final active = _active[userId];
    if (active != null) {
      await active.close(erase: true);
      return;
    }
    await _secure.delete(key: '${_prefix(userId)}.key');
    for (final name in [
      'secret_journal_v2_$userId',
      'secret_attachments_v2_$userId',
    ]) {
      if (Hive.isBoxOpen(name)) await Hive.box(name).close();
      if (await Hive.boxExists(name)) await Hive.deleteBoxFromDisk(name);
    }
    await WsMediaFetcher.clearPrivateCache();
  }
}

final secretChatCoordinatorProvider = FutureProvider<SecretChatCoordinator?>((
  ref,
) async {
  final account = ref.watch(authProvider.select((s) => s.session?.userId));
  if (account == null) return null;
  final username = ref.read(authProvider).session?.username ?? '';
  final ws = ref.read(webSocketClientProvider);
  final repository = ref.read(chatRepositoryProvider);
  var disposed = false;
  SecretChatCoordinator? coordinator;
  ref.onDispose(() {
    disposed = true;
    unawaited(coordinator?.close());
  });
  coordinator = await SecretChatCoordinator.open(
    account,
    username,
    ws,
    repository,
  );
  if (disposed) {
    await coordinator.close();
    return null;
  }
  return coordinator;
});

final secretChatRevisionProvider = StreamProvider<int>((ref) async* {
  final coordinator = await ref.watch(secretChatCoordinatorProvider.future);
  yield 0;
  if (coordinator == null) return;
  var revision = 0;
  await for (final _ in coordinator.engine.changes) {
    yield ++revision;
  }
});

final secretChatEngineProvider = Provider<SecretChatEngine?>(
  (ref) => ref.watch(secretChatCoordinatorProvider).value?.engine,
);
