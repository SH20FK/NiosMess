# Comprehensive Architectural Analysis: Chat Details & Message Bubbles (Explorer 2)

## Executive Summary
This report presents an in-depth survey of the Chat Details screen, Message Bubble widgets, consecutive grouping logic, bubble geometry, layout constraints, micro-timestamps, delivery status indicators, and Scroll-to-Bottom FAB in `pulse_flutter` (`f:\Niosmess V2\pulse_flutter`).

---

## 1. Chat Details Screen & Component Architecture

### 1.1 Key Source Files
- **`lib/screens/chat_detail_screen.dart`** (1901 lines) — Primary screen container. Coordinates message streaming via `chatMessagesProvider(chatId)`, app bar, E2EE status banner, older message pagination, message list rendering, scroll listening, and input docking.
- **`lib/widgets/chat/chat_message_list.dart`** (389 lines) — `ListView.builder` (reversed) displaying chronological message streams, date separators, sender avatars, retry buttons, and optimistic upload indicators.
- **`lib/widgets/message_bubble.dart`** (1655 lines) — Main message bubble container handling text styling, mentions, markdown, quotes/replies, forwards, media previews, carousels, circle videos, voice players, reactions, swipe-to-reply, and footer timestamps.
- **`lib/widgets/chat/chat_detail_fab.dart`** (62 lines) — Floating Action Button with animated opacity/scale, M3 badge support, and touch-safety (`IgnorePointer`).
- **`lib/widgets/voice_message_player.dart`** (423 lines) — Standalone voice note audio player with just_audio integration, dynamic waveform rendering, seek gestures, and progress indicators.
- **`lib/widgets/call_bubble.dart`** (129 lines) — Inline bubble representing audio/video call logs.
- **`lib/widgets/chat/chat_detail_app_bar.dart`** (191 lines) — Top navigation bar with avatar, typing subtitle, call triggers, security verification shortcut, and popup menu.
- **`lib/widgets/chat/chat_detail_input_area.dart`** (156 lines) — Bottom input anchor wrapping draft restoration banner and `ChatInputBar`.

### 1.2 Layout & Screen Hierarchy
```
ChatDetailScreen (Scaffold)
 ├── ChatDetailAppBar (PreferredSizeWidget)
 └── PulseScaffoldBody (maxWidth: 1560, bottomSafe: false)
      ├── OfflineBanner (if disconnected)
      ├── E2EE Secret Banner (if secret chat)
      ├── Top Loading Indicator (older messages pagination)
      ├── Expanded -> Stack
      │    ├── messagesAsync.when(...)
      │    │    ├── data: ChatMessageList (ListView.builder, reverse: true)
      │    │    │          ├── DateSeparator
      │    │    │          ├── Sender Avatar (on group tail)
      │    │    │          └── MessageBubble (or Voice / Video / Call)
      │    │    ├── loading: MessageListSkeleton
      │    │    └── error: Error retry card
      │    └── ChatDetailScrollToBottomFAB (Positioned at bottom-right)
      └── ChatDetailInputArea (ChatInputBar, voice/circle recorders)
```

---

## 2. Message Bubble Types & Rendering Pipeline

| Message Type | Widget / Handler | Key Styling & Properties |
|---|---|---|
| **Plain / Mention Text** | `MessageBubble` -> `_parseTextWithMentions` | `bodyMedium` with mention highlights (`scheme.primary` or `scheme.onPrimaryContainer`), markdown bold/italic parsing. |
| **Replies / Quotes** | `MessageBubble` -> `replyPreview` | Vertical left accent bar (`scheme.primary` / `scheme.secondary`), single-line truncated text, indent left padding (48dp). |
| **Forwards** | `MessageBubble` -> `_parseForwarded` | Tonal card container (`surfaceContainerHighest` with alpha 0.4), forward icon, bold label, and original sender name. |
| **Single Image** | `MessageBubble` -> `WsCachedImage` | Fixed size `220x180dp`, `borderRadius: 12dp`, full E2EE decryption support. |
| **Image Carousel** | `MessageBubble` -> `_MediaCarousel` | `PageView.builder` with `viewportFraction: 0.85`, animated scaling, slide indicator `${page}/${total}` badge. |
| **File Attachments** | `MessageBubble` -> `FileTypeDetector` | Fixed width `220dp`, 38x38dp rounded icon tile, file name, file type label & size, chevron action icon. |
| **Voice Notes** | `VoiceMessagePlayer` | `minWidth: 200, maxWidth: 280dp`, play/pause circle button (48x48dp), custom-painted 50-bar audio waveform, scrubbing support. |
| **Circle Video (Video Notes)** | `_CircleVideoInlinePlayer` | Fixed circular dimensions `180x180dp`, `ClipOval`, play/pause overlay, duration badge, overlay footer. |
| **Call Logs** | `CallBubble` | `Card.filled`, `maxWidth: 240dp`, call type icon badge, duration/status subtitle. |
| **Reactions** | `MessageBubble` -> `reactions` Wrap | Pill chips (`surfaceContainerHigh`, `borderRadius: 999`), emoji + count, tap haptics. |
| **Inline Keyboards** | `MessageBubble` -> `_buildInlineKeyboard` | M3 `OutlinedButton`s in wrapped rows with url or callback triggers. |

---

## 3. Consecutive Message Grouping Logic

### 3.1 Precomputation (`chat_message_list.dart:26-75`)
Messages are received in chronological order ($0 = \text{oldest}, len-1 = \text{newest}$).
`_precomputeLayout(List<ApiMessage> messages)` computes a layout token per message:
- **`showDateSep`**:
  - `i == 0` -> `true`
  - `i > 0` -> `messageDate.day != prevDate.day || messageDate.month != prevDate.month || messageDate.year != prevDate.year`
- **`isPrevSame`** (adjacent message *above* in visual feed):
  - `messages[i - 1].senderId == message.senderId && !messages[i - 1].isDeleted && !showDateSep`
- **`isNextSame`** (adjacent message *below* in visual feed):
  - `messages[i + 1].senderId == message.senderId && !messages[i + 1].isDeleted && sameDay`

### 3.2 List Rendering (`chat_message_list.dart:189-378`)
- `ListView.builder` uses `reverse: true`.
- `index = 0` corresponds to `reversedIndex = messages.length - 1` (the newest message at the bottom).
- **Sender Avatar Display**:
  - For incoming messages: Avatar is shown only on the **last** message of a group (`!data.isNextSame`).
  - Consecutive messages above the bottom-most message show `const SizedBox(width: 36)` spacer to maintain visual alignment.

---

## 4. Bubble Geometry & Corner Radius Analysis

### 4.1 Current Implementation (`message_bubble.dart:123-183`)
```dart
// Outgoing (Mine)
_mineRadiusNoneSame = BorderRadius.all(Radius.circular(20));
_mineRadiusPrevSame = BorderRadius.only(topLeft: 20, bottomLeft: 20, topRight: 6, bottomRight: 20);
_mineRadiusNextSame = BorderRadius.only(topLeft: 20, bottomLeft: 20, topRight: 20, bottomRight: 6);
_mineRadiusPrevSameNextSame = BorderRadius.only(topLeft: 20, bottomLeft: 20, topRight: 6, bottomRight: 6);

// Incoming (Theirs)
_theirsRadiusNoneSame = BorderRadius.all(Radius.circular(20));
_theirsRadiusPrevSame = BorderRadius.only(topRight: 20, bottomRight: 20, topLeft: 6, bottomLeft: 20);
_theirsRadiusNextSame = BorderRadius.only(topRight: 20, bottomRight: 20, topLeft: 20, bottomLeft: 6);
_theirsRadiusPrevSameNextSame = BorderRadius.only(topRight: 20, bottomRight: 20, topLeft: 6, bottomLeft: 6);
```

### 4.2 Comparison with Google Messages Signature Geometry
- **Outer Corners**: Google Messages uses **20-22dp** squircle curves. Current 20dp matches the outer spec.
- **Grouped Inner Corners**: Google Messages uses tight **4-6dp** curves on consecutive edges. Current 6dp correctly contracts grouped corners.
- **Corner Inconsistencies Identified**:
  - Media inside bubbles uses hardcoded `BorderRadius.circular(12)` (`message_bubble.dart:754, 825, 1497`), which creates mismatched inner/outer nesting with the bubble container's 20dp/6dp borders.
  - Voice player uses fixed `BorderRadius.circular(16)` instead of adapting to group geometry.
  - Standalone bubbles have symmetrical 20dp radii on all 4 corners; Google Messages often employs an organic asymmetric tail radius (e.g. 20dp top-left, 20dp top-right, 20dp bottom-left, 4-6dp bottom-right for outgoing tail).

---

## 5. Responsive Width Constraints (Desktop, Tablet & Mobile)

### 5.1 Current Max-Width Rules
1. **Screen Level**: `PulseScaffoldBody(maxWidth: 1560)` (`chat_detail_screen.dart:1555`).
2. **Bubble Level** (`message_bubble.dart:291-295`):
   ```dart
   constraints: BoxConstraints(
     maxWidth: MediaQuery.sizeOf(context).width > 600
         ? 460.0
         : MediaQuery.sizeOf(context).width * 0.78,
   ),
   ```
3. **Media / Voice Constraints**:
   - Single Image / Carousel: fixed `width: 220, height: 180`.
   - File Preview: fixed `width: 220`.
   - Voice Player: `minWidth: 200, maxWidth: 280`.
   - Call Bubble: `maxWidth: 240`.

### 5.2 Responsive Assessment
- The `460dp` max-width cap for wide screens (> 600dp) prevents excessive stretching on desktop/tablet, aligning closely with the R2 guideline (`480-560dp`).
- However, fixed media widths (`220dp`) on large screens feel overly constrained when placed next to 460dp text bubbles. Media should dynamically scale up to the bubble max width.

---

## 6. Color Scheme & Tonal Palette Compliance

### 6.1 M3 Token Mapping
- **Outgoing Bubbles (`isMine`)**:
  - Background: `scheme.primaryContainer` (`message_bubble.dart:236`)
  - Text / Foreground: `scheme.onPrimaryContainer` (`message_bubble.dart:239`)
  - Mention Links: `scheme.onPrimaryContainer` (`message_bubble.dart:202`)
  - Checkmarks: `scheme.primary.withValues(alpha: 0.8)` (`message_bubble.dart:1115`)
- **Incoming Bubbles (`!isMine`)**:
  - Background: `scheme.surfaceContainerHigh` (`message_bubble.dart:236`)
  - Text / Foreground: `scheme.onSurface` (`message_bubble.dart:239`)
  - Mention Links: `scheme.primary` (`message_bubble.dart:203`)
  - Sender Display Name: `scheme.primary` (`message_bubble.dart:1041`)
- **Deleted Messages**:
  - Background: `scheme.surfaceContainerHighest`
  - Text: `scheme.onSurfaceVariant`

### 6.2 Visual Contrast
The bubble token mapping strictly aligns with Material 3 Expressive and Google Messages patterns (`primaryContainer`/`onPrimaryContainer` for outgoing, `surfaceContainerHigh`/`onSurface` for incoming).

---

## 7. Micro-timestamps, Status Indicators & Scroll-to-Bottom FAB

### 7.1 Timestamp & Delivery Status (`_MessageBubbleFooter`)
- Located at `Positioned(bottom: 0, right: 0)` in `MessageBubble`.
- E2EE indicator: `Icons.lock_rounded` (11dp) in `scheme.tertiary.withValues(alpha: 0.7)`.
- Edited badge: `Text(context.l10n.chatEdited)` (11dp) in `scheme.onSurfaceVariant.withValues(alpha: 0.7)`.
- Micro-timestamp: `formattedTime` (11dp) in `scheme.onSurfaceVariant.withValues(alpha: 0.7)`.
- Outgoing delivery checkmarks:
  - Read: `Icons.done_all_rounded` (13dp)
  - Sent/Delivered: `Icons.check_rounded` (13dp)
- Sending in progress: `AppLoadingIndicator(size: 14)` on side of bubble.
- Send failed: `IconButton(icon: Icon(Icons.refresh_rounded, color: scheme.error))` on side of bubble.

### 7.2 Scroll-to-Bottom FAB Analysis (`chat_detail_fab.dart` & `chat_detail_screen.dart`)
- **Implementation**:
  - `IgnorePointer(ignoring: !show)` prevents phantom touch blocking when hidden.
  - `AnimatedOpacity` + `AnimatedScale(curve: Curves.easeOutBack)` gives smooth pop-in animation.
  - `Badge` component supports live counter badges.
  - FAB background: `scheme.surfaceContainerHigh`, foreground: `scheme.onSurface`.
- **Identified Deficiency**:
  - In `chat_detail_screen.dart:1714-1723`, `ChatDetailScrollToBottomFAB` is instantiated **without** `unreadCount` (defaults to 0).
  - When user scrolls up and new incoming messages arrive via WebSocket/provider, no live unread count is tracked or passed to the FAB.

---

## 8. AGENTS.md Compliance Audit

| Requirement | Status | Observations / Violations Found |
|---|---|---|
| **Zero hardcoded colors** | ⚠️ Minor Violations | - `message_bubble.dart:682`: `Colors.black.withValues(alpha: 0.38)`<br>- `message_bubble.dart:1609`: `Colors.black.withValues(alpha: 0.62)`<br>- `message_bubble.dart:1613`: `Colors.black.withValues(alpha: 0.25)`<br>- `message_bubble.dart:1627`: `Colors.white.withValues(alpha: 0.25)`<br>- `message_bubble.dart:1628, 1635, 1643`: `Colors.white` |
| **Zero `withOpacity()`** | ✅ Fully Compliant | 0 occurrences across entire codebase; 100% `withValues(alpha: ...)`. |
| **100% Localization (`context.l10n`)** | ⚠️ Minor Violations | - `message_bubble.dart:1637`: `tooltip: 'Отменить'`<br>- `chat_detail_screen.dart:1608-1614`: Secret chat empty state strings ('Секретный чат', etc.)<br>- `chat_detail_screen.dart:1687, 1694, 1705`: 'Подключение к серверу...', 'Восстанавливаем соединение с чатом', 'Обновить' |
| **No `dart:io` imports** | ✅ Fully Compliant | Uses `package:universal_io/io.dart`. |
| **Riverpod Notifier pattern** | ✅ Fully Compliant | Uses Riverpod 3 `NotifierProvider` / `AsyncNotifierProvider`. No deprecated `StateProvider`. |
