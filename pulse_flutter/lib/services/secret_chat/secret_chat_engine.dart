import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import 'package:pulse_flutter/services/double_ratchet_service.dart';
import 'secret_journal.dart';

abstract interface class SecretTransport {
  Future<SecretJson> request(String action, SecretJson payload);
  Future<String> upload(String attachmentId, SecretJson file);
}

class SecretTransportException implements Exception {
  const SecretTransportException(this.code, {this.permanent = false});
  final String code;
  final bool permanent;
}

/// Account-owned delivery engine. Screens only enqueue and observe projections.
/// Every ratchet transition is committed with the corresponding message change.
class SecretChatEngine {
  SecretChatEngine({
    required this.userId,
    required this.username,
    required this.journal,
    required this.transport,
    required this.staticSeed,
    required this.identitySeed,
  });

  final int userId;
  final String username;
  final SecretJournal journal;
  final SecretTransport transport;
  final List<int> staticSeed;
  final List<int> identitySeed;
  final _serial = SecretSerialExecutor();
  final _dr = DoubleRatchetService();
  final _dh = X25519();
  final _ed = Ed25519();
  final _uuid = const Uuid();
  final _changes = StreamController<String>.broadcast();
  final Set<String> _pumping = {};
  bool _stopped = false;
  late String publicKey;
  late String edPublicKey;
  late SimpleKeyPair _identity;

  Stream<String> get changes => _changes.stream;
  bool get stopped => _stopped;

  Future<void> initialize() async {
    final pair = await _dh.newKeyPairFromSeed(staticSeed);
    publicKey = base64Encode((await pair.extractPublicKey()).bytes);
    _identity = await _ed.newKeyPairFromSeed(identitySeed);
    edPublicKey = base64Encode((await _identity.extractPublicKey()).bytes);
  }

  String? findChat(int uiId) => journal.conversations.where((key) {
    final state = journal.state(key);
    return state['ui_id'] == uiId || state['remote_id'] == uiId;
  }).firstOrNull;

  SecretJson chat(int uiId) => journal.state(findChat(uiId) ?? '$uiId');

  Future<void> saveDraft(int uiId, String text) async {
    final key = findChat(uiId);
    if (key == null || _stopped) return;
    await _serial.run(key, () async {
      final state = journal.state(key);
      if (state['draft'] == text) return;
      state['draft'] = text;
      await _commit(key, state);
    });
  }

  Future<String> safetyNumber(int uiId) async {
    final state = chat(uiId);
    if (state['pinned_ed'] == null) return '';
    final identities = [
      '$publicKey:$edPublicKey',
      '${state['peer_key']}:${state['pinned_ed']}',
    ]..sort();
    final hash = await Sha256().hash(
      utf8.encode(jsonEncode(['NiosMess/secret/2', ...identities])),
    );
    final hex = hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return [
      for (var i = 0; i < hex.length; i += 4) hex.substring(i, i + 4),
    ].join(' ');
  }

  Future<void> _commit(
    String key,
    SecretJson state, {
    Map<String, SecretJson> messages = const {},
    List<String> remove = const [],
  }) async {
    if (_stopped) throw StateError('Secret account is closed');
    if (remove.isEmpty &&
        jsonEncode(state) == jsonEncode(journal.state(key)) &&
        messages.entries.every(
          (entry) =>
              jsonEncode(entry.value) ==
              jsonEncode(
                journal
                    .messages(key)
                    .where((row) => row['local_id'] == entry.key)
                    .firstOrNull,
              ),
        )) {
      return;
    }
    await journal.commit(key, state, messages: messages, remove: remove);
    if (!_changes.isClosed) _changes.add(key);
  }

  Future<int> open({
    required int peerId,
    required String peerName,
    int? remoteId,
    String? peerKey,
    SecretJson? peerProfile,
  }) async {
    return _serial.run('conversations', () async {
      final existing = journal.conversations.where((key) {
        final state = journal.state(key);
        return remoteId != null
            ? state['remote_id'] == remoteId ||
                  (state['remote_id'] == null &&
                      state['peer_id'] == peerId &&
                      (state['peer_key'] == null ||
                          state['peer_key'] == peerKey))
            : state['peer_id'] == peerId && state['status'] != 'otherDevice';
      }).firstOrNull;
      if (existing != null) {
        if (peerProfile != null ||
            (remoteId != null &&
                journal.state(existing)['remote_id'] == null)) {
          await _serial.run(existing, () async {
            final state = journal.state(existing);
            if (remoteId != null && state['remote_id'] == null) {
              state['remote_id'] = remoteId;
              state['peer_key'] = peerKey;
            }
            if (peerProfile != null) {
              state['peer_profile'] = peerProfile;
              state['peer_name'] = peerName;
            }
            await _commit(existing, state);
          });
        }
        return journal.state(existing)['ui_id'] as int;
      }
      final key = _uuid.v4();
      final id = remoteId ?? -DateTime.now().microsecondsSinceEpoch;
      await _commit(key, {
        'ui_id': id,
        'remote_id': remoteId,
        'peer_id': peerId,
        'peer_name': peerName,
        'peer_profile': ?peerProfile,
        'peer_key': peerKey,
        'cursor': 0,
        'status': 'waiting',
        'controls': <String, dynamic>{},
        'initialized': false,
      });
      return id;
    });
  }

  Future<void> importHistory(int uiId, List<SecretJson> messages) async {
    final key = findChat(uiId)!;
    await _serial.run(key, () async {
      final state = journal.state(key);
      if (state['legacy_imported'] == true) return;
      final rows = <String, SecretJson>{};
      for (final message in messages) {
        final id = 'legacy:${message['id']}';
        rows[id] = {
          'local_id': id,
          'message': message,
          if (message['is_e2ee'] == true &&
              message['is_decrypted'] != true &&
              (message['content'] == null || message['content'] == ''))
            'unavailable': true,
          'body': _bodyFromMessage(message),
          'operations': <dynamic>[],
        };
      }
      state['legacy_imported'] = true;
      await _commit(key, state, messages: rows);
    });
  }

  Future<void> importLegacySession(
    int uiId,
    SecretJson? session,
    String? verifiedEd,
  ) async {
    final key = findChat(uiId)!;
    await _serial.run(key, () async {
      final state = journal.state(key);
      if (state['legacy_keys_imported'] == true) return;
      if (session != null) state['legacy_ratchet'] = session;
      final knownEd = verifiedEd ?? session?['peerStaticEd'];
      if (knownEd is String && knownEd.isNotEmpty) {
        state['pinned_ed'] ??= knownEd;
      }
      if (verifiedEd != null) state['verified'] = true;
      state['legacy_keys_imported'] = true;
      await _commit(key, state);
    });
  }

  SecretJson _bodyFromMessage(SecretJson message) {
    SecretJson envelope = {};
    try {
      envelope = secretMap(jsonDecode(message['content'] as String));
    } catch (_) {}
    final legacyKey = envelope['fk'] ?? envelope['keyB64'];
    if (legacyKey is String && legacyKey.isNotEmpty) {
      return {
        'text': envelope['text'] ?? envelope['caption'] ?? '',
        'type': 'media',
        'file': {
          'key': legacyKey,
          'name': envelope['name'] ?? message['media_name'],
          'size': envelope['size'] ?? message['media_size'],
          'mime': message['media_type'],
        },
      };
    }
    return {
      'text': message['content'] ?? '',
      'type': message['msg_type'] ?? 'text',
      if (message['sticker'] != null) 'sticker': message['sticker'],
      if (message['e2ee_file_key'] != null)
        'file': {
          'key': message['e2ee_file_key'],
          'name': message['media_name'],
          'size': message['media_size'],
          'mime': message['media_type'],
        },
    };
  }

  Future<String> enqueue(int uiId, SecretJson body, {int? replyToId}) async {
    final key = findChat(uiId);
    if (key == null) throw StateError('Unknown secret conversation');
    final id = _uuid.v4();
    await _serial.run(key, () async {
      final state = journal.state(key);
      state['draft'] = '';
      final now = DateTime.now().toUtc();
      final message = <String, dynamic>{
        'id': -now.microsecondsSinceEpoch,
        'chat_id': state['ui_id'],
        'sender_id': userId,
        'sender_username': username,
        'sender_display_name': username,
        'sender_badges': <dynamic>[],
        'content': body['text'] ?? '',
        'msg_type': body['type'] ?? 'text',
        'sent_at': now.toIso8601String(),
        'reply_to_id': replyToId,
        'client_message_id': id,
        'is_e2ee': true,
        'is_decrypted': true,
      };
      final row = <String, dynamic>{
        'local_id': id,
        'message': message,
        'body': secretCopy(body),
        'local_numeric_id': message['id'],
        'operations': [
          {'id': id, 'action': 'send_message', 'body': secretCopy(body)},
        ],
      };
      await _commit(key, state, messages: {id: row});
    });
    wake();
    return id;
  }

  List<SecretJson> messages(int uiId) {
    final key = findChat(uiId);
    if (key == null) return [];
    final result = <SecretJson>[];
    for (final row in journal.messages(key)) {
      final message = secretMap(row['message']);
      final body = secretMap(row['body']);
      if (message['is_deleted'] == true) continue;
      final expiry = DateTime.tryParse('${message['expires_at']}');
      if (expiry != null && expiry.isBefore(DateTime.now())) continue;
      final file = secretMap(body['file']);
      final operations = row['operations'] as List? ?? [];
      final failed = operations.any((op) => secretMap(op)['failed'] == true);
      result.add({
        ...message,
        'chat_id': uiId,
        'content': body['text'] ?? message['content'] ?? '',
        'msg_type': body['type'] ?? message['msg_type'] ?? 'text',
        'is_e2ee': true,
        'is_decrypted': row['unavailable'] != true,
        'is_sending': operations.isNotEmpty && !failed,
        'is_failed': failed,
        'client_message_id': row['local_id'],
        if (body['sticker'] != null) 'sticker': body['sticker'],
        if (file.isNotEmpty) ...{
          'e2ee_file_key': file['key'],
          'media_name': file['name'],
          'media_size': file['size'],
          'media_type': file['mime'],
          if (file['attachment_id'] != null)
            'media_url': 'secret-local://${file['attachment_id']}',
        },
      });
    }
    result.sort((a, b) => '${a['sent_at']}'.compareTo('${b['sent_at']}'));
    return result;
  }

  Future<void> edit(int uiId, int messageId, String text) =>
      _mutateLocal(uiId, messageId, 'edit_message', text);
  Future<void> delete(int uiId, int messageId) =>
      _mutateLocal(uiId, messageId, 'delete_message', null);

  Future<void> _mutateLocal(
    int uiId,
    int messageId,
    String action,
    String? text,
  ) async {
    final key = findChat(uiId)!;
    await _serial.run(key, () async {
      final row = journal
          .messages(key)
          .where((row) => secretMap(row['message'])['id'] == messageId)
          .firstOrNull;
      if (row == null) return;
      final message = secretMap(row['message']);
      if (message['sender_id'] != userId) throw StateError('Not your message');
      final state = journal.state(key);
      final body = secretMap(row['body']);
      final ops = List<dynamic>.from(row['operations'] as List? ?? []);
      if (action == 'edit_message') {
        body['text'] = text;
        row['body'] = body;
        message['edited_at'] = DateTime.now().toUtc().toIso8601String();
      } else {
        message['is_deleted'] = true;
        message['content'] = '';
        message['e2ee_file_key'] = null;
        row['body'] = <String, dynamic>{};
        for (final op in ops) {
          if (secretMap(op)['packet'] != null) {
            (op as Map)['body'] = <String, dynamic>{};
          }
        }
      }
      // An unprepared local send has no remote side effects and can be edited
      // in place or cancelled. Once prepared, its immutable packet is retained.
      if (messageId < 0 &&
          ops.length == 1 &&
          secretMap(ops.first)['packet'] == null) {
        if (action == 'delete_message') {
          await _commit(key, state, remove: [row['local_id'] as String]);
          return;
        }
        ops[0] = {...secretMap(ops.first), 'body': body};
      } else {
        ops.add({
          'id': _uuid.v4(),
          'action': action,
          'body': action == 'delete_message' ? <String, dynamic>{} : body,
        });
      }
      row['message'] = message;
      row['operations'] = ops;
      await _commit(key, state, messages: {row['local_id'] as String: row});
    });
    wake();
  }

  Future<void> retry(int uiId, int messageId) async {
    final key = findChat(uiId)!;
    await _serial.run(key, () async {
      final row = journal
          .messages(key)
          .where((row) => secretMap(row['message'])['id'] == messageId)
          .firstOrNull;
      if (row == null) return;
      for (final op in row['operations'] as List? ?? []) {
        (op as Map).remove('failed');
      }
      await _commit(
        key,
        journal.state(key),
        messages: {row['local_id'] as String: row},
      );
    });
    wake();
  }

  void wake() {
    if (_stopped) return;
    for (final key in journal.conversations) {
      unawaited(pump(key).catchError((Object _) {}));
    }
  }

  Future<void> pump(String key) async {
    if (_stopped || !_pumping.add(key)) return;
    try {
      await _expire(key);
      await _resolve(key);
      if (_stopped || journal.state(key)['remote_id'] == null) return;
      await _sync(key);
      await _prepareHandshake(key);
      await _sendControls(key);
      // Re-read controls immediately: the peer may already have answered.
      await _sync(key);
      await _retryInbox(key);
      for (var count = 0; count < 32 && !_stopped; count++) {
        if (!await _sendNext(key)) break;
      }
    } on SecretTransportException catch (error) {
      if (error.permanent && !_stopped) {
        await _serial.run(key, () async {
          final state = journal.state(key);
          if (error.code.contains('DEVICE_MISMATCH')) {
            state['status'] = 'otherDevice';
          }
          final row = journal
              .messages(key)
              .where((r) => (r['operations'] as List? ?? []).isNotEmpty)
              .firstOrNull;
          if (row != null) {
            final ops = row['operations'] as List;
            ops[0] = {...secretMap(ops.first), 'failed': true};
          }
          await _commit(
            key,
            state,
            messages: row == null ? {} : {row['local_id'] as String: row},
          );
        });
      }
      rethrow;
    } finally {
      _pumping.remove(key);
    }
  }

  Future<void> _expire(String key) => _serial.run(key, () async {
    final expired = journal.messages(key).where((row) {
      final message = secretMap(row['message']);
      final expiry = DateTime.tryParse('${message['expires_at']}');
      return message['is_deleted'] != true &&
          expiry != null &&
          expiry.isBefore(DateTime.now());
    }).toList();
    if (expired.isEmpty) return;
    await _commit(
      key,
      journal.state(key),
      messages: {
        for (final row in expired)
          row['local_id'] as String: {
            'local_id': row['local_id'],
            'body': <String, dynamic>{},
            'operations': <dynamic>[],
            'message': {
              ...secretMap(row['message']),
              'is_deleted': true,
              'content': '',
              'e2ee_content': null,
            },
          },
      },
    );
  });

  Future<void> _resolve(String key) async {
    var state = journal.state(key);
    if (state['remote_id'] != null) return;
    final response = await transport.request('get_public_key', {
      'user_id': state['peer_id'],
    });
    final devices =
        (response['devices'] as List? ?? []).map(secretMap).where((device) {
          try {
            return base64Decode('${device['public_key']}').length == 32;
          } catch (_) {
            return false;
          }
        }).toList()..sort(
          (a, b) => (b['session_id'] as int).compareTo(a['session_id'] as int),
        );
    if (devices.isEmpty) return;
    final peerKey = devices.first['public_key'];
    final opened = await transport.request('open_direct', {
      'user_id': state['peer_id'],
      'is_secret': true,
      'public_key': publicKey,
      'target_public_key': peerKey,
    });
    await _serial.run(key, () async {
      state = journal.state(key);
      state['remote_id'] = opened['chat_id'];
      state['peer_key'] = peerKey;
      final profile = secretMap(opened['with_user']);
      if (profile.isNotEmpty && profile['id'] == state['peer_id']) {
        state['peer_profile'] = {
          'display_name': profile['display_name'],
          'username': profile['username'],
          'avatar_url': profile['avatar_url'],
        };
      }
      await _commit(key, state);
    });
  }

  Future<void> _sync(String key) async {
    for (var page = 0; page < 50 && !_stopped; page++) {
      final state = journal.state(key);
      final response = await transport.request('secret_sync', {
        'chat_id': state['remote_id'],
        'after_event_id': state['cursor'] ?? 0,
        'limit': 100,
      });
      await _serial.run(key, () async {
        final current = journal.state(key);
        current['peer_protocol'] = response['peer_protocol_version'] ?? 0;
        final peerKey = response['peer_public_key'];
        if (current['peer_key'] != null && peerKey != current['peer_key']) {
          current['status'] = 'keyChanged';
          current['candidate_key'] = peerKey;
        } else {
          current['peer_key'] = peerKey;
        }
        await _commit(key, current);
      });
      final ordered =
          (response['events'] as List? ?? []).map(secretMap).toList()..sort(
            (a, b) => (a['event_id'] as int).compareTo(b['event_id'] as int),
          );
      for (final event in ordered) {
        await _serial.run(key, () => _receive(key, event));
      }
      if (response['has_more'] != true) {
        await _serial.run(key, () async {
          final current = journal.state(key);
          if (current['initialized'] != true) {
            current['initialized'] = true;
            await _commit(key, current);
          }
        });
        return;
      }
    }
  }

  List<int> _controlBytes(SecretJson control) => utf8.encode(
    jsonEncode([
      control['v'],
      control['kind'],
      control['session_id'],
      control['chat_id'],
      control['from_key'],
      control['to_key'],
      control['dh'],
      control['ed'],
    ]),
  );

  Future<SecretJson> _control(
    SecretJson state,
    String kind,
    String sid,
    String dh,
  ) async {
    final value = <String, dynamic>{
      'v': 2,
      'kind': kind,
      'session_id': sid,
      'chat_id': state['remote_id'],
      'from_key': publicKey,
      'to_key': state['peer_key'],
      'dh': dh,
      'ed': edPublicKey,
    };
    value['sig'] = base64Encode(
      (await _ed.sign(_controlBytes(value), keyPair: _identity)).bytes,
    );
    return value;
  }

  Future<void> _prepareHandshake(String key) => _serial.run(key, () async {
    final state = journal.state(key);
    if (state['status'] == 'keyChanged' ||
        state['status'] == 'invalidSignature') {
      return;
    }
    if (state['peer_protocol'] != 2) {
      if (state['status'] != 'updateRequired') {
        state['status'] = 'updateRequired';
        await _commit(key, state);
      }
      return;
    }
    if (state['ratchet'] != null) return;
    final peer = state['peer_key'] as String;
    final controls = secretMap(state['controls']);
    // A restored account with no session asks the other device to establish a
    // fresh epoch. Cached history survives; old epoch packets are never reused.
    if (state['reset_requested'] != true) {
      final resetId = _uuid.v4();
      controls[resetId] = await _control(state, 'reset', _uuid.v4(), publicKey);
      state['reset_requested'] = true;
    }
    state['status'] = 'connecting';
    if (publicKey.compareTo(peer) > 0) {
      final session = await _dr.initiateSession(
        ourStaticSeed: staticSeed,
        theirStaticPublic: SimplePublicKey(
          base64Decode(peer),
          type: KeyPairType.x25519,
        ),
        peerStaticEdB64: state['pinned_ed'] as String? ?? '',
      );
      final sid = _uuid.v4();
      state['session_id'] = sid;
      state['ratchet'] = await session.toJson();
      final dh = await _dh.newKeyPairFromSeed(session.dhsSeed!);
      controls[_uuid.v4()] = await _control(
        state,
        'init',
        sid,
        base64Encode((await dh.extractPublicKey()).bytes),
      );
    }
    state['controls'] = controls;
    await _commit(key, state);
  });

  Future<void> _sendControls(String key) async {
    final state = journal.state(key);
    if (state['status'] == 'keyChanged' ||
        state['status'] == 'invalidSignature') {
      return;
    }
    for (final entry in secretMap(state['controls']).entries) {
      if (_stopped) return;
      await transport.request('secret_control', {
        'chat_id': state['remote_id'],
        'client_operation_id': entry.key,
        'control': entry.value,
      });
      await _serial.run(key, () async {
        final latest = journal.state(key);
        latest['controls'] = secretMap(latest['controls'])..remove(entry.key);
        await _commit(key, latest);
      });
    }
  }

  Future<void> _receive(String key, SecretJson event) async {
    final state = journal.state(key);
    final cursor = event['event_id'] as int;
    if (cursor <= (state['cursor'] as int? ?? 0)) return;
    final data = secretMap(event['payload']);
    final kind = event['kind'];
    final updates = <String, SecretJson>{};
    if (kind == 'control') {
      if (event['sender_id'] != userId) await _receiveControl(state, data);
    } else if (kind == 'read') {
      if (data['user_id'] != userId) {
        for (final row in journal.messages(key)) {
          if (secretMap(row['message'])['sender_id'] != userId) continue;
          row['message'] = {...secretMap(row['message']), 'is_read': true};
          updates[row['local_id'] as String] = row;
        }
      }
    } else if (kind == 'reaction') {
      final row = journal
          .messages(key)
          .where((r) => secretMap(r['message'])['id'] == data['message_id'])
          .firstOrNull;
      if (row != null) {
        row['message'] = {
          ...secretMap(row['message']),
          'reactions': data['reactions'],
        };
        updates[row['local_id'] as String] = row;
      }
    } else {
      await _receiveMessage(key, state, data, updates, eventId: cursor);
    }
    state['cursor'] = cursor;
    await _commit(key, state, messages: updates);
  }

  Future<void> _receiveControl(SecretJson state, SecretJson control) async {
    if (control['from_key'] != state['peer_key'] ||
        control['to_key'] != publicKey ||
        control['chat_id'] != state['remote_id'] ||
        control['v'] != 2) {
      return;
    }
    bool valid;
    try {
      valid = await _ed.verify(
        _controlBytes(control),
        signature: Signature(
          base64Decode(control['sig'] as String),
          publicKey: SimplePublicKey(
            base64Decode(control['ed'] as String),
            type: KeyPairType.ed25519,
          ),
        ),
      );
    } catch (_) {
      valid = false;
    }
    if (!valid) {
      state['status'] = 'invalidSignature';
      return;
    }
    if (state['status'] == 'keyChanged' ||
        state['status'] == 'invalidSignature') {
      return;
    }
    if (state['pinned_ed'] != null && state['pinned_ed'] != control['ed']) {
      state['status'] = 'keyChanged';
      state['candidate_control'] = control;
      return;
    }
    state['pinned_ed'] = control['ed'];
    final kind = control['kind'];
    if (kind == 'reset') {
      // Replayed controls are excluded by the persisted event cursor.
      _archiveSession(state);
      state['ratchet'] = null;
      state['status'] = 'connecting';
      state['controls'] = <String, dynamic>{};
      state['reset_requested'] = true;
      return;
    }
    if (kind == 'ack') {
      if (state['session_id'] == control['session_id'] &&
          state['ratchet'] != null) {
        final session = await DoubleRatchetSession.fromJson(
          secretMap(state['ratchet']),
        );
        session.peerStaticEd = control['ed'] as String;
        state['ratchet'] = await session.toJson();
        state['status'] = 'secured';
      }
      return;
    }
    if (kind != 'init' ||
        (control['from_key'] as String).compareTo(publicKey) <= 0) {
      return;
    }
    if (state['session_id'] == control['session_id'] &&
        state['ratchet'] != null) {
      return;
    }
    _archiveSession(state);
    final session = await _dr.respondSession(
      ourStaticSeed: staticSeed,
      theirStaticPublic: SimplePublicKey(
        base64Decode(state['peer_key'] as String),
        type: KeyPairType.x25519,
      ),
      theirEphemeralPublic: SimplePublicKey(
        base64Decode(control['dh'] as String),
        type: KeyPairType.x25519,
      ),
      peerStaticEdB64: control['ed'] as String,
    );
    state['session_id'] = control['session_id'];
    state['ratchet'] = await session.toJson();
    state['status'] = 'secured';
    state['reset_requested'] = true;
    final pair = await _dh.newKeyPairFromSeed(session.dhsSeed!);
    final ack = await _control(
      state,
      'ack',
      control['session_id'] as String,
      base64Encode((await pair.extractPublicKey()).bytes),
    );
    state['controls'] = {...secretMap(state['controls']), _uuid.v4(): ack};
  }

  void _archiveSession(SecretJson state) {
    if (state['ratchet'] != null && state['session_id'] != null) {
      state['previous_sessions'] = {
        ...secretMap(state['previous_sessions']),
        state['session_id'] as String: state['ratchet'],
      };
    }
  }

  Future<void> acceptChangedIdentity(int uiId) async {
    final key = findChat(uiId)!;
    await _serial.run(key, () async {
      final state = journal.state(key);
      state.remove('pinned_ed');
      state.remove('verified');
      _archiveSession(state);
      state['ratchet'] = null;
      state['controls'] = <String, dynamic>{};
      state['status'] = 'connecting';
      state['reset_requested'] = false;
      if (state['candidate_key'] != null) {
        state['peer_key'] = state.remove('candidate_key');
      }
      final control = secretMap(state.remove('candidate_control'));
      if (control.isNotEmpty) await _receiveControl(state, control);
      await _commit(key, state);
    });
    wake();
  }

  Future<void> verifyIdentity(int uiId) async {
    final key = findChat(uiId)!;
    await _serial.run(key, () async {
      final state = journal.state(key);
      if (state['status'] != 'secured') return;
      state['verified'] = true;
      await _commit(key, state);
    });
  }

  Future<void> markReadLocally(int uiId) async {
    final key = findChat(uiId);
    if (key == null || _stopped) return;
    await _serial.run(key, () async {
      final updates = <String, SecretJson>{};
      for (final row in journal.messages(key)) {
        final message = secretMap(row['message']);
        if (message['sender_id'] == userId || message['is_read'] == true) {
          continue;
        }
        row['message'] = {...message, 'is_read': true};
        updates[row['local_id'] as String] = row;
      }
      if (updates.isNotEmpty) {
        await _commit(key, journal.state(key), messages: updates);
      }
    });
  }

  Future<void> _receiveMessage(
    String key,
    SecretJson state,
    SecretJson message,
    Map<String, SecretJson> updates, {
    int? eventId,
  }) async {
    final clientId = message['client_message_id'];
    final existing = journal
        .messages(key)
        .where(
          (row) =>
              (clientId != null && row['local_id'] == clientId) ||
              secretMap(row['message'])['id'] == message['id'],
        )
        .firstOrNull;
    if (message['is_deleted'] == true) {
      final discarded = message['discard_e2ee_content'];
      if (discarded is String && message['sender_id'] != userId) {
        final disposable = <String, SecretJson>{};
        await _receiveMessage(key, state, {
          ...message,
          'is_deleted': false,
          'e2ee_content': discarded,
        }, disposable);
      }
      if (existing != null) {
        existing['message'] = {
          ...secretMap(existing['message']),
          'is_deleted': true,
          'content': '',
          'e2ee_content': null,
          'media_url': null,
          'e2ee_file_key': null,
        };
        existing['body'] = <String, dynamic>{};
        existing['operations'] = <dynamic>[];
        existing.remove('pending_message');
        updates[existing['local_id'] as String] = existing;
      }
      return;
    }
    final id =
        existing?['local_id'] as String? ??
        clientId as String? ??
        'remote:${message['id']}';
    if (clientId == null && message['is_e2ee'] != true) {
      updates[id] = {
        'local_id': id,
        'message': message,
        'body': _bodyFromMessage(message),
        'operations': <dynamic>[],
      };
      return;
    }
    if (message['sender_id'] == userId) {
      if (existing == null) {
        updates[id] = {
          'local_id': id,
          'message': message,
          'body': <String, dynamic>{},
          'operations': <dynamic>[],
          'unavailable': true,
        };
      } else {
        // Never decrypt our own echo or replace our locally authored body.
        final oldMessage = secretMap(existing['message']);
        existing['message'] = {
          ...oldMessage,
          ...message,
          if (oldMessage['is_read'] == true) 'is_read': true,
          if (oldMessage['is_deleted'] == true) 'is_deleted': true,
        };
        final opId = message['client_operation_id'] ?? clientId;
        existing['operations'] = (existing['operations'] as List? ?? [])
            .where((op) => secretMap(op)['id'] != opId)
            .toList();
        updates[id] = existing;
      }
      return;
    }
    if (existing != null &&
        existing['unavailable'] != true &&
        secretMap(existing['message'])['e2ee_content'] ==
            message['e2ee_content']) {
      existing['message'] = {...secretMap(existing['message']), ...message};
      updates[id] = existing;
      return;
    }
    final row = existing ?? {'local_id': id, 'operations': <dynamic>[]};
    try {
      final packet = secretMap(
        jsonDecode(
          utf8.decode(base64Decode(message['e2ee_content'] as String)),
        ),
      );
      if (packet['session_id'] == null) {
        final String text;
        if (packet['v'] == 2) {
          final legacy = await DoubleRatchetSession.fromJson(
            secretMap(state['legacy_ratchet']),
          );
          final plain = await _dr.decrypt(
            session: legacy,
            headerB64: base64Encode(utf8.encode(jsonEncode(packet['h']))),
            ciphertext: base64Decode(packet['c'] as String),
          );
          if (plain == null) throw StateError('Legacy authentication failed');
          text = plain;
          state['legacy_ratchet'] = await legacy.toJson();
        } else {
          final shared = await _dh.sharedSecretKey(
            keyPair: await _dh.newKeyPairFromSeed(staticSeed),
            remotePublicKey: SimplePublicKey(
              base64Decode(state['peer_key'] as String),
              type: KeyPairType.x25519,
            ),
          );
          text = utf8.decode(
            await AesGcm.with256bits().decrypt(
              SecretBox(
                base64Decode(packet['ciphertext'] as String),
                nonce: base64Decode(packet['iv'] as String),
                mac: Mac(base64Decode(packet['tag'] as String)),
              ),
              secretKey: shared,
            ),
          );
        }
        SecretJson envelope = {};
        try {
          envelope = secretMap(jsonDecode(text));
        } catch (_) {}
        final fileKey = envelope['fk'] ?? envelope['keyB64'];
        row['body'] = fileKey == null
            ? {'text': text, 'type': message['msg_type'] ?? 'text'}
            : {
                'text': envelope['text'] ?? envelope['caption'] ?? '',
                'type': message['msg_type'],
                'file': {
                  'key': fileKey,
                  'name': envelope['name'],
                  'size': envelope['size'],
                  'mime': message['media_type'],
                },
              };
        row['message'] = message;
        row.remove('unavailable');
        row.remove('pending_message');
        updates[id] = row;
        return;
      }
      final sid = packet['session_id'];
      final current = sid == state['session_id'];
      final previous = secretMap(state['previous_sessions']);
      final rawSession = current ? state['ratchet'] : previous[sid];
      if (rawSession == null ||
          state['status'] == 'keyChanged' ||
          state['status'] == 'invalidSignature') {
        throw StateError('Session unavailable');
      }
      final session = await DoubleRatchetSession.fromJson(
        secretMap(rawSession),
      );
      final text = await _dr.decrypt(
        session: session,
        headerB64: base64Encode(utf8.encode(jsonEncode(packet['h']))),
        ciphertext: base64Decode(packet['c'] as String),
      );
      if (text == null) throw StateError('Message authentication failed');
      final body = secretMap(jsonDecode(text));
      if (current) {
        state['ratchet'] = await session.toJson();
      } else {
        previous[sid as String] = await session.toJson();
        state['previous_sessions'] = previous;
      }
      row['body'] = body;
      row['message'] = message;
      row.remove('unavailable');
      row.remove('pending_message');
    } catch (_) {
      // Preserve the last good revision; keep the failed ciphertext for recovery.
      row['pending_message'] = message;
      row['pending_event'] = eventId;
      if (row['body'] == null) {
        row['unavailable'] = true;
        row['message'] = message;
        row['body'] = <String, dynamic>{};
      }
    }
    updates[id] = row;
  }

  Future<void> _retryInbox(String key) async {
    for (final row
        in journal
            .messages(key)
            .where((row) => row['pending_message'] != null)) {
      await _serial.run(key, () async {
        final state = journal.state(key);
        final updates = <String, SecretJson>{};
        await _receiveMessage(
          key,
          state,
          secretMap(row['pending_message']),
          updates,
        );
        await _commit(key, state, messages: updates);
      });
    }
  }

  Future<bool> _sendNext(String key) async {
    var state = journal.state(key);
    if (state['status'] != 'secured' ||
        state['peer_protocol'] != 2 ||
        secretMap(state['controls']).isNotEmpty) {
      return false;
    }
    final row = journal
        .messages(key)
        .where((row) => (row['operations'] as List? ?? []).isNotEmpty)
        .firstOrNull;
    if (row == null) return false;
    var op = secretMap((row['operations'] as List).first);
    if (op['failed'] == true) return false;
    final file = secretMap(secretMap(op['body'])['file']);
    if (file['attachment_id'] != null &&
        op['upload_id'] == null &&
        op['action'] == 'send_message') {
      final uploadId = await transport.upload(
        file['attachment_id'] as String,
        file,
      );
      await _serial.run(key, () async {
        final latest = journal
            .messages(key)
            .where((r) => r['local_id'] == row['local_id'])
            .firstOrNull;
        if (latest == null) return;
        final ops = latest['operations'] as List;
        if (secretMap(ops.first)['id'] != op['id']) return;
        ops[0] = {...secretMap(ops.first), 'upload_id': uploadId};
        await _commit(
          key,
          journal.state(key),
          messages: {latest['local_id'] as String: latest},
        );
      });
    }
    SecretJson? prepared;
    await _serial.run(key, () async {
      state = journal.state(key);
      if (state['status'] != 'secured') return;
      final latest = journal
          .messages(key)
          .where((r) => r['local_id'] == row['local_id'])
          .firstOrNull;
      if (latest == null || (latest['operations'] as List).isEmpty) return;
      final ops = latest['operations'] as List;
      op = secretMap(ops.first);
      if (op['packet'] == null) {
        final message = secretMap(latest['message']);
        final action = op['action'];
        if (action != 'send_message' && (message['id'] as int) < 0) return;
        final payload = <String, dynamic>{
          'chat_id': state['remote_id'],
          if (action == 'send_message')
            'client_message_id': op['id']
          else ...{
            'client_operation_id': op['id'],
            'message_id': message['id'],
          },
        };
        if (action != 'delete_message') {
          final body = secretCopy(secretMap(op['body']));
          secretMap(body['file']).remove('attachment_id');
          if (body['file'] is Map) {
            (body['file'] as Map).remove('attachment_id');
          }
          final session = await DoubleRatchetSession.fromJson(
            secretMap(state['ratchet']),
          );
          final encrypted = await _dr.encrypt(
            session: session,
            plaintext: jsonEncode(body),
            messageType: 'txt',
          );
          payload['e2ee_content'] = base64Encode(
            utf8.encode(
              jsonEncode({
                'v': 2,
                'session_id': state['session_id'],
                'h': jsonDecode(utf8.decode(base64Decode(encrypted.headerB64))),
                'c': base64Encode(encrypted.ciphertext),
              }),
            ),
          );
          state['ratchet'] = await session.toJson();
          if (action == 'send_message') {
            if (op['upload_id'] != null) payload['upload_id'] = op['upload_id'];
            var reply = message['reply_to_id'];
            if (reply is int && reply < 0) {
              final original = journal
                  .messages(key)
                  .where((r) => r['local_numeric_id'] == reply)
                  .firstOrNull;
              reply = secretMap(original?['message'])['id'];
              if (reply is! int || reply < 0) return;
              message['reply_to_id'] = reply;
              latest['message'] = message;
            }
            if (reply is int && reply > 0) payload['reply_to_id'] = reply;
          }
        }
        op['packet'] = payload;
        ops[0] = op;
        await _commit(
          key,
          state,
          messages: {latest['local_id'] as String: latest},
        );
      }
      prepared = secretCopy(op);
    });
    if (prepared == null || _stopped) return false;
    final result = await transport.request(
      prepared!['action'] as String,
      secretMap(prepared!['packet']),
    );
    if (_stopped) return false;
    await _serial.run(key, () async {
      final current = journal.state(key);
      final updates = <String, SecretJson>{};
      await _receiveMessage(key, current, {
        ...result,
        'sender_id': userId,
        'client_operation_id': prepared!['id'],
      }, updates);
      await _commit(key, current, messages: updates);
    });
    return true;
  }

  Future<void> stop({bool erase = false}) async {
    _stopped = true;
    await _serial.drain();
    await journal.close(erase: erase);
    await _changes.close();
  }
}
