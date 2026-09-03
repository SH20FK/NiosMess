# Handoff Report: Settings & Navigation Survey

**Agent:** Explorer 2 (`.agents/explorer_survey_2`)  
**Parent Agent:** `c161be69-def7-4b17-96ef-099a84377da2` (parent)  
**Date:** 2026-09-02  
**Task:** Codebase survey of Settings screens, Navigation & Router, 2-Pane Master-Detail layout, M3 Expressive tokens, and Riverpod state interactions.

---

## 1. Observation

1. **Settings Screen Files Locations:**
   - `lib/screens/profile_screen.dart` (500 lines): Hub for user profile and settings section links.
   - `lib/screens/settings_account_screen.dart` (202 lines): Sessions link, biometrics toggle, 2FA toggle.
   - `lib/screens/settings_appearance_screen.dart` (562 lines): Mesh gradient, theme mode cards, dynamic colors, font scale.
   - `lib/screens/settings_privacy_screen.dart` (145 lines): Hide online, E2EE shortcut, predictive back, background mode.
   - `lib/screens/settings_storage_screen.dart` (424 lines): Storage breakdown bar, cache & draft purge.
   - `lib/screens/settings_language_region_screen.dart` (257 lines): Language selector, timezone picker sheet.
   - `lib/screens/settings_preferences_screen.dart` (158 lines): Push notifications, volume slider, haptics, compact mode, reset.
   - `lib/screens/settings_about_screen.dart` (1005 lines): Hero cookie logo badge, version, 4 tabs (Developers, FAQ, Changelog, Legal).
   - `lib/screens/e2ee_settings_screen.dart` (175 lines): Keypair status, rotate keys, erase secret chats.
   - `lib/screens/sessions_screen.dart` (401 lines): Device list, session revoke, terminate all.
   - `lib/screens/legal_viewer_screen.dart` (846 lines): Privacy, ToS, Consent reader.

2. **Routing in `lib/router/app_router.dart` (lines 222–260):**
   - Direct `/settings` redirects to `/main/profile` (line 223).
   - Dedicated routes exist for `/settings/appearance`, `/settings/language-region`, `/settings/account`, `/settings/privacy`, `/settings/storage`, `/settings/about`, `/settings/e2ee`, `/settings/preferences`, `/settings/sessions`.
   - In `MainShellScreen` (`lib/screens/main_shell_screen.dart`, lines 153–193):
     - Screen width breakpoint `constraints.maxWidth >= 760` enables desktop 2-pane for Chats (Tab 0: `ChatListScreen` + `ChatDetailScreen`), but Tab 3 (`ProfileScreen`) is simply wrapped in `ConstrainedBox(maxWidth: 780)` in single-column layout without Master-Detail pane splitting.

3. **Shared Settings UI in `lib/widgets/settings_ui.dart` (576 lines):**
   - `SettingsScaffold`: Includes top `AppBar` with `Navigator.canPop(context)` back button, gradient background, and `PulseScaffoldBody(maxWidth: 920)`.
   - `SettingsSection`: Wraps child tiles in `Material(color: scheme.surfaceContainer.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(28))`.
   - `SettingsTile`: Renders leading squircle (`Container(width: 44, height: 44, borderRadius: 16)`), title, subtitle, trailing chevron.
   - `SettingsSwitchTile`: Standard switch with haptics and sound tick.

---

## 2. Logic Chain

1. **Current Desktop Experience Limitation:**
   - On screens $\ge 760\text{dp}$, while chats utilize a Master-Detail split (`desktopSelectedChatProvider`), Settings (under `/main/profile`) renders as a single centered column.
   - When a user taps a section (e.g. "Внешний вид"), it invokes `context.push('/settings/appearance')`, popping open a full-window route that completely obscures the `NavigationRail` and main application shell.

2. **Master-Detail 2-Pane Solution:**
   - When screen width $\ge 760\text{dp}$:
     - Left Master Pane ($320\text{–}360\text{dp}$): Persistent vertical list of settings sections with user profile header and reactive selection indicator (`colorScheme.secondaryContainer` background with 16dp rounded corners).
     - Right Detail Pane (`Expanded`): In-place rendering of the active sub-screen driven by a new `desktopSelectedSettingsSectionProvider` (`NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId>`).
   - `SettingsScaffold` should support embedded mode (`isEmbedded: true`) to omit top `AppBar` and back arrow when presented inside the split detail pane.

3. **M3 Expressive Harmonization:**
   - Grouped cards: Standardize to `colorScheme.surfaceContainerLow` with `BorderRadius.circular(20)` and `colorScheme.outlineVariant.withValues(alpha: 0.16)`.
   - Interactive components: Use `Switch.adaptive`, high-contrast `SegmentedButton`, and tonal sliders with semantic tokens and zero hardcoded colors.

---

## 3. Caveats

- **Deep Link Navigation on Desktop:** If a user accesses `/settings/appearance` directly via browser URL on desktop, the router should either display the Master-Detail shell with `appearance` preselected in `desktopSelectedSettingsSectionProvider`, or display the standalone page adaptively.
- **Biometrics on Desktop/Web:** Biometrics check in `SettingsAccountScreen` is conditionally rendered based on `biometricServiceProvider.canCheckBiometrics` (typically false on web/desktop unless hardware supports it).

---

## 4. Conclusion

The codebase is well-structured and ready for the Settings M3 Expressive and Master-Detail overhaul. All 10 screens and shared widgets have been surveyed, routes documented, state providers mapped, and a comprehensive migration plan delivered in `survey_report.md`.

---

## 5. Verification Method

To independently verify the survey observations:
1. **Inspect Route Registrations:**
   ```bash
   # In pulse_flutter/
   grep -n "/settings" lib/router/app_router.dart
   ```
2. **Inspect Existing Chat Desktop Split Reference:**
   ```bash
   grep -n "desktopSelectedChatProvider" lib/screens/main_shell_screen.dart lib/screens/chat_list_screen.dart
   ```
3. **Verify Settings Screen Files:**
   Check existence and contents of `lib/screens/settings_*.dart`, `lib/screens/profile_screen.dart`, `lib/screens/e2ee_settings_screen.dart`, `lib/screens/sessions_screen.dart`, and `lib/widgets/settings_ui.dart`.
4. **Run Static Analysis & Tests:**
   ```bash
   flutter analyze
   flutter test
   ```
