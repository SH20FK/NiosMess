# Investigation Analysis: Chat Input Bar, Voice Controls, Attachments, Context Menu & Reactions Dock

**Project**: NiosMess (`pulse_flutter`)  
**Investigator**: Explorer 3  
**Date**: 2026-08-31  
**Target Milestone**: Google Messages Redesign & M3 Expressive Polish

---

## Executive Summary

This investigation explores the current implementation of the chat input surface, voice note controls, attachment picker, message context menu, and quick reactions dock in `pulse_flutter`. The existing architecture is modular, well-structured, and leverages Riverpod 3.x, Material 3, and custom services. To achieve the signature **Google Messages** design and interaction polish, specific architectural and visual upgrades have been mapped across 5 core functional areas.

---

## 1. Chat Input Bar Architecture & Styling

### 1.1 Current Architecture & File Placement
- **File**: `lib/widgets/chat/chat_input_bar.dart` (685 lines)
- **Container Wrapper**: `lib/widgets/chat/chat_detail_input_area.dart` (156 lines)
- **Screen Integration**: `lib/screens/chat_detail_screen.dart` (lines 1727–1760)

```
ChatDetailScreen
 └── ChatDetailInputArea
      ├── (Optional) Draft Restored Banner [tertiaryContainer]
      ├── (Optional) Channel Read-Only Notice (if not allowed to post)
      └── ChatInputBar (StatefulWidget)
           ├── (Optional) Edit Message Banner [primaryContainer / primary left border]
           ├── (Optional) Reply Preview Banner [surfaceContainerHigh / secondary left border]
           ├── VoiceRecordingPanel (shown when _isRecording == true)
           ├── Input Row (shown when _isRecording == false)
           │    ├── Text Input Pill Container [surfaceContainerLow + border]
           │    │    ├── Emoji Toggle Button (Icons.emoji_emotions_outlined / Icons.keyboard_outlined)
           │    │    ├── Multiline TextField (1–5 lines, Enter/Shift+Enter handling)
           │    │    ├── AI Assistant Action Button (Icons.auto_awesome_rounded / AppLoadingIndicator)
           │    │    └── Media Attachment Action Button (Icons.attach_file_rounded)
           │    └── Mic/Video Record Button OR Send/Commit Button (48x48dp circle)
           └── EmojiPicker Sheet (380dp animated drawer with M3EmojiSearchView)
```

### 1.2 Text Input Container Styling & State Transitions
- **Current Container Decoration** (`chat_input_bar.dart:328-337`):
  ```dart
  decoration: BoxDecoration(
    color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: widget.inputFocusNode.hasFocus
          ? scheme.primary.withValues(alpha: 0.45)
          : scheme.outlineVariant.withValues(alpha: 0.30),
      width: 1.0,
    ),
  )
  ```
- **Analysis & Redesign Targets (Google Messages R3)**:
  1. **Container Shape**: Update from `BorderRadius.circular(22)` to the authentic Google Messages pill shape (`BorderRadius.circular(28)`).
  2. **Tonal Elevation / Fill**: Replace low-opacity `surfaceContainerLow.withValues(alpha: 0.5)` with solid tonal `scheme.surfaceContainerHighest` or `scheme.surfaceContainerHigh`. Remove artificial thin outline borders in favor of clean M3 Expressive container fill and tonal depth.
  3. **Dynamic Expand/Collapse**: The text field currently uses `ConstrainedBox(minHeight: 52, maxHeight: 140)` with `TextField(maxLines: 5, minLines: 1)`. Ensure smooth curve transitions when typing multiline text.
  4. **Action Button Switching**:
     - Controlled by `_isInputEmpty && widget.editingMessageId == null`.
     - Switches between `_buildRecordButton` (Mic/Video) and `_buildSendButton` (Send/Commit) via `AnimatedSwitcher` + `ScaleTransition` (180ms).
     - Single tap on record button toggles `_isVideoMode` (Mic ↔ Circle Video) with `tertiary` vs `primary` color transition.

---

## 2. Voice Recording Controls & Dynamic Amplitude Waveforms

### 2.1 Component & Service Structure
- **Service**: `lib/core/utils/voice_recorder_service.dart` (112 lines)
  - Uses `record` package (`AudioRecorder`).
  - Timer tick for elapsed duration (1-second intervals).
  - Amplitude polling timer (100ms interval):
    $$\text{normalized} = \left(\frac{\text{dbfs} + 50.0}{50.0}\right).\text{clamp}(0.0, 1.0)$$
  - Duration formatting: `VoiceRecorderService.formatDuration(d)` with `FontFeature.tabularFigures()` for zero jitter.
- **Panel Widget**: `lib/widgets/chat/voice_recording_panel.dart` (310 lines)

### 2.2 Gesture & State Workflow
1. **Initiation**: Long-press on the Record button (`GestureDetector.onLongPressStart` in `chat_input_bar.dart:568`).
2. **Dragging Mode (`_buildDraggingMode`)**:
   - `onLongPressMoveUpdate` tracks `details.localOffsetFromOrigin` -> `_recordingDragOffset`.
   - **Real-time Lock Detection**: `if (details.localOffsetFromOrigin.dy < -60 && !_isRecordingLocked)` -> triggers `HapticService.confirm()` and sets `_isRecordingLocked = true`.
   - **Slide to Cancel**: `if (dx < -120)` on release -> calls `_cancelVoiceRecording()` (`HapticService.destructive()`).
   - **Send on Release**: If not locked and not cancelled, calls `_sendVoiceRecording()` (`HapticService.confirm()`).
3. **Locked Mode (`_buildLockedMode`)**:
   - Lock badge pill (`primaryContainer`).
   - Pulsing mic indicator (`scheme.error`).
   - Real-time tabular timer (`mm:ss`).
   - Waveform visualizer (24 bars).
   - Cancel / Delete button (error container icon button) and Send button (primary icon button).

### 2.3 Visual Waveform Bars
- Rendered via `_buildWaveform`: 24 vertical bars (`barCount = 24`), bar width 3.0dp, max height 28dp.
- Heights animated smoothly via `AnimatedContainer(duration: Duration(milliseconds: 80))`.
- Bars colored with `scheme.primary.withValues(alpha: 0.7)`.

### 2.4 Google Messages Polish Recommendations
1. **Vertical Lock Rail**: Add an expressive vertical sliding rail guide above the record button during touch-drag, displaying a lock icon and upward progress chevron track that fills dynamically as $dy \to -60\text{dp}$.
2. **Horizontal Cancel Rail**: Display an animated horizontal slide track with chevron pulses and red tint progression as $dx \to -120\text{dp}$.
3. **Dynamic Waveform Polish**: Use rounded squircle caps on waveform bars with tonal gradient fill for expressive audio feedback.

---

## 3. Attachment Bottom Sheet (`m3_file_picker_bottom_sheet.dart`)

### 3.1 Current Implementation
- **File**: `lib/widgets/m3_file_picker_bottom_sheet.dart` (242 lines)
- **Invocation**: `showM3FilePicker(context)` called from `ChatDetailScreen._pickAndUploadMedia()` (`chat_detail_screen.dart:789`).
- **Current Items**: Currently only renders 3 items in a single horizontal row (`Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly)`):
  1. **Gallery**: `Icons.photo_rounded`, `filePickerGallery`, `primaryContainer` -> opens `MediaGridPicker` (or `FileType.media` on Web).
  2. **Document**: `Icons.description_rounded`, `filePickerDocument`, `secondaryContainer` -> `FilePicker.pickFiles(type: FileType.custom, allowedExtensions: [...])`.
  3. **Audio**: `Icons.music_note_rounded`, `filePickerAudio`, `tertiaryContainer` -> `FilePicker.pickFiles(type: FileType.audio)`.

### 3.2 Redesign Requirements (Google Messages R3)
- Transform from a simple 3-item row into an **Expressive Material 3 Grid with Rounded Cards**:
  - Grid layout: 2 rows of 3 columns or adaptive wrap grid of rounded cards.
  - Required Options:
    1. **Gallery** (`Icons.photo_library_rounded` / `Icons.photo_rounded`): Media gallery picker.
    2. **Camera** (`Icons.camera_alt_rounded`): Direct photo/video capture using device camera / `camera` package.
    3. **File / Document** (`Icons.description_rounded`): Document and general file picker.
    4. **Contact** (`Icons.person_pin_rounded` / `Icons.contact_phone_rounded`): Contact vCard sharing.
    5. **Location** (`Icons.location_on_rounded`): Live / pinned map location sharing.
    6. **Audio** (`Icons.music_note_rounded`): Audio and music file picker.
  - Card Visuals:
    - M3 surface container cards (`surfaceContainerHigh` or individual tonal container palettes: `primaryContainer`, `secondaryContainer`, `tertiaryContainer`, `surfaceContainerHighest`).
    - 56x56dp tonal squircle/circle icon avatars with 26dp icons.
    - Clear label typography (`textTheme.labelMedium` with `fontWeight: FontWeight.w600`).
    - Rounded corners: `BorderRadius.circular(20)`.

---

## 4. Message Context Menu & Quick Reactions Dock

### 4.1 Component Structure & Invocation
- **Context Menu File**: `lib/widgets/message_context_menu_sheet.dart` (501 lines)
- **Message Bubble File**: `lib/widgets/message_bubble.dart` (lines 278–289)
- **Trigger**: Long-press on `MessageBubble` or secondary right-click invokes `HapticService.confirm()` and opens `_showMessageActions()` in `ChatDetailScreen`.

### 4.2 Current Sheet Layout (`MessageContextMenuSheet`)
1. **Message Preview Card (`_MessagePreviewCard`)**:
   - `surfaceContainerHigh` container with 16dp rounded corners.
   - Colored indicator stripe (3dp width, `primary` if mine, `secondary` if incoming).
   - Excerpt of message content (up to 2 lines), timestamp, and media type thumbnail icon.
2. **Reactions Row (`_ReactionsRow`)**:
   - `surfaceContainerLow` container with 16dp rounded corners.
   - 6 Quick reaction circles (44x44dp): `👍`, `❤️`, `🔥`, `😂`, `🎉`, `👎` (`surfaceContainerHighest`).
   - Add button `+` (44x44dp) in `primaryContainer` to open full reaction emoji sheet (`_showAllReactionsPicker`).
3. **Compact Action Tiles (`_ActionsCompact`)**:
   - Wrap of action chips with 12dp rounded corners (`surfaceContainerHigh`).
   - Supported actions: `Reply`, `Copy Text`, `Resend/Forward`, `Comments` (channel), `Edit` (own text messages), `Delete` (own / admin), `Report` (incoming).

### 4.3 Redesign Targets (Google Messages R4)
1. **Floating Quick Reactions Pill Dock**:
   - Floating pill container styling (`surfaceContainerHighest` / `surfaceContainerHigh` with 28dp pill radius and subtle elevation).
   - Micro-scale entrance and tap animations using `flutter_animate` (e.g. `.scale(begin: Offset(0.7, 0.7), curve: Curves.easeOutBack)`).
   - **Active Reaction Highlighting**: When the user has already reacted with an emoji on the message (`message.reactions` contains emoji), highlight that reaction button with `scheme.primaryContainer` fill and `scheme.primary` border.
   - **48x48dp Touch Targets**: Upgrade touch target dimensions from 44x44dp to minimum 48x48dp for accessibility compliance.
2. **Context Action Tiles**:
   - Tonal M3 list tiles or rounded container cards with clean `titleMedium` / `bodyMedium` typography.
   - Tonal container leading icons (`primaryContainer`, `secondaryContainer`, etc.).
   - Destructive actions (`Delete`, `Report`) highlighted in `scheme.error` and `scheme.errorContainer`.
   - Comprehensive haptic feedback: `HapticService.tap()` on regular actions, `HapticService.destructive()` on delete/report, and `HapticService.reaction()` on reaction selections.

---

## 5. Theming, Localization & Code Quality

### 5.1 Theming Rules (`AppTheme.themed` in `lib/core/theme/app_theme.dart`)
- Full dynamic Material 3 tonal palettes.
- All colors sourced from `Theme.of(context).colorScheme` (`surface`, `onSurface`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`, `primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`, `error`, etc.).
- **Zero hardcoded colors**: No `Colors.white`, `Colors.black`, `Colors.black45`.
- **Zero `withOpacity()`**: Exclusively use `withValues(alpha:)`.

### 5.2 Localization Keys (`lib/l10n/`)
- Existing keys:
  - `chatEditingMessage`, `chatEditCancel`, `chatReply`, `chatCancelReply`, `chatEmojiToggle`, `chatMessageHint`, `chatAiAssistant`, `chatAttachMedia`, `chatSlideToCancel`, `chatCopyText`, `chatResendTo`, `chatComments`, `chatEdit`, `chatDelete`, `reportAction`, `filePickerGallery`, `filePickerDocument`, `filePickerAudio`, `chatReactionsPickerTitle`.
- Recommended additional keys to support full M3 attachment grid:
  - `filePickerCamera`: "Camera" / "Камера"
  - `filePickerContact`: "Contact" / "Контакт"
  - `filePickerLocation`: "Location" / "Геолокация"

### 5.3 Test Suite Verification
- Ran test suite `flutter test --no-pub`: **All 22 tests passing**.

---

## 6. Component Comparison Matrix

| Feature | Current State | Google Messages Target | Proposed Solution |
|---|---|---|---|
| **Input Bar Container** | 22dp radius, `surfaceContainerLow` (alpha 0.5), thin border | 28dp pill geometry, solid `surfaceContainerHighest`/`High`, no border | Update `BoxDecoration` to 28dp radius and tonal container fill |
| **Voice Lock Rail** | Invisible threshold at dy < -60 | Visual vertical lock track with glowing lock badge and chevron | Add sliding lock rail widget rendered during drag |
| **Voice Cancel Rail** | Text hint "Slide to cancel" | Progressive horizontal slide track with red tint shift | Enhance drag visualizer with interactive chevron rail |
| **Waveform Visualizer** | 24 fixed bars, 80ms animation | Dynamic organic rounded amplitude bars | Polish waveform bar rendering with rounded caps & tonal colors |
| **Attachment Sheet** | 3 horizontal items (Gallery, Doc, Audio) | M3 Expressive Grid (Gallery, Camera, File, Contact, Location, Audio) | Expand `_CompactAttachmentMenu` to 6-card M3 grid |
| **Reactions Dock** | 44x44dp circles in low container | Floating 28dp pill, 48x48dp bouncy touch targets, active highlighting | Refactor `_ReactionsRow` with floating pill dock & `flutter_animate` |
| **Context Action Tiles** | Simple horizontal chip wrap | Tonal container action tiles with M3 icons & typography | Refactor `_ActionsCompact` into expressive M3 action tiles |
| **Haptics** | Basic selection clicks | Differentiated haptics (`tap`, `confirm`, `reaction`, `destructive`) | Ensure all touch targets trigger appropriate `HapticService` methods |
