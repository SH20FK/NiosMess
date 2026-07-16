library;

import 'dart:convert';
import 'dart:typed_data';

const int kPacketTypeAudio = 0x00;
const int kPacketTypeHeartbeat = 0x01;
const int kPacketTypeVideo = 0x02;
const int kPacketTypeServerClientId = 0x03;
const int kPacketTypeServerEndCall = 0x04;

const int kClientIdBytes = 4;
const int kAesGcmIvBytes = 12;
const int kVideoTimestampBytes = 8;
const int kVideoFrameTypeBytes = 1;
const int kAudioIvOffset = 5;
const int kAudioPayloadOffset = 17;
const int kVideoFrameTypeOffset = 5;
const int kVideoTimestampOffset = 6;
const int kVideoIvOffset = 14;
const int kVideoPayloadOffset = 26;
const int kStreamLengthPrefixBytes = 4;

const int kDatagramSizeLimit = 1100;

class ParsedPacket {
  const ParsedPacket({
    required this.type,
    required this.senderClientId,
    required this.payload,
    this.iv,
    this.videoFrameType,
    this.videoTimestamp,
  });

  final int type;
  final int senderClientId;
  final Uint8List payload;
  final Uint8List? iv;
  final int? videoFrameType;
  final double? videoTimestamp;
}

/// Parse a binary packet from the server (Type 3 or Type 4).
int parseClientIdPacket(Uint8List data) {
  final int clientId = ByteData.view(data.buffer, data.offsetInBytes, data.length).getUint32(1);
  return clientId;
}

bool parseEndCallPacket(Uint8List data) {
  if (data.length < 9) return false;
  final String marker = utf8.decode(data.sublist(1));
  return marker == 'end_call';
}

/// Unpack a client-to-server media packet.
ParsedPacket unpackPacket(Uint8List data) {
  final int type = data[0];
  final int clientId = ByteData.view(data.buffer, data.offsetInBytes, data.length).getUint32(1);

  switch (type) {
    case kPacketTypeAudio:
      final Uint8List iv = Uint8List.sublistView(data, 5, 17);
      final Uint8List payload = Uint8List.sublistView(data, 17);
      return ParsedPacket(
        type: type,
        senderClientId: clientId,
        payload: payload,
        iv: iv,
      );
    case kPacketTypeVideo:
      final int frameType = data[5];
      final double timestamp = ByteData.view(data.buffer, data.offsetInBytes, data.length).getFloat64(6);
      final Uint8List iv = Uint8List.sublistView(data, 14, 26);
      final Uint8List payload = Uint8List.sublistView(data, 26);
      return ParsedPacket(
        type: type,
        senderClientId: clientId,
        payload: payload,
        iv: iv,
        videoFrameType: frameType,
        videoTimestamp: timestamp,
      );
    case kPacketTypeHeartbeat:
      final Uint8List payload = Uint8List.sublistView(data, 5);
      return ParsedPacket(
        type: type,
        senderClientId: clientId,
        payload: payload,
      );
    default:
      return ParsedPacket(
        type: type,
        senderClientId: clientId,
        payload: Uint8List.sublistView(data, 5),
      );
  }
}

/// Build an audio packet (Type 0).
Uint8List packAudioPacket({
  required int clientId,
  required Uint8List iv,
  required Uint8List encryptedOpus,
}) {
  final int totalLen = 1 + 4 + 12 + encryptedOpus.length;
  final Uint8List packet = Uint8List(totalLen);
  final ByteData bd = ByteData.view(packet.buffer, packet.offsetInBytes, totalLen);
  bd.setUint8(0, kPacketTypeAudio);
  bd.setUint32(1, clientId);
  packet.setRange(5, 17, iv);
  packet.setRange(17, totalLen, encryptedOpus);
  return packet;
}

/// Build a heartbeat packet (Type 1).
Uint8List packHeartbeatPacket({
  required int clientId,
  required String nickname,
}) {
  final List<int> nickBytes = utf8.encode(nickname);
  final int totalLen = 1 + 4 + nickBytes.length;
  final Uint8List packet = Uint8List(totalLen);
  final ByteData bd = ByteData.view(packet.buffer, packet.offsetInBytes, totalLen);
  bd.setUint8(0, kPacketTypeHeartbeat);
  bd.setUint32(1, clientId);
  packet.setRange(5, totalLen, nickBytes);
  return packet;
}

/// Build a video packet (Type 2).
Uint8List packVideoPacket({
  required int clientId,
  required int frameType,
  required double timestamp,
  required Uint8List iv,
  required Uint8List encryptedVp8,
}) {
  final int totalLen = 1 + 4 + 1 + 8 + 12 + encryptedVp8.length;
  final Uint8List packet = Uint8List(totalLen);
  final ByteData bd = ByteData.view(packet.buffer, packet.offsetInBytes, totalLen);
  bd.setUint8(0, kPacketTypeVideo);
  bd.setUint32(1, clientId);
  bd.setUint8(5, frameType);
  bd.setFloat64(6, timestamp);
  packet.setRange(14, 26, iv);
  packet.setRange(26, totalLen, encryptedVp8);
  return packet;
}

/// Add Length-Prefixed Framing for WebTransport Streams.
Uint8List addLengthPrefix(Uint8List packet) {
  final Uint8List framed = Uint8List(4 + packet.length);
  final ByteData bd = ByteData.view(framed.buffer, framed.offsetInBytes, framed.length);
  bd.setUint32(0, packet.length);
  framed.setRange(4, framed.length, packet);
  return framed;
}
