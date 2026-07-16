library;

import 'dart:convert';
import 'dart:typed_data';

const int kPacketTypeMedia = 0x01;
const int kPacketTypeHeartbeat = 0x02;
const int kPacketTypeServerClientId = 0x03;
const int kPacketTypeServerEndCall = 0x04;
const int kPacketTypePublicKey = 0x05;
const int kPacketTypeKeyExchange = 0x06;

const int kClientIdBytes = 4;
const int kAesGcmIvBytes = 12;
const int kStreamLengthPrefixBytes = 4;
const int kDatagramSizeLimit = 1100;

class ParsedPacket {
  const ParsedPacket({
    required this.type,
    required this.senderClientId,
    required this.payload,
    this.iv,
  });

  final int type;
  final int senderClientId;
  final Uint8List payload;
  final Uint8List? iv;
}

/// Parse a binary packet from the server (Type 3).
int parseClientIdPacket(Uint8List data) {
  final int clientId = ByteData.view(data.buffer, data.offsetInBytes, data.length).getUint32(1);
  return clientId;
}

/// Unpack a client-to-client or server-to-client packet.
ParsedPacket unpackPacket(Uint8List data) {
  final int type = data[0];
  if (data.length < 5) {
    return ParsedPacket(
      type: type,
      senderClientId: 0,
      payload: data.length > 1 ? Uint8List.sublistView(data, 1) : Uint8List(0),
    );
  }

  final int senderClientId = ByteData.view(data.buffer, data.offsetInBytes, data.length).getUint32(1);

  switch (type) {
    case kPacketTypeMedia:
      final Uint8List iv = Uint8List.sublistView(data, 5, 17);
      final Uint8List payload = Uint8List.sublistView(data, 17);
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: payload,
        iv: iv,
      );
    case kPacketTypeHeartbeat:
      final Uint8List payload = Uint8List.sublistView(data, 5);
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: payload,
      );
    case kPacketTypePublicKey:
      final Uint8List payload = Uint8List.sublistView(data, 5); // 65 bytes public key
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: payload,
      );
    case kPacketTypeKeyExchange:
      // [0x06] + [Sender_ID (4b)] + [IV (12b)] + [EncryptedKey (48b)]
      final Uint8List iv = Uint8List.sublistView(data, 5, 17);
      final Uint8List payload = Uint8List.sublistView(data, 17);
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: payload,
        iv: iv,
      );
    default:
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: Uint8List.sublistView(data, 5),
      );
  }
}

/// Build a media packet to send (Type 1).
Uint8List packMediaPacket({
  required Uint8List iv,
  required Uint8List encryptedData,
}) {
  final int totalLen = 1 + 12 + encryptedData.length;
  final Uint8List packet = Uint8List(totalLen);
  packet[0] = kPacketTypeMedia;
  packet.setRange(1, 13, iv);
  packet.setRange(13, totalLen, encryptedData);
  return packet;
}

/// Build a heartbeat packet (Type 2).
Uint8List packHeartbeatPacket({
  required String nickname,
}) {
  final List<int> nickBytes = utf8.encode(nickname);
  final int totalLen = 1 + nickBytes.length;
  final Uint8List packet = Uint8List(totalLen);
  packet[0] = kPacketTypeHeartbeat;
  packet.setRange(1, totalLen, nickBytes);
  return packet;
}

/// Build a public key packet to send (Type 5).
Uint8List packPublicKeyPacket({
  required Uint8List myPubKeyRaw,
}) {
  final int totalLen = 1 + 65;
  final Uint8List packet = Uint8List(totalLen);
  packet[0] = kPacketTypePublicKey;
  packet.setRange(1, totalLen, myPubKeyRaw);
  return packet;
}

/// Build a key exchange packet to send (Type 6).
Uint8List packKeyExchangePacket({
  required int peerId,
  required Uint8List iv,
  required Uint8List encryptedKey,
}) {
  final int totalLen = 1 + 4 + 12 + 48;
  final Uint8List packet = Uint8List(totalLen);
  final ByteData bd = ByteData.view(packet.buffer, packet.offsetInBytes, totalLen);
  bd.setUint8(0, kPacketTypeKeyExchange);
  bd.setUint32(1, peerId);
  packet.setRange(5, 17, iv);
  packet.setRange(17, totalLen, encryptedKey);
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
