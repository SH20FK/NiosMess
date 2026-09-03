# NiosMess (pulse_flutter) Full-Codebase Audit & Master Upgrade Blueprint

**Audit Scope**: UI/UX Design (M3 Expressive), Core Protocols & Realtime Architecture, Riverpod State & Stability, Platform Parity, and Master Roadmap.  
**Target Codebase**: `f:/Niosmess V2/pulse_flutter`  
**Reference Specifications**: `calls.html`, `web.html`, `NiosMess_WS_frontend_integration.md`, `SERVER_CORE_CHANGES.md`, `design.md`, `goal.md`, `ДОКУМЕНТАЦИЯ.md`  
**Date**: 2026-08-22  

---

## Table of Contents
1. [Executive Summary & Architecture Health Scorecard](#1-executive-summary--architecture-health-scorecard)
2. [Domain 1: UI/UX Design & Material 3 Expressive Audit](#2-domain-1-uiux-design--material-3-expressive-audit)
   - 1.1 Chat Details, Bubbles, Reactions & Input Bar
   - 1.2 Profiles, Settings & Theme Tonal Foundations
   - 1.3 Calls UI & Dynamic Controls Dock
   - 1.4 NiosGram Feed, Stories & Fluid Previews
3. [Domain 2: Core Protocols & Realtime Architecture Audit](#3-domain-2-core-protocols--realtime-architecture-audit)
   - 2.1 WebSocket Connection Lifecycle, Handshake & Event Dispatching
   - 2.2 Calls & Media Transport SFU Protocol (Critical Framing Bug & Key Exchange)
   - 2.3 E2EE Double Ratchet & File Crypto Envelope Interoperability
   - 2.4 Media Playback (Waveforms) & Recording Pipelines
4. [Domain 3: Performance, State Management & Stability Audit](#4-domain-3-performance-state-management--stability-audit)
   - 3.1 Riverpod 3.x Architecture, Root Rebuild Cascades & Optimistic Rollbacks
   - 3.2 Memory Leaks, Stream Subscriptions & Controller Lifecycles
   - 3.3 Network Degradation, Disconnect Loops & Malformed Payloads
   - 3.4 Platform Parity: Android APK vs. Flutter Web
5. [Domain 4: Master Upgrade Roadmap & Actionable Implementation Blueprints](#5-domain-4-master-upgrade-roadmap--actionable-implementation-blueprints)
   - Milestone 1: Critical Protocol & Zero-Decryption Fixes
   - Milestone 2: State Stability, Memory Leak Eradication & Web Parity
   - Milestone 3: Material 3 Expressive UI/UX Modernization
   - Milestone 4: VoIP Audio/Video Pipeline Hardening & Quality of Life
6. [Verification, Static Analysis & Testing Guidelines](#6-verification-static-analysis--testing-guidelines)

---

## 1. Executive Summary & Architecture Health Scorecard

An exhaustive, multi-agent line-by-line audit of the entire NiosMess (`pulse_flutter`) codebase was conducted across all UI layers, cryptographic routines, communication protocols, state management notifiers, and build targets.

### System Health Scorecard

| Subsystem | Score | Critical Deficiencies | Key Strengths |
| :--- | :---: | :--- | :--- |
| **Realtime WebSocket & Events** | **88 / 100** | Lack of exponential backoff & ping/pong; typing indicator stale leak; unclosed JSON in file download. | High contract fidelity for `chat_read`, `message_edited`, `message_deleted`, `message_reaction` without refetching. |
| **Calls & SFU Media Transport** | **42 / 100** | **CRITICAL**: 4-byte offset bug in `packMediaPacket` breaks 100% of media decryption; one-way ECDH key exchange lockout; discrete WAV VoIP playback lag. | Correct Opus 48kHz configuration; uncompressed P-256 key generation; dual UDP/TCP transport scaffolding. |
| **E2EE & Cryptography** | **91 / 100** | **INTEROP BUG**: Nonce prepended directly to file binary blob instead of `nios_file_key` envelope metadata, breaking Web interoperability. | Solid Curve25519 Double Ratchet (X25519 + HKDF-SHA256 + AES-GCM-256 with header AAD) and Ed25519 identity verification. |
| **Riverpod State Management** | **74 / 100** | Root `MaterialApp` rebuild cascades on settings changes; optimistic rollback erases incoming WebSocket messages; sync mutations in async `build()`. | Strict adherence to `NotifierProvider` / `AsyncNotifierProvider` (no legacy `StateNotifier` / `StateProvider`). |
| **Memory & Lifecycle Stability** | **68 / 100** | Undisposed `TextEditingController`s in modals; leaked `StreamSubscription`s in call providers and voice player; 1 `AudioPlayer` per voice bubble. | Clean singleton architecture in core services; reactive dispose hooks in custom widgets. |
| **UI/UX & M3 Expressive** | **79 / 100** | Rigid 16px bubble radii; missing unread badge on chat FAB; hardcoded `Colors.black`/`Colors.white`; untranslated strings; rigid 16:10 NiosGram cards. | M3 tonal color scheme foundation; `flutter_m3shapes` custom squircle integration; expressive bottom sheets. |
| **Platform Parity (Android/Web)** | **65 / 100** | `Isolate.run` throws on Web; `OpenFile.open` fails without local filesystem; Web call session is completely stubbed. | `universal_io` used consistently; zero direct `dart:io` imports. |

---

## 2. Domain 1: UI/UX Design & Material 3 Expressive Audit

### 1.1 Chat Details, Bubbles, Reactions & Input Bar

#### A. Message Bubble Geometry & Constraints
- **File**: `pulse_flutter/lib/widgets/message_bubble.dart` (Lines 123–183, Line 292)
- **Defects Identified**:
  1. *Rigid 16px/4px Radii*: `_getBubbleRadius()` hardcodes `Radius.circular(16)` and `Radius.circular(4)`. This creates dated, boxy bubbles that clash with Material 3 Expressive organic squircle curvature.
  2. *Unconstrained Tablet/Desktop Width*: Line 292 uses `constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75)`. On desktop/tablet screens (e.g. 1200px), bubbles stretch to 900px wide, severely compromising readability.
  3. *Static Reaction Badges*: Lines 459–493 render reaction pills without differentiating whether the current user reacted, and lack animated counter scale transitions (`AnimatedSwitcher`).
- **Modernization Blueprint**:
  ```dart
  // Blueprint: Modern M3 Expressive Bubble Geometry with Adaptive Constraints
  static BorderRadius getExpressiveRadius({
    required bool isMe,
    required bool hasPrev,
    required bool hasNext,
  }) {
    const double large = 22.0;
    const double small = 6.0;
    if (isMe) {
      return BorderRadius.only(
        topLeft: const Radius.circular(large),
        topRight: Radius.circular(hasPrev ? small : large),
        bottomLeft: const Radius.circular(large),
        bottomRight: Radius.circular(hasNext ? small : large),
      );
    } else {
      return BorderRadius.only(
        topLeft: Radius.circular(hasPrev ? small : large),
        topRight: const Radius.circular(large),
        bottomLeft: Radius.circular(hasNext ? small : large),
        bottomRight: const Radius.circular(large),
      );
    }
  }

  // Constrain bubble maxWidth adaptively
  final double screenWidth = MediaQuery.sizeOf(context).width;
  final double maxBubbleWidth = screenWidth > 600 ? 460.0 : screenWidth * 0.78;
  ```

#### B. Scroll-to-Bottom Floating Action Button (FAB)
- **File**: `pulse_flutter/lib/widgets/chat/chat_detail_fab.dart` (Lines 23–38)
- **Defects Identified**:
  1. *Missing Unread Counter Badge*: When scrolled up into history, users have no visual feedback on how many new messages have arrived.
  2. *Hit-Test Pointer Leak*: When `show == false`, `FloatingActionButton.small` is faded to opacity 0, but without `IgnorePointer(ignoring: !show)`, it still intercepts touches in the bottom-right corner.
- **Modernization Blueprint**:
  ```dart
  // Blueprint: Expressive Scroll-to-Bottom FAB with Unread Badge & IgnorePointer
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        offset: show ? Offset.zero : const Offset(0, 1.5),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: show ? 1.0 : 0.0,
          child: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount', style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: scheme.error,
            textColor: scheme.onError,
            offset: const Offset(-4, -4),
            child: FloatingActionButton.small(
              heroTag: 'chat_scroll_down_fab',
              onPressed: show ? onPressed : null,
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.primary,
              elevation: 3,
              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
            ),
          ),
        ),
      ),
    );
  }
  ```

#### C. Input Bar & Voice/Video Recording Dock
- **Files**: `pulse_flutter/lib/widgets/chat/chat_input_bar.dart` (Lines 584–600), `voice_recording_panel.dart` (Line 104), `circle_video_recorder_screen.dart` (Lines 201–203)
- **Defects Identified**:
  1. *Hardcoded Gesture Thresholds*: `dy < -60` (lock) and `dx < -120` (cancel) have no visual lock rail or sliding guide.
  2. *Static Waveform Representation*: `voice_recording_panel.dart` generates static 24 bars without real amplitude normalization or dynamic spring expansion.
  3. *Circular Video Letterboxing*: `circle_video_recorder_screen.dart` lacks pinch-to-zoom and torch controls.

---

### 1.2 Profiles, Settings & Theme Tonal Foundations

#### A. Public Profile & Canvas Redraw Optimizations
- **Files**: `pulse_flutter/lib/screens/public_profile_screen.dart` (Lines 119, 468), `pulse_flutter/lib/widgets/profile_header_delegate.dart` (Lines 361–450), `pulse_flutter/lib/widgets/active_color_orb.dart` (Line 41)
- **Defects Identified**:
  1. *Untranslated Russian Strings*: Hardcoded strings in `public_profile_screen.dart` (`'Сервер временно недоступен...'`, `'Чат'`, `'Звонок'`, `'Видео'`, `'Секретный'`). Must use `context.l10n.chat`, `context.l10n.call`, etc.
  2. *Unsafe Router Navigation*: `public_profile_screen.dart:472` uses `context.go('/chat/dm/${profile.username}')` instead of `context.push()`, destroying the backstack.
  3. *GPU Canvas Overdraw*: `_ExpressiveProfileFogPainter` executes 5 radial gradient passes with `blurSigma: 32` on every single scroll pixel change.
  4. *Lifecycle Bug in Theme Listener*: `active_color_orb.dart:41` queries `Theme.of(context)` inside `initState()`, failing to update when theme mode toggles at runtime.

---

### 1.3 Calls UI & Dynamic Controls Dock

- **Files**: `pulse_flutter/lib/screens/calls/active_call_screen.dart` (Lines 16, 21, 32), `active_voice_call_screen.dart` (Line 225), `incoming_call_overlay.dart` (Line 111)
- **Defects Identified**:
  1. *Hardcoded Black/White Colors*: `active_call_screen.dart` uses `backgroundColor: Colors.black`, `Icon(..., color: Colors.white)`, bypassing M3 Expressive dark surface tokens (`colorScheme.surfaceContainerLowest`).
  2. *Hardcoded Security Badge*: Line 225 hardcodes `'E2EE PROTECTED'` instead of a localized string.
  3. *Shadow Hardcoding*: Shadows use `Colors.black.withValues(alpha: 0.35)` instead of `colorScheme.shadow`.

---

### 1.4 NiosGram Feed, Stories & Fluid Previews

- **Files**: `pulse_flutter/lib/screens/niosgram_screen.dart` (Lines 55–58), `pulse_flutter/lib/widgets/post_card.dart` (Lines 220, 338), `fluid_preview_card.dart` (Lines 159, 180)
- **Defects Identified**:
  1. *Rigid 16:10 Aspect Ratio*: `post_card.dart:220` enforces `aspectRatio: 16 / 10`, which cuts off portrait (4:5) and square (1:1) photos. Must support dynamic aspect ratio clamped between 0.8 (4:5) and 1.91 (16:9).
  2. *Hardcoded Test Usernames*: `fluid_preview_card.dart` hardcodes `'SH20FK'` and `'@sh20fk'`.

---

## 3. Domain 2: Core Protocols & Realtime Architecture Audit

### 2.1 WebSocket Connection Lifecycle, Handshake & Event Dispatching

#### A. Reconnection Logic & Liveness Detection
- **Target File**: `pulse_flutter/lib/core/network/web_socket_client.dart` (Lines 130–139)
- **Comparison with Reference (`web.html:3356-3357`)**:
  * *Current Flutter*: Uses a flat 3-second timer with no attempt counter, no exponential scaling, and no jitter.
  * *Reference*: `delay = min(20000, 1200 * pow(2, attempt)) + rand(0..350)`.
  * *Missing Liveness*: `web_socket_client.dart` has **no ping/pong heartbeat timer**, causing half-open TCP connections to hang silently during network handovers.
- **Modernization Blueprint**:
  ```dart
  // Blueprint: Exponential Backoff with Jitter & 25s Ping Liveness
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final int backoffMs = (1200 * math.pow(1.8, math.min(_reconnectAttempts, 6))).toInt();
    final int jitterMs = math.Random().nextInt(400);
    final int totalDelay = math.min(25000, backoffMs + jitterMs);
    
    _reconnectTimer = Timer(Duration(milliseconds: totalDelay), () {
      if (!_closed && !isConnected && !_isConnecting) {
        connect().catchError((e) => debugPrint('[WS] Reconnect failed: $e'));
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (isConnected) {
        sendRaw(jsonEncode({'action': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch}));
      }
    });
  }
  ```

#### B. Event Dispatcher & State Reactivity Matrix

| Event / Action | Backend Push Action | Client Dispatcher Handler | UI Notifier State Reactivity | Refetch Needed? | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Read Receipts** | `chat_read` `{chat_id, user_id}` | `websocket_dispatcher_provider.dart:149` | `ChatsNotifier._handleReadPush`<br>`ChatMessagesNotifier._handleReadPush` | **No** (In-place update) | **Verified Correct** |
| **Message Edit** | `message_edited` `serialized_msg` | `websocket_dispatcher_provider.dart:120` | `ChatsNotifier._handleEditedPush`<br>`ChatMessagesNotifier._handleEditedIncomingMessage` | **No** (Replaces by ID, decrypts E2EE) | **Verified Correct** |
| **Message Delete** | `message_deleted` `{chat_id, message_id}`| `websocket_dispatcher_provider.dart:125` | `ChatsNotifier._handleDeletedPush`<br>`ChatMessagesNotifier._handleDeletedIncomingMessage` | **No** (Removes from list and cache) | **Verified Correct** |
| **Reactions** | `message_reaction` `{chat_id, message_id, emoji, action}` | `websocket_dispatcher_provider.dart:133` | `ChatsNotifier._handleReactionPush`<br>`ChatMessagesNotifier._handleReactionPush` | **No** (Adjusts counters $\pm 1$) | **Verified Correct** |
| **Decline Call** | Client action `decline_call` | `call_repository.dart:70-83` | `incoming_call_overlay.dart:215-224` | **No** (Stops ringing immediately) | **Verified Correct** |
| **End Call** | `end_call` `{chat_id, room_id, was_missed, message}` | `call_push_handler.dart:21, 68-84` | `CallPushHandler._handleEndCall` | **No** (Closes banner & tears down) | **Verified Correct** |
| **Unregister FCM** | Client action `unregister_fcm_token` | `auth_repository.dart:78-83` | `auth_provider.dart:439` (Prior to `logout()`) | **No** | **Verified Correct** |
| **Typing** | `typing` / `who_writing` | `typing_provider.dart:33-58` | `TypingNotifier` | **No** | **Defect**: Missing auto-expiry timer & `who_writing` support. |
| **Push Notifications**| `new_ng_post`, `notification` | `niosgram_provider.dart:75`, `notifications_provider.dart:94` | `NiosgramNotifier`, `NotificationsNotifier` | **No** | **Defect**: Looks in `msg['data']` instead of `msg['payload']`. |

---

### 2.2 Calls & Media Transport SFU Protocol

#### CRITICAL BUG #1: SFU Binary Packet 0x01 Extra 4-Byte Offset
- **Files**: `pulse_flutter/lib/services/calls/binary_packet.dart` (Lines 100–113) & `call_session_io.dart` (Lines 477–481)
- **The Defect**:
  ```dart
  // binary_packet.dart:100-113 (CURRENT BROKEN IMPLEMENTATION)
  Uint8List packMediaPacket({
    required int senderClientId, // <-- 4 BYTES ADDED HERE BY CLIENT
    required Uint8List iv,
    required Uint8List encryptedData,
  }) {
    final packet = Uint8List(1 + 4 + 12 + encryptedData.length);
    final bd = ByteData.sublistView(packet);
    bd.setUint8(0, kPacketTypeMedia);
    bd.setUint32(1, senderClientId); // <-- CAUSES 100% DECRYPTION FAILURE
    packet.setRange(5, 17, iv);
    packet.setRange(17, packet.length, encryptedData);
    return packet;
  }
  ```
- **The Fix** (Per `calls.html:1064-1068`):
  ```dart
  // Blueprint: Correct SFU Media Packet Packaging (1 + 12 + N bytes)
  Uint8List packMediaPacket({
    required Uint8List iv,
    required Uint8List encryptedData,
  }) {
    final int totalLen = 1 + 12 + encryptedData.length;
    final packet = Uint8List(totalLen);
    packet[0] = kPacketTypeMedia; // 0x01
    packet.setRange(1, 13, iv); // 12 bytes IV
    packet.setRange(13, totalLen, encryptedData); // Ciphertext + 16B MAC Tag
    return packet;
  }
  ```

#### CRITICAL BUG #2: One-Way ECDH Key Exchange Lockout
- **File**: `pulse_flutter/lib/services/calls/call_session_io.dart` (Lines 276–327)
- **The Defect**: When Client A connects and broadcasts its `0x05` public key, Client B receives it, derives the shared secret, and sends `0x06` (encrypted sender key) to Client A. But Client B **does not send its own `0x05` public key back to Client A**. Consequently, Client A has no public key for Client B, cannot derive the ECDH key, and fails to decrypt Client B's sender key, resulting in one-way audio lockout.
- **The Fix**: In `_handlePacketPublicKey (0x05)`, if we haven't sent our public key to this peer, immediately send `packPublicKeyPacket()` back.

---

### 2.3 E2EE Double Ratchet & File Crypto Envelope Interoperability

#### CRITICAL BUG #3: File Attachment Nonce Framing Divergence
- **File**: `pulse_flutter/lib/core/utils/e2ee_file_crypto.dart` (Lines 27–57)
- **Comparison with Web Reference (`web.html:6205-6215` & `web.html:5204-5224`)**:
  * *Web Reference*: Encrypted file blob is pure `[ciphertext | 16B tag]`. The 12-byte IV and 32-byte key are transmitted in JSON message metadata:
    `{"type": "nios_file_key", "keyB64": "...", "ivB64": "..."}`.
  * *Flutter Current*: Prepend 12-byte IV directly to the uploaded file binary (`[nonce 12B | ciphertext | 16B tag]`).
  * *Result*: Web client cannot decrypt files sent from Flutter, and Flutter cannot decrypt files sent from Web.
- **The Fix**: Align `E2eeFileCrypto` to keep the file binary as pure `ciphertext + tag`, and encapsulate both `keyB64` and `ivB64` in the `nios_file_key` envelope JSON.

---

### 2.4 Media Playback (Waveforms) & Recording Pipelines

- **Files**: `pulse_flutter/lib/widgets/voice_message_player.dart` (Lines 60, 72–84), `pulse_flutter/lib/core/utils/voice_recorder_service.dart`
- **Defects Identified**:
  1. *Synthetic Waveform*: `voice_message_player.dart` generates pseudo-random bar heights using `(url.hashCode ^ index)` instead of loading real recorded amplitude arrays persisted in the message metadata.
  2. *Single-Player Voice Architecture*: Currently, each voice bubble instantiates its own `AudioPlayer`, leading to excessive audio session handles. A centralized `GlobalVoicePlaybackService` is required.

---

## 4. Domain 3: Performance, State Management & Stability Audit

### 3.1 Riverpod 3.x Architecture, Root Rebuild Cascades & Optimistic Rollbacks

#### A. Root Rebuild Cascade in `main.dart`
- **File**: `pulse_flutter/lib/main.dart` (Line 89)
- **The Defect**:
  ```dart
  // main.dart:89 (CURRENT)
  final UiSettingsState themeSettings = ref.watch(uiSettingsProvider);
  ```
  Watching the entire `uiSettingsProvider` at the root of `PulseApp` causes any settings change (such as toggling haptic feedback or changing sound volume) to invalidate `PulseApp`, forcing a complete rebuild of `MaterialApp.router`, theme generation, and the GoRouter route tree.
- **The Fix**:
  Use selective `ref.watch(uiSettingsProvider.select((s) => s.themeMode))` and `ref.watch(uiSettingsProvider.select((s) => s.seedColor))` so only visual theme mutations trigger root rebuilds.

#### B. Optimistic Rollback Erasing In-Flight Realtime Messages
- **File**: `pulse_flutter/lib/providers/backend_chat_provider.dart` (Lines 997, 1013, 1063) & `niosgram_provider.dart` (Lines 171, 211, 245)
- **The Defect**:
  When editing, deleting, or reacting to a message, the notifier captures `final current = state.value;`. In the `catch (e)` block, it executes `state = AsyncData(current);`. If any new messages arrived via WebSocket while the HTTP request was in-flight, this whole-list rollback completely erases those incoming messages from memory!
- **The Fix**: Apply atomic single-item rollback targeting only the specific `messageId`.

---

### 3.2 Memory Leaks, Stream Subscriptions & Controller Lifecycles

- **Files**: `pulse_flutter/lib/providers/call_session_provider.dart` (Line 65), `call_video_provider.dart` (Line 49), `post_card.dart` (Line 650), `chat_creation_surfaces.dart` (Line 11), `voice_message_player.dart` (Lines 119–127)
- **Inventory of Leaks**:
  1. `CallSessionNotifier`: `_session!.stateStream.listen(...)` is never cancelled or stored in a `StreamSubscription` handle, leaking listeners on call renegotiation.
  2. `CallVideoNotifier`: `existingSub = frameStream.listen(...)` reassigns a pass-by-value argument.
  3. Modal Controllers: `TextEditingController` instances created in `_showEditSheet` (`post_card.dart:650`) and `showStartDirectChatDialog` (`chat_creation_surfaces.dart:11`) are never disposed.
  4. `VoiceMessagePlayer`: Position, duration, and player state streams are subscribed without cancelling previous subscriptions when the audio URL changes.

---

### 3.3 Network Degradation, Disconnect Loops & Malformed Payloads

- **Defects Identified**:
  1. *Logout Reconnect Loop* (`auth_provider.dart:433`): `logout()` clears tokens and deletes Hive boxes, but does not close `WebSocketClient`. `_scheduleReconnect` immediately triggers a loop attempting to reconnect with a null token.
  2. *Malformed Download JSON* (`chat_repository.dart:851`):
     ```dart
     // chat_repository.dart:851 (CURRENT BROKEN STRING - MISSING CLOSING '}')
     body: '{"token":"$token","file_path":"${cleanPath.replaceAll('"', '\\"')}"'
     ```
     This unclosed JSON string causes backend HTTP 400 Bad Request on all media downloads.
  3. *Uncaught Push Notifications* (`niosgram_provider.dart:75`, `notifications_provider.dart:94`): Handlers look up `msg['data']` instead of `msg['payload'] ?? msg['data']`, dropping push events.

---

### 3.4 Platform Parity: Android APK vs. Flutter Web

| Feature / API | Android Implementation | Flutter Web Status | Web Defect / Solution |
| :--- | :--- | :--- | :--- |
| **Encrypted Cache Parsing** | `Isolate.run(...)` (`encrypted_message_cache.dart:72, 105`) | ❌ **Crashes** (`UnsupportedError`) | Guard with `kIsWeb`: execute synchronously or via Web Workers on Web; use `Isolate.run` on native. |
| **File Opening / Preview** | `OpenFile.open(filePath)` (`file_opener.dart:94`) | ❌ **Fails** (No local paths) | On Web, trigger browser download via `html.AnchorElement(href: blobUrl).click()` or open in new tab. |
| **SFU VoIP Calls** | `CallSessionIo` (Opus/PCM pipelines) | ⚠️ **Stubbed** (`call_session_web_stub.dart`) | Implement WebRTC / WebTransport audio bridge using Web Audio API (`AudioContext`). |

---

## 5. Domain 4: Master Upgrade Roadmap & Actionable Implementation Blueprints

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             MASTER UPGRADE ROADMAP                               │
└──────────────────────────────────────────────────────────────────────────────────┘
                                         │
 ┌───────────────────────────────────────┼───────────────────────────────────────┐
 │                                       │                                       │
 ▼                                       ▼                                       ▼
【MILESTONE 1】                         【MILESTONE 2】                         【MILESTONE 3】
Critical Protocol & Wire Fixes          State Stability & Memory Cleanup        M3 Expressive UI Modernization
├── Fix packMediaPacket offset          ├── Root rebuild cascade fix in main.dart├── 22dp/6dp squircle message bubbles
├── Fix 0x05 key exchange lockout       ├── Atomic optimistic rollback in chat   ├── Unread badge on scroll-to-bottom FAB
├── Fix E2EE file crypto envelope       ├── Dispose all modal TextEditingContr.  ├── Dynamic aspect ratio NiosGram cards
├── Fix chat_repository download JSON   ├── Cancel leaked stream subscriptions   ├── Replace hardcoded black/white colors
└── Fix push payload key mapping        └── Web-safe Isolate.run & FileOpener    └── Localize all hardcoded strings
                                         │
                                         ▼
                                【MILESTONE 4】
                                VoIP Audio/Video Hardening & Web Parity
                                ├── Native streaming PCM audio sink for VoIP
                                ├── Real waveform amplitude persistence
                                ├── Video frame double-encoding elimination
                                └── WebTransport / WebAudio VoIP support on Web
```

### Detailed Milestone Specifications

#### Milestone 1: Critical Protocol & Zero-Decryption Fixes
- **Priority**: P0 (Blocker)
- **Target Files**:
  * `pulse_flutter/lib/services/calls/binary_packet.dart`
  * `pulse_flutter/lib/services/calls/call_session_io.dart`
  * `pulse_flutter/lib/core/utils/e2ee_file_crypto.dart`
  * `pulse_flutter/lib/repositories/chat_repository.dart`
  * `pulse_flutter/lib/providers/niosgram_provider.dart`
  * `pulse_flutter/lib/providers/notifications_provider.dart`
- **Concrete Changes**:
  1. Refactor `packMediaPacket` to remove `senderClientId` (emit 13 + N bytes).
  2. Implement bidirectional `0x05` public key exchange handshake in `CallSessionIo`.
  3. Separate 12-byte IV from file binary into `nios_file_key` envelope JSON metadata.
  4. Fix malformed JSON closing brace in `ChatRepository.downloadMedia`.
  5. Update `NiosgramNotifier` and `NotificationsNotifier` to parse `msg['payload'] ?? msg['data']`.

#### Milestone 2: State Stability, Memory Leak Eradication & Web Parity
- **Priority**: P1 (High)
- **Target Files**:
  * `pulse_flutter/lib/main.dart`
  * `pulse_flutter/lib/providers/backend_chat_provider.dart`
  * `pulse_flutter/lib/providers/auth_provider.dart`
  * `pulse_flutter/lib/core/storage/encrypted_message_cache.dart`
  * `pulse_flutter/lib/core/utils/file_opener.dart`
  * `pulse_flutter/lib/widgets/post_card.dart`
  * `pulse_flutter/lib/widgets/chat_creation_surfaces.dart`
- **Concrete Changes**:
  1. Scope `ref.watch` in `main.dart` to `uiSettingsProvider.select(...)`.
  2. Implement atomic message rollback in `backend_chat_provider.dart` and `niosgram_provider.dart`.
  3. Close `WebSocketClient` on `authNotifier.logout()`.
  4. Wrap `Isolate.run` in `kIsWeb` check in `encrypted_message_cache.dart`.
  5. Add Web blob download anchor in `file_opener.dart`.
  6. Add proper `.dispose()` calls to all modal dialog controllers.

#### Milestone 3: Material 3 Expressive UI/UX Modernization
- **Priority**: P2 (Medium-High)
- **Target Files**:
  * `pulse_flutter/lib/widgets/message_bubble.dart`
  * `pulse_flutter/lib/widgets/chat/chat_detail_fab.dart`
  * `pulse_flutter/lib/widgets/post_card.dart`
  * `pulse_flutter/lib/screens/calls/active_call_screen.dart`
  * `pulse_flutter/lib/screens/public_profile_screen.dart`
  * `pulse_flutter/lib/widgets/active_color_orb.dart`
  * `pulse_flutter/lib/l10n/app_en.arb` & `app_ru.arb`
- **Concrete Changes**:
  1. Upgrade message bubbles to 22dp/6dp continuous squircle curves with adaptive max width (460dp).
  2. Add M3 `Badge` with incoming count and `IgnorePointer` to `ChatDetailScrollToBottomFAB`.
  3. Implement dynamic aspect ratio media containers (clamped 0.8 to 1.91) in NiosGram `post_card.dart`.
  4. Replace `Colors.black`/`Colors.white` with semantic theme tokens in Calls UI.
  5. Move `Theme.of(context)` out of `initState()` in `active_color_orb.dart`.
  6. Extract all hardcoded Russian and English UI strings into `.arb` localization files.

#### Milestone 4: VoIP Audio/Video Pipeline Hardening & Quality of Life
- **Priority**: P3 (Polish)
- **Target Files**:
  * `pulse_flutter/lib/services/calls/audio_output_pipeline.dart`
  * `pulse_flutter/lib/services/calls/video_pipeline.dart`
  * `pulse_flutter/lib/widgets/voice_message_player.dart`
  * `pulse_flutter/lib/core/utils/voice_recorder_service.dart`
- **Concrete Changes**:
  1. Replace discrete WAV re-creation with continuous PCM streaming buffer.
  2. Eliminate `img.encodePng` intermediate step in video pipeline, streaming directly from camera YUV/NV21 to JPEG.
  3. Persist real amplitude sample arrays with voice messages and render dynamic waveforms.
  4. Implement centralized `GlobalVoicePlaybackService` singleton pool.

---

## 6. Verification, Static Analysis & Testing Guidelines

### 6.1 Static Analysis Verification
Run flutter analyzer across the codebase to ensure zero lint violations:
```bash
cd "f:/Niosmess V2/pulse_flutter"
flutter analyze
```

### 6.2 Wire Protocol Framing Unit Test
Verify binary packet packing offsets:
```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/calls/binary_packet.dart';

void main() {
  test('packMediaPacket wire layout compliance (calls.html)', () {
    final iv = Uint8List(12);
    final encryptedData = Uint8List(48); // 32B payload + 16B tag
    final packet = packMediaPacket(iv: iv, encryptedData: encryptedData);
    
    // Total length must be 1 (type) + 12 (IV) + 48 (data) = 61 bytes
    expect(packet.length, equals(61));
    expect(packet[0], equals(0x01)); // kPacketTypeMedia
    expect(packet.sublist(1, 13), equals(iv));
    expect(packet.sublist(13), equals(encryptedData));
  });
}
```

### 6.3 E2EE File Encryption Envelope Verification
Verify file crypto envelope structure matches Web client:
```dart
test('E2EE file crypto envelope contains separate key and IV metadata', () async {
  final rawBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
  final result = await E2eeFileCrypto.encrypt(rawBytes);
  
  // Encrypted bytes must NOT contain the 12-byte IV at offset 0
  expect(result.encryptedBytes.length, equals(rawBytes.length + 16)); // ciphertext + 16B MAC
  expect(result.keyBase64.isNotEmpty, isTrue);
  expect(result.ivBase64.isNotEmpty, isTrue);
});
```

---
*Report compiled and certified by Project Orchestration Team.*
