# Codebase Survey Report: Design System, Vector Assets & Test Infrastructure
**Project**: NiosMess (`pulse_flutter`) — NiosGram & Settings M3 Expressive Overhaul  
**Investigator**: Explorer 3 (Design System, Assets & Test Infra)  
**Date**: 2026-09-02  
**Target Root**: `f:\Niosmess V2\pulse_flutter`

---

## 1. Executive Summary

This survey provides a comprehensive audit of the design system, vector/SVG asset ecosystem, coding convention compliance, and automated test harness infrastructure for the **Material 3 Expressive Overhaul** of NiosGram social feed and Settings screens.

### Core Discoveries:
1. **M3 Expressive Theming (`lib/core/theme/`)**: The app possesses a solid foundational M3 token system using `ColorScheme.fromSeed` with `DynamicSchemeVariant.tonalSpot`, Dynamic Color integration (`dynamic_color: ^1.7.0`), GoogleFonts Inter typography, and LRU-cached `ThemeData`. Semantic tonal surface levels (`surface`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`) are implemented.
2. **Squircle & Expressive Shapes (`flutter_m3shapes`)**: `flutter_m3shapes: ^1.0.0+2` is included in `pubspec.yaml` and utilized in badges and logo marks (`M3Container.c9SidedCookie`). However, card grouping and icon containers in `lib/widgets/settings_ui.dart` currently rely on basic `BorderRadius.circular(28/16)` and need consistent squircle/M3-expressive polygon styling and Master-Detail 2-pane adaptivity.
3. **Vector / SVG Assets (`assets/`)**: `flutter_svg: ^2.3.0` is configured in `pubspec.yaml`, but `assets/svg/` currently contains only a single file (`niosmess_logo_tintable.svg`). Empty states (`EmptyFeedWidget`, `EmptyStateWidget`) use basic `IconData` rather than rich expressive SVG illustrations or vector artwork.
4. **Codebase Hygiene & Lint Compliance**: `flutter analyze` passes with **0 issues**. Full compliance with `withValues(alpha:)` (0 occurrences of legacy `withOpacity()`), `NotifierProvider` (0 occurrences of `StateProvider`), and `universal_io` (0 direct `dart:io` imports).
5. **Test Harness & Infrastructure**: Riverpod 3.x `NotifierProvider` mocking patterns are proven in `test/chat_list_m1_test.dart` and `test/screens/login_screen_test.dart`. A four-tier test suite architecture (Tiers 1-4) is outlined to guarantee zero layout overflow, seamless wide-screen Master-Detail rendering, responsive feed centering (720–800dp), and rich interactive behavior.

---

## 2. Design System & M3 Expressive Token Architecture

### 2.1 Color Scheme & Tonal Surfaces (`lib/core/theme/app_theme.dart` & `app_colors.dart`)
- **Seed-Based Tonal Spot Generation**:
  `AppTheme._scheme` builds dynamic tonal palettes using:
  ```dart
  ColorScheme.fromSeed(
    seedColor: settings.seedColor,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  )
  ```
- **Semantic Tonal Palette Hierarchy**:
  | Token | Light Value (Fallback) | Role in M3 Expressive Overhaul |
  |---|---|---|
  | `surface` | `#FDF7FE` | Scaffolds, root canvas, full-screen backgrounds |
  | `surfaceContainerLow` | `#F8F1FA` | Grouped Settings cards, NiosGram post cards, Nav Rails |
  | `surfaceContainer` | `#F2ECF5` | Default Cards, SearchView, dialog overlays |
  | `surfaceContainerHigh` | `#ECE6F0` | SearchBar, dialog background, active icon containers |
  | `surfaceContainerHighest` | `#E7E0EC` | Inactive action chips, slider tracks, code preview blocks |
  | `primaryContainer` / `onPrimaryContainer` | `#D4C3FD` / `#493C6C` | Active navigation indicators, primary badge pills |
  | `secondaryContainer` / `onSecondaryContainer` | `#E8DEF8` / `#1D192B` | Master-Detail active pane item highlight, tonal pills |
  | `outlineVariant` | `#B5B0BB` | Subtle card borders (`alpha: 0.14` - `0.28`), dividers |

### 2.2 Typography Hierarchy (`lib/core/theme/app_typography.dart`)
- TextTheme is mapped via `GoogleFonts.interTextTheme`:
  - `displayLarge`: 36sp, `FontWeight.w800`, letterSpacing: -0.5
  - `headlineLarge`: 28sp, `FontWeight.w700`, letterSpacing: -0.4
  - `headlineMedium`: 22sp, `FontWeight.w700`, letterSpacing: -0.3
  - `headlineSmall`: 20sp, `FontWeight.w600`, letterSpacing: -0.2
  - `titleLarge`: 18sp, `FontWeight.w700`, letterSpacing: -0.2 (Used for AppBar and Card titles)
  - `titleMedium`: 16sp, `FontWeight.w600`, letterSpacing: -0.1
  - `titleSmall`: 14sp, `FontWeight.w600`
  - `bodyLarge`: 16sp, height: 1.45, `FontWeight.w400`
  - `bodyMedium`: 14sp, height: 1.45, `FontWeight.w400`
  - `bodySmall`: 12sp, `FontWeight.w500`, `onSurfaceVariant`
  - `labelLarge`: 15sp, `FontWeight.w600`, letterSpacing: -0.1 (56dp Button labels)
  - `labelMedium`: 12sp, `FontWeight.w600`
  - `labelSmall`: 11sp, `FontWeight.w500`

### 2.3 Expressive Shapes & Squircles (`flutter_m3shapes`)
- `flutter_m3shapes: ^1.0.0+2` provides M3 parametric shapes:
  - `Shapes.c9_sided_cookie` / `M3Container.c9SidedCookie` used in `AppLogoMark` and `EmptyFeedWidget`.
  - Available shapes in package: 4-sided flower, 8-sided cookie, 9-sided cookie, 12-sided scallop, sunny, squircle, pill, arch.
- **Current Settings UI (`lib/widgets/settings_ui.dart`)**:
  - `SettingsSection`: Uses `ClipRRect(borderRadius: BorderRadius.circular(28))` around `Material(color: scheme.surfaceContainer)`.
  - `SettingsTile` / `SettingsSwitchTile`: Uses `Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)))` for leading icon containers.
  - `SettingsNavBanner`: Uses `Container(borderRadius: BorderRadius.circular(28))` with a 52x52 tonal container (`borderRadius: 18`).

### 2.4 Gaps Identified in Existing UI Implementation
1. **NiosGram Wide Screen Layout**: In `lib/screens/main_shell_screen.dart` (line 188), NiosGram is currently constrained to `maxWidth: 680` rather than the requested `720-800dp` adaptive canvas.
2. **Settings Master-Detail Architecture**: `lib/screens/profile_screen.dart` currently presents a stacked single list view across all devices, with navigation pushed onto the root router (`/settings/account`, `/settings/appearance`, etc.). On desktop/web, this needs to be refactored into a Master-Detail layout:
   - Left Master Pane: Fixed 320–360dp width containing the section index with `secondaryContainer` active indicators.
   - Right Detail Pane: Expanded in-place sub-screen viewport without forcing full-page route transitions.
3. **Post Cards**: `lib/widgets/post_card.dart` uses basic rounded rectangles (`16dp` inner media radius). Media aspect ratio handling and floating/inline action bar styling can be enhanced with M3 expressive surface depth.

---

## 3. Vector Assets & Illustrations Ecosystem

### 3.1 Asset Catalog in `pubspec.yaml`
```yaml
flutter:
  assets:
    - assets/fonts/
    - assets/sounds/
    - assets/developers/
    - assets/lottie/
    - assets/icons/
    - assets/svg/
    - assets/legal/
    - assets/NiosMess_icon.png
```

### 3.2 Inventory of Existing Vector & Graphics Assets
| Directory | Current Contents | Format | Usage Status |
|---|---|---|---|
| `assets/svg/` | `niosmess_logo_tintable.svg` | SVG | Used in `AppLogoMark`, `SplashScreen`, `SettingsAboutScreen` |
| `assets/icons/` | `niosmess_logo_tintable.png`, `niosmess_logo_tintable.svg` | PNG/SVG | Launcher icons, tintable marks |
| `assets/lottie/` | `onboarding_calls.json`, `onboarding_chat.json`, `onboarding_speed.json` | Lottie JSON | Onboarding screen animations |
| `assets/developers/` | `KarlovPrime_clean.png`, `SH20FK_clean.png`, `Sanlsan_clean.png` | PNG | Settings About developers tab |
| `assets/legal/` | `Consent_EN.txt`, `Consent_RU.txt`, `Privacy.txt`, `ToS.txt` | TXT | Legal viewer |
| `assets/sounds/` | `message.ogg`, `nav1.ogg` | OGG | Audio feedback |

### 3.3 Vector Artwork Requirements for R3
To satisfy Requirement R3 ("Eliminate empty or flat placeholder elements across NiosGram and Settings"), the following vector components are required:
1. **Empty Feed Art**: Rich multi-layer vector illustration / SVG for `EmptyFeedWidget` depicting social publication / feed stream ("Лента пуста", "Здесь появятся ваши публикации").
2. **Media Loading & Placeholder Art**: Soft tinted vector placeholders with subtle gradients and M3 shapes for unloaded/cached network images and videos in post feeds.
3. **Settings Section Header Art / Leading Icons**: Stylized vector badges or custom squircle icon containers with dual-tone depth for Settings categories (Account, Appearance, Privacy, Storage, Language & Region, Preferences, About, E2EE).

---

## 4. Linter & Code Conventions Compliance Audit

### 4.1 Linter Configuration (`analysis_options.yaml`)
- Inherits `package:flutter_lints/flutter.yaml`.
- Verified via `flutter analyze`: **0 errors, 0 warnings, 0 lints**.

### 4.2 AGENTS.md Rules Verification
| Rule | Requirement | Scan Result | Compliance |
|---|---|---|---|
| **Color Alpha** | Must use `color.withValues(alpha: X)` instead of legacy `color.withOpacity(X)` | `grep_search` found **0** occurrences of `withOpacity` | 100% Compliant |
| **Riverpod State** | Must use `NotifierProvider` / `AsyncNotifierProvider`; **no** `StateProvider` / `StateNotifierProvider` | `grep_search` found **0** occurrences of `StateProvider` | 100% Compliant |
| **Cross-Platform IO** | **No** direct `dart:io` imports; must use `package:universal_io/io.dart` | `grep_search` found **0** `import 'dart:io'` | 100% Compliant |
| **Semantic Colors** | **No** hardcoded `Colors.white` / `Colors.black` for UI containers | Systematic use of `colorScheme.surface`, `colorScheme.onSurface`, `surfaceContainer*` | 100% Compliant |
| **Localization** | All user-facing strings through `context.l10n.*` | Verified in all settings & niosgram screens | 100% Compliant |

---

## 5. Existing Test Infrastructure & Mocks Analysis

### 5.1 Test Suites Breakdown
- `test/screens/`:
  - `login_screen_test.dart` — Verifies M3 auth hub, ecosystem pillars, responsive desktop 480dp card, error parameters.
  - `login_screen_adversarial_responsiveness_test.dart` — Screen resize torture tests across 320dp to 2560dp.
  - `register_screen_test.dart` — Tests redirect to OAuth login.
- `test/unit/`:
  - `ephemeral_and_auth_models_challenge_test.dart` — Storage and model serialization.
  - `oauth_service_test.dart` — PKCE cryptographic token exchange.
  - `pkce_test.dart` — S256 verifier and challenge generation.
- `test/integration/`:
  - `e2e_auth_flow_test.dart` — Full lifecycle auth flow.
  - `e2e_cold_start_and_logout_test.dart` — App launch, token validation, and logout.
- `test/stress/`:
  - `oauth_service_stress_test.dart`, `pkce_stress_test.dart` — Concurrency and load testing.
- Root `test/`:
  - `chat_list_m1_test.dart` — Unit/widget tests for chat tiles, search bar, filter chips (7/7 passing).
  - `onboarding_screens_test.dart`, `legal_viewer_screen_test.dart`, `verification_screens_test.dart`.

### 5.2 Riverpod 3.x Test Harness Architecture
Existing tests use a clean `ProviderScope` override harness pattern:
```dart
Widget createTestHarness({
  required Widget child,
  List<Override> overrides = const [],
  Size surfaceSize = const Size(800, 1000),
  Brightness brightness = Brightness.light,
}) {
  final theme = AppTheme.themed(
    const VisualThemeSettings(
      seedColor: Color(0xFF6750A4),
      themeMode: ThemeMode.light,
      useSystemDynamic: false,
      predictiveBackEnabled: false,
    ),
    brightness,
  );

  return ProviderScope(
    overrides: overrides,
    child: MediaQuery(
      data: MediaQueryData(
        size: surfaceSize,
        padding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: MaterialApp(
        theme: theme,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
}
```

---

## 6. Comprehensive E2E & Widget Testing Strategy (Tiers 1–4)

To support the testing track for the NiosGram & Settings overhaul, the test suite must be structured into four distinct verification tiers:

```
┌────────────────────────────────────────────────────────┐
│  Tier 4: E2E Integration & Responsive Viewport Matrix  │
│  - Main navigation shell tab switching                 │
│  - Viewport resize: 360dp -> 768dp -> 1440dp -> 3840dp │
│  - Theme mode (Dark/Light) & Dynamic Color real-time   │
├────────────────────────────────────────────────────────┤
│  Tier 3: Screen & Feature Flow Tests                   │
│  - NiosgramScreen (empty state, feed loading, loadMore)│
│  - Settings Master-Detail (Desktop 2-pane vs Mobile)   │
│  - 8 Settings sub-screens complete rendering           │
├────────────────────────────────────────────────────────┤
│  Tier 2: Component & Widget Tests                      │
│  - PostCard (author info, media viewport, like anim)   │
│  - SettingsTile, SettingsSwitchTile, SettingsSection   │
│  - EmptyFeedWidget with M3 shape & vector illustration │
├────────────────────────────────────────────────────────┤
│  Tier 1: Unit & Model / Notifier Tests                 │
│  - NgPost, NgAuthor, NgComment models serialization   │
│  - UiSettingsNotifier (theme, fontScale, haptics)      │
│  - NiosgramNotifier (feed state, reactions, deletions) │
└────────────────────────────────────────────────────────┘
```

### 6.1 Tier 1: Unit & State Notifier Tests
- **Target Files**: `test/unit/niosgram_state_test.dart`, `test/unit/ui_settings_notifier_test.dart`.
- **Scope**:
  - `NgPost` JSON parsing, copyWith, equality, like/dislike reaction counting.
  - `UiSettingsNotifier`: verifies state mutations for `setThemeMode`, `setSeedColor`, `setFontScale`, `setUseSystemDynamic`, `setNavBarFloating`, `setOptimizeForWeakDevices`.
  - `NiosgramNotifier`: verifies pagination logic, deduplication of posts, optimistic reaction updates, delete post synchronization.

### 6.2 Tier 2: Component & Widget Tests
- **Target Files**: `test/widgets/post_card_test.dart`, `test/widgets/settings_ui_components_test.dart`, `test/widgets/empty_feed_widget_test.dart`.
- **Scope**:
  - `PostCard`:
    - Renders author avatar, display name, handle `@username`, and relative time.
    - Double-tap triggers heart scale/fade animation and fires `reactPost(postId, true)`.
    - Markdown body renders rich text, links, and code styling without layout overflow.
    - Action bar chips (Likes, Dislikes, Comments, Share) reflect state and invoke handlers.
    - Media viewport renders with rounded inner corners (16dp) and placeholder loading spinner.
  - `SettingsTile` / `SettingsSwitchTile` / `SettingsInfoTile`:
    - Renders leading squircle icon container with semantic tinting.
    - Switch toggle fires haptics and updates state via Riverpod notifier.
    - Disabled state dims text and disables tap interactions.
  - `EmptyFeedWidget`:
    - Renders M3 parametric shape (`Shapes.c9_sided_cookie`), vector art, title, and action CTA button.

### 6.3 Tier 3: Screen & Feature Flow Tests
- **Target Files**: `test/screens/niosgram_screen_test.dart`, `test/screens/settings_master_detail_test.dart`, `test/screens/settings_screens_suite_test.dart`.
- **Scope**:
  - `NiosgramScreen`:
    - Feed empty state renders `EmptyFeedWidget` with CTA navigating to `/niosgram/create`.
    - Feed loading state renders skeleton pulse placeholders.
    - Loaded feed renders post list centered in 720–800dp canvas on wide screens.
    - Scroll-to-top floating action button appears when offset > 200dp.
    - Pull-to-refresh calls `niosgramProvider.notifier.refresh()`.
  - `SettingsMasterDetailScreen` (`ProfileScreen`):
    - **Desktop/Wide (>= 760dp)**: Left pane (320–360dp) displays section list; right pane displays selected settings sub-screen in place with active highlight on selected item.
    - **Mobile (< 760dp)**: Single stacked list with tap navigating to dedicated sub-routes.
  - **All 8 Individual Settings Screens**:
    - `SettingsAccountScreen`: Biometrics toggle, 2FA toggle, active sessions entry.
    - `SettingsAppearanceScreen`: Interactive theme mode card selector, active color orb picker, font scale segmented button.
    - `SettingsPrivacyScreen`: Online visibility toggle, background modes, E2EE navigation.
    - `SettingsStorageScreen`: Storage snapshot breakdown, segmented storage bar, clear cache and drafts dialogs.
    - `SettingsLanguageRegionScreen`: Language segmented button (Auto/RU/EN), time zone mode (Auto/Manual) and search sheet.
    - `SettingsPreferencesScreen`: Notifications toggle, sound effects switch, volume slider, reset all settings confirmation.
    - `SettingsAboutScreen`: Rotating M3 logo badge, 4 tabs (Developers, FAQ, Changelog, Legal) with version pill.
    - `E2eeSettingsScreen`: Device key status, key generation, key rotation, erase secret chats.

### 6.4 Tier 4: E2E Integration & Adverse Responsive Resizing Tests
- **Target Files**: `test/integration/e2e_niosgram_and_settings_flow_test.dart`, `test/integration/responsive_viewport_matrix_test.dart`.
- **Scope**:
  - Tab navigation across `MainShellScreen` (`/main/chats` -> `/main/contacts` -> `/main/niosgram` -> `/main/profile`).
  - Adversarial screen resize testing across full resolution matrix:
    - Mobile Portrait: 360 x 640
    - Mobile Large: 412 x 915
    - Tablet / iPad: 768 x 1024
    - Desktop Standard: 1280 x 800
    - Full HD Desktop: 1920 x 1080
    - 4K Ultra HD: 3840 x 2160
    - Ultra-Narrow Split: 320 x 800
  - Zero `RenderFlex` or `A RenderFlex overflowed by ... pixels` exceptions across any resize or layout transition.

---

## 7. Actionable Recommendations & Implementation Roadmap

### For Implementer 1 (NiosGram Redesign & Responsive Web Adaptation):
1. **Adaptive Centered Canvas**: Update `lib/screens/main_shell_screen.dart` and `lib/screens/niosgram_screen.dart` to enforce a responsive `720–800dp` maximum width container using `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 760), ...))`.
2. **PostCard Polish**: Elevate `PostCard` (`lib/widgets/post_card.dart`) with `surfaceContainerLow` surface, `20–24dp` outer squircle/smooth corners, `16dp` inner media viewport corners, reactive like heart animation, and floating/inline action dock.
3. **Empty State & Vector Art**: Replace basic icons in `EmptyFeedWidget` with vector artwork and M3 container styling.

### For Implementer 2 (Settings 2-Pane Master-Detail & 8-Screen Pure M3 Overhaul):
1. **Master-Detail Layout**: Introduce a responsive 2-pane scaffold in `lib/screens/profile_screen.dart` (or `settings_master_detail_screen.dart`):
   - Left pane: 320–360dp with M3 squircle icon cards and `secondaryContainer` active state.
   - Right pane: In-place rendering of the active settings widget.
2. **Sub-Screen Modernization**: Standardize all 8 settings screens (`settings_account_screen.dart`, `settings_appearance_screen.dart`, `settings_privacy_screen.dart`, `settings_storage_screen.dart`, `settings_language_region_screen.dart`, `settings_preferences_screen.dart`, `settings_about_screen.dart`, `e2ee_settings_screen.dart`) on `surfaceContainerLow` grouped cards with 20dp radius, `Switch.adaptive`, segmented buttons, and tonal sliders.

### For Implementer 3 (Testing & Quality Assurance):
1. Construct test fixtures and mock notifiers (`MockNiosgramNotifier`, `MockUiSettingsNotifier`).
2. Implement Tiers 1–4 test suites under `test/` covering all components, screen flows, and responsive resize matrix.
3. Run `flutter analyze` and `flutter test` across all targets to guarantee zero regressions.
4. Verify web compilation via `flutter build web --profile`.
