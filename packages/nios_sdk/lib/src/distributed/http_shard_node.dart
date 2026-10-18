import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:universal_io/io.dart';

import 'distributed_store.dart';

/// Authenticated HTTPS storage node; unencrypted HTTP is restricted to loopback.
final class HttpShardNode implements ShardNode {
  HttpShardNode({
    required this.id,
    required this.failureDomain,
    required this.origin,
    required this.token,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    final loopback =
        origin.host == 'localhost' ||
        origin.host == '127.0.0.1' ||
        origin.host == '::1';
    if ((origin.scheme != 'https' && !(origin.scheme == 'http' && loopback)) ||
        origin.userInfo.isNotEmpty ||
        origin.host.isEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        timeout <= Duration.zero ||
        token.isEmpty ||
        token.contains('\r') ||
        token.contains('\n')) {
      throw ArgumentError('HTTPS and a nonempty bearer token are required');
    }
  }
  @override
  final String id;
  @override
  final String failureDomain;
  final Uri origin;
  final String token;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;
  bool _closed = false;
  final Set<Completer<void>> _aborters = {};
  Uri _uri(String path, [Map<String, String>? query]) =>
      origin.replace(path: path, queryParameters: query);
  Map<String, String> get _headers => {'Authorization': 'Bearer $token'};
  String _metadata(DistributedManifest manifest) =>
      base64UrlEncode(utf8.encode(jsonEncode(manifest.toJson())));
  Future<Map<String, dynamic>> _send(
    http.BaseRequest request,
    Completer<void> abort,
  ) async {
    if (_closed) throw StateError('Storage transport is closed');
    _aborters.add(abort);
    final deadline = Timer(timeout, () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      return await _readResponse(request).timeout(timeout);
    } finally {
      deadline.cancel();
      _aborters.remove(abort);
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<Map<String, dynamic>> _readResponse(http.BaseRequest request) async {
    request.followRedirects = false;
    final response = await _client.send(request).timeout(timeout);
    final output = BytesBuilder(copy: false);
    await for (final bytes in response.stream.timeout(timeout)) {
      if (output.length + bytes.length > 2 * 1024 * 1024) {
        throw const FormatException('Storage response exceeded budget');
      }
      output.add(bytes);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Storage node returned HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(output.takeBytes())) as Map<String, dynamic>;
  }

  @override
  Future<ShareReceipt> put(
    DistributedManifest manifest,
    int index,
    Stream<List<int>> bytes,
  ) async {
    final abort = Completer<void>();
    final request = http.AbortableStreamedRequest(
      'PUT',
      _uri('/v1/shards/${manifest.objectId}/$index'),
      abortTrigger: abort.future,
    );
    request.headers.addAll({
      ..._headers,
      'Content-Type': 'application/octet-stream',
      'X-Nios-Manifest': _metadata(manifest),
      'X-Nios-Manifest-Hash': manifest.hash,
    });
    request.contentLength = manifest.shardLength;
    // Start the request before adding bytes: StreamedRequest applies backpressure.
    final receiving = _send(request, abort);
    final sending = () async {
      try {
        await request.sink.addStream(bytes);
      } finally {
        unawaited(
          request.sink.close().then<void>(
            (_) {},
            onError: (Object _, StackTrace _) {},
          ),
        );
      }
    }();
    late Map<String, dynamic> json;
    try {
      final results = await Future.wait<Object?>([
        receiving,
        sending,
      ], eagerError: true).timeout(timeout);
      json = results.first! as Map<String, dynamic>;
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
    if (json['node_id'] != id ||
        json['failure_domain'] != failureDomain ||
        json['index'] != index ||
        json['manifest_hash'] != manifest.hash) {
      throw const FormatException('Untrusted storage acknowledgement');
    }
    return ShareReceipt(id, failureDomain, index, manifest.hash);
  }

  @override
  Future<ShardBlock> get(
    DistributedManifest manifest,
    int index,
    int stripe,
  ) async {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      _uri('/v1/shards/${manifest.objectId}/$index', {'stripe': '$stripe'}),
      abortTrigger: abort.future,
    );
    request.headers.addAll({
      ..._headers,
      'X-Nios-Manifest-Hash': manifest.hash,
    });
    final json = await _send(request, abort);
    final rawProof = json['proof'] as List;
    if (rawProof.length > 12) {
      throw const FormatException('Oversized integrity proof');
    }
    final proof = rawProof.map((raw) {
      final item = raw as Map<String, dynamic>;
      return MerkleSibling(
        item['hash'] as String,
        onLeft: item['left'] as bool,
      );
    }).toList();
    final result = ShardBlock(
      index: json['index'] as int,
      stripe: json['stripe'] as int,
      bytes: base64Decode(json['data'] as String),
      proof: proof,
    );
    if (result.index != index ||
        result.stripe != stripe ||
        !manifest.verifies(result)) {
      throw const FormatException('Storage node supplied invalid data');
    }
    return result;
  }

  @override
  Future<void> delete(String objectId) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(objectId)) {
      throw const FormatException('Invalid object ID');
    }
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'DELETE',
      _uri('/v1/objects/$objectId'),
      abortTrigger: abort.future,
    );
    request.headers.addAll(_headers);
    await _send(request, abort);
  }

  void close() {
    _closed = true;
    for (final abort in _aborters) {
      if (!abort.isCompleted) abort.complete();
    }
    if (_ownsClient) _client.close();
  }
}

/// Isolated owner-scoped reference server. Put behind TLS for non-loopback use.
/// Production authentication/quotas must bind each node instance to its owner.
final class ShardNodeServer {
  ShardNodeServer._(this._server, this.node, this._token)
    : _port = _server.port;
  final HttpServer _server;
  final DirectoryShardNode node;
  final String _token;
  final int _port;
  final _manifests = <String, DistributedManifest>{};
  int get port => _port;
  Uri get origin => Uri.parse('http://127.0.0.1:$port');
  static Future<ShardNodeServer> bind({
    required DirectoryShardNode node,
    required String token,
    int port = 0,
  }) async {
    if (token.isEmpty) throw ArgumentError('Token is required');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final result = ShardNodeServer._(server, node, token);
    server.listen(result._handle);
    return result;
  }

  bool _authorized(String? header) {
    final expected = utf8.encode('Bearer $_token');
    final actual = utf8.encode(header ?? '');
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ (i < actual.length ? actual[i] : 0);
    }
    return difference == 0;
  }

  Future<void> _handle(HttpRequest request) async {
    var status = HttpStatus.ok;
    Map<String, Object?> body;
    try {
      if (!_authorized(
        request.headers.value(HttpHeaders.authorizationHeader),
      )) {
        status = HttpStatus.unauthorized;
        body = {'error': 'unauthorized'};
      } else {
        final parts = request.uri.pathSegments;
        if (parts.length == 4 && parts[0] == 'v1' && parts[1] == 'shards') {
          final id = parts[2];
          final index = int.tryParse(parts[3]);
          if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
              index == null ||
              index < 0 ||
              index > 4) {
            throw const FormatException('Invalid shard path');
          }
          final hash = request.headers.value('X-Nios-Manifest-Hash') ?? '';
          if (request.method == 'PUT') {
            final raw = request.headers.value('X-Nios-Manifest') ?? '';
            if (raw.length > 8192) {
              throw const FormatException('Oversized manifest');
            }
            final manifest = DistributedManifest.fromJson(
              jsonDecode(utf8.decode(base64Url.decode(raw)))
                  as Map<String, dynamic>,
              expectedHash: hash,
            );
            if (manifest.objectId != id ||
                request.contentLength != manifest.shardLength) {
              throw const FormatException('Wrong upload dimensions');
            }
            final receipt = await node.put(
              manifest,
              index,
              request.timeout(const Duration(seconds: 30)),
            );
            if (_manifests.length >= 16) {
              _manifests.remove(_manifests.keys.first);
            }
            _manifests[hash] = manifest;
            body = {
              'node_id': receipt.nodeId,
              'failure_domain': receipt.failureDomain,
              'index': receipt.index,
              'manifest_hash': receipt.manifestHash,
            };
          } else if (request.method == 'GET') {
            var manifest = _manifests[hash];
            if (manifest == null) {
              final metadataFile = File(
                '${node.directory}${Platform.pathSeparator}$id${Platform.pathSeparator}$index${Platform.pathSeparator}metadata.json',
              );
              if (await metadataFile.length() > 1024 * 1024) {
                throw const FormatException('Oversized metadata');
              }
              final metadata =
                  jsonDecode(await metadataFile.readAsString())
                      as Map<String, dynamic>;
              manifest = DistributedManifest.fromJson(
                metadata['manifest'] as Map<String, dynamic>,
                expectedHash: hash,
              );
              _manifests[hash] = manifest;
            }
            final stripe = int.tryParse(
              request.uri.queryParameters['stripe'] ?? '',
            );
            if (stripe == null) throw const FormatException('Missing stripe');
            final block = await node.get(manifest, index, stripe);
            body = {
              'index': block.index,
              'stripe': block.stripe,
              'data': base64Encode(block.bytes),
              'proof': block.proof
                  .map((item) => {'hash': item.hash, 'left': item.onLeft})
                  .toList(),
            };
          } else {
            status = HttpStatus.methodNotAllowed;
            body = {'error': 'method_not_allowed'};
          }
        } else if (request.method == 'DELETE' &&
            parts.length == 3 &&
            parts[0] == 'v1' &&
            parts[1] == 'objects') {
          await node.delete(parts[2]);
          _manifests.removeWhere((_, value) => value.objectId == parts[2]);
          body = {'deleted': true};
        } else {
          status = HttpStatus.notFound;
          body = {'error': 'not_found'};
        }
      }
    } on FileSystemException {
      status = HttpStatus.notFound;
      body = {'error': 'unavailable'};
    } on FormatException {
      status = HttpStatus.badRequest;
      body = {'error': 'invalid_object'};
    } catch (_) {
      status = HttpStatus.conflict;
      body = {'error': 'storage_failure'};
    }
    try {
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
      await request.response.close();
    } on IOException {
      /* Client disconnected; no data was acknowledged to it. */
    }
  }

  Future<void> close() => _server.close(force: true);
}
