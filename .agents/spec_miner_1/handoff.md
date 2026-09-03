# Handoff Report: Protocol Reference & Specification Alignment Audit

**Agent Archetype**: Specification Miner
**Folder**: `.agents/spec_miner_1`
**Date**: 2026-08-21T19:50:00Z

---

## 1. Observation

1. **Calls Protocol & Binary Packets**:
   - In `calls.html:1064-1068`, client creates outgoing 0x01 packet without embedding its client ID:
     `packet = new Uint8Array(1 + 12 + encryptedBytes.length); packet[0] = 0x01; packet.set(iv, 1); packet.set(encryptedBytes, 13);`.
   - In `pulse_flutter/lib/services/calls/binary_packet.dart:100-113`, `packMediaPacket` writes `[0x01 | senderClientId (4B) | iv (12B) | encryptedData (NB)]`.
   - In `calls.html:579-590`, verification fingerprint renders 4 icons from 8 SVG shapes and 8 colors (`val = hash[i] % 64`, `color = colors[val % 8]`, `shape = shapes[val / 8]`), whereas `pulse_flutter/lib/services/calls/e2ee_key_manager.dart:20-29` maps to an arbitrary 64-emoji animal/object list.
   - In `calls.html:1133`, SFU emits packet Type `0x07` (`[0x07 | senderId (4B)]`) when a peer disconnects. `pulse_flutter/lib/services/calls/call_session_io.dart:206-242` omits `case 0x07`.

2. **WebSocket & Realtime Events**:
   - In `pulse_flutter/lib/repositories/chat_repository.dart:851`, `downloadMedia` sends `body: '{"token":"$token","file_path":"${cleanPath.replaceAll('"', '\\"')}"'` missing the closing `}`.
   - In `pulse_flutter/lib/providers/niosgram_provider.dart:75` and `pulse_flutter/lib/providers/notifications_provider.dart:94`, handlers check `msg['data']` instead of `msg['payload'] ?? msg['data']`.
   - In `pulse_flutter/lib/providers/typing_provider.dart:35`, handler only checks `action == 'typing'`, whereas reference backend in `web.html:3846` and `web.html:6163` emits `who_writing` with `{ chat_id, user_id, display_name }`.

3. **E2EE & Attachment File Encryption**:
   - In `web.html:6205-6215` and `web.html:5204-5224`, file binary blob is the raw AES-GCM encrypted ciphertext+tag without nonce. The 12-byte IV and 32-byte key are transmitted inside the message envelope JSON metadata: `{"type": "nios_file_key", "keyB64": "...", "ivB64": "..."}`.
   - In `pulse_flutter/lib/core/utils/e2ee_file_crypto.dart:27-57`, `E2eeFileCrypto.encrypt` prepends 12-byte nonce directly to the file blob (`[nonce 12B | ciphertext | tag 16B]`), breaking decryption interoperability with the web client.

---

## 2. Logic Chain

1. **Media Frame Decryption Logic**:
   - When the client sends packet Type 0x01 to the SFU, the SFU protocol assigns routing headers. Because the SFU inserts the sender's client ID at offset 1 when forwarding to peers, a packet constructed with a client-side sender ID has two sender IDs prepended (`[0x01][SFU_Sender_ID 4B][Client_Sender_ID 4B][IV 12B]...`).
   - The receiver extracts IV from bytes 5..17. Since bytes 5..9 contain `Client_Sender_ID`, only 8 bytes of the real IV and 4 bytes of ciphertext are parsed as IV.
   - Cryptographic verification via AES-GCM fails on every incoming media frame (`AEADBadTagException`).
   - Removing the 4-byte `senderClientId` from `packMediaPacket` aligns the wire format with `calls.html` and restores audio/video streaming.

2. **File Download & Push Routing Logic**:
   - In `ChatRepository.downloadMedia`, the unclosed JSON string causes the backend HTTP parser to reject the POST request with HTTP 400 Bad Request.
   - In `NiosgramNotifier` and `NotificationsNotifier`, the WebSocket client puts broadcast payloads into `msg['payload']`. Because the notifiers check `msg['data']`, `data` evaluates to `null` and the push events are dropped without updating UI state.
   - In `E2eeFileCrypto`, separating IV storage into `nios_file_key` envelope metadata rather than prepending 12 bytes to the binary payload aligns file encryption with `web.html`.

---

## 3. Caveats

1. **QUIC / WebTransport on Native Platforms**:
   - Web uses browser `WebTransport` (UDP/QUIC); Flutter on mobile uses `pure_dart_quic` (local mock in local environment, actual package in CI) with automatic 2-second fallback to `WsCallTransport` (TCP WebSocket).
2. **Double Ratchet vs RSA-OAEP**:
   - `web.html` utilizes RSA-OAEP 2048-bit with AES-GCM-256 for secret chats, while `pulse_flutter` implements Signal Double Ratchet with X25519 (`v: 2` in JSON payload). Both envelopes coexist via message versioning.

---

## 4. Conclusion

The specification mining audit revealed 4 critical breaking bugs and 3 protocol divergences across Calls, WebSocket realtime events, and E2EE file encryption:
- **Critical #1**: Wire offset mismatch in `packMediaPacket` (`binary_packet.dart:100-113`).
- **Critical #2**: File crypto framing divergence in `E2eeFileCrypto` (`e2ee_file_crypto.dart:27-57`).
- **Critical #3**: Malformed JSON string in `ChatRepository.downloadMedia` (`chat_repository.dart:851`).
- **Critical #4**: Ignored push notifications in `NiosgramNotifier` (`niosgram_provider.dart:75`) and `NotificationsNotifier` (`notifications_provider.dart:94`).
- **Divergence #1**: Missing peer disconnect packet (0x07) in `CallSession`.
- **Divergence #2**: Missing `who_writing` action in `TypingNotifier`.
- **Divergence #3**: Visual fingerprint mismatch (emoji list vs SVG shape/color matrix).

Complete Dart definitions and exact diff locations are documented in `protocol_audit_report.md`.

---

## 5. Verification Method

1. **Verify Binary Packet Wire Layout**:
   - Inspect `pulse_flutter/lib/services/calls/binary_packet.dart:100-113` against `calls.html:1064-1068`.
   - Run unit test validating `packMediaPacket(iv: iv, encryptedData: data).length == 1 + 12 + data.length`.
2. **Verify JSON Formats & Push Handlers**:
   - Inspect `pulse_flutter/lib/repositories/chat_repository.dart:851` for valid JSON serialization.
   - Inspect `pulse_flutter/lib/providers/niosgram_provider.dart:75` and `notifications_provider.dart:94` for `payload` vs `data`.
3. **Verify File Crypto Envelope**:
   - Cross-check `pulse_flutter/lib/core/utils/e2ee_file_crypto.dart` against `web.html:6205-6220` and `web.html:5204-5224`.
