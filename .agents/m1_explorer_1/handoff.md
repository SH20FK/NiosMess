# Milestone 1 Handoff Report: NiosGram Responsive Canvas & Expressive Quick-Creation Bar

## 1. Observation

- **File**: `pulse_flutter/lib/screens/main_shell_screen.dart`
  - Lines 184–193:
    ```dart
    final List<Widget> pages = <Widget>[
      if (isWide)
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[ ... ],
        )
      else
        const ChatListScreen(),
      isWide
          ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: const ContactsScreen()))
          : const ContactsScreen(),
      isWide
          ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: const NiosgramScreen()))
          : const NiosgramScreen(),
      isWide
          ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: const ProfileScreen()))
          : const ProfileScreen(),
    ];
    ```
  - Observation: `isWide` is triggered at `constraints.maxWidth >= 760` (line 153). While `ContactsScreen` and `ProfileScreen` use `maxWidth: 780`, `NiosgramScreen` is restricted to `maxWidth: 680`.

- **File**: `pulse_flutter/lib/screens/niosgram_screen.dart`
  - Lines 75–88:
    ```dart
    floatingActionButton: _showFab
        ? FloatingActionButton.small(
            heroTag: 'niosgram_scroll_top',
            onPressed: () {
              if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            },
            child: const Icon(Icons.keyboard_arrow_up_rounded),
          )
        : null,
    ```
  - Lines 148–153:
    ```dart
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: Animate( ... ),
    );
    ```
  - Observation: Card item padding is fixed at 12dp regardless of viewport width. When scrolled down, only `FloatingActionButton.small` appears for scroll-to-top; there is no persistent or floating quick-creation button in NiosGram.

- **Dependency & Shapes Capability**:
  - `pubspec.yaml` specifies `flutter_m3shapes: ^1.0.0+2`.
  - Codebase grep confirms `M3Clipper(Shapes.c9_sided_cookie)` and `M3Container.c9SidedCookie` are used across multiple active screens (`active_video_call_screen.dart:446`, `call_control_dock.dart:206`, `app_logo_mark.dart:20`, `settings_about_screen.dart:198`).
  - `flutter analyze` runs cleanly with 0 issues.

---

## 2. Logic Chain

1. **Canvas Constraint Expansion**:
   - `main_shell_screen.dart` currently limits NiosGram to `maxWidth: 680`.
   - Modern social feed layouts with rich aspect-ratio media (16:9, 4:3) and comment threads on 1080p/1440p displays suffer from awkward white margins when confined to 680dp.
   - Expanding to `maxWidth: 780` matches `ContactsScreen` and the 720–800dp specification in `PROJECT.md` and `ORIGINAL_REQUEST.md`, creating a balanced reading experience.

2. **Responsive Gutters**:
   - Fixed 12dp horizontal padding is suboptimal: too cramped on desktop canvas (where 24dp gives proper breathing room) and lacks standard M3 token spacing on mobile (where 16dp is the standard minimum margin).
   - Dynamically selecting `horizontalGutter = isWide ? 24.0 : 16.0` ensures proportional card boundaries across mobile, tablet, and desktop viewports.

3. **Expressive Quick-Creation FAB Architecture**:
   - In `NiosgramScreen`, post creation is currently hidden in the top `AppBar` actions or empty state.
   - Using `flutter_m3shapes` (`Shapes.c9_sided_cookie`) with `M3Clipper`, `Material`, and `InkWell` produces a distinct Material 3 Expressive tactile button.
   - Wrapping with `BoxShadow(color: scheme.primary.withValues(alpha: 0.30), blurRadius: 14, offset: Offset(0, 5))` provides elevation and glow.
   - Stacking this button with `FloatingActionButton.small` when `_showFab == true` preserves scroll-to-top convenience while keeping creation reachable at all times.

---

## 3. Caveats

1. **Navigation Rail on Desktop**: On wide screens (≥ 760dp), `MainShellScreen` includes a `NavigationRail` with a compose button in its `leading` slot that opens the chat create menu (`_showCreateMenu`). The NiosGram quick-create FAB operates independently to specifically create NiosGram posts (`/niosgram/create`).
2. **Media Aspect Ratio**: PostCard media rendering is being overhauled in parallel subtasks; the 780dp max width accommodates these media viewport changes seamlessly.

---

## 4. Conclusion

- In `pulse_flutter/lib/screens/main_shell_screen.dart`: Update line 188 from `maxWidth: 680` to `maxWidth: 780`.
- In `pulse_flutter/lib/screens/niosgram_screen.dart`:
  1. Calculate responsive horizontal gutters (`16dp` mobile, `24dp` desktop).
  2. Implement `_NiosgramQuickCreateFab` using `M3Clipper(Shapes.c9_sided_cookie)`, `Material`, `InkWell`, `Tooltip`, and haptic feedback.
  3. Replace the single scroll-to-top FAB with `_buildFloatingActions` that composites the cookie quick-create FAB with the scroll-to-top button.
  4. Adjust `ListView` padding to responsive gutters and proper bottom clearance (`84dp` desktop, `96dp` mobile).
- The full blueprint is saved in `f:\Niosmess V2\.agents\m1_explorer_1\plan.md`.

---

## 5. Verification Method

1. **Code Review & Static Analysis**:
   ```bash
   cd "f:\Niosmess V2\pulse_flutter"
   flutter analyze
   ```
2. **Widget Verification**:
   - Run existing and new widget tests verifying `NiosgramScreen` renders `_NiosgramQuickCreateFab`, handles tap navigation to `/niosgram/create`, and respects 780dp constraint on wide screen.
3. **Invalidation Conditions**:
   - If `main_shell_screen.dart` retains `maxWidth: 680`.
   - If `NiosgramScreen` FAB does not use `Shapes.c9_sided_cookie` or lacks ripple/tooltip.
   - If horizontal gutters on desktop remain hardcoded at 12dp.
