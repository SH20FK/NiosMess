import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:iroh_quic/iroh_quic.dart' as iroh;
import 'package:nios_sdk/link.dart';

/// A peer pin must be obtained from an authenticated identity/key exchange, not
/// from an unauthenticated discovery address. Addresses may change; the pin may
/// only be replaced after the application confirms an identity change.
final class IrohPeer {
  final String deviceId;
  final iroh.EndpointId endpointId;
  final iroh.EndpointAddr address;

  IrohPeer({
    required this.deviceId,
    required this.endpointId,
    required this.address,
  }) {
    if (deviceId.isEmpty || deviceId.length > 256 || address.id != endpointId) {
      throw ArgumentError('Invalid or mismatched Iroh peer pin');
    }
  }
}

/// Each request occupies one bounded bidirectional QUIC stream. The peer's QUIC
/// identity is pinned before envelope dispatch. Envelopes retain their own E2EE
/// authentication; a successful stream write is never a durable receipt.
final class IrohLinkTransport implements LinkTransport {
  static const String alpn = 'nios.link/1';
  static const int maximumFrameBytes = 2 * 1024 * 1024;

  final String deviceId;
  final Duration timeout;
  final int maximumConnections;
  final iroh.Endpoint _endpoint;
  final Future<EncryptedEnvelope> Function(EncryptedEnvelope) _onOperation;
  final Future<void> Function(EncryptedEnvelope) _onAcknowledgement;
  final Map<String, IrohPeer> _peers = {};
  final Set<iroh.Connection> _connections = {};
  final Set<Future<void>> _handlers = {};
  final _diagnostics = StreamController<String>.broadcast();
  late final Future<void> _accepting;
  bool _closed = false;
  int _dialing = 0;
  Future<void>? _closeFuture;

  IrohLinkTransport._({
    required this.deviceId,
    required this.timeout,
    required this.maximumConnections,
    required this._endpoint,
    required this._onOperation,
    required this._onAcknowledgement,
  }) {
    _accepting = _acceptLoop();
  }

  /// Relays are disabled unless explicit URLs are supplied. Custom address
  /// lookup replaces default DNS/pkarr discovery. No production relay is chosen
  /// implicitly. Public/private NAT traversal needs a deployment-owned relay.
  static Future<IrohLinkTransport> bind({
    required String deviceId,
    required iroh.SecretKey identity,
    required Future<EncryptedEnvelope> Function(EncryptedEnvelope) onOperation,
    required Future<void> Function(EncryptedEnvelope) onAcknowledgement,
    List<String> relayUrls = const [],
    Duration timeout = const Duration(seconds: 20),
    int maximumConnections = 16,
  }) async {
    if (deviceId.isEmpty ||
        deviceId.length > 256 ||
        timeout <= Duration.zero ||
        maximumConnections <= 0 ||
        maximumConnections > 128) {
      throw ArgumentError('Invalid Iroh transport bounds');
    }
    for (final relay in relayUrls) {
      final uri = Uri.parse(relay);
      if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
        throw ArgumentError('Custom Iroh relays require HTTPS');
      }
    }
    await iroh.Iroh.init();
    final endpoint = await iroh.Endpoint.bindWithAddressLookup(
      secretKey: identity,
      alpns: [utf8.encode(alpn)],
      relayMode: relayUrls.isEmpty
          ? iroh.RelayMode.disabled
          : iroh.RelayMode.custom(iroh.RelayMap.fromUrls(relayUrls)),
      resolve: (_) => null,
    );
    return IrohLinkTransport._(
      deviceId: deviceId,
      timeout: timeout,
      maximumConnections: maximumConnections,
      endpoint: endpoint,
      onOperation: onOperation,
      onAcknowledgement: onAcknowledgement,
    );
  }

  iroh.EndpointId get endpointId => _endpoint.id;
  iroh.EndpointAddr get address => _endpoint.addr;
  Stream<iroh.EndpointAddr> watchAddress() => _endpoint.watchAddr();
  Stream<String> get diagnostics => _diagnostics.stream;

  void setPeer(IrohPeer peer) {
    _checkOpen();
    final previous = _peers[peer.deviceId];
    if (previous != null && previous.endpointId != peer.endpointId) {
      throw const LinkTransportException(
        'peer_identity_changed',
        permanent: true,
      );
    }
    if (_peers.values.any(
      (existing) =>
          existing.deviceId != peer.deviceId &&
          existing.endpointId == peer.endpointId,
    )) {
      throw const LinkTransportException(
        'peer_identity_ambiguous',
        permanent: true,
      );
    }
    _peers[peer.deviceId] = peer;
  }

  /// A caller must independently confirm a key change before removing its pin.
  void removePeer(String peerDeviceId) {
    final previous = _peers.remove(peerDeviceId);
    if (previous == null) return;
    for (final connection in List<iroh.Connection>.of(_connections)) {
      if (connection.remoteId == previous.endpointId) {
        connection.close(errorCode: 3);
      }
    }
  }

  @override
  Future<TransportReceipt> deliver(EncryptedEnvelope envelope) async {
    _validateOutgoing(envelope, 'operation');
    final reply = await _exchange(envelope);
    final encoded = reply['acknowledgement'];
    if (reply['version'] != 1 || encoded is! Map<String, dynamic>) {
      throw const LinkTransportException(
        'invalid_direct_receipt',
        permanent: true,
      );
    }
    final acknowledgement = EncryptedEnvelope.fromJson(encoded);
    if (acknowledgement.context.kind != 'ack' ||
        acknowledgement.context.senderId != envelope.context.recipientId ||
        acknowledgement.context.recipientId != deviceId ||
        acknowledgement.context.sessionId != envelope.context.sessionId ||
        acknowledgement.context.operationId != envelope.context.operationId) {
      throw const LinkTransportException('invalid_direct_ack', permanent: true);
    }
    // DurableSession validates/decrypts the acknowledgement before advancing.
    return TransportReceipt(acknowledgement: acknowledgement);
  }

  @override
  Future<void> publishAcknowledgement(EncryptedEnvelope acknowledgement) async {
    _validateOutgoing(acknowledgement, 'ack');
    final reply = await _exchange(acknowledgement);
    if (reply['version'] != 1 || reply['received'] != acknowledgement.digest) {
      throw const LinkTransportException(
        'invalid_ack_receipt',
        permanent: true,
      );
    }
  }

  @override
  Future<List<EncryptedEnvelope>> poll(String deviceId) async {
    _checkOpen();
    if (deviceId != this.deviceId) throw StateError('Wrong direct device');
    return const [];
  }

  @override
  Future<void> confirmReceived(EncryptedEnvelope envelope) async {
    _checkOpen();
    if (envelope.context.recipientId != deviceId) {
      throw StateError('Wrong direct recipient');
    }
  }

  void _checkOpen() {
    if (_closed) throw const LinkTransportException('transport_closed');
  }

  void _validateOutgoing(EncryptedEnvelope envelope, String kind) {
    _checkOpen();
    if (envelope.context.senderId != deviceId ||
        envelope.context.kind != kind) {
      throw const LinkTransportException('invalid_sender', permanent: true);
    }
  }

  Future<Map<String, dynamic>> _exchange(EncryptedEnvelope envelope) async {
    final peer = _peers[envelope.context.recipientId];
    if (peer == null) throw const LinkTransportException('peer_not_pinned');
    if (_connections.length + _dialing >= maximumConnections) {
      throw const LinkTransportException('direct_capacity');
    }
    _dialing++;
    var reserved = true;
    iroh.Connection? connection;
    try {
      final connecting = _endpoint.connect(peer.address, utf8.encode(alpn));
      // Dart timeouts cannot cancel Rust's connect future. A late successful
      // connection is explicitly closed instead of leaking native resources.
      var expired = false;
      unawaited(
        connecting.then<void>((lateConnection) {
          if (expired || _closed) lateConnection.close(errorCode: 1);
        }, onError: (Object _, StackTrace _) {}),
      );
      try {
        connection = await connecting.timeout(timeout);
      } on TimeoutException {
        expired = true;
        rethrow;
      }
      _checkOpen();
      if (connection.remoteId != peer.endpointId) {
        throw const LinkTransportException(
          'peer_identity_mismatch',
          permanent: true,
        );
      }
      _connections.add(connection);
      _dialing--;
      reserved = false;
      final (send, receive) = await connection.openBi().timeout(timeout);
      await _writeFrame(send, {'version': 1, 'envelope': envelope.toJson()});
      return await _readFrame(receive).timeout(timeout);
    } on LinkTransportException {
      rethrow;
    } catch (_) {
      throw const LinkTransportException('direct_unavailable');
    } finally {
      if (reserved) _dialing--;
      if (connection != null) {
        _connections.remove(connection);
        connection.close();
      }
    }
  }

  Future<void> _acceptLoop() async {
    while (!_closed) {
      try {
        final connection = await _endpoint.accept();
        if (connection == null) break;
        if (_closed || _connections.length + _dialing >= maximumConnections) {
          connection.close(errorCode: 2);
          continue;
        }
        _connections.add(connection);
        final future = _serve(connection);
        _handlers.add(future);
        unawaited(future.then((_) => _handlers.remove(future)));
      } catch (_) {
        if (_closed) break;
        _diagnostics.add('accept_failed');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> _serve(iroh.Connection connection) async {
    try {
      final matching = _peers.values
          .where((peer) => peer.endpointId == connection.remoteId)
          .toList();
      if (matching.length != 1) {
        throw const LinkTransportException('untrusted_incoming_peer');
      }
      final peer = matching.single;
      final (send, receive) = await connection.acceptBi().timeout(timeout);
      final request = await _readFrame(receive).timeout(timeout);
      final encoded = request['envelope'];
      if (request['version'] != 1 || encoded is! Map<String, dynamic>) {
        throw const LinkTransportException('invalid_direct_request');
      }
      final envelope = EncryptedEnvelope.fromJson(encoded);
      if (envelope.context.senderId != peer.deviceId ||
          envelope.context.recipientId != deviceId ||
          _peers[peer.deviceId]?.endpointId != connection.remoteId) {
        throw const LinkTransportException('incoming_identity_mismatch');
      }
      if (envelope.context.kind == 'operation') {
        final acknowledgement = await _onOperation(envelope).timeout(timeout);
        _validateOutgoing(acknowledgement, 'ack');
        await _writeFrame(send, {
          'version': 1,
          'acknowledgement': acknowledgement.toJson(),
        });
      } else if (envelope.context.kind == 'ack') {
        await _onAcknowledgement(envelope).timeout(timeout);
        await _writeFrame(send, {'version': 1, 'received': envelope.digest});
      } else {
        throw const LinkTransportException('unsupported_direct_kind');
      }
      // finish() queues FIN; the dialer closes only after reading the full frame.
      await connection.closed().timeout(timeout);
    } catch (_) {
      if (!_closed) _diagnostics.add('incoming_rejected');
    } finally {
      _connections.remove(connection);
      connection.close();
    }
  }

  Future<void> _writeFrame(
    iroh.SendStream send,
    Map<String, dynamic> frame,
  ) async {
    final bytes = utf8.encode(jsonEncode(frame));
    if (bytes.isEmpty || bytes.length > maximumFrameBytes) {
      throw const LinkTransportException(
        'direct_frame_too_large',
        permanent: true,
      );
    }
    final header = ByteData(4)..setUint32(0, bytes.length, Endian.big);
    await send.writeAll(header.buffer.asUint8List()).timeout(timeout);
    await send.writeAll(bytes).timeout(timeout);
    await send.finish().timeout(timeout);
  }

  Future<Map<String, dynamic>> _readFrame(iroh.RecvStream receive) async {
    final header = await receive.readExact(4);
    final length = ByteData.sublistView(header).getUint32(0, Endian.big);
    if (length == 0 || length > maximumFrameBytes) {
      throw const LinkTransportException(
        'invalid_direct_frame_length',
        permanent: true,
      );
    }
    final bytes = await receive.readExact(length);
    if (await receive.read(1) != null) {
      throw const LinkTransportException(
        'trailing_direct_frame',
        permanent: true,
      );
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const LinkTransportException(
        'invalid_direct_json',
        permanent: true,
      );
    }
    return decoded;
  }

  @override
  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _closed = true;
    return _closeFuture = _close();
  }

  Future<void> _close() async {
    for (final connection in List<iroh.Connection>.of(_connections)) {
      connection.close();
    }
    await _endpoint.close();
    await _accepting;
    await Future.wait(_handlers.toList());
    await _diagnostics.close();
  }
}
