import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:nios_sdk/media.dart';
import 'package:nios_sdk/stream.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  test(
    'closing the player cancels and drains a pending authenticated read',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios-media-cancel-',
      );
      final input = await File(
        p.join(directory.path, 'input'),
      ).writeAsBytes([1, 2, 3]);
      final prepared = await NiosStream.prepareFile(
        inputPath: input.path,
        outputDirectory: p.join(directory.path, 'prepared'),
      );
      final source = _PendingSource();
      final download = await NiosStreamDownload.open(
        directory: p.join(directory.path, 'cache'),
        manifest: prepared.manifest,
        key: prepared.key,
        sources: [source],
      );
      final gateway = await AuthenticatedMediaGateway.bind(download: download);
      final client = http.Client();
      final response = client
          .get(gateway.uri)
          .then<void>((_) {}, onError: (Object _, StackTrace _) {});
      try {
        await source.started.future;
        await gateway.close().timeout(const Duration(seconds: 2));
        expect(source.cancelled, isTrue);
        await response;
        await expectLater(
          download.fetchSegment(
            0,
            cancellation: StreamCancellation()..cancel(),
          ),
          throwsA(isA<StreamCancelledException>()),
        );
      } finally {
        client.close();
        await gateway.close();
        await download.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'native media gateway supports verified ranges without a plaintext cache',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nios-media-gateway-',
      );
      final input = File(p.join(directory.path, 'input'));
      final plaintext = List.generate(100000, (i) => i % 251);
      await input.writeAsBytes(plaintext);
      final prepared = await NiosStream.prepareFile(
        inputPath: input.path,
        outputDirectory: p.join(directory.path, 'prepared'),
        segmentSize: 8192,
      );
      final download = await NiosStreamDownload.open(
        directory: p.join(directory.path, 'cache'),
        manifest: prepared.manifest,
        key: prepared.key,
        sources: [prepared.ciphertextSource],
      );
      final gateway = await AuthenticatedMediaGateway.bind(
        download: download,
        mimeType: 'video/mp4',
      );
      final client = http.Client();
      try {
        final suffix = await client.get(
          gateway.uri,
          headers: {'Range': 'bytes=-317'},
        );
        expect(suffix.statusCode, 206);
        expect(suffix.bodyBytes, plaintext.sublist(plaintext.length - 317));
        expect(suffix.headers['cache-control'], 'no-store');
        final middle = await client.get(
          gateway.uri,
          headers: {'Range': 'bytes=19001-30001'},
        );
        expect(middle.bodyBytes, plaintext.sublist(19001, 30002));
        expect(middle.headers['content-range'], 'bytes 19001-30001/100000');
        expect(
          (await client.get(
            gateway.uri,
            headers: {'Range': 'bytes=100000-'},
          )).statusCode,
          416,
        );
        expect(
          (await client.get(
            gateway.uri,
            headers: {'Range': 'bytes=1-3,5-8'},
          )).statusCode,
          416,
        );
        expect(
          (await client.get(
            gateway.uri.replace(path: '/wrong/media'),
          )).statusCode,
          404,
        );
        final head = await client.head(gateway.uri);
        expect(head.statusCode, 200);
        expect(head.bodyBytes, isEmpty);
        expect(head.headers['content-length'], '100000');
        await gateway.close();
        await download.close();
        final files = await Directory(
          p.join(directory.path, 'cache'),
        ).list(recursive: true).where((e) => e is File).cast<File>().toList();
        for (final file in files) {
          final bytes = await file.readAsBytes();
          expect(
            base64Encode(
              bytes,
            ).contains(base64Encode(plaintext.sublist(20000, 20100))),
            isFalse,
          );
        }
      } finally {
        client.close();
        await gateway.close();
        await download.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

class _PendingSource implements StreamCiphertextSource {
  final started = Completer<void>();
  bool cancelled = false;
  @override
  Future<Uint8List> readRange(
    int start,
    int endExclusive, {
    StreamCancellation? cancellation,
  }) async {
    final pending = Completer<Uint8List>();
    final remove = cancellation!.onCancel(() {
      cancelled = true;
      if (!pending.isCompleted) {
        pending.completeError(const StreamCancelledException());
      }
    });
    started.complete();
    try {
      return await pending.future;
    } finally {
      remove();
    }
  }
}
