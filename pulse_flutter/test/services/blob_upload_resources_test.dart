import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/services/blob_store_service.dart';
import 'package:universal_io/io.dart';

class _NoAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial();
}

void main() {
  test(
    'successful chunk waits for response consumption and keeps borrowed client open',
    () async {
      final response = StreamController<List<int>>();
      var sent = false;
      final client = MockClient.streaming((request, body) async {
        await body.drain<void>();
        if (request.method == 'GET') {
          return http.StreamedResponse(const Stream.empty(), 200);
        }
        sent = true;
        expect(request, isA<http.AbortableRequest>());
        return http.StreamedResponse(response.stream, 204);
      });
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(_NoAuth.new)],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      final service = container.read(
        Provider((ref) => BlobStoreService(ref, client: client)),
      );
      var complete = false;
      final upload = service
          .uploadChunk(
            blobId: 'blob',
            chunkIndex: 0,
            bytes: Uint8List.fromList([1, 2, 3]),
          )
          .then((_) => complete = true);
      await Future<void>.delayed(Duration.zero);
      expect(sent, isTrue);
      expect(complete, isFalse);
      response.add([42]);
      await response.close();
      await upload;
      expect(complete, isTrue);
      service.dispose();
      // Disposing a service does not close a caller-owned transport.
      final another = await client.send(
        http.Request('GET', Uri.parse('https://test.invalid')),
      );
      await another.stream.drain<void>();
    },
  );

  test(
    'cancellation after headers consumes response before returning cancellation',
    () async {
      final token = CancellationToken();
      var consumed = false;
      final client = MockClient.streaming((request, body) async {
        await body.drain<void>();
        token.cancel();
        return http.StreamedResponse(
          Stream<List<int>>.multi((controller) {
            controller.add([1]);
            consumed = true;
            controller.close();
          }),
          200,
        );
      });
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(_NoAuth.new)],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      final service = container.read(
        Provider((ref) => BlobStoreService(ref, client: client)),
      );
      await expectLater(
        service.uploadChunk(
          blobId: 'blob',
          chunkIndex: 0,
          bytes: Uint8List.fromList([1]),
          cancellationToken: token,
        ),
        throwsA(isA<UploadCancelledException>()),
      );
      expect(consumed, isTrue);
    },
  );

  test(
    'resumable chunks can reuse one open file handle in arbitrary order',
    () async {
      final dir = await Directory.systemTemp.createTemp('nios_chunks_');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File(
        '${dir.path}/upload',
      ).writeAsBytes([0, 1, 2, 3, 4, 5, 6]);
      final handle = await file.open();
      try {
        expect(
          await BlobStoreService.sliceChunkBytes(
            fileHandle: handle,
            chunkIndex: 2,
            chunkSize: 3,
            totalSize: 7,
          ),
          [6],
        );
        expect(
          await BlobStoreService.sliceChunkBytes(
            fileHandle: handle,
            chunkIndex: 0,
            chunkSize: 3,
            totalSize: 7,
          ),
          [0, 1, 2],
        );
      } finally {
        await handle.close();
      }
    },
  );
}
