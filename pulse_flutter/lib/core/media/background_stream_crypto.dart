import 'dart:async';
import 'dart:isolate';

import 'package:nios_sdk/stream.dart';

/// One CPU job per account at a time. Only bounded primitive segment buffers
/// cross the isolate boundary; sockets, account owners and file handles stay
/// on their original isolate. Shutdown drains an active segment and fences all
/// queued work before account storage can be erased.
final class BackgroundStreamCrypto {
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  Future<StreamCryptoResult> run(StreamCryptoRequest request) {
    final job = _tail
        .then((_) async {
          if (_closed) throw StateError('stream_crypto_stopped');
          final result = await _executeInBackground(request);
          if (_closed) {
            result.bytes.fillRange(0, result.bytes.length, 0);
            throw StateError('stream_crypto_stopped');
          }
          return result;
        })
        .whenComplete(() {
          request.key?.fillRange(0, request.key!.length, 0);
          if (request.operation == StreamCryptoOperation.encrypt) {
            request.bytes.fillRange(0, request.bytes.length, 0);
          }
        });
    _tail = job.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return job;
  }

  Future<void> close() {
    _closed = true;
    return _tail;
  }
}

// Top-level trampoline deliberately captures only the primitive job DTO.
Future<StreamCryptoResult> _executeInBackground(StreamCryptoRequest request) =>
    Isolate.run(
      () => executeStreamCrypto(request),
      debugName: 'nios-stream-crypto',
    );
