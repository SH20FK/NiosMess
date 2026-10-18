import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:universal_io/io.dart';

import 'cancellation.dart';

/// All offsets use an exclusive end. Implementations must bound body size.
abstract interface class StreamCiphertextSource {
  Future<Uint8List> readRange(
    int start,
    int endExclusive, {
    StreamCancellation? cancellation,
  });
}

final class FileCiphertextSource implements StreamCiphertextSource {
  final String path;
  final int maximumRangeLength;

  const FileCiphertextSource(
    this.path, {
    this.maximumRangeLength = 1024 * 1024 + 16,
  });

  @override
  Future<Uint8List> readRange(
    int start,
    int endExclusive, {
    StreamCancellation? cancellation,
  }) async {
    _validateRange(start, endExclusive, maximumRangeLength);
    cancellation?.throwIfCancelled();
    final file = await File(path).open();
    try {
      if (endExclusive > await file.length()) {
        throw const FormatException('Truncated ciphertext source');
      }
      await file.setPosition(start);
      final result = Uint8List(endExclusive - start);
      var position = 0;
      while (position < result.length) {
        cancellation?.throwIfCancelled();
        final length = (result.length - position).clamp(0, 64 * 1024);
        final count = await file.readInto(result, position, position + length);
        if (count == 0) {
          throw const FormatException('Truncated ciphertext source');
        }
        position += count;
      }
      cancellation?.throwIfCancelled();
      return result;
    } finally {
      await file.close();
    }
  }
}

/// A strict range source: 200 responses, redirects, mismatched ranges, truncated
/// bodies and oversized bodies are rejected. A private client per request allows
/// cancellation to abort an in-flight socket without closing another transfer.
final class HttpRangeCiphertextSource implements StreamCiphertextSource {
  final Uri uri;
  final int totalLength;
  final Map<String, String> headers;
  final Duration timeout;
  final int maximumRangeLength;

  HttpRangeCiphertextSource({
    required this.uri,
    required this.totalLength,
    Map<String, String> headers = const {},
    this.timeout = const Duration(seconds: 30),
    this.maximumRangeLength = 1024 * 1024 + 16,
    bool allowInsecureLoopback = false,
  }) : headers = Map.unmodifiable(headers) {
    final loopback = const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
    if ((uri.scheme != 'https' &&
            !(allowInsecureLoopback && loopback && uri.scheme == 'http')) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        totalLength < 0 ||
        maximumRangeLength <= 0 ||
        maximumRangeLength > 1024 * 1024 + 16 ||
        timeout <= Duration.zero) {
      throw ArgumentError('Invalid HTTP ciphertext source');
    }
  }

  @override
  Future<Uint8List> readRange(
    int start,
    int endExclusive, {
    StreamCancellation? cancellation,
  }) async {
    _validateRange(start, endExclusive, maximumRangeLength);
    if (endExclusive > totalLength) throw RangeError('Range exceeds source');
    cancellation?.throwIfCancelled();
    final client = http.Client();
    final unregister = cancellation?.onCancel(client.close);
    Timer? deadline;
    try {
      deadline = Timer(timeout, client.close);
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers.addAll(headers)
        ..headers['Range'] = 'bytes=$start-${endExclusive - 1}'
        ..headers['Accept-Encoding'] = 'identity';
      final response = await client.send(request).timeout(timeout);
      cancellation?.throwIfCancelled();
      final expectedLength = endExclusive - start;
      final expectedRange = 'bytes $start-${endExclusive - 1}/$totalLength';
      if (response.statusCode != 206 ||
          response.headers['content-range'] != expectedRange ||
          (response.contentLength != null &&
              response.contentLength != expectedLength) ||
          (response.headers['content-encoding'] != null &&
              response.headers['content-encoding'] != 'identity')) {
        throw const FormatException('Invalid HTTP range response');
      }
      final result = Uint8List(expectedLength);
      var position = 0;
      await for (final chunk in response.stream.timeout(timeout)) {
        cancellation?.throwIfCancelled();
        if (chunk.length > result.length - position) {
          throw const FormatException('Oversized HTTP range response');
        }
        result.setRange(position, position + chunk.length, chunk);
        position += chunk.length;
      }
      cancellation?.throwIfCancelled();
      if (position != result.length) {
        throw const FormatException('Truncated HTTP range response');
      }
      return result;
    } catch (_) {
      cancellation?.throwIfCancelled();
      rethrow;
    } finally {
      deadline?.cancel();
      unregister?.call();
      client.close();
    }
  }
}

void _validateRange(int start, int endExclusive, int maximum) {
  if (start < 0 || endExclusive <= start || endExclusive - start > maximum) {
    throw RangeError('Invalid or oversized ciphertext range');
  }
}
