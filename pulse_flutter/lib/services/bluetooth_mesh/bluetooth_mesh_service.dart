import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart' as hashing;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import '../ordinary_e2ee/ordinary_e2ee_service.dart';
import 'ble_transport.dart';
import 'mesh_packet.dart';
import 'mesh_preferences.dart';
import 'mesh_router.dart';

class MeshMessage {
  MeshMessage(
    this.packet,
    this.operationId,
    this.chatId,
    this.senderId,
    this.text,
    this.sentAt,
    this.reply,
  );
  final MeshPacket packet;
  final String operationId, text;
  final int chatId, senderId;
  final DateTime sentAt;
  final int? reply;
  bool acknowledged = false;
  int? cloudId;
  int get localId =>
      -int.parse(
        hashing.sha256
            .convert(utf8.encode(operationId))
            .toString()
            .substring(0, 13),
        radix: 16,
      ) -
      1;
  ApiMessage asApi({required int ownId, required String senderName}) =>
      ApiMessage.fromJson({
        'id': cloudId ?? localId,
        'chat_id': chatId,
        'sender_id': senderId,
        'sender_username': senderName,
        'sender_display_name': senderName,
        'content': text,
        'msg_type': 'text',
        'reply_to_id': reply,
        'sent_at': sentAt.toIso8601String(),
        'is_e2ee': true,
        'is_decrypted': true,
        'e2ee_content': packet.envelope,
        'client_message_id': 'mesh:$operationId',
        'is_sending':
            senderId == ownId &&
            !acknowledged &&
            cloudId == null &&
            packet.expiresAt.isAfter(DateTime.now()),
        'is_failed':
            senderId == ownId &&
            !acknowledged &&
            cloudId == null &&
            !packet.expiresAt.isAfter(DateTime.now()),
      });
}

class BluetoothMeshService extends ChangeNotifier {
  BluetoothMeshService({
    required this.userId,
    required this.scope,
    required this.ordinary,
    required this.transport,
    required this.chat,
    required this.cloudSubmit,
    required this.enabled,
    required this.online,
  });
  final int userId;
  final String Function() scope;
  final OrdinaryE2eeService ordinary;
  final BleTransport transport;
  final ApiChatSummary? Function(int id) chat;
  final Future<ApiMessage> Function(MeshPacket packet) cloudSubmit;
  final bool Function() enabled, online;
  final _messages = <String, MeshMessage>{};
  final _receipts = <String, Set<int>>{};
  final _ackSent = <String>{};
  final _peers = <String>{};
  final _cloudDone = <String>{};
  final _hidden = <String>{};
  final _outbox = <String, MeshPacket>{};
  final _decoded = <String, Map<String, dynamic>>{};
  final _changes = StreamController<int>.broadcast();
  Stream<int> get changes => _changes.stream;
  List<MeshMessage> messages(int chatId) => _messages.values
      .where((m) => m.chatId == chatId && !_hidden.contains(m.operationId))
      .toList();
  MeshRouter? _router;
  Box<String>? _box;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _timer;
  Future<void>? _starting, _flushing, _warming;
  Future<void> _sending = Future.value();
  final _warmQueue = <int>{};
  final _expiredNotified = <String>{};
  bool _loaded = false;
  String state = 'stopped';
  bool _closed = false;
  bool get active => state == 'active';
  int get peerCount => _peers.length;
  String get stateText => switch (state) {
    'active' =>
      peerCount == 0 ? 'Ищем устройства рядом' : 'Устройств рядом: $peerCount',
    'permission_required' => 'Нужно разрешение на доступ к Bluetooth',
    'bluetooth_off' => 'Bluetooth выключен на устройстве',
    'unsupported' => 'Этот Bluetooth-адаптер не поддерживает передачу',
    'unsupported_peripheral' =>
      'Адаптер поддерживает только поиск соседних устройств',
    'starting' => 'Подключаем Bluetooth',
    'stopped' => 'Передача по Bluetooth отключена',
    _ => 'Bluetooth временно недоступен',
  };
  void _notify() {
    if (!_closed) notifyListeners();
  }

  void _changed(int chatId) {
    if (!_closed) {
      _changes.add(chatId);
      _notify();
    }
  }

  Future<void> start({bool requestPermission = false}) => _starting ??= _start(
    requestPermission,
  ).whenComplete(() => _starting = null);
  Future<void> _start(bool requestPermission) async {
    if (_closed || !enabled()) return;
    state = 'starting';
    _notify();
    try {
      if (!ordinary.initialised) await ordinary.open();
      if (online()) {
        try {
          await ordinary.prepareMesh();
        } catch (_) {}
      }
      await HiveBootstrap.ensureInitialized();
      if (_closed) return;
      _box ??= await Hive.openBox<String>('bluetooth_mesh_ciphertext_v1');
      if (_closed) return;
      _router ??= MeshRouter(
        send: (peer, frame) =>
            transport.send(peer, Uint8List.fromList(utf8.encode(frame))),
        persist: (value) async {
          if (!_closed) await _box!.put(scope(), value);
        },
        deliver: _deliver,
      );
      if (!_loaded) {
        await _router!.restore(_box!.get(scope()));
        final pending = _box!.get('${scope()}.outbox');
        if (pending != null && pending.length < 8 * 1024 * 1024) {
          final values = jsonDecode(pending);
          if (values is List && values.length <= 256) {
            for (final wire in values.whereType<String>()) {
              try {
                final packet = await MeshPacket.parse(wire, forBackfill: true);
                final age =
                    DateTime.now().millisecondsSinceEpoch -
                    (jsonDecode(packet.body)['created'] as int);
                if (age <= const Duration(days: 30).inMilliseconds) {
                  _outbox[packet.id] = packet;
                }
              } catch (_) {}
            }
          }
        }
        final hidden = _box!.get('${scope()}.hidden');
        if (hidden != null) {
          _hidden.addAll(
            (jsonDecode(hidden) as List).whereType<String>().take(4096),
          );
        }
        final savedCloud = _box!.get('${scope()}.cloud');
        if (savedCloud != null) {
          final ids = jsonDecode(savedCloud);
          if (ids is List && ids.length <= MeshRouter.maxPackets) {
            _cloudDone.addAll(ids.whereType<String>());
          }
        }
        while (_box!.length > 16) {
          final key = _box!.keys.firstWhere(
            (key) =>
                key != scope() &&
                key != '${scope()}.cloud' &&
                key != '${scope()}.hidden' &&
                key != '${scope()}.outbox',
          );
          await _box!.delete(key);
        }
        _loaded = true;
      }
      if (_closed) return;
      _subscription ??= transport.events.listen(
        _event,
        onError: (Object _) {
          if (!_closed) {
            state = 'unavailable';
            _notify();
          }
        },
      );
      final status = await transport.start(
        requestPermission: requestPermission,
      );
      if (_closed) {
        await transport.stop();
        return;
      }
      state = status['state'] as String? ?? 'unavailable';
      _notify();
      await _router!.replayLocal();
      _timer ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (_closed) return;
        for (final peer in _peers.toList()) {
          unawaited(_router!.connected(peer).catchError((Object _) {}));
        }
        if (!active &&
            state != 'unsupported' &&
            state != 'unsupported_peripheral') {
          unawaited(start().catchError((Object _) {}));
        }
        unawaited(replay());
        for (final m in _messages.values) {
          if (!m.acknowledged &&
              m.cloudId == null &&
              !m.packet.expiresAt.isAfter(DateTime.now()) &&
              _expiredNotified.add(m.operationId)) {
            _changed(m.chatId);
          }
        }
        while (_expiredNotified.length > 512) {
          _expiredNotified.remove(_expiredNotified.first);
        }

        unawaited(flushCloud());
      });
      await flushCloud();
    } catch (_) {
      if (!_closed) {
        state = 'unavailable';
        _notify();
      }
      rethrow;
    }
  }

  void _event(Map<String, dynamic> event) {
    if (_closed || !enabled()) return;
    if (event['type'] == 'status') {
      state = event['state'] as String? ?? 'unavailable';
      _notify();
    } else if (event['type'] == 'peer' && event['peer'] is String) {
      final peer = event['peer'] as String;
      if (event['connected'] == true) {
        _peers.add(peer);
        unawaited(_router!.connected(peer).catchError((Object _) {}));
      } else {
        _peers.remove(peer);
        _router?.disconnected(peer);
      }
      _notify();
    } else if (event['type'] == 'frame' &&
        event['peer'] is String &&
        event['data'] is Uint8List) {
      final bytes = event['data'] as Uint8List;
      if (bytes.length > MeshPacket.maxBytes + 1024) return;
      try {
        final text = utf8.decode(bytes);
        unawaited(
          _router!
              .receive(event['peer'] as String, text)
              .catchError((Object _) {}),
        );
      } catch (_) {
        /* Invalid radio input is never logged or interpreted as text. */
      }
    }
  }

  Future<MeshMessage> sendText(int chatId, String text, {int? reply}) {
    final task = _sending.then((_) => _sendText(chatId, text, reply: reply));
    _sending = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  Future<MeshMessage> _sendText(int chatId, String text, {int? reply}) async {
    if (_closed || !enabled()) throw StateError('Bluetooth-доставка отключена');
    final summary = chat(chatId);
    if (summary == null ||
        summary.isSecret ||
        summary.chatType != 'direct' ||
        summary.isBlocked) {
      throw StateError('Bluetooth доступен для обычных личных чатов');
    }
    if (!active) await start(requestPermission: true);
    if (!active && state != 'unsupported_peripheral') {
      throw StateError(stateText);
    }
    if (_outbox.length >= 256) {
      throw StateError(
        'Очередь синхронизации заполнена. Подключитесь к интернету перед новой отправкой',
      );
    }
    final packet = await ordinary.createMeshPacket(
      chatId,
      text,
      reply: reply,
      extra: {
        'mesh': {'kind': 'message'},
      },
    );
    if (_closed || !enabled()) throw StateError('Bluetooth-доставка отключена');
    await _router!.enqueue(packet);
    final decoded = await ordinary.openMeshPacket(packet);
    final result = _messages[decoded['operation_id']];
    if (result == null) throw StateError('Не удалось сохранить сообщение');
    return result;
  }

  Future<void> _deliver(MeshPacket packet) async {
    if (_closed || !enabled()) return;
    Map<String, dynamic> decoded;
    try {
      decoded = _decoded[packet.id] ?? await ordinary.openMeshPacket(packet);
    } catch (_) {
      return;
    }
    if (_closed) return;
    final chatId = decoded['chat_id'] as int,
        sender = decoded['sender_id'] as int;
    final summary = chat(chatId);
    if (summary == null ||
        summary.isSecret ||
        summary.isBlocked ||
        summary.chatType != 'direct') {
      return;
    }
    final body = decoded['body'] as Map<String, dynamic>,
        metadata = body['mesh'];
    if (metadata is! Map || metadata['kind'] != packet.purpose) return;
    _decoded[packet.id] = decoded;
    while (_decoded.length > 256) {
      _decoded.remove(_decoded.keys.first);
    }
    if (packet.purpose == 'message' &&
        !_cloudDone.contains(packet.id) &&
        !_outbox.containsKey(packet.id)) {
      if (_outbox.length >= 256) {
        return;
      }
      _outbox[packet.id] = packet;
      await _saveOutbox();
    }

    if (metadata['kind'] == 'receipt') {
      final id = metadata['id'];
      if (id is! String || id.length > 64) return;
      _receipts.putIfAbsent('$chatId:$id', () => {}).add(sender);
      final message = _messages[id];
      if (message != null &&
          message.chatId == chatId &&
          message.senderId == userId &&
          !message.acknowledged &&
          sender == summary.partnerUserId) {
        message.acknowledged = true;
        _changed(chatId);
      }
      return;
    }
    if (metadata['kind'] != 'message') return;
    final id = decoded['operation_id'] as String;
    if (_hidden.contains(id)) return;
    while (_messages.length >= 256 && !_messages.containsKey(id)) {
      _messages.remove(_messages.keys.first);
    }
    while (_receipts.length > 512) {
      _receipts.remove(_receipts.keys.first);
    }
    while (_ackSent.length > 512) {
      _ackSent.remove(_ackSent.first);
    }
    if (!_messages.containsKey(id)) {
      final signed = jsonDecode(packet.body) as Map<String, dynamic>;
      final message = MeshMessage(
        packet,
        id,
        chatId,
        sender,
        body['text'] as String,
        DateTime.fromMillisecondsSinceEpoch(
          signed['created'] as int,
          isUtc: true,
        ),
        decoded['reply'] as int?,
      );
      message.acknowledged =
          _receipts['$chatId:$id']?.contains(summary.partnerUserId) == true;
      _messages[id] = message;
      _changed(chatId);
    }
    // Enqueue after the router finishes its current transaction; no recursive lock.
    if (sender != userId && _ackSent.add(id)) {
      scheduleMicrotask(() async {
        try {
          if (_closed || !enabled()) return;
          final receipt = await ordinary.createMeshPacket(
            chatId,
            '',
            extra: {
              'mesh': {'kind': 'receipt', 'id': id},
            },
          );
          if (!_closed && enabled()) await _router!.enqueue(receipt);
        } catch (_) {
          _ackSent.remove(id);
        }
      });
    }
  }

  Future<void> flushCloud() =>
      _flushing ??= _flushCloud().whenComplete(() => _flushing = null);
  Future<void> _flushCloud() async {
    if (_closed || !online() || !enabled() || _router == null) return;
    // Backend verifies the original signature and membership, including relays.
    final pending = <String, MeshPacket>{
      for (final p in _router!.packets) p.id: p,
      ..._outbox,
    };
    for (final packet in pending.values) {
      if (_closed || !online()) return;
      if (packet.purpose != 'message' || _cloudDone.contains(packet.id)) {
        continue;
      }
      try {
        final result = await cloudSubmit(packet);
        if (_closed) return;
        _outbox.remove(packet.id);
        await _saveOutbox();
        _cloudDone.add(packet.id);
        _cloudDone.removeWhere(
          (id) => !_router!.packets.any((p) => p.id == id),
        );
        await _box!.put('${scope()}.cloud', jsonEncode(_cloudDone.toList()));
        final id = decodedOperation(packet);
        final local = _messages[id];
        if (local != null) {
          local.cloudId = result.id;
          local.acknowledged = true;
          _changed(local.chatId);
        }
      } catch (_) {
        /* Keep the bounded encrypted outbox for an authenticated retry. */
      }
    }
  }

  static String decodedOperation(MeshPacket packet) {
    // This is public routing metadata, not decryption.
    final wrapper =
        jsonDecode(utf8.decode(base64Decode(packet.envelope)))
            as Map<String, dynamic>;
    final header =
        jsonDecode(wrapper['body'] as String) as Map<String, dynamic>;
    return header['id'] as String;
  }

  Future<void> _saveOutbox() async {
    await _box?.put(
      '${scope()}.outbox',
      jsonEncode(_outbox.values.map((p) => p.wire).toList()),
    );
  }

  void warmChats(Iterable<ApiChatSummary> chats) {
    if (_closed || !online() || !enabled()) return;
    for (final c in chats) {
      if (c.chatType == 'direct' &&
          !c.isSecret &&
          !c.isBotChat &&
          !c.isBlocked &&
          _warmQueue.length < 2048) {
        _warmQueue.add(c.id);
      }
    }
    _warming ??= _warm().whenComplete(() => _warming = null);
  }

  Future<void> _warm() async {
    while (!_closed && enabled() && online() && _warmQueue.isNotEmpty) {
      final id = _warmQueue.first;
      _warmQueue.remove(id);
      try {
        await ordinary.warmMeshChat(id);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (!_closed) await replay();
  }

  Future<void> replay() async {
    if (!_closed && enabled()) {
      try {
        await _router?.replayLocal();
        for (final p in _outbox.values.toList()) {
          await _deliver(p);
        }
      } catch (_) {}
    }
  }

  Future<void> hide(int localId) async {
    final message = _messages.values
        .where((m) => m.localId == localId || m.cloudId == localId)
        .firstOrNull;
    if (message == null) return;
    _hidden.add(message.operationId);
    while (_hidden.length > 4096) {
      _hidden.remove(_hidden.first);
    }
    await _box?.put('${scope()}.hidden', jsonEncode(_hidden.toList()));
    _changed(message.chatId);
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _peers.clear();
    await transport.stop();
    if (!_closed) {
      state = 'stopped';
      _notify();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    _router?.close();
    _messages.clear();
    _decoded.clear();
    _outbox.clear();
    _receipts.clear();
    _warmQueue.clear();
    unawaited(_subscription?.cancel());
    unawaited(transport.stop());
    unawaited(_changes.close());
    super.dispose();
  }
}

final bluetoothMeshProvider = Provider<BluetoothMeshService?>((ref) {
  final account = ref.watch(
    authProvider.select((s) => (s.session?.userId, s.session?.accessToken)),
  );
  if (account.$1 == null || !meshPlatformSupported) return null;
  final ordinary = ref.read(ordinaryE2eeProvider);
  if (ordinary == null) return null;
  final ws = ref.read(webSocketClientProvider);
  final service = BluetoothMeshService(
    userId: account.$1!,
    scope: () => ordinary.meshStorageScope,
    ordinary: ordinary,
    transport: NativeBleTransport(),
    chat: (id) => ref.read(chatByIdProvider(id)),
    enabled: () => ref.read(meshPreferenceProvider),
    online: () => ws.isConnected,
    cloudSubmit: (packet) async {
      final data = await ws.request(
        'ordinary_e2ee',
        payload: {'op': 'mesh_submit', 'wire': packet.wire},
        maxRetries: 0,
      );
      return ApiMessage.fromJson(Map<String, dynamic>.from(data as Map));
    },
  );
  void keysChanged() {
    if (!ordinary.locked && ordinary.initialised && ref.mounted) {
      service.warmChats(ref.read(chatsProvider).value ?? const []);
      unawaited(service.start().catchError((Object _) {}));
    }
  }

  ordinary.addListener(keysChanged);
  ref.onDispose(() => ordinary.removeListener(keysChanged));
  ref.listen(meshPreferenceProvider, (_, enabled) {
    if (enabled) {
      unawaited(service.start().catchError((Object _) {}));
    } else {
      unawaited(service.stop());
    }
  });
  final connected = ws.onConnected.listen(
    (_) => unawaited(service.start().catchError((Object _) {})),
  );
  ref.onDispose(() {
    unawaited(connected.cancel());
    service.dispose();
  });
  if (ref.read(meshPreferenceProvider)) {
    unawaited(service.start().catchError((Object _) {}));
  }
  return service;
});
