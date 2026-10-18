// Isolated SDK test/development mailbox. It never touches the NiosMess backend.
// Requires NIOS_MAILBOX_KEY (base64 32 bytes) and NIOS_MAILBOX_TOKENS (JSON map
// deviceId -> random bearer token). Bind is loopback only; deploy behind HTTPS.
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:nios_sdk/link.dart';
import 'package:nios_sdk/src/link/journal_guard.dart';
import 'package:universal_io/io.dart';

Future<void> main(List<String> arguments) async {
  final keyValue = Platform.environment['NIOS_MAILBOX_KEY'];
  final tokenValue = Platform.environment['NIOS_MAILBOX_TOKENS'];
  if (keyValue == null || tokenValue == null) {
    stderr.writeln(
      'Set NIOS_MAILBOX_KEY and NIOS_MAILBOX_TOKENS. Credentials are never printed.',
    );
    exitCode = 64;
    return;
  }
  final key = base64Decode(keyValue);
  final tokens = Map<String, String>.from(jsonDecode(tokenValue) as Map);
  if (key.length != 32 ||
      tokens.isEmpty ||
      tokens.values.any((token) => token.length < 24) ||
      tokens.values.toSet().length != tokens.length) {
    throw ArgumentError(
      'Use a 256-bit key and unique random tokens of at least 24 characters',
    );
  }
  final directory =
      Platform.environment['NIOS_MAILBOX_DIRECTORY'] ?? '.nios-mailbox';
  await Directory(directory).create(recursive: true);
  await verifyJournalKey(
    directory: directory,
    name: 'opaque_mailbox_v1',
    key: key,
  );
  final box = await Hive.openBox<String>(
    'opaque_mailbox_v1',
    path: directory,
    encryptionCipher: HiveAesCipher(key),
  );
  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    int.tryParse(Platform.environment['NIOS_MAILBOX_PORT'] ?? '') ?? 0,
  );
  final mailbox = _Mailbox(box, tokens);
  stdout.writeln(
    jsonEncode({
      'port': server.port,
      'protocol': 'nios-mailbox-v1',
      'loopback': true,
    }),
  );
  Future<void> tail = Future<void>.value();
  var queued = 0;
  await for (final request in server) {
    // Serialize quota, uniqueness and commit decisions. A slow request has a
    // bounded body timeout and cannot cause concurrent double insertion.
    if (queued >= 64) {
      request.response.statusCode = HttpStatus.tooManyRequests;
      unawaited(request.response.close());
      continue;
    }
    queued++;
    tail = tail
        .then((_) => mailbox.handle(request))
        .catchError((Object error, StackTrace stack) {
          stderr.writeln('mailbox_request_failed');
        })
        .whenComplete(() {
          queued--;
        });
  }
  await tail;
  await box.close();
}

class _Mailbox {
  _Mailbox(this.box, this.tokens) {
    for (final key in box.keys) {
      if (key is! String || !key.startsWith('e:')) continue;
      final value = jsonDecode(box.get(key)!) as Map<String, dynamic>;
      records[key.substring(2)] = value;
      totalBytes += (value['size'] as int);
      final envelope = EncryptedEnvelope.fromJson(
        value['envelope'] as Map<String, dynamic>,
      );
      if (envelope.context.kind == 'operation') {
        operations[_operationKey(envelope)] = key.substring(2);
      }
    }
  }

  final Box<String> box;
  final Map<String, String> tokens;
  final Map<String, Map<String, dynamic>> records = {};
  final Map<String, String> operations = {};
  int totalBytes = 0;

  String _operationKey(EncryptedEnvelope envelope) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            envelope.context.senderId,
            envelope.context.recipientId,
            envelope.context.sessionId,
            envelope.context.operationId,
          ]),
        ),
      )
      .toString();

  String? _authenticate(HttpRequest request) {
    final authorization =
        request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (!authorization.startsWith('Bearer ')) return null;
    final supplied = utf8.encode(authorization.substring(7));
    String? device;
    for (final entry in tokens.entries) {
      final expected = utf8.encode(entry.value);
      var difference = expected.length ^ supplied.length;
      for (var i = 0; i < expected.length; i++) {
        difference |= expected[i] ^ (i < supplied.length ? supplied[i] : 0);
      }
      if (difference == 0) device = entry.key;
    }
    return device;
  }

  Future<void> _reply(
    HttpRequest request,
    int status,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set('cache-control', 'no-store');
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final bytes = <int>[];
    final completed = Completer<void>();
    final subscription = request.listen(
      (chunk) {
        if (completed.isCompleted) return;
        if (bytes.length + chunk.length > 1500000) {
          completed.completeError(const FormatException('body_too_large'));
        } else {
          bytes.addAll(chunk);
        }
      },
      onDone: () {
        if (!completed.isCompleted) completed.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!completed.isCompleted) completed.completeError(error, stack);
      },
    );
    // An idle timeout resets after every chunk. Use a total deadline so an
    // authenticated slow sender cannot hold the serialized mailbox indefinitely.
    final deadline = Timer(const Duration(seconds: 10), () {
      if (!completed.isCompleted) {
        completed.completeError(TimeoutException('body_timeout'));
      }
    });
    try {
      await completed.future;
    } finally {
      deadline.cancel();
      await subscription.cancel();
    }
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<void> handle(HttpRequest request) async {
    try {
      final device = _authenticate(request);
      if (device == null) {
        await _reply(request, 401, {'error': 'unauthorized'});
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/v1/inbox') {
        final items = <Map<String, dynamic>>[];
        var size = 0;
        final after = request.uri.queryParameters['after'];
        var passedCursor = after == null || !records.containsKey(after);
        String? next;
        for (final entry in records.entries) {
          if (!passedCursor) {
            if (entry.key == after) passedCursor = true;
            continue;
          }
          final record = entry.value;
          if (record['pending'] != true) continue;
          final envelope = record['envelope'] as Map<String, dynamic>;
          if (envelope['recipient'] != device) continue;
          final length = record['size'] as int;
          if (items.length >= 100 ||
              (items.isNotEmpty && size + length > 1800000)) {
            next = items.isEmpty
                ? null
                : EncryptedEnvelope.fromJson(items.last).digest;
            break;
          }
          size += length;
          items.add(envelope);
        }
        await _reply(request, 200, {'envelopes': items, 'next': next});
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/confirm') {
        final body = await _body(request);
        final digest = body['digest'];
        final old = records[digest];
        if (old == null) {
          await _reply(request, 404, {'error': 'not_found'});
          return;
        }
        if ((old['envelope'] as Map)['recipient'] != device) {
          await _reply(request, 403, {'error': 'wrong_recipient'});
          return;
        }
        if (old['pending'] == true) {
          final updated = <String, dynamic>{...old, 'pending': false};
          await box.put('e:$digest', jsonEncode(updated));
          await box.flush();
          records[digest as String] = updated;
        }
        await _reply(request, 200, {'confirmed': true});
        return;
      }
      if (request.method == 'POST' &&
          const {'/v1/messages', '/v1/acks'}.contains(request.uri.path)) {
        final data = await _body(request);
        final envelope = EncryptedEnvelope.fromJson(data);
        if (envelope.context.senderId != device ||
            !tokens.containsKey(envelope.context.recipientId)) {
          await _reply(request, 403, {'error': 'invalid_devices'});
          return;
        }
        final expectedKind = request.uri.path == '/v1/acks'
            ? 'ack'
            : 'operation';
        if (envelope.context.kind != expectedKind) {
          await _reply(request, 422, {'error': 'invalid_domain'});
          return;
        }
        final digest = envelope.digest;
        final operationKey = _operationKey(envelope);
        final previous = operations[operationKey];
        if (expectedKind == 'operation' &&
            previous != null &&
            previous != digest) {
          await _reply(request, 409, {'error': 'operation_collision'});
          return;
        }
        if (!records.containsKey(digest)) {
          final encoded = jsonEncode(envelope.toJson());
          final size = utf8.encode(encoded).length;
          // The isolated reference server rejects capacity exhaustion rather
          // than expiring unacknowledged data. Production needs archival/quota UI.
          if (records.length >= 100000 ||
              totalBytes + size > 128 * 1024 * 1024) {
            await _reply(request, 507, {'error': 'mailbox_capacity'});
            return;
          }
          final record = <String, dynamic>{
            'envelope': envelope.toJson(),
            'pending': true,
            'size': size,
          };
          await box.put('e:$digest', jsonEncode(record));
          await box.flush();
          records[digest] = record;
          totalBytes += size;
          if (expectedKind == 'operation') operations[operationKey] = digest;
        }
        await _reply(request, 200, {'stored': true, 'digest': digest});
        return;
      }
      await _reply(request, 404, {'error': 'not_found'});
    } on FormatException {
      await _reply(request, 400, {'error': 'invalid_envelope'});
    } on TimeoutException {
      await _reply(request, 408, {'error': 'body_timeout'});
    } catch (_) {
      await _reply(request, 503, {'error': 'storage_or_request_failure'});
    }
  }
}
