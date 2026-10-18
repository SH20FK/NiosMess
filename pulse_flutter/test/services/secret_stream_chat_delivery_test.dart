import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nios_sdk/stream.dart';
import 'package:pulse_flutter/services/secret_chat/secret_stream_service.dart';
import 'package:universal_io/io.dart';

import 'secret_chat_delivery_test.dart' show Pair;

void main() {
  test(
    'stream manifest and authored caption survive ratchet echo and restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'secret-stream-message-',
      );
      final input = await File(
        '${directory.path}/input',
      ).writeAsBytes([1, 2, 3, 4, 5]);
      final prepared = await NiosStream.prepareFile(
        inputPath: input.path,
        outputDirectory: '${directory.path}/encrypted',
      );
      final pair = Pair();
      await pair.start();
      try {
        await pair.settle();
        pair.hub.online = false;
        final file = <String, dynamic>{
          'attachment_id': 'stream_${prepared.manifest.objectId}',
          'key': base64Encode(await prepared.key.extractBytes()),
          'name': 'private-video.mp4',
          'size': 5,
          'mime': 'video/mp4',
          'subtype': 'media',
          'stream': {
            'v': 1,
            'manifest': prepared.manifest.toJson(),
            'manifest_hash': prepared.manifest.hash,
          },
        };
        final descriptor = SecretStreamDescriptor.fromFile(file);
        await pair.a.enqueue(42, {
          'text': 'saved caption',
          'type': 'media',
          'file': file,
        });
        expect(pair.a.messages(42).single['content'], 'saved caption');
        expect(pair.a.messages(42).single['media_url'], descriptor.localUri);
        await pair.a.stop();
        pair.a = await pair.create(1, pair.aDisk, pair.aTransport);
        expect(pair.a.messages(42).single['content'], 'saved caption');
        pair.hub.online = true;
        await pair.settle();
        expect(pair.a.messages(42).single['content'], 'saved caption');
        final received = pair.b.messages(42).single;
        expect(received['media_url'], descriptor.localUri);
        expect(received['media_type'], 'video/mp4');
        expect(received['media_name'], 'private-video.mp4');
        expect(received['e2ee_file_key'], file['key']);
        final sentPacket = pair.hub.attempts.single;
        expect(sentPacket.containsKey('key'), isFalse);
        expect(sentPacket.containsKey('stream'), isFalse);
        expect(sentPacket.containsKey('name'), isFalse);
        expect(sentPacket.containsKey('e2ee_content'), isTrue);
        descriptor.dispose();
      } finally {
        await pair.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
