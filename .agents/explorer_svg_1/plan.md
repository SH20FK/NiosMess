# Execution Plan: Milestone 4 — SVG & Vector Illustrations Integration

## Overview & Scope
Milestone 4 elevates the visual quality of NiosMess across NiosGram social feed and Settings screens by replacing flat placeholder icons, empty containers, and grey boxes with crisp, responsive, theme-tintable SVG vector graphics and dedicated Flutter vector illustration widgets (`EmptyFeedIllustration`, `MediaPlaceholderIllustration`, `MediaErrorIllustration`, `SettingsHeaderIllustration`).

---

## 1. Baseline Architectural Survey & Current State

### 1.1 Dependency & Asset Infrastructure
- **Package**: `flutter_svg: ^2.3.0` is already declared in `pulse_flutter/pubspec.yaml` (line 88).
- **Asset Directory**: `assets/svg/` is already registered in `pulse_flutter/pubspec.yaml` under `flutter.assets` (line 126).
- **Existing Vector Assets**:
  - `pulse_flutter/assets/svg/niosmess_logo_tintable.svg` (uses `fill="currentColor"`, 1254x1254 viewBox).
- **Existing Vector Consumers**:
  - `pulse_flutter/lib/widgets/app_logo_mark.dart` uses `SvgPicture.asset('assets/svg/niosmess_logo_tintable.svg', ...)`
  - `pulse_flutter/lib/screens/splash_screen.dart` uses `SvgPicture.asset(...)`
  - `pulse_flutter/lib/screens/settings_about_screen.dart` uses `SvgPicture.asset(...)`

### 1.2 Empty Feed State in NiosGram
- **Current File**: `pulse_flutter/lib/screens/niosgram_screen.dart` renders `EmptyFeedWidget` from `pulse_flutter/lib/widgets/empty_feed_widget.dart`.
- **Current Look**: `EmptyFeedWidget` renders an 84dp `M3Container(Shapes.c9_sided_cookie)` containing a static icon `Icons.chat_bubble_outline_rounded`.
- **Target Look**: A rich, multi-layered, tintable vector illustration (`EmptyFeedIllustration`) featuring floating expressive post cards, speech bubble glyphs, spark/star accents, soft gradient backdrops, and subtle entrance animation conforming to Material 3 Expressive colorScheme tokens (`primary`, `primaryContainer`, `surfaceContainerHigh`, `outlineVariant`).

### 1.3 Media Placeholders & Error States in PostCard
- **Current File**: `pulse_flutter/lib/widgets/post_card.dart`.
  - Loading placeholder: `SizedBox(height: 260, child: Center(child: AppLoadingIndicator(size: 28, color: scheme.onSurfaceVariant)))`.
  - Error state: `SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image_rounded, color: scheme.outline, size: 32)))`.
- **Target Look**:
  - `MediaPlaceholderIllustration`: Elegant shimmering frame with soft mountain/landscape vector contours, camera emblem, and rounded container (16dp).
  - `MediaErrorIllustration`: Tinted error container with broken frame glyph, friendly error copy, and retry button option.

### 1.4 Settings Section Headers & Visual Badges
- **Current Files**: `pulse_flutter/lib/widgets/settings_ui.dart` (`SettingsNavBanner` uses 52x52 container with standard `Icon(icon)`).
- **Target Look**:
  - `SettingsHeaderIllustration`: Dedicated vector badges for all 9 settings domains:
    1. `account`: Nios ID badge, user squircle, verified key
    2. `appearance`: Dynamic palette, glowing mesh, sparkle theme
    3. `privacy`: Security shield, biometric padlock, visibility toggle
    4. `storage`: Cloud cylinder database, local storage bars
    5. `languageRegion`: Global translation glyphs, speech bubbles
    6. `preferences`: Sound bell, haptic vibration wave, notifications
    7. `about`: NiosMess brand emblem with orbit ring
    8. `e2ee`: End-to-end cryptographic double padlock & key exchange
    9. `sessions`: Multi-platform devices (mobile, desktop, web) connected grid

### 1.5 Code Health Notice (from flutter analyze)
- In `lib/widgets/post_card.dart:158`, `HapticService.selection()` should be `HapticService.tap()`.
- In `test/widgets/niosgram_feed_m3_test.dart:5`, remove unused import `l10n.dart`.

---

## 2. Technical Architecture & File Layout

```
pulse_flutter/
├── assets/
│   └── svg/
│       ├── niosmess_logo_tintable.svg        (existing)
│       ├── illustration_empty_feed.svg       (NEW: Empty feed illustration)
│       ├── illustration_media_placeholder.svg (NEW: Shimmer media placeholder)
│       ├── illustration_media_error.svg      (NEW: Media error graphic)
│       ├── settings_account.svg              (NEW: Account category badge)
│       ├── settings_appearance.svg           (NEW: Appearance category badge)
│       ├── settings_privacy.svg              (NEW: Privacy & security badge)
│       ├── settings_storage.svg              (NEW: Storage & cache badge)
│       ├── settings_language.svg             (NEW: Language & region badge)
│       ├── settings_preferences.svg          (NEW: Notifications & sounds badge)
│       ├── settings_about.svg                (NEW: About NiosMess badge)
│       ├── settings_e2ee.svg                 (NEW: E2EE cryptography badge)
│       └── settings_sessions.svg             (NEW: Active sessions device badge)
├── lib/
│   ├── widgets/
│   │   ├── vector_illustrations.dart         (NEW: Comprehensive vector widget library)
│   │   ├── empty_feed_widget.dart            (UPDATED: Uses EmptyFeedIllustration)
│   │   ├── post_card.dart                    (UPDATED: Uses MediaPlaceholder & MediaError)
│   │   ├── settings_ui.dart                  (UPDATED: Integrates SettingsHeaderIllustration)
│   │   └── chat/ws_cached_image.dart         (UPDATED: Uses vector placeholders)
│   └── screens/
│       ├── niosgram_screen.dart              (UPDATED: Expressive empty state integration)
│       ├── settings_account_screen.dart      (UPDATED: Uses category illustration)
│       ├── settings_appearance_screen.dart   (UPDATED: Uses category illustration)
│       ├── settings_privacy_screen.dart      (UPDATED: Uses category illustration)
│       ├── settings_storage_screen.dart      (UPDATED: Uses category illustration)
│       ├── settings_language_region_screen.dart (UPDATED: Uses category illustration)
│       ├── settings_preferences_screen.dart  (UPDATED: Uses category illustration)
│       ├── settings_about_screen.dart        (UPDATED: Uses category illustration)
│       ├── e2ee_settings_screen.dart         (UPDATED: Uses category illustration)
│       ├── sessions_screen.dart              (UPDATED: Uses category illustration)
│       └── profile_screen.dart               (UPDATED: Uses category illustrations in master pane)
└── test/
    └── widgets/
        ├── vector_illustrations_test.dart    (NEW: Unit & widget tests for all vector components)
        └── niosgram_feed_m3_test.dart        (UPDATED: Asserts vector illustration rendering)
```

---

## 3. Step-by-Step Implementation Roadmap

| Step | Action | Files Touched | Description |
|------|--------|---------------|-------------|
| **1** | Create SVG Assets | `assets/svg/*.svg` | Generate 12 clean, crisp SVG vector assets with `currentColor` styling |
| **2** | Create Vector Library | `lib/widgets/vector_illustrations.dart` | Implement `EmptyFeedIllustration`, `MediaPlaceholderIllustration`, `MediaErrorIllustration`, `SettingsHeaderIllustration` |
| **3** | Update Empty Feed Widget | `lib/widgets/empty_feed_widget.dart` | Integrate `EmptyFeedIllustration` with fallback to icon |
| **4** | Update NiosGram Screen | `lib/screens/niosgram_screen.dart` | Verify empty state displays rich `EmptyFeedIllustration` |
| **5** | Update PostCard Media Viewports | `lib/widgets/post_card.dart` | Replace placeholder/error widgets with `MediaPlaceholderIllustration` and `MediaErrorIllustration`, fix `HapticService.tap()` on line 158 |
| **6** | Update Settings UI | `lib/widgets/settings_ui.dart` | Enhance `SettingsNavBanner` to support `SettingsIllustrationCategory` |
| **7** | Update Settings Sub-screens | `lib/screens/settings_*.dart`, `e2ee_settings_screen.dart`, `sessions_screen.dart` | Pass appropriate category to `SettingsNavBanner` |
| **8** | Unit & Widget Tests | `test/widgets/vector_illustrations_test.dart`, `test/widgets/niosgram_feed_m3_test.dart` | Add comprehensive tests for vector illustration rendering, tinting, and error states |
| **9** | Validation & Lint Check | All | Run `flutter test` and `flutter analyze` ensuring 0 warnings, 0 errors |

---

## 4. Verification & Acceptance Criteria
- [ ] `EmptyFeedIllustration` renders smoothly in NiosGram when post feed is empty.
- [ ] `MediaPlaceholderIllustration` and `MediaErrorIllustration` render crisply in `PostCard` for loading / missing media.
- [ ] `SettingsHeaderIllustration` renders beautiful vector badges across all 9 settings screens.
- [ ] All SVG assets scale crisply across DPR 1.0x to 4.0x without pixelation or raster artifacts.
- [ ] Dynamic color tinting reflects active light/dark `ColorScheme` tokens.
- [ ] `flutter test` passes 100% test cases.
- [ ] `flutter analyze` reports 0 errors and 0 warnings.
