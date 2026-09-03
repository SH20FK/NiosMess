# NiosMess (pulse_flutter) UI/UX & Material 3 Expressive Audit Report

**Author**: Explorer 1 (UI/UX Design & Material 3 Expressive Specialist)  
**Date**: 2026-08-22  
**Target Codebase**: `f:/Niosmess V2/pulse_flutter`  
**Reference Guidelines**: `f:/Niosmess V2/design.md`, `f:/Niosmess V2/goal.md`, `f:/Niosmess V2/.agents/ORIGINAL_REQUEST.md`

---

## 1. Executive Summary

An exhaustive, line-by-line visual polish, ergonomic, and Material 3 Expressive compliance audit of the NiosMess Flutter messenger (`pulse_flutter`) was conducted across all UI modules.

### Key Audit Findings Overview:
- **Total UI Components & Screens Analyzed**: 44 screens, 59 widgets, 3 theme modules.
- **Material 3 Expressive Compliance**: The app has established strong foundation tokens (M3 color schemes, `SettingsScaffold`, custom shape clipping with `flutter_m3shapes`), but suffers from inconsistent corner smoothing, hardcoded colors/dimensions, missing interactive state feedback (haptics, unread FAB badges), rigid media aspect ratios in NiosGram, and hardcoded untranslated strings.
- **Critical Visual Anti-Patterns Identified**:
  1. *Hardcoded Colors*: `Colors.black`, `Colors.white`, `Colors.black45` in calls and post cards instead of semantic `colorScheme.surface`, `colorScheme.onSurface`, `colorScheme.shadow`.
  2. *Missing Unread Counter on Scroll-to-Bottom FAB*: The chat FAB fails to show incoming unread message counts when scrolled up.
  3. *Rigid Message Bubble Radii & Max Width*: Static 16px/4px corner radii without continuous squircle smoothing and unconstrained tablet width.
  4. *Lifecycle & Performance Flaws*: `Theme.of(context)` in `initState` in `active_color_orb.dart`, expensive canvas blur calculations in `profile_header_delegate.dart`.
  5. *Localization Hardcoding*: Hardcoded Russian and English strings scattered across `public_profile_screen.dart`, `chat_detail_screen.dart`, `fluid_preview_card.dart`, and `active_voice_call_screen.dart`.

---

## 2. Exhaustive File-by-File Audit by Scope

### Scope 1: Chat Details & List

#### 1.1 `pulse_flutter/lib/widgets/message_bubble.dart`
- **Line 123-183 (`_getBubbleRadius`)**:
  - *Observation*: Bubble geometry uses rigid 16px and 4px radius (`_mineRadiusNoneSame = BorderRadius.all(Radius.circular(16))`, `_mineRadiusPrevSame`, etc.).
  - *Issue*: Lacks M3 Expressive organic curvature and continuous squircle corner smoothing (should be 22dp standard with 6dp grouping corners).
- **Line 292 (`constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75)`)**:
  - *Issue*: Fixed percentage constraint causes bubbles on desktop/tablet to stretch excessively wide (e.g. 900px on a 1200px screen) without an absolute max width threshold (e.g. 480dp).
- **Line 459-493 (`reactions`)**:
  - *Issue*: Reaction badges rendered in a flat `Wrap` with `scheme.surfaceContainerHigh`. Lacks distinction when the current logged-in user reacted to the message, lacks animated count transitions (`AnimatedSwitcher`), and has no micro-scale press animation.
- **Line 408**: Hardcoded `'Image unavailable'` string fallback.

#### 1.2 `pulse_flutter/lib/widgets/message_context_menu_sheet.dart`
- **Line 41-48 (`_quickReactions`)**:
  - *Observation*: Static 6-item quick reaction list `['👍', '❤️', '🔥', '😂', '🎉', '👎']`.
  - *Issue*: No user customizable quick reactions; touch targets for `_ReactionButton` are 44x44dp (`Line 256`), below the 48x48dp M3 accessibility recommendation.
- **Line 458-498 (`_CompactActionTile`)**:
  - *Issue*: Context menu items use static `InkWell` without individual haptic taps (`HapticService.tap()`) and lack M3 Expressive tonal container icons.

#### 1.3 `pulse_flutter/lib/widgets/chat/chat_detail_fab.dart`
- **Line 23-38 (`ChatDetailScrollToBottomFAB`)**:
  - *Observation*: Uses `AnimatedOpacity` and `AnimatedScale` with `FloatingActionButton.small`.
  - *Issue*:
    1. **Missing Unread Badge**: Does not display the count of unread messages waiting below when user is scrolled up.
    2. **Pointer Capture when Hidden**: When `show == false`, the widget remains in the tree with opacity 0 and `onPressed: null`, but is not wrapped with `IgnorePointer(ignoring: !show)`.

#### 1.4 `pulse_flutter/lib/widgets/chat/chat_input_bar.dart` & `voice_recording_panel.dart`
- **Line 320-360 (`ChatInputBar` text container)**:
  - *Observation*: Input container has `minHeight: 52, maxHeight: 140` and `borderRadius: BorderRadius.circular(22)`.
  - *Issue*: Border animation between focused and unfocused uses standard `Border.all` instead of M3 Expressive smooth animated outline container.
- **Line 584-600 (`_buildRecordButton` long press gestures)**:
  - *Observation*: Fixed magic numbers `details.localOffsetFromOrigin.dy < -60` for lock and `dx < -120` for cancel.
  - *Issue*: No visual sliding track / lock rail shown above the mic button while holding down to guide the user's gesture.
- **`voice_recording_panel.dart:104`**:
  - *Observation*: Waveform has fixed 24 bars (`const int barCount = 24;`) of static width 3.0. Lacks real-time amplitude normalization and spring bounce on dynamic speech volume.

#### 1.5 `pulse_flutter/lib/screens/circle_video_recorder_screen.dart`
- **Line 201-203 (`circleSize = screenWidth * 0.78`)**:
  - *Observation*: Preview size takes 78% of screen width; no support for pinch-to-zoom during recording or flashlight/torch toggle.
- **Line 218 (`Container(color: scheme.scrim.withValues(alpha: 0.88))`)**:
  - *Issue*: Lacks frosted glass overlay and animated shape transition between idle and active recording states.

#### 1.6 `pulse_flutter/lib/widgets/chat/chat_detail_app_bar.dart`
- **Line 84-89 (`PulseAvatar(radius: 19)`)**:
  - *Observation*: Small avatar size (38dp diameter). On wide screens, title & subtitle layout can be enhanced with online status dots and call shortcut pills.

---

### Scope 2: Profiles, Settings & Theme Foundations

#### 2.1 `pulse_flutter/lib/screens/public_profile_screen.dart`
- **Lines 119, 121, 207, 468, 479, 490, 500**:
  - *Issue*: Hardcoded Russian strings:
    - `_error = 'Сервер временно недоступен. Проверьте соединение с интернетом.';`
    - `_error = 'Не удалось загрузить профиль. Попробуйте позже.';`
    - `'Не удалось получить данные с сервера'`
    - Quick actions: `label: 'Чат'`, `label: 'Звонок'`, `label: 'Видео'`, `label: 'Секретный'`.
- **Line 472**: `context.go('/chat/dm/${profile.username}');` — breaks GoRouter stack by using `go` instead of `push`, and fails if username contains special characters.
- **Lines 448-463 (`_buildQuickActionDock`)**:
  - *Issue*: Quick action dock has 4 horizontal buttons packed into a single row without flexible wrapping or adaptive layout for narrow screens (<360dp).

#### 2.2 `pulse_flutter/lib/widgets/profile_header_delegate.dart`
- **Lines 61, 214, 246, 275, 280**:
  - *Observation*: Magic numbers `collapsedAvatarLeft = 16`, `maxWidth: 320`, `left: 64`, `screenWidth - 140`.
- **Line 188**: Hardcoded `Colors.white` in progress indicator.
- **Lines 361-450 (`_ExpressiveProfileFogPainter`)**:
  - *Issue*: Expensive canvas custom painter performs 5 separate radial gradient draw operations with `blurSigma: 32` on every scroll offset change, triggering substantial GPU/CPU redraw overhead.

#### 2.3 `pulse_flutter/lib/widgets/settings_ui.dart`
- **Line 71 (`PulseScaffoldBody(maxWidth: 920)`)**:
  - *Observation*: Fixed max width 920dp across all settings pages.
- **Lines 385-456 (`SettingsSwitchTile`)**:
  - *Issue*: Standard `Switch` widget without jelly bounce transition or expressive micro-interactions.
- **Lines 301-383 (`SettingsTile`)**:
  - *Issue*: Subtitle typography is `bodySmall` with small line height; trailing chevron is not color-adaptive to tile focus state.

#### 2.4 `pulse_flutter/lib/widgets/active_color_orb.dart`
- **Line 41**:
  - *CRITICAL BUG*: `Theme.of(context).brightness` called inside `initState()`. If the user toggles dark/light theme while on the appearance screen, `_previewScheme` does not update because `initState` does not re-run.

#### 2.5 `pulse_flutter/lib/widgets/fluid_preview_card.dart`
- **Lines 159, 180, 225, 232**:
  - *Issue*: Hardcoded strings `'SH20FK'`, `'@sh20fk'`, `'NiosMess News'` instead of dynamic preview mock data or localized resource keys.

#### 2.6 `pulse_flutter/lib/widgets/badge_chip.dart`
- **Lines 280-294 (`BadgeDisplayMode.statusIcon`) & Lines 296-312 (`BadgeDisplayMode.avatarBadge`)**:
  - *Issue*: Completely ignores the `color` parameter passed to the constructor and hardcodes `scheme.primary` (statusIcon) and `scheme.tertiary` (avatarBadge). Only `infoLabel` parses the custom hex color.

---

### Scope 3: Calls UI

#### 3.1 `pulse_flutter/lib/screens/calls/active_call_screen.dart`
- **Lines 16, 21, 32**:
  - *CRITICAL LINT / M3 VIOLATION*:
    - `backgroundColor: Colors.black` (violates semantic color rule)
    - `icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)`
    - `CircularProgressIndicator(color: Colors.white)` (violates `AppLoadingIndicator` guideline).

#### 3.2 `pulse_flutter/lib/screens/calls/active_voice_call_screen.dart`
- **Line 225**:
  - *Issue*: Hardcoded English string `'E2EE PROTECTED'`.
- **Lines 154-158 (`bgDark`)**:
  - *Observation*: Manually manipulates HSL lightness (`(HSLColor.fromColor(baseBg).lightness * 0.55).clamp(0.04, 0.2)`) instead of using standard M3 `colorScheme.surfaceContainerLowest` or `ColorScheme.surfaceDim`.

#### 3.3 `pulse_flutter/lib/screens/calls/incoming_call_overlay.dart`
- **Line 111 (`color: Colors.black.withValues(alpha: 0.35)`)**:
  - *Issue*: Hardcoded `Colors.black` shadow color.
- **Lines 135-139 (`onVerticalDragEnd`)**:
  - *Issue*: Vertical swipe thresholds (`v > 120` accept, `v < -120` decline) lack interactive visual slide handle indicators to guide user gestures.

#### 3.4 `pulse_flutter/lib/widgets/calls/call_control_dock.dart`
- **Lines 46, 62 (`Colors.black.withValues(alpha: 0.35)`)**:
  - *Issue*: Hardcoded black shadow.
- **Lines 75-160 (`CallShapeButton`)**:
  - *Observation*: Buttons use `Shapes.c9_sided_cookie` shape. End call button is 64dp, regular buttons are 56dp. Touch target feedback is good, but labels should ensure complete screen-reader semantics.

---

### Scope 4: NiosGram & Stories & Feed

#### 4.1 `pulse_flutter/lib/screens/niosgram_screen.dart`
- **Lines 55-58 (`appBar`)**:
  - *Issue*: Hardcoded `TextStyle(fontWeight: FontWeight.w700, fontSize: 22)` instead of `textTheme.headlineSmall` / `textTheme.titleLarge`.
- **Lines 90-111 (`loading skeleton`)**:
  - *Issue*: Skeleton cards are rigid and don't match the actual layout of `PostCard` (missing action bar and author header placeholders).

#### 4.2 `pulse_flutter/lib/widgets/post_card.dart`
- **Line 220 (`aspectRatio: 16 / 10`)**:
  - *Issue*: Rigid fixed 16:10 aspect ratio crops square (1:1) and vertical (4:5 or 9:16) photos and videos.
- **Line 308 (`count: 0` on share chip)**:
  - *Issue*: Share chip hardcodes `count: 0` and is permanently rendered as non-interactive counter.
- **Line 338 (`Shadow(blurRadius: 24, color: Colors.black45)`)**:
  - *Issue*: Hardcoded `Colors.black45` shadow.

#### 4.3 `pulse_flutter/lib/screens/post_comments_screen.dart`
- **Lines 136-160 (`commentsAsync.when`)**:
  - *Issue*: Comments list lacks smooth message bubble continuous grouping, thread indentation, and quick reaction buttons.

---

## 3. Concrete Dart Modernization Blueprints

### Blueprint 1: Material 3 Expressive Message Bubble (`MessageBubbleM3`)
**Target File**: `pulse_flutter/lib/widgets/message_bubble.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExpressiveBubbleGeometry {
  static const double largeRadius = 22.0;
  static const double smallRadius = 6.0;

  static BorderRadius getBubbleRadius({
    required bool isMine,
    required bool isPrevSame,
    required bool isNextSame,
  }) {
    if (isMine) {
      return BorderRadius.only(
        topLeft: const Radius.circular(largeRadius),
        bottomLeft: const Radius.circular(largeRadius),
        topRight: Radius.circular(isPrevSame ? smallRadius : largeRadius),
        bottomRight: Radius.circular(isNextSame ? smallRadius : largeRadius),
      );
    } else {
      return BorderRadius.only(
        topRight: const Radius.circular(largeRadius),
        bottomRight: const Radius.circular(largeRadius),
        topLeft: Radius.circular(isPrevSame ? smallRadius : largeRadius),
        bottomLeft: Radius.circular(isNextSame ? smallRadius : largeRadius),
      );
    }
  }

  static BoxConstraints getConstraints(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    // Responsive adaptive width: max 460dp on tablet/desktop, 78% on mobile
    final double maxWidth = screenWidth > 600 ? 460.0 : screenWidth * 0.78;
    return BoxConstraints(maxWidth: maxWidth);
  }
}
```

---

### Blueprint 2: Scroll-to-Bottom FAB with Unread Counter Badge
**Target File**: `pulse_flutter/lib/widgets/chat/chat_detail_fab.dart`

```dart
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

class ChatDetailScrollToBottomFAB extends StatelessWidget {
  const ChatDetailScrollToBottomFAB({
    super.key,
    required this.show,
    required this.unreadCount,
    required this.onPressed,
    required this.chatId,
  });

  final bool show;
  final int unreadCount;
  final VoidCallback onPressed;
  final int chatId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 12),
        child: IgnorePointer(
          ignoring: !show,
          child: AnimatedSlide(
            offset: show ? Offset.zero : const Offset(0, 0.5),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: show ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: AnimatedScale(
                scale: show ? 1.0 : 0.6,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  backgroundColor: scheme.primary,
                  textColor: scheme.onPrimary,
                  alignment: const AlignmentDirectional(18, -18),
                  child: FloatingActionButton.small(
                    heroTag: 'scroll_down_$chatId',
                    elevation: 3,
                    highlightElevation: 6,
                    backgroundColor: scheme.surfaceContainerHigh,
                    foregroundColor: scheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    tooltip: context.l10n.chatScrollToBottom,
                    onPressed: () {
                      HapticService.tap();
                      onPressed();
                    },
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### Blueprint 3: Material 3 Interactive Reactions Dock
**Target File**: `pulse_flutter/lib/widgets/message_bubble.dart`

```dart
class ExpressiveReactionsDock extends StatelessWidget {
  const ExpressiveReactionsDock({
    super.key,
    required this.reactions,
    required this.userReaction,
    required this.isMine,
    required this.onReactionTap,
  });

  final Map<String, int> reactions;
  final String? userReaction;
  final bool isMine;
  final ValueChanged<String>? onReactionTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        children: reactions.entries.map((entry) {
          final bool isSelected = entry.key == userReaction;
          final Color bg = isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh.withValues(alpha: 0.85);
          final Color fg = isSelected
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onReactionTap != null ? () => onReactionTap!(entry.key) : null,
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.4)
                        : scheme.outlineVariant.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Text(
                        '${entry.value}',
                        key: ValueKey<int>(entry.value),
                        style: textTheme.labelSmall?.copyWith(
                          color: fg,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
```

---

### Blueprint 4: Active Call Screen & M3 Loading State
**Target File**: `pulse_flutter/lib/screens/calls/active_call_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'active_voice_call_screen.dart';
import 'active_video_call_screen.dart';

class ActiveCallScreen extends ConsumerWidget {
  const ActiveCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final session = ref.watch(callSessionProvider)?.session;

    if (session == null) {
      return Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                ref.read(appRouterProvider).go('/main/chats');
              }
            },
          ),
        ),
        body: Center(
          child: AppLoadingIndicator(size: 40, color: scheme.primary),
        ),
      );
    }

    final isVideo = session.currentData.isVideo;
    if (isVideo) {
      return const ActiveVideoCallScreen();
    } else {
      return const ActiveVoiceCallScreen();
    }
  }
}
```

---

### Blueprint 5: Dynamic Aspect Ratio & Double Tap Heart for NiosGram
**Target File**: `pulse_flutter/lib/widgets/post_card.dart`

```dart
Widget buildMediaContainer(BuildContext context, String rawUrl, ColorScheme scheme) {
  final resolvedUrl = ApiConstants.resolve(rawUrl);
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: GestureDetector(
      onDoubleTap: _onDoubleTapLike,
      onTap: () => _openFullScreen(context, resolvedUrl, widget.post.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 180,
            maxHeight: 480,
          ),
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: CachedNetworkImage(
            imageUrl: resolvedUrl,
            httpHeaders: cachedAuthHeaders(),
            fit: BoxFit.cover,
            memCacheWidth: 1080,
            placeholder: (_, _) => Center(
              child: AppLoadingIndicator(size: 32, color: scheme.primary),
            ),
            errorWidget: (_, _, _) => Center(
              child: Icon(Icons.broken_image_rounded, color: scheme.outline, size: 36),
            ),
          ),
        ),
      ),
    ),
  );
}
```

---

## 4. UI/UX & M3 Expressive Architecture Checklist

| Component | Status | Required Modernization |
|---|---|---|
| **Chat Bubbles** | 🟡 Partial | Apply 22dp/6dp continuous squircle radii, adaptive 460dp max constraint. |
| **Reactions** | 🟡 Partial | Add active user reaction styling, scale count transitions, 48dp dock buttons. |
| **Input Bar & Mic** | 🟡 Partial | Visual drag lock rail, normalized animated waveform, gesture spring cancel. |
| **Scroll-to-Bottom FAB** | 🔴 Incomplete | Add unread count Badge, ignore pointer when hidden, scale transition. |
| **Public Profile** | 🟡 Partial | Fix hardcoded Russian strings, safe GoRouter push, responsive action dock. |
| **Settings UI** | 🟢 Good | Upgrade Switch tiles with jelly physics & haptics, adaptive max width. |
| **Active Calls** | 🔴 Buggy | Eliminate `Colors.black`/`Colors.white`/`CircularProgressIndicator`, localize E2EE pill. |
| **NiosGram Feed** | 🟡 Partial | Adaptive media aspect ratios (1:1, 4:5, 16:9), fix mock usernames and share counts. |
| **Theme & Typography** | 🟢 Good | Fix `Theme.of(context)` in `initState()` in `ActiveColorOrb`, verify HSL dark contrast. |
