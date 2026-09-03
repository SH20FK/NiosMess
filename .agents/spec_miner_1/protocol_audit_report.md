# NiosMess Protocol Specification Mining & Alignment Audit Report

**Authoritative Sources Analyzed**:
- `f:/Niosmess V2/calls.html` (Reference Web Calls, SFU binary framing, ECDH/AES-GCM key exchange)
- `f:/Niosmess V2/web.html` (Reference Web Client, E2EE Double Ratchet, file crypto envelopes, WS handlers)
- `f:/Niosmess V2/NiosMess_WS_frontend_integration.md` (Authoritative WS events & realtime actions)
- `f:/Niosmess V2/SERVER_CORE_CHANGES.md` (Recent backend event signatures & handlers)
- `f:/Niosmess V2/ДОКУМЕНТАЦИЯ.md` (Comprehensive backend & protocol documentation)
**Target Codebase**: `f:/Niosmess V2/pulse_flutter`

---

## 1. Specification Matrix: Reference vs Flutter Implementation

### 1.1 Calls & SFU Media Protocol Matrix

| Protocol Component | Authoritative Reference (`calls.html` / `ДОКУМЕНТАЦИЯ.md`) | Flutter Implementation (`pulse_flutter`) | Status | Divergence / Impact |
|---|---|---|---|---|
| **SFU Endpoint (TCP)** | `wss://c.ni-os.ru:4433/ws?room=<roomId>&nick=<nick>` | `WsCallTransport` at `wss://c.ni-os.ru:4433/ws?room=$roomId&nick=$nickname` | ✅ Match | Correct endpoint & parameters |
| **SFU Endpoint (UDP)** | `https://c.ni-os.ru:4433/wt?room=<roomId>&nick=<nick>` | `QuicCallTransport` (mock/local or `pure_dart_quic` in CI) | ⚠️ Partial | QUIC transport has 2s fallback to WS; Web uses WebTransport API |
| **Media Packet (0x01) Client -> SFU** | `[0x01 (1B) \| IV (12B) \| AES-GCM-256 Ciphertext+Tag (NB)]` (Total: 13 + N bytes) | `packMediaPacket`: `[0x01 (1B) \| senderClientId (4B) \| IV (12B) \| Ciphertext (NB)]` (Total: 17 + N bytes) in `binary_packet.dart:100-113` | ❌ **CRITICAL BREAKING BUG** | Client adds extra 4-byte client ID. SFU prepends another 4-byte sender ID when forwarding, shifting IV offset by 4 bytes. Receiver decrypts wrong bytes resulting in `AEADBadTagException` on 100% of frames. |
| **Media Packet (0x01) SFU -> Client** | `[0x01 (1B) \| senderId (4B) \| IV (12B) \| Ciphertext+Tag (NB)]` (Bytes 0: type, 1..5: senderId, 5..17: IV, 17..: ciphertext) | `unpackPacket` in `binary_packet.dart:52-60` and `call_session_io.dart:330-334` | ✅ Match | Reads `senderId` at 1..5, `IV` at 5..17, `ciphertext` at 17.. |
| **Heartbeat / Nickname (0x02) Outgoing** | `[0x02 (1B) \| UTF-8 Nickname (NB)]` (Total: 1 + N bytes) | `packHeartbeatPacket`: `[0x02 \| UTF-8 Nickname]` in `binary_packet.dart:116-125` | ✅ Match | Exact match |
| **Heartbeat / Nickname (0x02) Incoming** | `[0x02 (1B) \| senderId (4B) \| UTF-8 Nickname (NB)]` | `unpackPacket`: `senderClientId = getUint32(1)`, `payload = sublistView(5)` | ✅ Match | Exact match |
| **Server Client ID (0x03)** | `[0x03 (1B) \| assignedClientId (4B)]` | `parseClientIdPacket` in `binary_packet.dart:33-36` | ✅ Match | Reads 4-byte big-endian uint32 |
| **Server End Call (0x04)** | `[0x04 (1B)]` | Handled in `call_session_io.dart:223-226` (`kPacketTypeServerEndCall`) | ✅ Match | Tears down session |
| **Public Key Announce (0x05) Outgoing** | `[0x05 (1B) \| Uncompressed P-256 PubKey (65B: 0x04 \| X \| Y)]` | `packPublicKeyPacket`: `[0x05 \| myPubKeyRaw (65B)]` in `binary_packet.dart:128-136` | ✅ Match | Generates uncompressed 65B EC public key |
| **Public Key Announce (0x05) Incoming** | `[0x05 (1B) \| senderId (4B) \| peerPubKeyRaw (65B)]` | `call_session_io.dart:276-280` reads `peerId` at 1..5, `peerPubKeyRaw` at 5..70 | ✅ Match | Extracts 65-byte peer public key |
| **Key Exchange (0x06) Outgoing** | `[0x06 (1B) \| targetPeerId (4B) \| IV (12B) \| EncryptedSenderKey (48B)]` | `packKeyExchangePacket`: `[0x06 \| peerId (4B) \| iv (12B) \| encryptedKey (48B)]` in `binary_packet.dart:139-152` | ✅ Match | Target peer ID, 12B IV, 48B encrypted 32B AES key |
| **Key Exchange (0x06) Incoming** | `[0x06 (1B) \| senderId (4B) \| IV (12B) \| EncryptedSenderKey (48B)]` | `call_session_io.dart:308-316` reads `senderId` at 1..5, `iv` at 5..17, `encryptedKey` at 17..65 | ✅ Match | Decrypts peer's sender key with shared ECDH secret |
| **Peer Disconnected (0x07)** | `[0x07 (1B) \| senderId (4B)]` | Missing explicit case `0x07` in `call_session_io.dart:206-242` | ⚠️ Divergence | Peer disconnect relying only on stale timeout (10s) instead of immediate 0x07 removal |
| **Verification Fingerprint** | Sorted ascending by uint32 ID, `N * 69` buffer, SHA-256 digest, 4 icons: `val = hash[i] % 64`, `shape = shapes[val / 8]`, `color = colors[val % 8]` (8 SVG shapes, 8 colors) | `E2eeKeyManager.getVerificationEmojis`: maps `byte % 64` to `verificationEmojiList` (animals/objects emojis) | ⚠️ Visual Mismatch | Cryptographic hash calculation matches (`N*69` bytes), but visual representation differs (emoji list vs SVG geometric shape/color matrix). |
| **Audio Codec Parameters** | Opus mono, 48 kHz, 32 kbps, 20 ms frames (960 samples) | `AudioPipeline` uses `RecordConfig` 48 kHz, mono, 20 ms frames, Opus voip | ✅ Match | Correct Opus configuration |
| **Audio Output Playback** | WebCodecs `AudioDecoder` -> `MediaStreamTrackGenerator` (lossless jitter streaming) | `AudioOutputPipeline` encodes PCM into dynamic WAV chunks, calling `audioplayers.play(BytesSource(wav))` every 60ms | ❌ Performance Defect | Audio stutters and pops under load due to continuous player reinitialization; requires native PCM streaming buffer. |

---

### 1.2 WebSocket & Realtime Events Matrix

| Action / Event | Direction | Reference Specification (`NiosMess_WS_frontend_integration.md` / `web.html`) | Flutter Implementation (`pulse_flutter`) | Status | Divergence / Notes |
|---|---|---|---|---|---|
| `key_exchange` | S -> C | `{ "action": "key_exchange", "key": "<base64 32B>" }` | Handled in `web_socket_client.dart:215-232` | ✅ Match | Sets `_secretKey` and completes ready completer |
| `mark_read` | C -> S | `{ "action": "mark_read", "payload": { "chat_id": 123 } }` | `ChatRepository.markAsRead(chatId)` | ✅ Match | Sends `mark_read` |
| `chat_read` | S -> C (Broadcast) | `{ "action": "chat_read", "payload": { "chat_id": 123, "user_id": 42 } }` | Handled in `WebSocketPushDispatcher:149-156` & `backend_chat_provider.dart:126-157` | ✅ Match | Updates read receipts without refetching |
| `edit_message` | C -> S | `{ "action": "edit_message", "payload": { "chat_id": 1, "message_id": 2, "content": "..." } }` | `ChatRepository.editMessage` | ✅ Match | Sends edit request |
| `message_edited` | S -> C (Broadcast) | `{ "action": "message_edited", "payload": { serialized message } }` | Handled in `WebSocketPushDispatcher:121-124` & `backend_chat_provider.dart:208-222` | ✅ Match | Replaces message in state/cache |
| `delete_message` | C -> S | `{ "action": "delete_message", "payload": { "chat_id": 1, "message_id": 2 } }` | `ChatRepository.deleteMessage` | ✅ Match | Sends delete request |
| `message_deleted` | S -> C (Broadcast) | `{ "action": "message_deleted", "payload": { "chat_id": 123, "message_id": 987 } }` | Handled in `WebSocketPushDispatcher:125-132` & `backend_chat_provider.dart:159-178` | ✅ Match | Removes message from state/cache |
| `react` | C -> S | `{ "action": "react", "payload": { "chat_id": 1, "message_id": 2, "emoji": "❤️" } }` | `ChatRepository.reactToMessage` | ✅ Match | Sends reaction toggle |
| `message_reaction` | S -> C (Broadcast) | `{ "action": "message_reaction", "payload": { "chat_id": 123, "message_id": 987, "emoji": "👍", "action": "added"|"removed" } }` | Handled in `WebSocketPushDispatcher:133-148` & `backend_chat_provider.dart:180-206` | ✅ Match | Updates reaction count dynamically |
| `decline_call` | C -> S | `{ "action": "decline_call", "payload": { "chat_id": 123, "room_id": "abc...", "message_id": 987 } }` | `CallRepository.decline` | ✅ Match | Finalizes active call server-side immediately |
| `end_call` / `call_ended` | S -> C (Broadcast) | `{ "action": "end_call", "payload": { "chat_id": 123, "room_id": "...", "message_id": 987, "was_missed": true, "duration": 0, "message": { ... } } }` | Handled in `WebSocketPushDispatcher:157-166` and `call_push_handler.dart:68-84` | ✅ Match | Closes incoming banner and terminates active session |
| `unregister_fcm_token` | C -> S | `{ "action": "unregister_fcm_token", "payload": { "fcm_token": "<token>" } }` | `AuthRepository.unregisterFcmToken` & called in `AuthNotifier.logout()` | ✅ Match | Revokes FCM token on logout |
| `new_call` / `incoming_call_push` | S -> C (Broadcast) | `{ "action": "new_call", "payload": { "chat_id": 1, "room_id": "...", "message_id": 2, "caller_nickname": "...", "is_video": false, "caller_id": 1 } }` | Handled in `call_push_handler.dart:25-64` | ✅ Match | Sets `incomingCallProvider` state |
| `call_joined` | S -> C (Broadcast) | `{ "action": "call_joined", "payload": { "chat_id": 1, "room_id": "...", "message_id": 2 } }` | Missing in `call_push_handler.dart` | ⚠️ Divergence | Web client listens to `call_joined` to transition from calling overlay to active call. |
| `who_writing` / `typing` | S -> C (Broadcast) | `{ "action": "who_writing", "payload": { "chat_id": 1, "user_id": 2, "display_name": "..." } }` | `typing_provider.dart:35-47` only checks `action == 'typing'` and fields `sender_id` and `is_typing` | ⚠️ Divergence | If backend broadcasts `who_writing` with `user_id`, typing indicator is not triggered in Flutter. |
| `new_ng_post` | S -> C (Broadcast) | `{ "action": "new_ng_post", "payload": { serialized post } }` | `niosgram_provider.dart:73-76` checks `msg['data']` instead of `msg['payload']` | ❌ **BUG** | Payload is stored in `payload`, not `data`, causing push posts to be discarded. |
| `notification` | S -> C (Broadcast) | `{ "action": "notification", "payload": { ... } }` | `notifications_provider.dart:94` checks `msg['data']` instead of `msg['payload']` | ❌ **BUG** | Discards push notifications due to looking in `msg['data']`. |
| HTTP File Download | POST `/api/files/download` | Body: `{"token": "...", "file_path": "...", "message_id": ...}` | `chat_repository.dart:851`: `body: '{"token":"$token","file_path":"${cleanPath.replaceAll('"', '\\"')}"'` | ❌ **BUG** | Malformed JSON string (missing closing brace `}`) causes 400 Bad Request on downloads via `ChatRepository.downloadMedia`. |

---

### 1.3 E2EE & Media Encryption Protocol Matrix

| Crypto Component | Authoritative Reference (`web.html`) | Flutter Implementation (`pulse_flutter`) | Status | Divergence / Impact |
|---|---|---|---|---|
| **E2EE Key Pair** | RSA-OAEP 2048-bit (Web Crypto API) | X25519 (Double Ratchet) / Ed25519 Identity | ⚠️ Architecture Difference | Web client uses RSA-OAEP 2048-bit with AES-GCM-256 for secret chats; Flutter implements Signal Double Ratchet with X25519. Both formats are versioned (`v: 2` in Flutter). |
| **File Crypto Envelope (Attachment Encryption)** | Encrypted file bytes: `[ciphertext \| tag (16B)]` (NO nonce in file blob). AES-256-GCM key and 12-byte IV are packaged in JSON metadata: `{"type": "nios_file_key", "keyB64": "...", "ivB64": "..."}` and encrypted into message envelope `e2ee_content`. | `E2eeFileCrypto.encrypt` (`e2ee_file_crypto.dart:27-38`) prepends 12-byte nonce directly to the file blob: `[nonce (12B) \| ciphertext \| tag (16B)]`. | ❌ **INTEROP BREAKING BUG** | Web client cannot decrypt files encrypted by Flutter (file contains 12 extra nonce bytes at offset 0). Flutter cannot decrypt files encrypted by Web (strips first 12 bytes of ciphertext as nonce). |
| **File Chunk Size** | 262,144 bytes (256 KB) via WebSocket `init_upload`/`upload_chunk` or multipart HTTP `/api/files/upload` (up to 50MB) | 262,144 bytes (256 KB) in `chat_repository.dart` and `/api/files/upload` fallback | ✅ Match | Exact 256 KB chunking compatibility |
| **Metadata Encryption** | Secret chat files pass `e2ee_content` containing encrypted `nios_file_key` metadata; normal text is empty. | `sendMessage` in `chat_repository.dart` passes `e2ee_content` | ✅ Match | Metadata envelope structure supported |

---

## 2. List of Critical Bugs & Breaking Divergences with Line Numbers

### BUG #1: SFU Binary Packet 0x01 Extra 4-Byte Offset (Breaks Voice & Video Decryption)
- **Files**: `pulse_flutter/lib/services/calls/binary_packet.dart` (Lines 100–113) & `pulse_flutter/lib/services/calls/call_session_io.dart` (Lines 477–481)
- **Problem**: `packMediaPacket` includes `senderClientId` (4 bytes) at byte offset 1:
  ```dart
  // binary_packet.dart:108-111
  bd.setUint8(0, kPacketTypeMedia);
  bd.setUint32(1, senderClientId);
  packet.setRange(5, 17, iv);
  packet.setRange(17, totalLen, encryptedData);
  ```
- **Authoritative Spec** (`calls.html:1064-1068`):
  ```javascript
  const packet = new Uint8Array(1 + 12 + encryptedBytes.length);
  packet[0] = 0x01; 
  packet.set(iv, 1); 
  packet.set(encryptedBytes, 13);
  ```
  The SFU automatically prepends the forwarding client's 4-byte ID when broadcasting to other peers. Because Flutter embeds its own client ID, the SFU prepends another 4 bytes. The receiver parses bytes 5..17 as IV, which shifts the IV and ciphertext by 4 bytes, causing 100% decryption failures.
- **Fix**: Update `packMediaPacket` to omit `senderClientId` and write `[0x01 (1B) | IV (12B) | encryptedData]`.

---

### BUG #2: E2EE File Encryption Framing Mismatch (Breaks Secret Media Downloads)
- **Files**: `pulse_flutter/lib/core/utils/e2ee_file_crypto.dart` (Lines 27–57)
- **Problem**: `E2eeFileCrypto` prepends the 12-byte nonce to the file binary blob (`[nonce 12B][ciphertext|tag]`).
- **Authoritative Spec** (`web.html:6205-6215` & `web.html:5204-5224`):
  In the reference implementation, the uploaded file contains only the raw AES-GCM output (`[ciphertext | tag (16B)]`). The IV and key are transmitted inside the message envelope JSON metadata:
  ```json
  {
    "type": "nios_file_key",
    "keyB64": "<base64 32-byte key>",
    "ivB64": "<base64 12-byte IV>"
  }
  ```
- **Fix**: Update `E2eeFileCrypto` to support raw file encryption/decryption where IV is passed explicitly from the metadata envelope.

---

### BUG #3: Malformed JSON String in `ChatRepository.downloadMedia`
- **File**: `pulse_flutter/lib/repositories/chat_repository.dart` (Line 851)
- **Problem**:
  ```dart
  body: '{"token":"$token","file_path":"${cleanPath.replaceAll('"', '\\"')}"',
  ```
  Missing closing brace `}` at the end of the JSON string.
- **Fix**: Use `jsonEncode({'token': token, 'file_path': cleanPath})`.

---

### BUG #4: Push Broadcast Field Mismatch in `NiosgramNotifier` and `NotificationsNotifier`
- **Files**:
  - `pulse_flutter/lib/providers/niosgram_provider.dart` (Line 75)
  - `pulse_flutter/lib/providers/notifications_provider.dart` (Line 94)
- **Problem**: Both providers extract event data using `msg['data']`:
  ```dart
  final dynamic data = msg['data'];
  if (data is! Map) return;
  ```
  The WebSocket client (`web_socket_client.dart:261`) dispatches server broadcast objects as `{"action": "...", "payload": { ... }}`. Because `data` is checked instead of `payload`, both `new_ng_post` and `notification` push broadcasts are discarded silently.
- **Fix**: Check `final dynamic data = msg['payload'] ?? msg['data'];`.

---

### BUG #5: Typing Notification Protocol Incompleteness
- **File**: `pulse_flutter/lib/providers/typing_provider.dart` (Lines 34–47)
- **Problem**: Only checks `action == 'typing'` with `sender_id` and `is_typing: bool`.
- **Authoritative Spec** (`web.html:3846` & `web.html:6163-6176`):
  Reference backend also emits `who_writing` with `{ "chat_id": ..., "user_id": ..., "display_name": "..." }`.
- **Fix**: Support both `who_writing` and `typing` actions and accept either `user_id` or `sender_id`.

---

### BUG #6: Missing Peer Disconnect Event (0x07) in Call Session
- **File**: `pulse_flutter/lib/services/calls/call_session_io.dart` (Lines 206–242)
- **Problem**: When a remote peer leaves, the SFU sends packet Type `0x07` (`[0x07 | senderId (4B)]`). `CallSession` does not handle `0x07` in `_handleIncomingPacket`, relying solely on the 10-second heartbeat timeout (`_pruneStaleParticipants`).
- **Fix**: Add `case 0x07` to immediately invoke `_removeParticipant(senderId)` and call `onRemoteParticipantLeft?.call(senderId)`.

---

## 3. Precise Dart Code Definitions for Protocol Fidelity

### 3.1 Corrected Binary Packet Encoders/Decoders (`binary_packet.dart`)

```dart
import 'dart:convert';
import 'dart:typed_data';

const int kPacketTypeMedia = 0x01;
const int kPacketTypeHeartbeat = 0x02;
const int kPacketTypeServerClientId = 0x03;
const int kPacketTypeServerEndCall = 0x04;
const int kPacketTypePublicKey = 0x05;
const int kPacketTypeKeyExchange = 0x06;
const int kPacketTypePeerLeft = 0x07;

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

/// Parse server welcome packet (Type 0x03)
int parseClientIdPacket(Uint8List data) {
  return ByteData.view(data.buffer, data.offsetInBytes, data.length).getUint32(1, Endian.big);
}

/// Unpack incoming server-to-client packet
ParsedPacket unpackPacket(Uint8List data) {
  if (data.isEmpty) {
    return ParsedPacket(type: 0, senderClientId: 0, payload: Uint8List(0));
  }
  final int type = data[0];
  if (data.length < 5) {
    return ParsedPacket(
      type: type,
      senderClientId: 0,
      payload: data.length > 1 ? Uint8List.sublistView(data, 1) : Uint8List(0),
    );
  }

  final int senderClientId = ByteData.view(data.buffer, data.offsetInBytes, data.length).getUint32(1, Endian.big);

  switch (type) {
    case kPacketTypeMedia:
      // [0x01 (1B)][senderId (4B)][IV (12B)][Ciphertext+Tag (NB)]
      final Uint8List iv = Uint8List.sublistView(data, 5, 17);
      final Uint8List payload = Uint8List.sublistView(data, 17);
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: payload,
        iv: iv,
      );
    case kPacketTypeHeartbeat:
      // [0x02 (1B)][senderId (4B)][Nickname UTF-8]
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: Uint8List.sublistView(data, 5),
      );
    case kPacketTypePublicKey:
      // [0x05 (1B)][senderId (4B)][PublicKey (65B)]
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: Uint8List.sublistView(data, 5, 5 + 65),
      );
    case kPacketTypeKeyExchange:
      // [0x06 (1B)][senderId (4B)][IV (12B)][EncryptedKey (48B)]
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: Uint8List.sublistView(data, 17, 65),
        iv: Uint8List.sublistView(data, 5, 17),
      );
    case kPacketTypePeerLeft:
      // [0x07 (1B)][senderId (4B)]
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: Uint8List(0),
      );
    default:
      return ParsedPacket(
        type: type,
        senderClientId: senderClientId,
        payload: Uint8List.sublistView(data, 5),
      );
  }
}

/// Pack outgoing client-to-SFU media packet (Type 0x01).
/// Wire format: [0x01 (1B)][IV (12B)][Encrypted AES-GCM Payload (NB)]
Uint8List packMediaPacket({
  required Uint8List iv,
  required Uint8List encryptedData,
}) {
  final int totalLen = 1 + kAesGcmIvBytes + encryptedData.length;
  final Uint8List packet = Uint8List(totalLen);
  packet[0] = kPacketTypeMedia;
  packet.setRange(1, 13, iv);
  packet.setRange(13, totalLen, encryptedData);
  return packet;
}

/// Pack outgoing client-to-SFU heartbeat packet (Type 0x02).
/// Wire format: [0x02 (1B)][Nickname UTF-8]
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

/// Pack outgoing client-to-SFU public key announce (Type 0x05).
/// Wire format: [0x05 (1B)][Uncompressed P-256 Public Key (65B)]
Uint8List packPublicKeyPacket({
  required Uint8List myPubKeyRaw,
}) {
  assert(myPubKeyRaw.length == 65);
  final int totalLen = 1 + 65;
  final Uint8List packet = Uint8List(totalLen);
  packet[0] = kPacketTypePublicKey;
  packet.setRange(1, totalLen, myPubKeyRaw);
  return packet;
}

/// Pack outgoing client-to-SFU key exchange packet (Type 0x06).
/// Wire format: [0x06 (1B)][TargetPeerID (4B)][IV (12B)][EncryptedKey (48B)]
Uint8List packKeyExchangePacket({
  required int peerId,
  required Uint8List iv,
  required Uint8List encryptedKey,
}) {
  assert(iv.length == 12);
  assert(encryptedKey.length == 48);
  final int totalLen = 1 + 4 + 12 + 48;
  final Uint8List packet = Uint8List(totalLen);
  final ByteData bd = ByteData.view(packet.buffer, packet.offsetInBytes, totalLen);
  bd.setUint8(0, kPacketTypeKeyExchange);
  bd.setUint32(1, peerId, Endian.big);
  packet.setRange(5, 17, iv);
  packet.setRange(17, totalLen, encryptedKey);
  return packet;
}
```

---

### 3.2 Visual Verification Fingerprint Definition (`call_fingerprint.dart`)

```dart
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CallFingerprintIcon {
  const CallFingerprintIcon({required this.shapeIndex, required this.colorHex});
  final int shapeIndex; // 0..7 (Heart, Star, Key, Crown, Lightning, Cloud, Drop, Shield)
  final String colorHex; // '#ff3b30', '#34c759', '#007aff', etc.
}

class CallFingerprintCalculator {
  static const List<String> colors = <String>[
    '#ff3b30', '#34c759', '#007aff', '#ffcc00',
    '#af52de', '#ff9500', '#ff2d55', '#5ac8fa'
  ];

  static Future<List<CallFingerprintIcon>> calculate({
    required int localClientId,
    required Uint8List localPublicKeyRaw,
    required Map<int, Uint8List> peerPublicKeys,
  }) async {
    final List<MapEntry<int, Uint8List>> participants = [
      MapEntry(localClientId, localPublicKeyRaw),
      ...peerPublicKeys.entries,
    ];

    // Sort ascending by uint32 client ID
    participants.sort((a, b) => a.key.compareTo(b.key));

    // Combine participants: 69 bytes each (4 bytes ID + 65 bytes raw key)
    final Uint8List combined = Uint8List(participants.length * 69);
    int offset = 0;
    for (final p in participants) {
      final ByteData bd = ByteData.view(combined.buffer, combined.offsetInBytes + offset, 4);
      bd.setUint32(0, p.key, Endian.big);
      combined.setRange(offset + 4, offset + 69, p.value);
      offset += 69;
    }

    final hash = await Sha256().hash(combined);
    final List<int> hashBytes = hash.bytes;

    final List<CallFingerprintIcon> icons = [];
    for (int i = 0; i < 4; i++) {
      final int val = hashBytes[i] % 64;
      final String color = colors[val % 8];
      final int shapeIndex = val ~/ 8;
      icons.add(CallFingerprintIcon(shapeIndex: shapeIndex, colorHex: color));
    }
    return icons;
  }
}
```

---

### 3.3 Interoperable File Encryption Envelope (`e2ee_file_meta.dart`)

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class NiosFileKeyMeta {
  const NiosFileKeyMeta({
    required this.keyBytes,
    required this.ivBytes,
  });

  final Uint8List keyBytes; // 32 bytes AES-256 key
  final Uint8List ivBytes;  // 12 bytes IV

  factory NiosFileKeyMeta.fromJson(Map<String, dynamic> json) {
    return NiosFileKeyMeta(
      keyBytes: base64Decode(json['keyB64'] as String),
      ivBytes: base64Decode(json['ivB64'] as String),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'nios_file_key',
    'keyB64': base64Encode(keyBytes),
    'ivB64': base64Encode(ivBytes),
  };

  String serialize() => jsonEncode(toJson());
}
```
