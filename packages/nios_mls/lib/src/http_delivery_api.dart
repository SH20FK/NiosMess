part of 'client.dart';

final class MlsControlPage {
  const MlsControlPage({required this.events, required this.next});
  final List<MlsControlEvent> events;
  final int? next;
}

/// Authenticated HTTPS implementation of the additive server MLS v1 API.
/// Application delivery is delegated to a durable host outbox; this class does
/// not pretend a successful local enqueue is a recipient acknowledgement.
final class HttpMlsDeliveryApi implements MlsDeliveryApi {
  HttpMlsDeliveryApi({
    required this.baseUri,
    required this.deviceId,
    required String bearerToken,
    Future<void> Function(MlsApplicationDelivery)? enqueueApplication,
    this.timeout = const Duration(seconds: 30),
    bool allowInsecureLoopback = false,
    http.Client? client,
  }) : _token = bearerToken,
       _enqueue = enqueueApplication,
       _client = client ?? http.Client(),
       _ownsClient = client == null {
    final loopback = const {
      '127.0.0.1',
      'localhost',
      '::1',
    }.contains(baseUri.host);
    if (!baseUri.hasAuthority ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        !const {'', '/'}.contains(baseUri.path) ||
        !(baseUri.scheme == 'https' ||
            (baseUri.scheme == 'http' && allowInsecureLoopback && loopback)) ||
        timeout <= Duration.zero ||
        !RegExp(r'^[\x21-\x7e]{1,4096}$').hasMatch(bearerToken) ||
        !RegExp(r'^[A-Za-z0-9._:@-]{1,160}$').hasMatch(deviceId)) {
      if (_ownsClient) _client.close();
      throw ArgumentError('Invalid MLS HTTPS origin, credential or device');
    }
  }

  final Uri baseUri;
  final String deviceId;
  final Duration timeout;
  final String _token;
  final http.Client _client;
  final bool _ownsClient;
  final Future<void> Function(MlsApplicationDelivery)? _enqueue;
  final Set<Completer<void>> _aborts = {};
  bool _closed = false;

  String _groupPath(List<int> group) {
    if (group.isEmpty || group.length > 128) {
      throw ArgumentError('Invalid native MLS group ID');
    }
    return '/v1/mls/groups/${mlsServerGroupId(group)}';
  }

  static BigInt _epoch(Object? value) {
    if (value is! int || value < 0 || value > 9007199254740991) {
      throw const NiosMlsException('mls_invalid_epoch_response');
    }
    return BigInt.from(value);
  }

  static int _wireEpoch(BigInt value) {
    if (value < BigInt.zero || value > BigInt.from(9007199254740991)) {
      throw const NiosMlsException('mls_epoch_outside_wire_range');
    }
    return value.toInt();
  }

  static String _digest(Object? value) {
    if (value is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw const NiosMlsException('mls_invalid_digest_response');
    }
    return value;
  }

  static Uint8List _bytes(Object? value, int maximum) {
    if (value is! String || value.length > ((maximum + 2) ~/ 3) * 4) {
      throw const NiosMlsException('mls_invalid_bytes_response');
    }
    try {
      final result = base64Decode(value);
      if (result.isEmpty ||
          result.length > maximum ||
          base64Encode(result) != value) {
        throw const FormatException();
      }
      return result;
    } on FormatException {
      throw const NiosMlsException('mls_invalid_bytes_response');
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    int maxBytes = 65536,
  }) async {
    if (_closed) throw const NiosMlsException('mls_http_closed');
    final abort = Completer<void>();
    _aborts.add(abort);
    final request = http.AbortableRequest(
      method,
      baseUri.resolve(path),
      abortTrigger: abort.future,
    )..followRedirects = false;
    request.headers.addAll({
      'Authorization': 'Bearer $_token',
      'Accept-Encoding': 'identity',
    });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.bodyBytes = utf8.encode(jsonEncode(body));
    }
    try {
      return await (() async {
        final response = await _client.send(request);
        if (response.statusCode >= 300 && response.statusCode < 400) {
          throw const NiosMlsException('mls_http_redirect_rejected');
        }
        if (response.headers['content-encoding'] != null &&
            response.headers['content-encoding'] != 'identity') {
          throw const NiosMlsException('mls_http_encoding_rejected');
        }
        final declared = response.contentLength;
        if (declared != null && declared > maxBytes) {
          throw const NiosMlsException('mls_http_response_too_large');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxBytes) {
            throw const NiosMlsException('mls_http_response_too_large');
          }
          bytes.add(chunk);
        }
        final Object? decoded;
        try {
          decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
        } on FormatException {
          throw const NiosMlsException('mls_http_invalid_json');
        }
        if (decoded is! Map<String, dynamic>) {
          throw const NiosMlsException('mls_http_invalid_json');
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final detail = decoded['detail'];
          throw NiosMlsException(
            detail is String && RegExp(r'^[a-z0-9_]{1,120}$').hasMatch(detail)
                ? detail
                : 'mls_http_${response.statusCode}',
          );
        }
        return decoded;
      })().timeout(timeout);
    } on TimeoutException {
      throw const NiosMlsException('mls_http_timeout');
    } finally {
      if (!abort.isCompleted) abort.complete();
      _aborts.remove(abort);
    }
  }

  MlsServerHead _head(List<int> groupId, Map<String, dynamic> result) {
    if (result['group_id'] != mlsServerGroupId(groupId) ||
        result['coordinator'] is! String ||
        (result['pending_operation'] != null &&
            result['pending_operation'] is! String)) {
      throw const NiosMlsException('mls_group_response_mismatch');
    }
    return MlsServerHead(
      groupId: groupId,
      epoch: _epoch(result['epoch']),
      head: _digest(result['head']),
      coordinatorDeviceId: _id(result['coordinator'] as String),
      pendingOperationId: result['pending_operation'] as String?,
    );
  }

  Future<MlsServerHead> createGroup({
    required List<int> groupId,
    required String chatId,
  }) async => _head(
    groupId,
    await _request(
      'PUT',
      _groupPath(groupId),
      body: {'chat_id': _id(chatId), 'ciphersuite': '0x0001'},
    ),
  );

  @override
  Future<MlsServerHead> groupHead(Uint8List groupId) async =>
      _head(groupId, await _request('GET', _groupPath(groupId)));

  /// Sign with the account-authorized device Link Ed25519 key. No native MLS
  /// private key leaves OpenMLS; this signature binds publication metadata.
  Future<void> publishKeyPackage({
    required List<int> keyPackage,
    required DateTime expiresAt,
    required Future<Uint8List> Function(Uint8List bytes) signPublication,
  }) async {
    if (keyPackage.isEmpty || keyPackage.length > 65536) {
      throw ArgumentError('Invalid KeyPackage size');
    }
    final stable = _copy(keyPackage);
    final digest = _hash(stable);
    final expiry = expiresAt.millisecondsSinceEpoch ~/ 1000;
    final signature = await signPublication(
      _copy(
        utf8.encode(
          jsonEncode(['nios-mls-keypackage', 1, deviceId, digest, expiry]),
        ),
      ),
    );
    if (signature.length != 64) {
      throw ArgumentError('Expected Ed25519 signature');
    }
    final result = await _request(
      'PUT',
      '/v1/mls/keypackages/$deviceId/$digest',
      body: {
        'package': base64Encode(stable),
        'expires_at': expiry,
        'signature': base64Encode(signature),
      },
    );
    if (result['stored'] != true || result['hash'] != digest) {
      throw const NiosMlsException('mls_keypackage_receipt_mismatch');
    }
  }

  @override
  Future<MlsMembershipReservation> reserve({
    required Uint8List groupId,
    required String operationId,
    required BigInt baseEpoch,
    required String baseHead,
    required List<String> addDevices,
    required List<String> removeDevices,
  }) async {
    final result = await _request(
      'POST',
      '${_groupPath(groupId)}/reservations',
      maxBytes: 6 * 1024 * 1024,
      body: {
        'operation_id': _id(operationId),
        'base_epoch': _wireEpoch(baseEpoch),
        'base_head': baseHead,
        'add_devices': addDevices,
        'remove_devices': removeDevices,
      },
    );
    final packages = result['keypackages'];
    final intent = result['intent'];
    if (packages is! List ||
        packages.length > 64 ||
        result['operation_id'] != operationId ||
        intent is! Map ||
        jsonEncode(intent['add_devices']) !=
            jsonEncode(addDevices.toList()..sort()) ||
        jsonEncode(intent['remove_devices']) !=
            jsonEncode(removeDevices.toList()..sort())) {
      throw const NiosMlsException('mls_reservation_binding_mismatch');
    }
    final parsed = <String, Uint8List>{};
    for (final package in packages) {
      if (package is! Map || package['device_id'] is! String) {
        throw const NiosMlsException('mls_invalid_keypackage_response');
      }
      final device = _id(package['device_id'] as String);
      final bytes = _bytes(package['package'], 65536);
      if (parsed.containsKey(device) ||
          _hash(bytes) != _digest(package['hash'])) {
        throw const NiosMlsException('mls_keypackage_hash_mismatch');
      }
      parsed[device] = bytes;
    }
    return MlsMembershipReservation(
      operationId: operationId,
      token: _digest(result['token']),
      baseEpoch: _epoch(result['base_epoch']),
      baseHead: _digest(result['base_head']),
      keyPackages: parsed,
    );
  }

  @override
  Future<MlsCommitReceipt> publishCommit({
    required MlsMembershipReservation reservation,
    required NiosMlsOutbound operation,
  }) async {
    if (operation.baseEpoch != reservation.baseEpoch ||
        operation.epoch == null ||
        operation.kind != 'commit' ||
        operation.operationId != reservation.operationId) {
      throw const NiosMlsException('mls_commit_epoch_metadata_required');
    }
    final result = await _request(
      'PUT',
      '${_groupPath(operation.groupId)}/commits/${_id(operation.operationId)}',
      body: {
        'token': reservation.token,
        'base_epoch': _wireEpoch(reservation.baseEpoch),
        'epoch': _wireEpoch(operation.epoch!),
        'commit': base64Encode(operation.message),
        'welcome': operation.welcome == null
            ? null
            : base64Encode(operation.welcome!),
      },
    );
    if (result['stored'] != true) {
      throw const NiosMlsException('mls_commit_receipt_mismatch');
    }
    return MlsCommitReceipt(
      epoch: _epoch(result['epoch']),
      head: _digest(result['head']),
      digest: _digest(result['digest']),
    );
  }

  @override
  Future<void> ensureApplicationDeliveryAllowed({
    required Uint8List groupId,
    required BigInt epoch,
    required List<String> recipientDeviceIds,
  }) async {
    final result = await _request(
      'POST',
      '${_groupPath(groupId)}/gate',
      body: {'epoch': _wireEpoch(epoch), 'recipients': recipientDeviceIds},
    );
    if (result['allowed'] != true || _epoch(result['epoch']) != epoch) {
      throw const NiosMlsException('mls_delivery_gate_mismatch');
    }
    _digest(result['head']);
  }

  @override
  Future<void> enqueueApplication(MlsApplicationDelivery delivery) async {
    if (_closed) throw const NiosMlsException('mls_http_closed');
    final enqueue = _enqueue;
    if (enqueue == null) {
      throw const NiosMlsException('mls_application_transport_unavailable');
    }
    await enqueue(delivery);
  }

  Future<MlsControlPage> controlPage({int after = 0}) async {
    if (after < 0 || after > 9007199254740991) {
      throw ArgumentError('Invalid cursor');
    }
    final result = await _request(
      'GET',
      '/v1/mls/inbox?after=$after',
      maxBytes: 6 * 1024 * 1024 + 65536,
    );
    final events = result['events'];
    if (events is! List || events.length > 32) {
      throw const NiosMlsException('mls_invalid_control_page');
    }
    final parsed = <MlsControlEvent>[];
    var previous = after;
    for (final event in events) {
      if (event is! Map ||
          event['id'] is! int ||
          event['group_id'] is! String ||
          !const {'commit', 'welcome'}.contains(event['kind'])) {
        throw const NiosMlsException('mls_invalid_control_page');
      }
      final id = event['id'] as int;
      final encodedGroup = event['group_id'] as String;
      if (id <= previous ||
          id > 9007199254740991 ||
          !RegExp(r'^[A-Za-z0-9_-]{1,171}$').hasMatch(encodedGroup)) {
        throw const NiosMlsException('mls_invalid_control_cursor');
      }
      final Uint8List group;
      try {
        group = base64Url.decode(base64Url.normalize(encodedGroup));
      } on FormatException {
        throw const NiosMlsException('mls_invalid_control_group');
      }
      if (group.isEmpty ||
          group.length > 128 ||
          mlsServerGroupId(group) != encodedGroup) {
        throw const NiosMlsException('mls_invalid_control_group');
      }
      _digest(event['head']);
      parsed.add(
        MlsControlEvent(
          id: id.toString(),
          groupId: group,
          epoch: _epoch(event['epoch']),
          kind: event['kind'] as String,
          payload: _bytes(event['payload'], 4 * 1024 * 1024),
        ),
      );
      previous = id;
    }
    final next = result['next'];
    if (next != null && (next is! int || parsed.isEmpty || next != previous)) {
      throw const NiosMlsException('mls_invalid_control_cursor');
    }
    return MlsControlPage(
      events: List.unmodifiable(parsed),
      next: next as int?,
    );
  }

  /// Each confirmed event is safely replayable on interruption. The server
  /// cursor is traversal only; it never replaces the per-event durable ACK.
  Future<int> synchronizeControls(
    NiosMlsDeliveryCoordinator coordinator, {
    int maxPages = 100,
  }) async {
    if (maxPages < 1 || maxPages > 1000) {
      throw ArgumentError('Invalid page budget');
    }
    var count = 0;
    var after = 0;
    for (var pageIndex = 0; pageIndex < maxPages; pageIndex++) {
      final page = await controlPage(after: after);
      for (final event in page.events) {
        await coordinator.processControl(event);
        count++;
      }
      if (page.next == null) return count;
      after = page.next!;
    }
    return count;
  }

  @override
  Future<void> confirmControl(String eventId) async {
    final id = int.tryParse(eventId);
    if (id == null ||
        id < 1 ||
        id > 9007199254740991 ||
        id.toString() != eventId) {
      throw ArgumentError('Invalid event ID');
    }
    final result = await _request('POST', '/v1/mls/confirm', body: {'id': id});
    if (result['confirmed'] != true) {
      throw const NiosMlsException('mls_confirm_mismatch');
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final abort in _aborts.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
    if (_ownsClient) _client.close();
  }
}
