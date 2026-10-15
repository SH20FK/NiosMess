import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/storage/chat_media_cache.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/secret_chat/secret_chat_engine.dart';
import 'package:pulse_flutter/services/secret_chat/secret_attachment_store.dart';
import 'package:pulse_flutter/services/secret_chat/secret_poll_schedule.dart';
import 'package:pulse_flutter/services/secret_chat/secret_journal.dart';

export 'package:pulse_flutter/services/secret_chat/secret_journal.dart'
    show SecretJson, secretMap;

class SecretChatCoordinator
    with WidgetsBindingObserver
    implements SecretTransport {
  SecretChatCoordinator._(this.userId, this.username, this.ws, this.repository);
  final int userId;
  final String username;
  final WebSocketClient ws;
  final ChatRepository repository;
  static const _secure = FlutterSecureStorage();
  static final Map<int, SecretChatCoordinator> _active = {};
  static final Map<int, int> _accountEpochs = {};
  static final Map<int, Future<void>> _accountOperations = {};
  static final Map<int, Set<int>> _retiredRemoteIds = {};
  static SecretChatCoordinator? _mediaLoaderOwner;
  late SecretChatEngine engine;
  late SecretAttachmentStore _attachments;
  final Set<Future<void>> _attachmentJobs = {};
  final Set<CancellationToken> _uploads = {};
  Future<void>? _closing;
  Timer? _timer;
  Timer? _expiryTimer;
  Future<void>? _expiring;
  StreamSubscription<void>? _connected;
  StreamSubscription<Map<String, dynamic>>? _push;
  StreamSubscription<String>? _engineChanges;
  bool _closed = false;
  bool _registered = false;
  int? _legacyOwnerUserId;
  Future<void>? _registering;
  final _pollSchedule = SecretPollSchedule();
  Future<void>? _ticking;
  bool _tickAgain = false;
  bool _background = false;
  bool _transportAllowed = true;
  bool get _canUseTransport =>
      !_closed && _transportAllowed && !ws.isBackgroundPaused;
  DateTime? _lastAttachmentCollection;
  final Set<String> _savingAttachments = {};

  @visibleForTesting
  bool get debugPollingScheduled => _timer?.isActive ?? false;

  static String _prefix(int id) => 'niosmess.secret.$id.v2';

  static Future<SecretChatCoordinator> open(
    int userId,
    String username,
    WebSocketClient ws,
    ChatRepository repository,
  ) {
    final epoch = _accountEpochs[userId] ?? 0;
    return _accountOperation(userId, () async {
      if (epoch != (_accountEpochs[userId] ?? 0)) {
        throw StateError('Secret account opening was revoked');
      }
      final active = _active[userId];
      if (active != null && !active._closed) return active;
      // A provider may be replaced while the previous instance is draining.
      // Never open its Hive boxes until that instance has released ownership.
      await active?._closing;
      return _open(userId, username, ws, repository, epoch);
    });
  }

  static Future<T> _accountOperation<T>(int userId, Future<T> Function() work) {
    final previous = _accountOperations[userId];
    final job = previous == null
        ? Future<T>.sync(work)
        : previous.then((_) => work());
    final settled = job.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _accountOperations[userId] = settled;
    unawaited(
      settled.whenComplete(() {
        if (identical(_accountOperations[userId], settled)) {
          _accountOperations.remove(userId);
        }
      }),
    );
    return job;
  }

  static Future<SecretChatCoordinator> _open(
    int userId,
    String username,
    WebSocketClient ws,
    ChatRepository repository,
    int epoch,
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
    coordinator._attachments = await SecretAttachmentStore.open(
      'secret_attachments_v2_$userId',
      directoryPath: await _attachmentDirectoryPath(userId),
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
    coordinator._legacyOwnerUserId = canMigrate ? userId : null;
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
    await WsMediaFetcher.clearPrivateCache();
    if (epoch != (_accountEpochs[userId] ?? 0)) {
      _retiredRemoteIds
          .putIfAbsent(userId, () => {})
          .addAll(coordinator._remoteChatIds);
      // A logout that started during secure-storage/disk initialization owns
      // the following serialized purge. Do not expose loaders or senders.
      await coordinator.close();
      throw StateError('Secret account opening was revoked');
    }
    _active[userId] = coordinator;
    _mediaLoaderOwner = coordinator;
    WsMediaFetcher.secretLocalLoader = coordinator.readAttachment;
    WsMediaFetcher.secretLocalFileLoader = kIsWeb
        ? null
        : coordinator.readAttachmentFile;
    coordinator._connected = ws.onConnected.listen((_) {
      coordinator._registered = false;
      coordinator._pollSchedule.reset();
      unawaited(coordinator.tick());
    });
    coordinator._push = ws.pushStream.listen((event) {
      if (event['action'] != 'secret_changed' || !coordinator._canUseTransport) {
        return;
      }
      final id = secretMap(event['payload'])['chat_id'] ?? event['chat_id'];
      if (id is int) {
        coordinator.engine.wakeChat(id);
      } else {
        coordinator.engine.wake();
      }
    });
    coordinator._engineChanges = coordinator.engine.changes.listen((_) {
      coordinator._scheduleExpiry();
      if (coordinator.engine.journal.hasPendingWork) {
        coordinator._pollSchedule.reset();
        coordinator._schedulePoll();
      } else if (coordinator._background) {
        coordinator._schedulePoll();
      }
    });
    coordinator._background =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.hidden ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.detached;
    WidgetsBinding.instance.addObserver(coordinator);
    coordinator._scheduleExpiry();
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

  /// A paused screen stops idle polling; pending sends, pushes and reconnects
  /// still belong to the account and do not depend on mounted chat histories.
  void setBackground(bool background) {
    if (_closed || _background == background) return;
    _background = background;
    if (!background) {
      _pollSchedule.reset();
      unawaited(tick());
    } else {
      _schedulePoll();
    }
  }

  void setTransportAllowed(bool allowed) {
    _transportAllowed = allowed;
    if (!_canUseTransport) {
      _timer?.cancel();
      return;
    }
    _pollSchedule.reset();
    unawaited(tick());
  }

  /// Opening a history or explicitly refreshing it is a single addressed wake,
  /// never a screen-owned polling loop or a reset of the account idle backoff.
  void refreshChat(int uiId) {
    if (_canUseTransport && ws.isConnected) engine.wakeChat(uiId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => setBackground(
    state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached,
  );

  Future<void> tick() {
    if (_closed) return Future<void>.value();
    if (_ticking != null) {
      _tickAgain = true;
      return _ticking!;
    }
    final future = Future<void>.microtask(_runTick);
    _ticking = future;
    return future;
  }

  Future<void> _runTick() async {
    _timer?.cancel();
    try {
      if (!_canUseTransport || !ws.isConnected) {
        return; // onConnected catches up immediately.
      }
      await register();
      await engine.pumpAll();
      final now = DateTime.now();
      if (_lastAttachmentCollection == null ||
          now.difference(_lastAttachmentCollection!) >=
              const Duration(minutes: 1)) {
        await _collectAttachments();
        _lastAttachmentCollection = now;
      }
    } catch (_) {
      // The authenticated journal keeps every queued row through offline time.
    } finally {
      _ticking = null;
      if (_tickAgain && !_closed) {
        _tickAgain = false;
        unawaited(tick());
      } else {
        _schedulePoll();
      }
    }
  }

  void _schedulePoll() {
    _timer?.cancel();
    if (_closed) return;
    final delay = _pollSchedule.next(
      connected: ws.isConnected && _canUseTransport,
      background: _background,
      pending: engine.journal.hasPendingWork,
      hasChats: engine.journal.conversations.isNotEmpty,
    );
    if (delay != null) _timer = Timer(delay, () => unawaited(tick()));
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    if (_closed || _expiring != null) return;
    final deadline = engine.journal.nextExpiry;
    if (deadline == null) return;
    final remaining = deadline.difference(DateTime.now());
    _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (_closed) return;
      _expiring = _expireLocalMessages();
    });
  }

  Future<void> _expireLocalMessages() async {
    var committed = false;
    try {
      await engine.expireDue();
      await _collectAttachments();
      committed = true;
    } catch (_) {
      // Keep data on a failed durable write; do not spin a zero-delay timer.
    } finally {
      _expiring = null;
      if (committed) _scheduleExpiry();
    }
  }

  Future<void> _collectAttachments() async {
    if (_closed) return;
    final retained = {..._savingAttachments, ...engine.journal.attachmentIds};
    if (await _attachments.retain(retained)) {
      await WsMediaFetcher.clearPrivateCache();
    }
  }

  @override
  Future<SecretJson> request(String action, SecretJson payload) async {
    if (_closed) throw StateError('Secret account is closed');
    if (!_canUseTransport) throw StateError('Secret transport is paused');
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
    final importedIds = <int>{};
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
      importedIds.add(uiId);
      if (engine.chat(uiId)['legacy_keys_imported'] != true) {
        final raw = _legacyOwnerUserId == userId
            ? await _secure.read(key: 'e2ee.session.${chat.id}')
            : null;
        final pinsRaw = _legacyOwnerUserId == userId
            ? await _secure.read(key: 'e2ee.verified_peers')
            : null;
        final pins = pinsRaw == null
            ? <String, dynamic>{}
            : secretMap(jsonDecode(pinsRaw));
        await engine.importLegacySession(
          uiId,
          raw == null ? null : secretMap(jsonDecode(raw)),
          pins['${chat.id}'] as String?,
        );
      }
      final draft = _legacyOwnerUserId == userId
          ? await const DraftStorage().get(chat.id)
          : null;
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
        legacyOwnerUserId: _legacyOwnerUserId,
      );
      final media = _legacyOwnerUserId == userId
          ? await ChatMediaCache.getCachedMedia(chat.id)
          : <ApiMessage>[];
      final byId = <int, ApiMessage>{
        for (final m in [...cached, ...media]) m.id: m,
      };
      final ownTexts = EncryptedMessageCache.senderPlaintextsForMigration(
        chat.id,
        userId,
        legacyOwnerUserId: _legacyOwnerUserId,
      );
      for (final entry in ownTexts.entries) {
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
              final own =
                  ownTexts[message.id] ??
                  EncryptedMessageCache.getSenderPlaintext(
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
      final saved = {
        for (final row in engine.journal.messageViews(engine.findChat(uiId)!))
          secretMap(row['message'])['id']: secretMap(row['message']),
      };
      if (!migrated.every(
        (source) =>
            saved[source['id']]?['content'] == (source['content'] ?? ''),
      )) {
        continue;
      }
      if (_legacyOwnerUserId == userId) {
        await ChatMediaCache.clearChatMedia(chat.id);
      }
      await EncryptedMessageCache.clearMigratedSecretChat(
        chat.id,
        userId: userId,
        legacyOwnerUserId: _legacyOwnerUserId,
      );
    }
    for (final uiId in importedIds) {
      refreshChat(uiId);
    }
  }

  List<ApiChatSummary> mergeChats(List<ApiChatSummary> remote) {
    final result = remote.where((c) => !c.isSecret).toList();
    for (final key in engine.journal.conversations) {
      final data = engine.journal.stateView(key);
      if (data['status'] == 'deleted') continue;
      final uiId = data['ui_id'] as int;
      final server = remote.where((c) => c.id == data['remote_id']).firstOrNull;
      final lastMessage = engine.lastVisibleMessage(uiId);
      final profile = secretMap(data['peer_profile']);
      final peerName =
          [
                profile['display_name'] as String?,
                data['peer_name'] as String?,
                profile['username'] as String?,
                server?.name,
              ]
              .map((name) => name?.trim() ?? '')
              .where((name) => name.isNotEmpty)
              .firstOrNull;
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
              // Server conversation labels must not replace the known peer.
              name: peerName,
              username: profile['username'] as String?,
              avatarUrl: profile['avatar_url'] as String?,
              lastMessage: lastMessage == null
                  ? null
                  : ApiMessage.fromJson(lastMessage),
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

  Future<void> _attachmentJob(Future<void> Function() operation) {
    if (_closed) return Future.error(StateError('Secret account is closed'));
    final releaseWork = BackgroundService.retainWork();
    final result = Future<void>.sync(operation);
    final settled = result
        .then<void>((_) {}, onError: (Object error, StackTrace stack) {})
        .whenComplete(releaseWork);
    _attachmentJobs.add(settled);
    unawaited(settled.whenComplete(() => _attachmentJobs.remove(settled)));
    return result;
  }

  Future<void> enqueueAttachment(
    int chatId,
    Uint8List bytes, {
    required String filename,
    required String type,
    String text = '',
    int? replyToId,
  }) => _attachmentJob(() async {
    if (bytes.isEmpty) throw StateError('Empty attachment');
    final id = const Uuid().v4();
    final fileKey = E2eeFileCrypto.generateFileKey();
    _savingAttachments.add(id);
    try {
      final encrypted = await E2eeFileCrypto.encrypt(bytes, fileKey);
      if (_closed) throw StateError('Secret account is closed');
      await _attachments.save(id, encrypted);
      await _enqueueSavedAttachment(
        chatId,
        id,
        fileKey,
        filename: filename,
        type: type,
        size: bytes.length,
        text: text,
        replyToId: replyToId,
      );
    } finally {
      fileKey.fillRange(0, fileKey.length, 0);
      _savingAttachments.remove(id);
    }
  });

  Future<void> enqueueAttachmentFile(
    int chatId,
    String plainPath, {
    required String filename,
    required String type,
    String text = '',
    int? replyToId,
  }) => _attachmentJob(() async {
    if (kIsWeb || !_attachments.supportsFiles) {
      throw UnsupportedError('Native file storage unavailable');
    }
    final size = await File(plainPath).length();
    if (size == 0) throw StateError('Empty attachment');
    final id = const Uuid().v4();
    final fileKey = E2eeFileCrypto.generateFileKey();
    _savingAttachments.add(id);
    try {
      await _attachments.saveFile(
        id,
        (outputPath) => E2eeFileCrypto.encryptFile(
          plainPath: plainPath,
          outputPath: outputPath,
          key: fileKey,
        ),
      );
      await _enqueueSavedAttachment(
        chatId,
        id,
        fileKey,
        filename: filename,
        type: type,
        size: size,
        text: text,
        replyToId: replyToId,
      );
    } finally {
      fileKey.fillRange(0, fileKey.length, 0);
      _savingAttachments.remove(id);
    }
  });

  Future<void> _enqueueSavedAttachment(
    int chatId,
    String id,
    Uint8List fileKey, {
    required String filename,
    required String type,
    required int size,
    required String text,
    int? replyToId,
  }) async {
    if (_closed) throw StateError('Secret account is closed');
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
        'size': size,
        'mime': mime,
        'subtype': type,
      },
    }, replyToId: replyToId);
  }

  Future<Uint8List> readAttachment(String id) async {
    if (_closed) throw StateError('Secret account is closed');
    return _attachments.read(id);
  }

  Future<String> readAttachmentFile(String id) async {
    if (_closed) throw StateError('Secret account is closed');
    return _attachments.readFile(id);
  }

  @override
  Future<String> upload(String attachmentId, SecretJson file) async {
    if (!_canUseTransport) throw StateError('Secret transport is paused');
    final releaseWork = BackgroundService.retainWork();
    final cancellation = CancellationToken();
    _uploads.add(cancellation);
    try {
      final path = _attachments.supportsFiles
          ? await readAttachmentFile(attachmentId)
          : null;
      final bytes = path == null ? await readAttachment(attachmentId) : null;
      if (!_canUseTransport) throw StateError('Secret transport is paused');
      return await repository.uploadSecretCiphertext(
        bytes: bytes,
        filePath: path,
        mediaSubtype: file['subtype'] as String? ?? 'media',
        localId: attachmentId,
        cancellationToken: cancellation,
      );
    } finally {
      _uploads.remove(cancellation);
      releaseWork();
    }
  }

  static Future<String?> _attachmentDirectoryPath(int accountId) async {
    if (kIsWeb) return null;
    final root = await getApplicationSupportDirectory();
    return '${root.path}/secret_attachments_v3_$accountId';
  }

  Future<void> close({bool erase = false}) {
    final closing = _closing;
    if (closing != null) {
      return erase ? closing.then((_) => _eraseClosedAccount(userId)) : closing;
    }
    _closed = true;
    for (final cancellation in _uploads) {
      cancellation.cancel();
    }
    return _closing = _finishClose(erase);
  }

  Future<void> _finishClose(bool erase) async {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _expiryTimer?.cancel();
    await _connected?.cancel();
    await _push?.cancel();
    await _engineChanges?.cancel();
    await _ticking;
    await _expiring;
    if (identical(_mediaLoaderOwner, this)) {
      _mediaLoaderOwner = null;
      WsMediaFetcher.secretLocalLoader = null;
      WsMediaFetcher.secretLocalFileLoader = null;
    }
    await Future.wait(_attachmentJobs.toList());
    await engine.stop(erase: erase);
    await _attachments.close(erase: erase);
    if (identical(_active[userId], this)) _active.remove(userId);
    if (erase) {
      final prefix = _prefix(userId);
      // Retain only device identity in secure storage; all conversation keys and
      // history keys are erased. A subsequent login starts fresh sessions.
      await _secure.delete(key: '$prefix.key');
    }
    await WsMediaFetcher.clearPrivateCache();
  }

  Iterable<int> get _remoteChatIds => engine.journal.conversations
      .map((key) => engine.journal.stateView(key)['remote_id'])
      .whereType<int>();

  /// Fence pending opens synchronously, then drain and purge in account order.
  /// The returned IDs allow legacy cache cleanup without forcing a new open.
  static Future<List<int>> shutdownAccount(int userId, {required bool erase}) {
    _accountEpochs[userId] = (_accountEpochs[userId] ?? 0) + 1;
    final active = _active[userId];
    final ids = <int>{
      ...?_retiredRemoteIds[userId],
      ...?active?._remoteChatIds,
    };
    // close cancels current uploads before the first await in this method.
    final stopping = active?.close(erase: erase);
    return _accountOperation(userId, () async {
      await stopping;
      ids.addAll(_retiredRemoteIds.remove(userId) ?? {});
      if (erase) await _eraseClosedAccount(userId);
      return ids.toList(growable: false);
    });
  }

  static Future<void> suspendAccount(int userId) =>
      shutdownAccount(userId, erase: false).then<void>((_) {});

  static Future<void> eraseAccount(int userId) =>
      shutdownAccount(userId, erase: true).then<void>((_) {});

  static Future<void> _eraseClosedAccount(int userId) async {
    await _secure.delete(key: '${_prefix(userId)}.key');
    for (final name in [
      'secret_journal_v2_$userId',
      'secret_attachments_v2_$userId',
    ]) {
      if (Hive.isBoxOpen(name)) {
        if (name.startsWith('secret_attachments_')) {
          await Hive.lazyBox<Uint8List>(name).close();
        } else {
          await Hive.box<String>(name).close();
        }
      }
      if (await Hive.boxExists(name)) await Hive.deleteBoxFromDisk(name);
    }
    final directory = await _attachmentDirectoryPath(userId);
    if (directory != null) await SecretAttachmentStore.eraseFiles(directory);
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
