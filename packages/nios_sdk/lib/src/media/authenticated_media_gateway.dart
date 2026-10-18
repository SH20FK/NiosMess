import 'dart:async';
import 'dart:math';

import 'package:universal_io/io.dart';

import '../stream/cancellation.dart';
import '../stream/stream_object.dart';

/// A loopback-only, unguessable media URL for native range-capable players.
/// Plaintext is authenticated in RAM by NiosStreamDownload; no plaintext file
/// is materialized. Close this gateway before closing the account/download.
final class AuthenticatedMediaGateway {
  AuthenticatedMediaGateway._(
    this._server,
    this._download,
    this._capability,
    this._contentType,
  ) : _port = _server.port;

  final HttpServer _server;
  final NiosStreamDownload _download;
  final String _capability;
  final ContentType _contentType;
  final int _port;
  bool _closed = false;
  Future<void>? _closing;
  final _cancellation = StreamCancellation();
  final Set<Future<void>> _handlers = {};

  Uri get uri => Uri.parse('http://127.0.0.1:$_port/$_capability/media');

  static Future<AuthenticatedMediaGateway> bind({
    required NiosStreamDownload download,
    String mimeType = 'application/octet-stream',
  }) async {
    final contentType = ContentType.parse(mimeType);
    final random = Random.secure();
    final capability = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final gateway = AuthenticatedMediaGateway._(
      server,
      download,
      capability,
      contentType,
    );
    server.listen((request) {
      final handler = gateway._handle(request);
      gateway._handlers.add(handler);
      unawaited(handler.whenComplete(() => gateway._handlers.remove(handler)));
    });
    return gateway;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (_closed ||
          request.uri.path != '/$_capability/media' ||
          request.uri.hasQuery ||
          (request.method != 'GET' && request.method != 'HEAD')) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      final length = _download.manifest.plaintextLength;
      var start = 0;
      var end = length;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
        var valid = match != null && length > 0;
        if (valid) {
          final first = match.group(1)!;
          final last = match.group(2)!;
          if (first.isEmpty) {
            final suffix = int.tryParse(last);
            valid = suffix != null && suffix > 0;
            if (valid) start = max(0, length - suffix);
          } else {
            final parsed = int.tryParse(first);
            final inclusiveEnd = last.isEmpty ? length - 1 : int.tryParse(last);
            valid =
                parsed != null &&
                inclusiveEnd != null &&
                parsed >= 0 &&
                parsed < length &&
                inclusiveEnd >= parsed;
            if (valid) {
              start = parsed;
              end = min(length, inclusiveEnd + 1);
            }
          }
        }
        if (!valid) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */$length',
          );
          await response.close();
          return;
        }
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${end - 1}/$length',
        );
      }
      response.headers.contentType = _contentType;
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.contentLength = end - start;
      if (request.method == 'GET') {
        while (start < end && !_closed) {
          final next = min(end, start + 256 * 1024);
          final plaintext = await _download.readRange(
            start,
            next,
            cancellation: _cancellation,
          );
          try {
            _cancellation.throwIfCancelled();
            response.add(plaintext);
            await response.flush();
          } finally {
            plaintext.fillRange(0, plaintext.length, 0);
          }
          start = next;
        }
      }
      await response.close();
    } catch (_) {
      try {
        await response.close();
      } catch (_) {
        /* Client/account closed. */
      }
    }
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _cancellation.cancel();
    return _closing = _close();
  }

  Future<void> _close() async {
    await _server.close(force: true);
    await Future.wait(List.of(_handlers));
  }
}
