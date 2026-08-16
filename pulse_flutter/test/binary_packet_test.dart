import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/calls/binary_packet.dart';

void main() {
  group('media packet', () {
    test('packs and parses header fields', () {
      final iv = Uint8List.fromList(List<int>.generate(12, (i) => i));
      final data = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      final packet = packMediaPacket(iv: iv, encryptedData: data);

      expect(packet[0], kPacketTypeMedia);
      expect(packet.length, 1 + 12 + data.length);
      expect(packet.sublist(1, 13), iv);
      expect(packet.sublist(13), data);
    });
  });

  group('client id packet', () {
    test('parses uint32 id from byte 1', () {
      final packet = Uint8List(5);
      packet[0] = kPacketTypeServerClientId;
      packet[1] = 0x00;
      packet[2] = 0x01;
      packet[3] = 0x02;
      packet[4] = 0x03;
      expect(parseClientIdPacket(packet), 0x00010203);
    });
  });

  group('video frame framing', () {
    test('roundtrips frame type, timestamp and payload', () {
      final jpeg = Uint8List.fromList(List<int>.generate(64, (i) => i * 3));
      final plain = packVideoFramePlain(
        frameType: 0,
        timestamp: 1723799527.5,
        jpeg: jpeg,
      );

      final frame = tryUnpackVideoFrame(plain)!;
      expect(frame, isNotNull);
      expect(frame.frameType, 0);
      expect(frame.timestamp, closeTo(1723799527.5, 0.001));
      expect(frame.jpeg, jpeg);
    });

    test('returns null for opus-like audio payload', () {
      final opus = Uint8List.fromList(<int>[0x38, 0xF1, 0x12, 0x9A, 0x00, 0x33]);
      expect(tryUnpackVideoFrame(opus), isNull);
    });

    test('returns null for payload without full header', () {
      expect(tryUnpackVideoFrame(Uint8List(8)), isNull);
      expect(
        tryUnpackVideoFrame(
          Uint8List.fromList(<int>[0x56, 0x49, 0x44, 0x4F]),
        ),
        isNull,
      );
    });
  });

  group('length prefix', () {
    test('prepends big-endian length', () {
      final framed = addLengthPrefix(Uint8List.fromList(<int>[9, 9, 9]));
      expect(framed.length, 7);
      expect(framed.sublist(0, 4), <int>[0, 0, 0, 3]);
      expect(framed.sublist(4), <int>[9, 9, 9]);
    });
  });
}
