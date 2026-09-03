# In-Depth Codebase Survey Report: Settings & Navigation M3 Expressive Architecture

**Project:** NiosMess (`pulse_flutter`)  
**Investigator:** Explorer 2  
**Date:** 2026-09-02  
**Focus Area:** Settings Screens, Router & Navigation, Master-Detail 2-Pane Architecture, Material 3 Expressive Standardization, State & Riverpod Providers  

---

## 1. Executive Summary

This survey provides a comprehensive architectural and visual analysis of all Settings screens, navigation routes, and shared components within the NiosMess Flutter codebase (`f:\Niosmess V2\pulse_flutter`).

### Key Findings
1. **Screen Inventory:** Settings functionality is currently distributed across **10 primary screens** (located directly in `lib/screens/`) plus legal and viewer utilities:
   - `profile_screen.dart` (Main Profile hub & settings section list)
   - `settings_account_screen.dart` (Sessions, biometrics, 2FA)
   - `settings_appearance_screen.dart` (Theme mode, accent palettes, mesh gradient, font scale, system dynamic colors)
   - `settings_privacy_screen.dart` (Online status visibility, E2EE shortcut, Android predictive back, background mode, spam block)
   - `settings_storage_screen.dart` (Storage breakdown, cache clearing, draft clearing)
   - `settings_language_region_screen.dart` (App language, timezone mode & picker, local time preview)
   - `settings_preferences_screen.dart` (Push notifications, sound effects & volume slider, haptics, compact mode, weak device mode, reset)
   - `settings_about_screen.dart` (Hero banner, rotating M3 cookie logo, developers, FAQ, changelog, legal info)
   - `e2ee_settings_screen.dart` (Device cryptographic keypair, rotate keys, erase secret chats)
   - `sessions_screen.dart` (Active session list, device icons, revoke session, terminate other sessions)
   - `legal_viewer_screen.dart` (In-depth privacy, terms of service, and consent document viewer)

2. **Navigation & Router Structure (`lib/router/app_router.dart`):**
   - Main entry point is `/main/:tab` (tab `profile`).
   - `/settings` currently redirects to `/main/profile`.
   - Sub-screens are registered as individual top-level routes (`/settings/account`, `/settings/appearance`, `/settings/privacy`, `/settings/storage`, `/settings/language-region`, `/settings/preferences`, `/settings/about`, `/settings/e2ee`, `/settings/sessions`).
   - On mobile, tapping sections in `profile_screen.dart` executes `context.push('/settings/<subpath>')`.
   - On desktop/web (screens $\ge 760\text{dp}$), `profile_screen.dart` is currently constrained to `maxWidth: 780dp` in a single column without 2-pane Master-Detail split. Navigating to sub-screens triggers a full-window modal push over the desktop layout.

3. **Master-Detail 2-Pane Architecture Requirement:**
   - On desktop/wide screens ($\ge 760\text{dp}$), Settings must transition into an ergonomic 2-pane layout:
     - **Left Master Pane (320–360dp):** Persistent expressive navigation sidebar featuring user profile header and interactive section tiles with `colorScheme.secondaryContainer` active state highlights.
     - **Right Detail Pane (Expanded):** In-place rendering of the selected settings sub-screen with animated transitions, removing awkward full-screen context switches.
     - **Mobile Fallback (< 760dp):** Preserves native stacked navigation.

4. **M3 Expressive Standardization:**
   - Universal adoption of `colorScheme.surfaceContainerLow` for grouped section cards.
   - 20dp smooth rounded corners on cards and 16dp squircles for leading tonal icons.
   - `Switch.adaptive` with integrated haptic and auditory feedback.
   - High-contrast tonal sliders and `SegmentedButton` controls.
   - Strict adherence to zero hardcoded colors (`Colors.white`/`Colors.black` prohibited) and zero deprecated `withOpacity()`.

---

## 2. Detailed Screen Analysis & Inventory

### 2.1 Screen Matrix

| Screen File | Route | State / Providers | Core Features & Controls |
| :--- | :--- | :--- | :--- |
| `profile_screen.dart` | `/main/profile`<br>`/settings` | `authProvider`<br>`localStorageServiceProvider` | Sticky collapsible header (`ProfileHeaderDelegate`), avatar upload, user badges, bio, section entry points, logout button, `_EditProfileDialog`. |
| `settings_account_screen.dart` | `/settings/account` | `authProvider`<br>`biometricServiceProvider`<br>`authRepositoryProvider` | Active sessions link, biometrics toggle with authentication challenge, 2FA toggle with password verification dialog. |
| `settings_appearance_screen.dart` | `/settings/appearance` | `uiSettingsProvider` | Interactive 4-point mesh gradient banner, 8 seed color palette orbs, 3-way theme mode cards (Light/Dark/System) with circular reveal, dynamic color toggle, floating nav toggle, 4-tier font scale segmented button. |
| `settings_privacy_screen.dart` | `/settings/privacy` | `uiSettingsProvider`<br>`authProvider` | Hide online status switch, E2EE secret chat shortcut, predictive back toggle (Android), background service mode (Economy/Reliable/Off), spam block status. |
| `settings_storage_screen.dart` | `/settings/storage` | `localStorageServiceProvider`<br>`cacheServiceProvider`<br>`EncryptedMessageCache` | App data vs cache vs drafts segmented progress bar, storage category cards, cache clearing, draft clearing, refresh action. |
| `settings_language_region_screen.dart` | `/settings/language-region` | `uiSettingsProvider` | Language selector (`SegmentedButton` Auto/RU/EN), Timezone mode (Auto/Manual), searchable modal timezone picker (`appTimeZoneOptions`), live local time preview. |
| `settings_preferences_screen.dart` | `/settings/preferences` | `uiSettingsProvider` | Push notifications switch, sound effects switch + volume slider (0–100%), haptic feedback switch, compact mode switch, weak device optimization switch, reset all settings action. |
| `settings_about_screen.dart` | `/settings/about` | `package_info_plus` | Hero block with rotating M3 9-sided cookie logo badge, version pill, action chips, 4 tabs: Developers (Sanlsan, SH20FK), FAQ (10 Q&A items), Changelog (v3.0.0–v2.0.0), Legal links. |
| `e2ee_settings_screen.dart` | `/settings/e2ee` | `e2eeServiceProvider`<br>`authRepositoryProvider` | Device keypair status, key generation, keypair rotation with re-keying, cryptographic erase of secret chats and attachments. |
| `sessions_screen.dart` | `/settings/sessions` | `authRepositoryProvider` | Active session devices with platform-specific icons (iOS, Android, macOS, Windows, Linux, Web), current session badge, individual session revoke, terminate all other sessions button. |
| `legal_viewer_screen.dart` | `/legal/privacy`<br>`/legal/tos`<br>`/legal/consent` | Local asset parser | Legal document reader with section index chips, full-text live search, copy to clipboard, GDPR/E2EE verification badges, confirm button. |

---

## 3. Navigation & Router Flow Inspection

### 3.1 Existing AppRouter (`lib/router/app_router.dart`)
The router uses `go_router` (v17.x) wrapped in a Riverpod `Provider<GoRouter>`:
```dart
// Route definitions in app_router.dart
GoRoute(
  path: '/main/:tab',
  pageBuilder: (context, state) => _page(
    state,
    MainShellScreen(tab: state.pathParameters['tab'] ?? 'chats'),
    pageKey: const ValueKey<String>('main-shell'),
  ),
),
GoRoute(
  path: '/settings',
  redirect: (context, state) => '/main/profile',
),
GoRoute(path: '/settings/appearance', pageBuilder: (c, s) => _page(s, const SettingsAppearanceScreen())),
GoRoute(path: '/settings/language-region', pageBuilder: (c, s) => _page(s, const SettingsLanguageRegionScreen())),
GoRoute(path: '/settings/account', pageBuilder: (c, s) => _page(s, const SettingsAccountScreen())),
GoRoute(path: '/settings/privacy', pageBuilder: (c, s) => _page(s, const SettingsPrivacyScreen())),
GoRoute(path: '/settings/storage', pageBuilder: (c, s) => _page(s, const SettingsStorageScreen())),
GoRoute(path: '/settings/about', pageBuilder: (c, s) => _page(s, const SettingsAboutScreen())),
GoRoute(path: '/settings/e2ee', pageBuilder: (c, s) => _page(s, const E2eeSettingsScreen())),
GoRoute(path: '/settings/preferences', pageBuilder: (c, s) => _page(s, const SettingsPreferencesScreen())),
GoRoute(path: '/settings/sessions', pageBuilder: (c, s) => _page(s, const SessionsScreen())),
```

### 3.2 Navigation Flow Differences

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Current Mobile Flow                                                     │
│                                                                         │
│  MainShellScreen (tab: profile)                                         │
│       │                                                                 │
│       ├── (tap "Внешний вид") ──> context.push('/settings/appearance')  │
│       │                                 └── Full-Screen Page (Back btn) │
│       └── (tap "Приватность") ──> context.push('/settings/privacy')     │
│                                         └── Full-Screen Page (Back btn) │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ Target Desktop/Wide Flow (Master-Detail 2-Pane)                         │
│                                                                         │
│  MainShellScreen (tab: profile, width >= 760dp)                         │
│  ┌─────────────────────────┬─────────────────────────────────────────┐  │
│  │ Master Pane (320-360dp) │ Detail Pane (Expanded)                  │  │
│  │                         │                                         │  │
│  │ [User Header & Bio]     │ In-Place Sub-Screen                     │  │
│  │ [•] Аккаунт             │ (e.g. SettingsAppearanceScreen)         │  │
│  │ [✓] Внешний вид (active)│ - Embedded presentation                 │  │
│  │ [•] Приватность         │ - Smooth animated transition            │  │
│  │ [•] Хранилище           │ - No redundant back button              │  │
│  │ [•] Язык и регион       │ - Instant reactive switching            │  │
│  │ [•] Уведомления         │                                         │  │
│  │ [•] О приложении        │                                         │  │
│  │ [•] E2EE & Сессии       │                                         │  │
│  └─────────────────────────┴─────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Master-Detail 2-Pane Architecture Specification

### 4.1 Layout Architecture & Breakpoints
- **Breakpoint:** `constraints.maxWidth >= 760dp` triggers wide desktop layout (matching `MainShellScreen` and chat list split behavior).
- **Master Pane Width:** `340.0dp` (clamp: 320–360dp based on screen width).
- **Divider:** 1dp vertical separator with `colorScheme.outlineVariant.withValues(alpha: 0.2)`.
- **Detail Pane:** `Expanded` widget filling remaining viewport width, wrapping the active sub-screen in a responsive container with `maxWidth: 840dp` centering.

### 4.2 Section Identification & Enum Model
```dart
enum SettingsSectionId {
  account,
  appearance,
  privacy,
  storage,
  languageRegion,
  preferences,
  about,
  e2ee,
  sessions,
}
```

### 4.3 Desktop Selection State Provider
```dart
class DesktopSettingsSectionNotifier extends Notifier<SettingsSectionId> {
  @override
  SettingsSectionId build() => SettingsSectionId.account;

  void selectSection(SettingsSectionId section) {
    state = section;
  }
}

final NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId>
    desktopSelectedSettingsSectionProvider =
        NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId>(
  DesktopSettingsSectionNotifier.new,
);
```

### 4.4 Master Pane Visual Design Tokens
- **User Header Block:** Compact avatar (radius 24dp), display name, username, edit profile trigger.
- **Section Tile in Master List:**
  - Unselected:
    - Background: `Colors.transparent`
    - Leading squircle: `colorScheme.surfaceContainerHigh` with `colorScheme.onSurfaceVariant` icon.
    - Title: `colorScheme.onSurface`, `FontWeight.w600`.
  - Selected (Active Highlight):
    - Background: `colorScheme.secondaryContainer` (or `primaryContainer`) with `BorderRadius.circular(16)`.
    - Leading squircle: `colorScheme.secondary` (or `primary`) with `colorScheme.onSecondary` icon.
    - Title: `colorScheme.onSecondaryContainer`, `FontWeight.w700`.
    - Trailing: `Icon(Icons.chevron_right_rounded, color: colorScheme.onSecondaryContainer)`.

### 4.5 Detail Pane Sub-Screen Rendering & Embed Mode
When embedded in the right pane:
1. `SettingsScaffold` accepts `isEmbedded: true` (or detects wide parent layout):
   - Suppresses top `AppBar` and back arrow icon button.
   - Direct header rendering with `headlineMedium` typography.
   - Retains smooth scrollable body and pull-to-refresh where applicable.
2. Animated transition between sections:
   - `PageTransitionSwitcher` with `SharedAxisTransition(transitionType: SharedAxisTransitionType.vertical, fillColor: Colors.transparent)`.

---

## 5. Material 3 Expressive Standardization Requirements

To achieve a uniform, premium Material 3 Expressive visual hierarchy across all settings screens, the following standards must be applied:

### 5.1 Container & Surface Tokens
- **Grouped Section Containers:**
  - Background: `colorScheme.surfaceContainerLow` (replaced legacy `surfaceContainer.withValues(alpha: 0.72)`).
  - Shape: `RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))`.
  - Border: `Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.16), width: 1.0)`.
- **Top Nav Banners:**
  - Background: `colorScheme.surfaceContainerLow.withValues(alpha: 0.85)`.
  - Radius: `24dp`–`28dp`.
  - Border: `Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.18))`.

### 5.2 Leading Tonal Icon Squircles
- **Container Size:** 44×44dp (or 48×48dp for banners).
- **Radius:** `16dp` continuous squircle corner.
- **Coloring:** `color: resolvedIconColor.withValues(alpha: 0.12)`.
- **Icon Size:** 20–22dp, crisp tint matching section theme.

### 5.3 Interactive Controls & Form Elements
- **Switches:** Use `Switch.adaptive` everywhere with M3 active track and thumb colors. Toggling must trigger `HapticService.tap()` and `appSoundProvider.playUiTick()`.
- **Segmented Buttons:** High-contrast M3 `SegmentedButton` with tonal indicator (`primaryContainer` / `onPrimaryContainer`) for theme mode, font scale, language selection, and timezone mode.
- **Sliders:** M3 tonal sliders with active primary track, surface container highest inactive track, discrete step divisions, and percentage/value indicator.
- **Dialogs & Bottom Sheets:** Standardized via `AppDialog`, `showAppConfirmDialog`, and `AppBottomSheets` with 28dp top radius and drag handle.

### 5.4 Code Hygiene & Linting Standards
- **Zero Color Literals:** No `Colors.white`, `Colors.black`, or raw hex constants. All colors sourced from `Theme.of(context).colorScheme`.
- **Flutter 3.27+ API Compliance:** Replace all instances of deprecated `.withOpacity(x)` with `.withValues(alpha: x)`.
- **WidgetStatePropertyAll:** Explicit generic typing `WidgetStatePropertyAll<Color>(...)`.

---

## 6. State Interactions & Providers Map

```
┌────────────────────────────────────────────────────────────────────────┐
│ Riverpod Providers Interacting with Settings                           │
├────────────────────────────────┬───────────────────────────────────────┤
│ Provider                       │ Responsibilities / State Attributes   │
├────────────────────────────────┼───────────────────────────────────────┤
│ authProvider                   │ • Session data (username, user_id)    │
│ (NotifierProvider)             │ • User profile (displayName, bio,     │
│                                │   avatarUrl, twoFaEnabled, spamBlock) │
│                                │ • Logout / refreshProfile methods     │
├────────────────────────────────┼───────────────────────────────────────┤
│ uiSettingsProvider             │ • themeMode, seedColor, dynamicColor  │
│ (NotifierProvider)             │ • fontScale, navBarFloating           │
│                                │ • notifications, soundEffects, volume │
│                                │ • haptics, compactMode, optimizeWeak  │
│                                │ • predictiveBackEnabled               │
│                                │ • localeCode, timeZoneMode, timeZoneId│
│                                │ • backgroundMode (Android)            │
├────────────────────────────────┼───────────────────────────────────────┤
│ desktopSelectedChatProvider    │ • Selected chat ID for desktop 2-pane │
├────────────────────────────────┼───────────────────────────────────────┤
│ desktopSelectedSettingsSection │ • Proposed new provider for desktop   │
│ Provider (NotifierProvider)    │   Master-Detail active tab tracking   │
├────────────────────────────────┼───────────────────────────────────────┤
│ localStorageServiceProvider    │ • Storage size snapshot calculation   │
│                                │ • Clear temporary files & drafts      │
├────────────────────────────────┼───────────────────────────────────────┤
│ cacheServiceProvider           │ • Media cache management & purge      │
├────────────────────────────────┼───────────────────────────────────────┤
│ EncryptedMessageCache          │ • Secret message local cache purge    │
├────────────────────────────────┼───────────────────────────────────────┤
│ biometricServiceProvider       │ • Biometric support detection         │
│                                │ • Authenticate & toggle biometric auth│
├────────────────────────────────┼───────────────────────────────────────┤
│ e2eeServiceProvider            │ • Keypair generation & verification   │
│                                │ • Keypair deletion / rotation         │
├────────────────────────────────┼───────────────────────────────────────┤
│ authRepositoryProvider         │ • Backend 2FA toggle, avatar upload   │
│                                │ • Session query & revoke API          │
│                                │ • Public key registration & erase     │
├────────────────────────────────┼───────────────────────────────────────┤
│ appSoundProvider               │ • UI tick sounds & confirmation audio │
├────────────────────────────────┼───────────────────────────────────────┤
│ connectivityProvider           │ • Network status monitoring           │
└────────────────────────────────┴───────────────────────────────────────┘
```

---

## 7. Migration & Implementation Blueprint

### Step 1: Create Desktop Settings Provider & Enums
- Add `lib/providers/desktop_settings_provider.dart` with `SettingsSectionId` enum and `desktopSelectedSettingsSectionProvider`.

### Step 2: Refactor `SettingsScaffold` for Embed Adaptivity
- Update `lib/widgets/settings_ui.dart` so `SettingsScaffold` supports `isEmbedded` property or automatically omits standalone `AppBar` and back arrow when rendered inside a wide split pane.
- Update `SettingsSection` and `SettingsTile` to use `surfaceContainerLow` and 20dp border radii.

### Step 3: Implement Master-Detail Layout in `ProfileScreen` / Settings Shell
- Update `lib/screens/profile_screen.dart` (or create a dedicated `SettingsMasterDetailScreen`):
  - On wide screen ($\ge 760\text{dp}$): render `Row` with Left Master Pane (340dp) and Right Detail Pane (`Expanded` rendering the selected screen from `desktopSelectedSettingsSectionProvider`).
  - On mobile screen ($< 760\text{dp}$): retain existing single-column profile view with full headers and `context.push` navigation.

### Step 4: Refactor All Individual Settings Sub-Screens
- Standardize cards, switches (`Switch.adaptive`), sliders, and icon squircles in:
  - `settings_account_screen.dart`
  - `settings_appearance_screen.dart`
  - `settings_privacy_screen.dart`
  - `settings_storage_screen.dart`
  - `settings_language_region_screen.dart`
  - `settings_preferences_screen.dart`
  - `settings_about_screen.dart`
  - `e2ee_settings_screen.dart`
  - `sessions_screen.dart`

### Step 5: Route Harmonization in `app_router.dart`
- Ensure direct URL hits to `/settings/appearance`, `/settings/account`, etc. properly sync the `desktopSelectedSettingsSectionProvider` on desktop and display the appropriate view.

---

## 8. Conclusion
The NiosMess Settings ecosystem has a robust feature set and clean separation between business logic and UI. By transitioning to a 2-pane Master-Detail layout on desktop and standardizing all sub-screens on Material 3 Expressive surfaces, icon squircles, and adaptive widgets, NiosMess will deliver an exceptional, cohesive settings experience across desktop, web, and mobile platforms.
