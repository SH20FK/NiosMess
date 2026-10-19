import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart' as hashing;
import '../bluetooth_mesh/mesh_preferences.dart';
import '../bluetooth_mesh/mesh_packet.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'ordinary_e2ee_codec.dart';
import 'automatic_enrollment.dart';

typedef E2eRequest =
    Future<dynamic> Function(String action, {Map<String, dynamic>? payload});

class OrdinaryE2eeService extends ChangeNotifier {
  OrdinaryE2eeService(
    this.userId,
    this.request, {
    FlutterSecureStorage? storage,
    EnrollmentVerifier? enrollmentVerifier,
    bool Function()? isOnline,
    bool Function()? meshEnabled,
    this.offlineSessionTag,
  }) : storage = storage ?? const FlutterSecureStorage(),
       isOnline = isOnline ?? (() => true),
       meshEnabled = meshEnabled ?? (() => false),
       enrollmentVerifier = enrollmentVerifier ?? EnrollmentVerifier();
  final int userId;
  final E2eRequest request;
  final FlutterSecureStorage storage;
  final EnrollmentVerifier enrollmentVerifier;
  final bool Function() isOnline, meshEnabled;
  final String? offlineSessionTag;
  String get _offlineStateKey =>
      'niosmess.ordinary.$userId.offline.$offlineSessionTag.v1';
  EnrollmentStore get _enrollmentStore => EnrollmentStore(storage: storage);
  EnrollmentOffer? _autoOffer;
  Future<void>? _automaticSync;
  String? _autoStarted;
  bool get autoWaiting => locked && _autoOffer != null;
  OrdinaryKeys? _keys;
  List<int>? _recovery;
  bool enabled = true, locked = false, initialised = false;
  bool backupAcknowledged = false;
  E2eJson? _status;
  Future<void>? _opening;
  bool _disposed = false;
  int _identityGeneration = 0;
  String? get identityEpoch => locked ? null : _keys?.epoch;
  String _namespace = '';
  String get meshStorageScope {
    if (_namespace.isEmpty || !initialised) {
      throw StateError('Account keys unavailable');
    }
    return hashing.sha256
        .convert(utf8.encode('$userId:$_namespace'))
        .toString();
  }

  String get _prefix => _namespace.isEmpty
      ? 'niosmess.ordinary.$userId.v1'
      : 'niosmess.ordinary.$userId.${base64UrlEncode(utf8.encode(_namespace))}.v1';
  final Map<String, OrdinaryKeys> _keyring = {};
  SimpleKeyPair? _pairKey;
  String? _pairId;
  List<int>? _pairSecret;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _keys = null;
    _recovery = null;
    _keyring.clear();
    _opened.clear();
    _identities.clear();
    _pairKey = null;
    _pairSecret = null;
    _autoOffer = null;
    super.dispose();
  }

  Future<E2eJson> _call(String op, [E2eJson data = const {}]) async {
    if (_disposed) throw StateError('Сеанс шифрования закрыт');
    final result = await request('ordinary_e2ee', payload: {'op': op, ...data});
    if (_disposed) throw StateError('Сеанс шифрования закрыт');
    if (result is! Map) {
      throw StateError('Не удалось получить состояние шифрования');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<void> open() =>
      _opening ??= _open().whenComplete(() => _opening = null);
  Future<void> _open() async {
    _identityGeneration++;
    final E2eJson remote;
    if (isOnline()) {
      remote = await _call('status');
    } else {
      final cached = offlineSessionTag == null
          ? null
          : await storage.read(key: _offlineStateKey);
      if (cached == null) {
        throw StateError('Откройте NiosMess с интернетом для подготовки E2E');
      }
      remote = jsonDecode(cached) as E2eJson;
    }
    if (!remote.containsKey('identity') || !remote.containsKey('enabled')) {
      throw StateError('Сервер не поддерживает эту версию шифрования');
    }
    final namespace = remote['account_subject'] as String? ?? '';
    if (_namespace != namespace) {
      _keys = null;
      _recovery = null;
      _keyring.clear();
      _identities.clear();
      _opened.clear();
      _pairKey = null;
      _pairId = null;
      _pairSecret = null;
      _autoOffer = null;
      _autoStarted = null;
      _namespace = namespace;
    }
    backupAcknowledged =
        await storage.read(key: '$_prefix.backup_saved') == 'yes';
    _status = remote;
    enabled = remote['enabled'] != false || meshEnabled();
    if (isOnline() && meshEnabled() && remote['enabled'] == false) {
      await _call('preference', {'enabled': true});
    }
    final saved = await storage.read(key: '$_prefix.keys');
    if (saved != null) {
      final local = jsonDecode(saved) as E2eJson;
      final keys = OrdinaryKeys.fromJson(local['keys'] as E2eJson);
      if (keys.userId != userId) throw StateError('Неверный аккаунт ключей');
      _keyring[keys.epoch] = keys;
      _recovery = OrdinaryCodec.recoveryBytes(local['recovery'] as String);
      for (final data in (local['old'] as List? ?? const [])) {
        final old = OrdinaryKeys.fromJson(data as E2eJson);
        if (old.userId != userId) throw StateError('Неверный аккаунт ключей');
        _keyring[old.epoch] = old;
      }
      _keys = keys;
    }
    final pendingRaw = await storage.read(key: '$_prefix.pending');
    if (pendingRaw != null && remote['identity'] != null) {
      final pending = jsonDecode(pendingRaw) as E2eJson;
      final candidate = OrdinaryKeys.fromJson(pending['keys'] as E2eJson);
      if (candidate.userId == userId &&
          jsonEncode(await candidate.public()) ==
              jsonEncode(
                OrdinaryCodec.canonical(remote['identity'] as E2eJson),
              )) {
        _keys = candidate;
        _recovery = OrdinaryCodec.recoveryBytes(pending['recovery'] as String);
        backupAcknowledged = false;
        await storage.delete(key: '$_prefix.backup_saved');
        await _save();
        await storage.delete(key: '$_prefix.pending');
      }
    }
    if (remote['identity'] == null) {
      if (!isOnline()) {
        throw StateError('Нужно подключить ключи E2E с интернетом');
      }
      _keys ??= OrdinaryKeys.create(userId);
      _recovery ??= randomE2eBytes();
      await _save(); // Persist before publishing; a retry uses the same identity.
      await _register('register');
    }
    final identity = _status!['identity'] as E2eJson?;
    locked =
        _keys == null ||
        jsonEncode(await _keys!.public()) !=
            jsonEncode(OrdinaryCodec.canonical(identity!));
    initialised = true;
    if (isOnline() && offlineSessionTag != null) {
      await storage.write(key: _offlineStateKey, value: jsonEncode(_status));
    }
    _changed();
  }

  Future<void> _save() async {
    final keys = _keys!;
    _keyring[keys.epoch] = keys;
    await storage.write(
      key: '$_prefix.keys',
      value: jsonEncode({
        'keys': keys.secret(),
        'recovery': OrdinaryCodec.recoveryCode(_recovery!),
        'old': _keyring.values
            .where((k) => k.epoch != keys.epoch)
            .map((k) => k.secret())
            .toList(),
      }),
    );
  }

  Future<void> _register(String op) async {
    final keys = _keys!, pub = await keys.public();
    final backup = await OrdinaryCodec.backup(keys, _recovery!);
    final text =
        'niosmess-register-v1:$userId:${keys.epoch}:${pub['dh']}:${pub['ed']}:$backup';
    final result = await _call(op, {
      ...pub,
      'backup': backup,
      'signature': await keys.sign(text),
      if (op == 'reset') 'confirm': 'RESET_ENCRYPTED_HISTORY',
    });
    _status = {
      ...?_status,
      'identity': result['identity'],
      'backup': backup,
      'enabled': enabled,
    };
  }

  Future<void> setEnabled(bool value) async {
    if (!value && meshEnabled()) {
      throw StateError(
        'Сначала отключите «Если нет интернета использовать блютуз»',
      );
    }
    if (isOnline()) {
      await _call('preference', {'enabled': value});
    } else if (!value) {
      throw StateError('Для отключения E2E нужен интернет');
    }
    enabled = value;
    _changed();
  }

  Future<E2eJson?> prepare(int chatId, {bool force = false}) async {
    if (!initialised) await open();
    final E2eJson context;
    final cacheKey = '$_prefix.mesh-chat.$chatId';
    if (isOnline()) {
      try {
        context = await _call('chat', {'chat_id': chatId});
      } catch (_) {
        await storage.delete(key: cacheKey);
        rethrow;
      }
      if (context['eligible'] != true) await storage.delete(key: cacheKey);
    } else {
      context = await _offlineChat(chatId);
    }
    if (context['eligible'] != true ||
        (!force && !meshEnabled() && context['required'] != true)) {
      return null;
    }
    final identity = context['own'] as E2eJson?;
    if (locked ||
        _keys == null ||
        identity == null ||
        jsonEncode(await _keys!.public()) !=
            jsonEncode(OrdinaryCodec.canonical(identity))) {
      throw StateError(
        'Подключите шифрование в Настройки → Шифрование: нужен ключ восстановления или другое устройство.',
      );
    }
    final peer = context['peer'] as E2eJson?;
    if (peer == null) {
      throw StateError(
        'Собеседнику нужно обновить NiosMess и подключить шифрование. Открытый текст не отправлен.',
      );
    }
    await _checkPin(peer);
    if (isOnline()) {
      await storage.write(
        key: cacheKey,
        value: jsonEncode({
          'saved': DateTime.now().millisecondsSinceEpoch,
          'context': context,
        }),
      );
    }
    return context;
  }

  Future<void> warmMeshChat(int chatId) async {
    if (!isOnline() || locked || !meshEnabled()) return;
    if (!initialised) await open();
    final raw = await storage.read(key: '$_prefix.mesh-chat.$chatId');
    if (raw != null) {
      try {
        final value = jsonDecode(raw) as E2eJson;
        if (DateTime.now().millisecondsSinceEpoch - (value['saved'] as int) <
            const Duration(hours: 12).inMilliseconds) {
          return;
        }
      } catch (_) {}
    }
    await prepare(chatId, force: true);
  }

  Future<E2eJson> _offlineChat(int chatId) async {
    final raw = await storage.read(key: '$_prefix.mesh-chat.$chatId');
    if (raw == null) {
      throw StateError(
        'Откройте этот личный чат с интернетом перед отправкой по Bluetooth',
      );
    }
    final saved = jsonDecode(raw) as E2eJson;
    if (DateTime.now().millisecondsSinceEpoch - (saved['saved'] as int) >
        const Duration(days: 3).inMilliseconds) {
      throw StateError('Для обновления ключей этого чата нужен интернет');
    }
    return saved['context'] as E2eJson;
  }

  List<int>? _meshSeed;
  String? _meshPermit;
  Future<void>? _meshEnrolling;
  Future<void> prepareMesh() => _meshEnrolling ??= _prepareMesh().whenComplete(
    () => _meshEnrolling = null,
  );
  Future<void> _prepareMesh() async {
    if (!initialised) await open();
    if (locked || _keys == null || offlineSessionTag == null) return;
    final key = '$_offlineStateKey.mesh';
    final raw = await storage.read(key: key);
    if (raw != null) {
      final saved = jsonDecode(raw) as E2eJson;
      _meshSeed = decodeE2e(saved['seed'], 32);
      _meshPermit = saved['permit'] as String?;
    }
    _meshSeed ??= randomE2eBytes();
    if (_meshPermit != null) {
      try {
        final claim = MeshPacket.permitClaims(_meshPermit!);
        if (claim['epoch'] != _keys!.epoch ||
            claim['user'] != userId ||
            (claim['exp'] as int) * 1000 <
                DateTime.now()
                    .add(isOnline() ? const Duration(hours: 6) : Duration.zero)
                    .millisecondsSinceEpoch) {
          _meshPermit = null;
        }
      } catch (_) {
        _meshPermit = null;
      }
    }
    if (_meshPermit == null && isOnline() && _status?['mesh_relay'] == 1) {
      final keypair = await Ed25519().newKeyPairFromSeed(_meshSeed!);
      final device = base64Encode((await keypair.extractPublicKey()).bytes),
          nonce = const Uuid().v4();
      final result = await _call('mesh_permit', {
        'device': device,
        'nonce': nonce,
        'signature': await _keys!.sign(
          'niosmess-mesh-permit-v1:$userId:$device:$nonce',
        ),
      });
      _meshPermit = result['permit'] as String;
      MeshPacket.permitClaims(_meshPermit!);
      await storage.write(
        key: key,
        value: jsonEncode({
          'seed': base64Encode(_meshSeed!),
          'permit': _meshPermit,
        }),
      );
    }
  }

  Future<MeshPacket> createMeshPacket(
    int chatId,
    String text, {
    int? reply,
    E2eJson? extra,
  }) async {
    if (!meshEnabled()) throw StateError('Bluetooth-доставка отключена');
    if (utf8.encode(text).length > 4096) {
      throw StateError('Для Bluetooth текст должен быть не больше 4 КБ');
    }
    final context = await prepare(chatId, force: true);
    if (context == null || locked || _keys == null) {
      throw StateError('Нужны ключи личного чата');
    }
    final envelope = await encrypt(
      chatId,
      text,
      reply: reply,
      extra: extra,
      preparedContext: context,
    );
    return wrapMeshPacket(
      envelope,
      purpose:
          extra?['mesh'] is Map && (extra!['mesh'] as Map)['kind'] == 'receipt'
          ? 'receipt'
          : 'message',
    );
  }

  Future<MeshPacket> wrapMeshPacket(
    String envelope, {
    String purpose = 'message',
  }) async {
    await prepareMesh();
    if (_meshPermit == null || _meshSeed == null || _keys == null) {
      throw StateError(
        'Подключитесь к интернету для подготовки Bluetooth-доставки',
      );
    }
    return MeshPacket.create(
      _keys!,
      envelope,
      deviceSeed: _meshSeed!,
      permit: _meshPermit!,
      purpose: purpose,
    );
  }

  /// A relay cannot introduce a new conversation, member, identity or epoch.
  Future<E2eJson> openMeshPacket(MeshPacket packet) async {
    if (!initialised) await open();
    final header = OrdinaryCodec.header(packet.envelope);
    final chatId = header['chat'] as int, sender = header['sender'] as int;
    final context = await _offlineChat(chatId);
    final peer = context['peer'] as E2eJson?, own = context['own'] as E2eJson?;
    if (locked ||
        context['eligible'] != true ||
        peer == null ||
        own == null ||
        (sender != userId && sender != peer['user_id'])) {
      throw const FormatException('Unknown offline peer');
    }
    final author = sender == userId ? own : peer;
    if (author['ed'] != packet.author || author['epoch'] != header['epoch']) {
      throw const FormatException('Untrusted offline identity');
    }
    final box = (header['boxes'] as E2eJson)['$userId'] as E2eJson?;
    final keys = box == null ? null : _keyring[box['epoch']];
    if (keys == null) {
      throw const FormatException('Not addressed to this device');
    }
    final body = await OrdinaryCodec.decrypt(
      keys,
      author,
      packet.envelope,
      chatId,
      sender,
      reply: header['reply'] as int?,
    );
    if (body['text'] is! String ||
        utf8.encode(body['text'] as String).length > 4096 ||
        body['file_key'] != null) {
      throw const FormatException('Unsupported offline message');
    }
    return {
      'chat_id': chatId,
      'sender_id': sender,
      'operation_id': header['id'],
      'reply': header['reply'],
      'body': body,
    };
  }

  Future<void> _checkPin(E2eJson identity) async {
    final key = '$_prefix.pin.${identity['user_id']}.${identity['epoch']}';
    final value = jsonEncode(OrdinaryCodec.canonical(identity));
    final previous = await storage.read(key: key);
    if (previous != null && previous != value) {
      throw StateError('Ключ собеседника подменён. Отправка остановлена.');
    }
    final latestKey = '$_prefix.latest.${identity['user_id']}';
    final latest = await storage.read(key: latestKey);
    if (previous == null && latest != null && latest != identity['epoch']) {
      throw StateError(
        'Ключ собеседника изменился. Сверьте отпечаток в настройках шифрования.',
      );
    }
    await storage.write(key: key, value: value);
    await storage.write(key: latestKey, value: identity['epoch'] as String);
  }

  Future<String> encrypt(
    int chatId,
    String text, {
    int? reply,
    int? edit,
    String? fileKey,
    String? name,
    int? size,
    E2eJson? extra,
    E2eJson? preparedContext,
  }) async {
    final context =
        preparedContext ??
        await prepare(chatId, force: fileKey != null || edit != null);
    if (context == null) throw StateError('E2E не требуется для этого чата');
    return OrdinaryCodec.encrypt(
      _keys!,
      context['peer'] as E2eJson,
      chatId,
      {
        ...?extra,
        'text': text,
        'file_key': ?fileKey,
        'name': ?name,
        'size': ?size,
      },
      reply: reply,
      edit: edit,
    );
  }

  final Map<String, Future<E2eJson>> _identities = {};
  Future<E2eJson> _identity(int user, String epoch) => _identities.putIfAbsent(
    '$user:$epoch',
    () async {
      try {
        if (!isOnline()) {
          final own = _keyring[epoch];
          if (user == userId && own != null) return await own.public();
          final raw = await storage.read(key: '$_prefix.pin.$user.$epoch');
          if (raw == null) {
            throw const FormatException('Unknown offline identity');
          }
          final cached = jsonDecode(raw) as E2eJson;
          if (cached['user_id'] != user || cached['epoch'] != epoch) {
            throw const FormatException('Invalid offline pin');
          }
          return cached;
        }
        final data = await _call('identity', {'user_id': user, 'epoch': epoch});
        if (user != userId) await _checkPin(data);
        return data;
      } catch (_) {
        _identities.remove('$user:$epoch');
        rethrow;
      }
    },
  );
  final Map<(int, int, int?, int?, String), E2eJson> _opened = {};
  Future<ApiMessage> decrypt(ApiMessage message) async {
    if (message.e2eeContent == null) return message;
    try {
      if (!OrdinaryCodec.recognises(message.e2eeContent!)) {
        throw const FormatException('Unknown E2E format');
      }
      if (!initialised) await open();
      final h = OrdinaryCodec.header(message.e2eeContent!),
          box = (h['boxes'] as E2eJson)['$userId'] as E2eJson;
      final own = _keyring[box['epoch']];
      if (own == null) {
        throw StateError('Подключите это устройство в настройках шифрования.');
      }
      final sender = await _identity(message.senderId, h['epoch'] as String);
      final cacheKey = (
        message.chatId,
        message.senderId,
        message.replyToId,
        message.editedAt == null ? null : message.id,
        message.e2eeContent!,
      );
      final cached = _opened.remove(cacheKey);
      final body =
          cached ??
          await OrdinaryCodec.decrypt(
            own,
            sender,
            message.e2eeContent!,
            message.chatId,
            message.senderId,
            reply: message.replyToId,
            edit: message.editedAt == null ? null : message.id,
          );
      if (body['text'] is! String) {
        throw const FormatException('Invalid message text');
      }
      final fileKey = body['file_key'];
      if (fileKey != null) decodeE2e(fileKey, 32);
      if (message.hasMedia && fileKey == null && body['sticker'] == null) {
        throw const FormatException('Unauthenticated attachment');
      }
      if (_disposed) throw StateError('Сеанс шифрования закрыт');
      if (message.e2eeContent!.length <= 65536) {
        _opened[cacheKey] = body;
        if (_opened.length > 128) _opened.remove(_opened.keys.first);
      }
      final verified = ApiMessage.fromJson({
        ...message.toJson(),
        'is_e2ee': true,
        'is_decrypted': false,
        'e2ee_file_key': null,
        'sticker': null,
        'is_sticker': false,
        'sticker_set_id': null,
        'reply_markup': null,
        'system_event_type': null,
        'system_event': null,
        'media_name': null,
        'media_size': null,
      });
      return verified.copyWith(
        content: body['text'] as String? ?? '',
        isDecrypted: true,
        msgType: body['sticker'] != null
            ? 'sticker'
            : fileKey != null
            ? (const ['media', 'voice', 'circle'].contains(body['media_kind'])
                  ? body['media_kind'] as String
                  : 'media')
            : 'text',
        sticker: body['sticker'] != null
            ? ApiSticker.fromJson(body['sticker'] as E2eJson)
            : null,
        e2eeFileKey: body['file_key'] as String?,
        mediaName: body['name'] as String?,
        mediaSize: body['size'] as int?,
      );
    } catch (_) {
      return ApiMessage.fromJson({
        ...message.toJson(),
        'content':
            'Зашифрованное сообщение. Откройте настройки шифрования, чтобы подключить устройство или проверить ключ собеседника.',
        'is_e2ee': true,
        'is_decrypted': false,
        'msg_type': 'text',
        'media_url': null,
        'media_type': null,
        'media_name': null,
        'media_size': null,
        'e2ee_file_key': null,
        'sticker': null,
        'is_sticker': false,
        'sticker_set_id': null,
        'reply_markup': null,
        'system_event_type': null,
        'system_event': null,
      });
    }
  }

  Future<void> acknowledgeBackup() async {
    await storage.write(key: '$_prefix.backup_saved', value: 'yes');
    backupAcknowledged = true;
    _changed();
  }

  Future<void> syncAutomatic() => _automaticSync ??= _syncAutomatic()
      .whenComplete(() => _automaticSync = null);

  Future<void> _syncAutomatic() async {
    if (!initialised) await open();
    if (_status?['auto_enrollment'] != 1 || _namespace.isEmpty) return;
    // The namespace that located this device's saved keys pins the own NiosID
    // subject. Never use a subject supplied inside a relay's enrollment request.
    final subject = _namespace.split(':').first;
    final namespace = _namespace, generation = _identityGeneration;
    void requireCurrentSession() {
      if (_disposed ||
          _namespace != namespace ||
          _identityGeneration != generation) {
        throw StateError('Сеанс шифрования изменился');
      }
    }

    _autoOffer ??= await _enrollmentStore.read();
    if (_autoOffer != null) {
      final offer = _autoOffer!;
      EnrollmentProof? proof;
      try {
        proof = await enrollmentVerifier.verify(offer.proof, subject);
      } on FormatException {
        await _enrollmentStore.clear(offer);
        _autoOffer = null;
        _autoStarted = null;
        _changed();
        if (locked) return;
      }
      if (proof != null) {
        final localTarget = base64Encode(
          (await offer.keyPair.extractPublicKey()).bytes,
        );
        if (proof.requestId != offer.requestId || proof.target != localTarget) {
          throw const FormatException('Mismatched device login');
        }
        if (!locked) {
          await _enrollmentStore.clear(offer);
          _autoOffer = null;
        } else {
          if (_autoStarted != proof.requestId) {
            await _call('auto_start', {'proof': offer.proof});
            _autoStarted = proof.requestId;
            _changed();
          }
          final delivery = await _call('auto_get', {
            'request_id': proof.requestId,
          });
          if (delivery['packet'] == null) return;
          final current = await _call('status');
          final identity = current['identity'] as E2eJson?;
          final packet = delivery['packet'] as String;
          if (current['account_subject'] != _namespace ||
              identity == null ||
              delivery['epoch'] != identity['epoch'] ||
              !await OrdinaryCodec.verify(
                await proof.approvalText(userId, packet),
                delivery['signature'] as String,
                identity['ed'] as String,
              )) {
            throw const FormatException('Invalid encrypted key delivery');
          }
          final bundle = await OrdinaryCodec.unpair(
            offer.keyPair,
            userId,
            proof.requestId,
            packet,
            await proof.wrappingSalt(),
            domain: 'niosmess-auto-pair-v1',
          );
          final received = OrdinaryKeys.fromJson(bundle['keys'] as E2eJson);
          final recovery = bundle['recovery'] as String;
          final restored = await OrdinaryCodec.restore(
            identity,
            current['backup'] as String,
            recovery,
          );
          if (received.userId != userId ||
              jsonEncode(await received.public()) !=
                  jsonEncode(await restored.public())) {
            throw const FormatException(
              'Key backup does not match the enrolled device',
            );
          }
          final old = bundle['old'] as List? ?? const [];
          if (old.length > 256) {
            throw const FormatException('Too many identity epochs');
          }
          final imported = <String, OrdinaryKeys>{};
          for (final record in old) {
            final key = OrdinaryKeys.fromJson(record as E2eJson);
            if (key.userId != userId ||
                key.epoch == received.epoch ||
                imported.containsKey(key.epoch)) {
              throw const FormatException('Invalid previous identity');
            }
            imported[key.epoch] = key;
          }
          final previousKeys = _keys, previousRecovery = _recovery;
          final previousRing = Map<String, OrdinaryKeys>.from(_keyring);
          requireCurrentSession();
          try {
            _keys = received;
            _recovery = OrdinaryCodec.recoveryBytes(recovery);
            _keyring.addAll(imported);
            await _save();
          } catch (_) {
            _keys = previousKeys;
            _recovery = previousRecovery;
            _keyring
              ..clear()
              ..addAll(previousRing);
            rethrow;
          }
          requireCurrentSession();
          _status = current;
          _opened.clear();
          _identities.clear();
          locked = false;
          await _enrollmentStore.clear(offer);
          _autoOffer = null;
          _changed();
        }
      }
    }
    if (locked || _keys == null || _recovery == null) return;
    final nonce = const Uuid().v4();
    final requests = await _call('auto_list', {
      'request_nonce': nonce,
      'signature': await _keys!.sign('niosmess-auto-list-v1:$userId:$nonce'),
    });
    for (final value in requests['requests'] as List? ?? const []) {
      if (_disposed) return;
      final row = value as E2eJson;
      if (row['proof'] is! String) continue;
      EnrollmentProof proof;
      try {
        proof = await enrollmentVerifier.verify(
          row['proof'] as String,
          subject,
        );
      } on FormatException {
        continue; // A relay's invalid entry must not prevent other devices syncing.
      }
      requireCurrentSession();
      if (row['request_id'] != proof.requestId ||
          row['epoch'] != _keys!.epoch) {
        throw const FormatException('Invalid device request');
      }
      final packet = await OrdinaryCodec.pair(
        _keys!,
        _recovery!,
        proof.target,
        proof.requestId,
        await proof.wrappingSalt(),
        domain: 'niosmess-auto-pair-v1',
        old: _keyring.values
            .where((key) => key.epoch != _keys!.epoch)
            .map((key) => key.secret())
            .toList(),
      );
      requireCurrentSession();
      await _call('auto_approve', {
        'request_id': proof.requestId,
        'packet': packet,
        'signature': await _keys!.sign(
          await proof.approvalText(userId, packet),
        ),
      });
    }
  }

  Future<String> askAi(int chatId, int sourceId, String question) async {
    final result = await _call('ask_ai', {
      'chat_id': chatId,
      'source_id': sourceId,
      'question': question,
    });
    return result['answer'] as String;
  }

  Future<String> recoveryCode() async {
    if (!initialised) await open();
    if (locked || _recovery == null) {
      throw StateError('Сначала восстановите ключи');
    }
    return OrdinaryCodec.recoveryCode(_recovery!);
  }

  Future<void> restore(String code) async {
    await _automaticSync;
    _identityGeneration++;
    final state = await _call('status');
    final pub = state['identity'] as E2eJson?;
    if (pub == null) throw StateError('Нет зашифрованной резервной копии');
    final restoredNamespace = state['account_subject'] as String? ?? '';
    if (_namespace != restoredNamespace) {
      _namespace = restoredNamespace;
      _keyring.clear();
      _opened.clear();
      _identities.clear();
    }
    final keys = await OrdinaryCodec.restore(
      pub,
      state['backup'] as String,
      code,
    );
    if (keys.userId != userId) throw StateError('Ключ другого аккаунта');
    _keys = keys;
    _recovery = OrdinaryCodec.recoveryBytes(code);
    _status = state;
    locked = false;
    initialised = true;
    await _save();
    _changed();
  }

  Future<void> resetAfterLoss() async {
    await _automaticSync;
    _identityGeneration++;
    final previousKeys = _keys, previousRecovery = _recovery;
    _keys = OrdinaryKeys.create(userId);
    _recovery = randomE2eBytes();
    await storage.write(
      key: '$_prefix.pending',
      value: jsonEncode({
        'keys': _keys!.secret(),
        'recovery': OrdinaryCodec.recoveryCode(_recovery!),
      }),
    );
    try {
      await _register('reset');
      backupAcknowledged = false;
      await storage.delete(key: '$_prefix.backup_saved');
      await _save();
      await storage.delete(key: '$_prefix.pending');
      locked = false;
      initialised = true;
      _changed();
    } catch (_) {
      _keys = previousKeys;
      _recovery = previousRecovery;
      rethrow;
    }
  }

  Future<String> beginPairing() async {
    if (!initialised) await open();
    _pairKey = await X25519().newKeyPair();
    _pairId = const Uuid().v4();
    _pairSecret = randomE2eBytes();
    final target = base64Encode((await _pairKey!.extractPublicKey()).bytes);
    await _call('pair_start', {'request_id': _pairId, 'target_key': target});
    return 'niosmess-e2e:${base64UrlEncode(utf8.encode(jsonEncode({'v': 1, 'user_id': userId, 'request_id': _pairId, 'target_key': target, 'secret': base64Encode(_pairSecret!)})))}';
  }

  Future<void> approvePairing(String code) async {
    if (!initialised) await open();
    if (locked) throw StateError('Это устройство не подключено');
    final data =
        jsonDecode(
              utf8.decode(
                base64Url.decode(code.trim().replaceFirst('niosmess-e2e:', '')),
              ),
            )
            as E2eJson;
    if (data['v'] != 1 || data['user_id'] != userId) {
      throw StateError('Код другого аккаунта');
    }
    final target = data['target_key'] as String,
        request = data['request_id'] as String;
    final packet = await OrdinaryCodec.pair(
      _keys!,
      _recovery!,
      target,
      request,
      decodeE2e(data['secret'], 32),
    );
    await _call('pair_approve', {
      'request_id': request,
      'target_key': target,
      'packet': packet,
      'signature': await _keys!.sign(
        'niosmess-pair-v1:$userId:$request:$target:$packet',
      ),
    });
  }

  Future<bool> completePairing() async {
    if (_pairKey == null || _pairId == null) return false;
    final result = await _call('pair_get', {'request_id': _pairId});
    if (result['packet'] == null) return false;
    final data = await OrdinaryCodec.unpair(
      _pairKey!,
      userId,
      _pairId!,
      result['packet'] as String,
      _pairSecret!,
    );
    final keys = OrdinaryKeys.fromJson(data['keys'] as E2eJson);
    final state = await _call('status');
    if (keys.userId != userId ||
        jsonEncode(await keys.public()) !=
            jsonEncode(OrdinaryCodec.canonical(state['identity'] as E2eJson))) {
      throw StateError('Ключи устройства не совпадают');
    }
    // Authenticate the backup too, before persisting anything received.
    await restore(data['recovery'] as String);
    _pairKey = null;
    _pairId = null;
    _pairSecret = null;
    return true;
  }

  Future<String> ownFingerprint() async {
    if (!initialised) await open();
    if (_keys == null || locked) throw StateError('Устройство не подключено');
    return fingerprint(await _keys!.public());
  }

  Future<String> fingerprint(E2eJson identity) async {
    final hash = await Sha256().hash(
      utf8.encode(jsonEncode(OrdinaryCodec.canonical(identity))),
    );
    final hex = hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return [
      for (int i = 0; i < hex.length; i += 4) hex.substring(i, i + 4),
    ].join(' ');
  }

  Future<E2eJson> contactIdentity(int chatId) async {
    final context = await _call('chat', {'chat_id': chatId});
    final identity = context['peer'] as E2eJson?;
    if (identity == null) throw StateError('У собеседника нет ключа');
    return identity;
  }

  Future<void> acceptContact(E2eJson identity) async {
    await storage.write(
      key: '$_prefix.pin.${identity['user_id']}.${identity['epoch']}',
      value: jsonEncode(OrdinaryCodec.canonical(identity)),
    );
    await storage.write(
      key: '$_prefix.latest.${identity['user_id']}',
      value: identity['epoch'] as String,
    );
    _identities.clear();
    _opened.clear();
  }
}

final ordinaryE2eeProvider = Provider<OrdinaryE2eeService?>((ref) {
  final account = ref.watch(
    authProvider.select((s) => (s.session?.userId, s.session?.accessToken)),
  );
  final user = account.$1;
  if (user == null) return null;
  final ws = ref.watch(webSocketClientProvider);
  final service = OrdinaryE2eeService(
    user,
    (action, {payload}) async {
      await ref.read(meshPreferenceProvider.notifier).loaded;
      if (!ref.mounted) throw StateError('Account closed');
      return ws.request(
        action,
        payload: payload,
        timeout: payload?['op'] == 'ask_ai'
            ? const Duration(minutes: 2)
            : const Duration(seconds: 15),
        maxRetries: payload?['op'] == 'ask_ai' ? 0 : 2,
      );
    },
    isOnline: () => ws.isConnected,
    meshEnabled: () =>
        meshPlatformSupported &&
        ref.read(meshPreferenceProvider.notifier).hydrated &&
        ref.read(meshPreferenceProvider),
    offlineSessionTag: hashing.sha256
        .convert(utf8.encode(account.$2!))
        .toString(),
  );
  var lastPoll = DateTime.fromMillisecondsSinceEpoch(0);
  void sync({bool forced = false}) {
    if (!ws.isConnected ||
        (!forced &&
            !service.locked &&
            DateTime.now().difference(lastPoll).inSeconds < 30)) {
      return;
    }
    lastPoll = DateTime.now();
    unawaited(service.syncAutomatic().catchError((Object _) {}));
  }

  final timer = Timer.periodic(const Duration(seconds: 5), (_) => sync());
  final connected = ws.onConnected.listen((_) {
    unawaited(
      () async {
        await ref.read(meshPreferenceProvider.notifier).loaded;
        if (!ref.mounted) return;
        if (ref.read(meshPreferenceProvider)) await service.setEnabled(true);
        sync(forced: true);
      }().catchError((Object _) {}),
    );
  });
  final push = ws.pushStream.listen((event) {
    if (event['action'] == 'ordinary_auto_enrollment') sync(forced: true);
  });
  ref.onDispose(() {
    timer.cancel();
    unawaited(connected.cancel());
    unawaited(push.cancel());
    service.dispose();
  });
  return service;
});
