# Project: NiosGram & Settings M3 Expressive Overhaul

## Architecture
- **Framework & State Management**: Flutter 3.x with Riverpod 3.x (`NotifierProvider` / `AsyncNotifierProvider`), `go_router` v17.
- **Design System**: Material 3 Expressive with dynamic seed colors (`AppTheme`), semantic tonal containers (`surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`), `withValues(alpha:)`, and parametric shapes (`flutter_m3shapes`).
- **NiosGram Subsystem**:
  - `lib/screens/niosgram_screen.dart`: Adaptive social feed canvas (720–800dp on desktop/web) with expressive quick-creation bar.
  - `lib/widgets/post_card.dart`: M3 Expressive post card with 20–24dp smooth corners, tonal surface, verified author badges (`BadgeChip`), aspect-ratio-aware media viewport, and reactive controls (heart/like, comment, share, bookmark).
  - `lib/widgets/pulse_skeleton.dart`: Dedicated `PostCardSkeleton` and smooth shimmer loaders.
- **Settings Subsystem**:
  - `lib/screens/profile_screen.dart`: Responsive Master-Detail 2-pane coordinator on wide screens (left pane 320–360dp with profile header and active section highlight; right pane expanded sub-screen renderer) and mobile stacked fallback.
  - `lib/widgets/settings_ui.dart`: M3 Expressive reusable containers (`SettingsScaffold` with embedded mode, `SettingsSection` with `surfaceContainerLow` and 20dp radius, `SettingsTile` with squircle icon containers, `SettingsSwitchTile`).
  - Sub-screens: `settings_account_screen.dart`, `settings_appearance_screen.dart`, `settings_privacy_screen.dart`, `settings_storage_screen.dart`, `settings_language_region_screen.dart`, `settings_preferences_screen.dart`, `settings_about_screen.dart`, `e2ee_settings_screen.dart`, `sessions_screen.dart`.
- **Vector Assets & Artwork**:
  - SVG vector assets in `assets/svg/` and programmatic vector widgets in `lib/widgets/` for empty feed states, media placeholders, and section headers.
- **E2E & Widget Testing Track**:
  - 4-Tier requirement-driven test suite in `test/` covering unit models, widget components, screen flows, and responsive resize matrix (360dp to 3840dp).

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | NiosGram Adaptive Canvas | Centered 720–800dp canvas on desktop/web removing side voids | M1 | Survey (Explorer 1) |
| 2 | Expressive Post Card | M3 post card with 20–24dp radius, `surfaceContainerLow`, `outlineVariant` border, author badges | M1 | Survey (Explorer 1) |
| 3 | Aspect-Ratio Media Viewport | Adaptive aspect-ratio media box with 16dp inner radius and shimmer/blur loaders | M1 | Survey (Explorer 1) |
| 4 | Reactive Action Controls | Like/heart reactive animation, comment trigger with counter, share, bookmark | M1 | Survey (Explorer 1) |
| 5 | Expressive Quick-Creation FAB | M3 cookie-shaped FAB/dock using `flutter_m3shapes` for quick posting | M1 | Survey (Explorer 1) |
| 6 | Settings Master-Detail Layout | 2-pane desktop layout (320–360dp master pane with `secondaryContainer` highlight + expanded detail pane) | M2 | Survey (Explorer 2) |
| 7 | Settings Navigation & Deep Links | Seamless router synchronization and mobile stacked navigation fallback | M2 | Survey (Explorer 2) |
| 8 | Grouped Settings M3 Cards | Standardized `surfaceContainerLow` cards with 20dp radius across all 9 settings sub-screens | M3 | Survey (Explorer 2) |
| 9 | Expressive Settings Controls | `Switch.adaptive`, segmented buttons, tonal sliders, and squircle leading icon containers | M3 | Survey (Explorer 2) |
| 10 | SVG Vector Illustrations | Expressive SVG empty feed states, media placeholders, and section header visual indicators | M4 | Survey (Explorer 3) |
| 11 | E2E & Widget Test Suite | 4-tier opaque-box test suite covering features, boundaries, interactions, and responsive matrix | E2E / M5 | Survey (Explorer 3) |
| 12 | Quality & SemVer Bump | 0 analyze errors, clean build/test pass, and automated SemVer bump in `pubspec.yaml` | M5 | Survey (Explorer 3) |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| E2E | E2E & Widget Testing Suite | Test infrastructure & 4-tier test cases for NiosGram, Settings, and responsive matrix | Survey | IN_PROGRESS |
| M1 | NiosGram Expressive Feed & Canvas | 720–800dp canvas, M3 PostCard, media viewport, reactions, bookmark, FAB, skeleton | Survey | PLANNED |
| M2 | Settings Master-Detail Architecture | 2-pane desktop layout, `desktopSelectedSettingsSectionProvider`, router integration, embedded scaffold | Survey | PLANNED |
| M3 | Settings Screens M3 Overhaul | Overhaul all 9 settings screens with standardized M3 Expressive grouped cards and tonal controls | M2 | PLANNED |
| M4 | Vector Illustrations & Placeholders | Rich SVG empty states ("Лента пуста", etc.), media placeholders, and section headers | M1, M3 | PLANNED |
| M5 | Verification, E2E Pass & SemVer Bump | Pass 100% E2E tests, Tier 5 adversarial hardening, zero analyze issues, bump version | M1, M2, M3, M4, E2E | PLANNED |

---

## Interface Contracts

### 1. NiosGram Feed ↔ Shell
- `NiosgramScreen`: Self-contained widget fitting into `MainShellScreen` tab 2.
- Canvas constraint: `ConstrainedBox(constraints: BoxConstraints(maxWidth: 780))` with horizontal adaptive padding (`16dp` mobile, `24dp` desktop).
- `PostCard`: Accepts `NgPost post`, callback triggers `onLike`, `onDislike`, `onComment`, `onShare`, `onBookmark`, `onAuthorTap`, `onMediaTap`.

### 2. Settings Master-Detail Coordinator ↔ Sub-Screens
- State Provider: `desktopSelectedSettingsSectionProvider` (`NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId>`).
- Enum `SettingsSectionId`: `account`, `appearance`, `privacy`, `storage`, `languageRegion`, `preferences`, `about`, `e2ee`, `sessions`.
- `SettingsScaffold`:
  - Parameter `bool isEmbedded`: When `true`, suppresses top `AppBar`, back button, and outer screen padding so it embeds seamlessly into the right detail pane.
  - Parameter `Widget child`: Content wrapped in `surfaceContainerLow` grouped cards.

### 3. Vector Illustrations ↔ Screens
- `lib/widgets/vector_illustrations.dart` / `assets/svg/`:
  - `EmptyFeedIllustration`: Tintable expressive SVG vector for empty social feed.
  - `MediaPlaceholderIllustration`: Tintable SVG vector for missing / loading media.
  - `SettingsHeaderIllustration`: Dynamic vector header badge for settings categories.

---

## Code Layout
- `pulse_flutter/lib/screens/main_shell_screen.dart` — Shell responsive width & tab canvas adaptation.
- `pulse_flutter/lib/screens/niosgram_screen.dart` — Social feed screen, quick-creation bar, feed list.
- `pulse_flutter/lib/widgets/post_card.dart` — M3 Expressive post card, author header, media box, actions.
- `pulse_flutter/lib/widgets/pulse_skeleton.dart` — Shimmer skeletons, `PostCardSkeleton`.
- `pulse_flutter/lib/screens/profile_screen.dart` — Profile & Settings Master-Detail coordinator.
- `pulse_flutter/lib/providers/settings_navigation_provider.dart` — Master-Detail selection state.
- `pulse_flutter/lib/widgets/settings_ui.dart` — Standardized M3 settings scaffold, sections, tiles.
- `pulse_flutter/lib/screens/settings_*.dart` — Individual settings sub-screens.
- `pulse_flutter/lib/screens/e2ee_settings_screen.dart` — E2EE settings sub-screen.
- `pulse_flutter/lib/widgets/vector_illustrations.dart` — Vector artwork & SVG helpers.
- `pulse_flutter/assets/svg/` — SVG asset files.
- `pulse_flutter/test/` — Unit, widget, and responsive integration tests.
