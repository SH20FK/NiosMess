import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/calls/binary_packet.dart';
import 'package:pulse_flutter/services/calls/nios_calls_api.dart';

void main() {
  group('Call Transport & Protocol Tests', () {
    test('NiosCallsApi base URL uses standard HTTPS without 4433', () {
      expect(kCallsBaseUrl, equals('https://c.ni-os.ru'));
      expect(kCallsBaseUrl.contains(':4433'), isFalse);
    });

    test('packMediaPacket and unpackPacket format matches SFU server wire format', () {
      final iv = Uint8List.fromList(List.generate(12, (i) => i + 1));
      final encryptedData = Uint8List.fromList([10, 20, 30, 40, 50]);

      final packet = packMediaPacket(iv: iv, encryptedData: encryptedData);
      expect(packet[0], equals(kPacketTypeMedia)); // 0x01
      expect(packet.sublist(1, 13), equals(iv));
      expect(packet.sublist(13), equals(encryptedData));

      // Simulate SFU relaying packet by injecting 4-byte client ID at bytes 1..5:
      // [0x01][clientId (4B)][iv (12B)][payload]
      final sfuRelayed = Uint8List(1 + 4 + 12 + encryptedData.length);
      sfuRelayed[0] = kPacketTypeMedia;
      final bd = ByteData.view(sfuRelayed.buffer);
      bd.setUint32(1, 12345678);
      sfuRelayed.setRange(5, 17, iv);
      sfuRelayed.setRange(17, sfuRelayed.length, encryptedData);

      final unpacked = unpackPacket(sfuRelayed);
      expect(unpacked.type, equals(kPacketTypeMedia));
      expect(unpacked.senderClientId, equals(12345678));
      expect(unpacked.iv, equals(iv));
      expect(unpacked.payload, equals(encryptedData));
    });

    test('parseClientIdPacket parses server Type 3 packet', () {
      final serverPkt = Uint8List(5);
      serverPkt[0] = kPacketTypeServerClientId;
      ByteData.view(serverPkt.buffer).setUint32(1, 99887766);

      final clientId = parseClientIdPacket(serverPkt);
      expect(clientId, equals(99887766));
    });

    test('packHeartbeatPacket formats nickname correctly', () {
      final pkt = packHeartbeatPacket(nickname: 'TestUser');
      expect(pkt[0], equals(kPacketTypeHeartbeat)); // 0x02
      expect(String.fromCharCodes(pkt.sublist(1)), equals('TestUser'));
    });
  });
}
