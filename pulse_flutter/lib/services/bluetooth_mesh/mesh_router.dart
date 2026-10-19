import 'dart:async';
import 'dart:convert';
import 'mesh_packet.dart';

typedef MeshSend = Future<void> Function(String peer, String frame);

/// Bounded store-and-forward. No account keys, authentication tokens or text.
class MeshRouter {
  MeshRouter({
    required this.send,
    required this.persist,
    required this.deliver,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  static const maxPackets = 128, maxStoredBytes = 2 * 1024 * 1024;
  static const maxSeen = 4096, peerBytesPerMinute = 256 * 1024;
  final MeshSend send;
  final Future<void> Function(String state) persist;
  final Future<void> Function(MeshPacket packet) deliver;
  final DateTime Function() now;
  final _packets = <String, MeshPacket>{};
  final _seen = <String, int>{};
  final _peers = <String, _PeerBudget>{};
  Future<void> _serial = Future.value();
  bool _closed = false;
  int _page = 0;
  List<MeshPacket> get packets => List.unmodifiable(_packets.values);

  Future<T> _run<T>(Future<T> Function() operation) {
    final result = _serial.then((_) {
      if (_closed) throw StateError('Mesh closed');
      return operation();
    });
    _serial = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void close() {
    _closed = true;
    _peers.clear();
  }

  void disconnected(String peer) => _peers.remove(peer);

  void _trim() {
    final time = now();
    _packets.removeWhere((_, packet) => !packet.expiresAt.isAfter(time));
    _seen.removeWhere((_, expires) => expires <= time.millisecondsSinceEpoch);
    var bytes = _packets.values.fold<int>(
      0,
      (total, p) => total + p.byteLength,
    );
    while (_packets.length > maxPackets || bytes > maxStoredBytes) {
      bytes -= _packets.remove(_packets.keys.first)!.byteLength;
    }
    while (_seen.length > maxSeen) {
      _seen.remove(_seen.keys.first);
    }
    _peers.removeWhere((_, b) => time.difference(b.window).inMinutes >= 5);
    while (_peers.length > 32) {
      _peers.remove(_peers.keys.first);
    }
  }

  Future<void> _save() async {
    _trim();
    await persist(
      jsonEncode({
        'v': 1,
        'packets': _packets.values.map((p) => p.wire).toList(),
        'seen': _seen,
      }),
    );
  }

  Future<void> restore(String? state) => _run(() async {
    if (state == null || state.length > maxStoredBytes * 2) return;
    final value = jsonDecode(state);
    if (value is! Map || value['v'] != 1) return;
    final values = value['packets'];
    if (values is! List || values.length > maxPackets) return;
    for (final wire in values) {
      try {
        if (wire is! String) continue;
        final packet = await MeshPacket.parse(wire, now: now());
        _packets[packet.id] = packet;
      } catch (_) {
        /* Corrupt/expired entries are never forwarded. */
      }
    }
    final seen = value['seen'];
    if (seen is Map && seen.length <= maxSeen) {
      for (final entry in seen.entries) {
        if (entry.key is String &&
            entry.value is int &&
            (entry.key as String).length == 43) {
          _seen[entry.key as String] = entry.value as int;
        }
      }
    }
    for (final packet in _packets.values) {
      _seen[packet.id] = packet.expiresAt.millisecondsSinceEpoch;
    }
    await _save();
  });
  Future<void> enqueue(MeshPacket packet) => _run(() async {
    if (!packet.expiresAt.isAfter(now())) {
      throw const FormatException('Expired');
    }
    _packets[packet.id] = packet;
    _seen[packet.id] = packet.expiresAt.millisecondsSinceEpoch;
    await _save();
    await deliver(packet);
    for (final peer in _peers.keys.toList()) {
      await _inventory(peer);
    }
  });
  Future<void> connected(String peer) => _run(() async {
    _trim();
    if (_peers.length >= 32 && !_peers.containsKey(peer)) return;
    _peers.putIfAbsent(peer, () => _PeerBudget(now()));
    await _inventory(peer);
  });
  Future<void> _send(String peer, Map<String, dynamic> message) async {
    if (_closed) return;
    final frame = jsonEncode(message), budget = _peers[peer];
    if (budget == null ||
        !budget.allow(utf8.encode(frame).length, now(), sending: true)) {
      return;
    }
    await send(peer, frame);
  }

  Future<void> _inventory(String peer) async {
    _trim();
    final eligible = _packets.values
        .where((p) => p.hops < MeshPacket.maxHops)
        .map((p) => p.id)
        .toList();
    if (eligible.isEmpty) {
      await _send(peer, {'v': 1, 'type': 'inventory', 'ids': <String>[]});
      return;
    }
    final offset = (_page++ * 64) % eligible.length;
    final ids = List.generate(
      eligible.length.clamp(0, 64),
      (i) => eligible[(offset + i) % eligible.length],
    );
    await _send(peer, {'v': 1, 'type': 'inventory', 'ids': ids});
  }

  Future<void> receive(String peer, String frame) => _run(() async {
    if (utf8.encode(frame).length > MeshPacket.maxBytes + 1024) return;
    final budget = _peers[peer];
    if (budget == null || !budget.allow(utf8.encode(frame).length, now())) {
      return;
    }
    final value = jsonDecode(frame);
    if (value is! Map || value['v'] != 1) return;
    _trim();
    if (value['type'] == 'packet') {
      if (value['wire'] is! String) return;
      final packet = await MeshPacket.parse(
        value['wire'] as String,
        now: now(),
      );
      if (_seen.containsKey(packet.id)) return;
      _seen[packet.id] = packet.expiresAt.millisecondsSinceEpoch;
      _packets[packet.id] = packet;
      await _save();
      await deliver(packet);
      for (final other in _peers.keys.toList()) {
        if (other != peer) await _inventory(other);
      }
      return;
    }
    final ids = value['ids'];
    if (ids is! List ||
        ids.length > 64 ||
        ids.any((id) => id is! String || id.length != 43)) {
      return;
    }
    if (value['type'] == 'inventory') {
      final wanted = ids
          .cast<String>()
          .where((id) => !_seen.containsKey(id))
          .take(8)
          .toList();
      if (wanted.isNotEmpty) {
        await _send(peer, {'v': 1, 'type': 'want', 'ids': wanted});
      }
    } else if (value['type'] == 'want' && ids.length <= 8) {
      for (final id in ids) {
        final packet = _packets[id];
        if (packet != null && packet.hops < MeshPacket.maxHops) {
          await _send(peer, {
            'v': 1,
            'type': 'packet',
            'wire': packet.forwarded().wire,
          });
        }
      }
    }
  });
  Future<void> replayLocal() => _run(() async {
    _trim();
    for (final packet in _packets.values.toList()) {
      await deliver(packet);
    }
  });
}

class _PeerBudget {
  _PeerBudget(this.window);
  DateTime window;
  int incoming = 0, outgoing = 0, frames = 0;
  bool allow(int bytes, DateTime now, {bool sending = false}) {
    if (now.difference(window).inMinutes >= 1) {
      window = now;
      incoming = 0;
      outgoing = 0;
      frames = 0;
    }
    if (bytes > MeshPacket.maxBytes + 1024 || bytes < 0) return false;
    if (sending) {
      outgoing += bytes;
      return outgoing <= MeshRouter.peerBytesPerMinute;
    }
    incoming += bytes;
    frames++;
    return incoming <= MeshRouter.peerBytesPerMinute && frames <= 256;
  }
}
