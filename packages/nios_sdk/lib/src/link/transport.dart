import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class TransportReceipt {
  const TransportReceipt({this.mailboxStored = false, this.acknowledgement});
  final bool mailboxStored;
  final EncryptedEnvelope? acknowledgement;
}

/// Custom direct transports (including an Iroh adapter) implement this contract.
/// A mailbox receipt is never interpreted as a recipient acknowledgement.
abstract interface class LinkTransport {
  Future<TransportReceipt> deliver(EncryptedEnvelope envelope);
  Future<void> publishAcknowledgement(EncryptedEnvelope acknowledgement);
  Future<List<EncryptedEnvelope>> poll(String deviceId);
  Future<void> confirmReceived(EncryptedEnvelope envelope);
  Future<void> close();
}

class LinkTransportException implements Exception {
  const LinkTransportException(this.code, {this.permanent = false});
  final String code;
  final bool permanent;

  @override
  String toString() => 'LinkTransportException($code)';
}

/// Authenticated opaque-envelope mailbox. Plain HTTP is accepted only for an
/// explicitly enabled loopback test server; remote deployments require HTTPS.
class HttpMailboxTransport implements LinkTransport {
  HttpMailboxTransport({
    required this.baseUri,
    required this.deviceId,
    required this.bearerToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    bool allowInsecureLoopback = false,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    final loopback = const {
      'localhost',
      '127.0.0.1',
      '::1',
    }.contains(baseUri.host);
    if (baseUri.scheme != 'https' &&
        !(allowInsecureLoopback && loopback && baseUri.scheme == 'http')) {
      throw ArgumentError('Mailbox transport requires HTTPS');
    }
    if (baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        bearerToken.isEmpty) {
      throw ArgumentError('Invalid mailbox endpoint or credential');
    }
  }

  final Uri baseUri;
  final String deviceId;
  final String bearerToken;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;
  bool _closed = false;
  String? _inboxCursor;
  final Set<Completer<void>> _aborters = {};

  Uri _uri(String path) => baseUri.resolve(path);
  Map<String, String> get _headers => {
    'authorization': 'Bearer $bearerToken',
    'content-type': 'application/json',
  };

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Object? data,
  ]) async {
    if (_closed) throw const LinkTransportException('transport_closed');
    final abort = Completer<void>();
    _aborters.add(abort);
    final timer = Timer(timeout, () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final request =
          http.AbortableRequest(method, _uri(path), abortTrigger: abort.future)
            ..headers.addAll(_headers)
            ..followRedirects = false;
      if (data != null) request.body = jsonEncode(data);
      final response = await _client.send(request).timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(timeout)) {
        if (bytes.length + chunk.length > 2097152) {
          throw const LinkTransportException(
            'response_too_large',
            permanent: true,
          );
        }
        bytes.addAll(chunk);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LinkTransportException(
          'http_${response.statusCode}',
          permanent: const {
            400,
            401,
            403,
            404,
            409,
            413,
            422,
          }.contains(response.statusCode),
        );
      }
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } finally {
      timer.cancel();
      _aborters.remove(abort);
      if (!abort.isCompleted) abort.complete();
    }
  }

  @override
  Future<TransportReceipt> deliver(EncryptedEnvelope envelope) async {
    if (envelope.context.senderId != deviceId ||
        envelope.context.kind != 'operation') {
      throw const LinkTransportException('invalid_sender', permanent: true);
    }
    final result = await _request('POST', '/v1/messages', envelope.toJson());
    if (result['stored'] != true || result['digest'] != envelope.digest) {
      throw const LinkTransportException(
        'invalid_mailbox_receipt',
        permanent: true,
      );
    }
    return const TransportReceipt(mailboxStored: true);
  }

  @override
  Future<void> publishAcknowledgement(EncryptedEnvelope acknowledgement) async {
    if (acknowledgement.context.senderId != deviceId ||
        acknowledgement.context.kind != 'ack') {
      throw const LinkTransportException('invalid_sender', permanent: true);
    }
    final result = await _request('POST', '/v1/acks', acknowledgement.toJson());
    if (result['stored'] != true ||
        result['digest'] != acknowledgement.digest) {
      throw const LinkTransportException(
        'invalid_mailbox_receipt',
        permanent: true,
      );
    }
  }

  @override
  Future<List<EncryptedEnvelope>> poll(String deviceId) async {
    if (deviceId != this.deviceId) throw StateError('Wrong mailbox account');
    final path = _inboxCursor == null
        ? '/v1/inbox'
        : '/v1/inbox?after=$_inboxCursor';
    final result = await _request('GET', path);
    final items = result['envelopes'];
    if (items is! List || items.length > 100) {
      throw const LinkTransportException('invalid_inbox', permanent: true);
    }
    final next = result['next'];
    if (next != null &&
        (next is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(next))) {
      throw const LinkTransportException(
        'invalid_inbox_cursor',
        permanent: true,
      );
    }
    final envelopes = items
        .map(
          (item) => EncryptedEnvelope.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    // Reject an invalid page without advancing past its other, valid envelopes.
    _inboxCursor = next as String?;
    return envelopes;
  }

  @override
  Future<void> confirmReceived(EncryptedEnvelope envelope) async {
    await _request('POST', '/v1/confirm', {'digest': envelope.digest});
  }

  @override
  Future<void> close() async {
    _closed = true;
    for (final abort in _aborters) {
      if (!abort.isCompleted) abort.complete();
    }
    if (_ownsClient) _client.close();
  }
}

/// Direct in-process adapter for deterministic simulations and embedded hosts.
/// It makes no claim to provide a network or an Iroh implementation.
class CallbackLinkTransport implements LinkTransport {
  CallbackLinkTransport({required this.receiver, this.acknowledger});
  final Future<EncryptedEnvelope> Function(EncryptedEnvelope) receiver;
  final Future<void> Function(EncryptedEnvelope)? acknowledger;
  bool _closed = false;

  @override
  Future<TransportReceipt> deliver(EncryptedEnvelope envelope) async {
    if (_closed) throw const LinkTransportException('transport_closed');
    return TransportReceipt(acknowledgement: await receiver(envelope));
  }

  @override
  Future<void> publishAcknowledgement(EncryptedEnvelope acknowledgement) async {
    if (_closed) throw const LinkTransportException('transport_closed');
    if (acknowledger == null) {
      throw const LinkTransportException('ack_route_unavailable');
    }
    await acknowledger!(acknowledgement);
  }

  @override
  Future<List<EncryptedEnvelope>> poll(String deviceId) async => const [];
  @override
  Future<void> confirmReceived(EncryptedEnvelope envelope) async {}
  @override
  Future<void> close() async => _closed = true;
}
