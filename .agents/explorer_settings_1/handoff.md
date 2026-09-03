# Handoff Report: Settings Master-Detail Architecture & Settings Screens M3 Expressive Overhaul

**Milestone**: Milestone 2 & 3  
**Working Directory**: `f:\Niosmess V2\.agents\explorer_settings_1`  
**Handoff Type**: Hard (Complete Investigation & Architectural Plan)

---

## 1. Observation

Direct observations from codebase inspection across `pulse_flutter`:

1. **`lib/screens/main_shell_screen.dart` (lines 151-193, 268-274)**:
   - Line 153 defines wide breakpoint: `final bool isWide = constraints.maxWidth >= 760;`.
   - Line 191 constrains tab 3 (Profile):
     ```dart
     isWide
         ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: const ProfileScreen()))
         : const ProfileScreen(),
     ```
   - On wide viewports ($\ge 760\text{dp}$), `ProfileScreen` is artificially bounded to `780dp`, preventing it from taking full advantage of the split Master-Detail layout. Removing `ConstrainedBox(maxWidth: 780)` allows `ProfileScreen` to expand cleanly across available desktop real estate.

2. **`lib/screens/profile_screen.dart` (lines 113-245)**:
   - `ProfileScreen` currently uses a single `CustomScrollView` with `ProfileHeaderDelegate` in a `SliverPersistentHeader` and stacked `SettingsSection` cards.
   - All section taps directly push routes (e.g., `onTap: () => context.push('/settings/account')`, lines 154, 162, 175, 183, 191, 198, 212).
   - No 2-pane Master-Detail layout or embedded selection handling currently exists in `ProfileScreen`.

3. **`lib/widgets/settings_ui.dart` (lines 12-124, 198-299, 301-383, 385-455)**:
   - `SettingsScaffold` (lines 12-124) hardcodes `topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;` and wraps in a full `Scaffold` with an `AppBar` and back button (`Navigator.canPop(context)`). It does not accept an `isEmbedded` parameter.
   - `SettingsSection` (lines 252-261) uses `scheme.surfaceContainer.withValues(alpha: 0.72)` and `BorderRadius.circular(28)` instead of standardized `surfaceContainerLow` with 20dp smooth radius.
   - `SettingsTile` (lines 301-383) uses 44x44dp icon containers with `BorderRadius.circular(16)` but lacks an `isSelected` active highlight property.
   - `SettingsSwitchTile` (lines 442-452) uses raw `Switch` instead of `Switch.adaptive`.

4. **Settings Sub-Screens Inventory (`lib/screens/`)**:
   - `settings_account_screen.dart`: `ConsumerStatefulWidget`, uses `SettingsScaffold`, missing `isEmbedded` parameter.
   - `settings_appearance_screen.dart`: `ConsumerWidget`, uses `SettingsScaffold`, contains `_MeshWithOrbs` and `_ThemeModeSelector`, missing `isEmbedded`.
   - `settings_privacy_screen.dart`: `ConsumerWidget`, uses `SettingsScaffold`, missing `isEmbedded`.
   - `settings_storage_screen.dart`: `ConsumerStatefulWidget`, uses `SettingsScaffold`, custom `_StorageCategoryCard` row uses 22dp radius and `surfaceContainerLow`, missing `isEmbedded`.
   - `settings_language_region_screen.dart`: `ConsumerWidget`, uses `SettingsScaffold`, segmented buttons, missing `isEmbedded`.
   - `settings_preferences_screen.dart`: `ConsumerWidget`, uses `SettingsScaffold`, volume slider, raw switches, missing `isEmbedded`.
   - `settings_about_screen.dart`: `StatefulWidget` with `NestedScrollView` and `TabBar`, creates its own standalone `Scaffold` and `AppBar`, does not use `SettingsScaffold` or support `isEmbedded`.
   - `e2ee_settings_screen.dart`: `ConsumerStatefulWidget`, uses `SettingsScaffold`, missing `isEmbedded`.
   - `sessions_screen.dart`: `ConsumerStatefulWidget`, uses `SettingsScaffold`, missing `isEmbedded`.

5. **`lib/router/app_router.dart` (lines 222-260)**:
   - All 9 settings sub-routes are individually registered:
     * `/settings/appearance` (line 226)
     * `/settings/language-region` (line 230)
     * `/settings/account` (line 234)
     * `/settings/privacy` (line 238)
     * `/settings/storage` (line 242)
     * `/settings/about` (line 246)
     * `/settings/e2ee` (line 250)
     * `/settings/preferences` (line 254)
     * `/settings/sessions` (line 258)
   - Deep links and stacked routes can remain intact for mobile and direct URL access while the desktop Master-Detail layout embeds them dynamically.

---

## 2. Logic Chain

1. **Master-Detail Desktop Architecture**:
   - Based on Observation 1, unconstraining `ProfileScreen` in `MainShellScreen` on wide screens ($\ge 760\text{dp}$) allows `ProfileScreen` to host a full-width Master-Detail 2-pane view.
   - Based on Observation 2, introducing `desktopSelectedSettingsSectionProvider` (`NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId?>`) provides reactive state for the currently active section in the Master-Detail coordinator.
   - Based on Observation 2 and 5, on desktop ($\ge 760\text{dp}$), tapping a settings section updates `desktopSelectedSettingsSectionProvider` rather than pushing a route, rendering the sub-screen in-place in the right detail pane. On mobile ($< 760\text{dp}$), it seamlessly falls back to `context.push('/settings/...')`.

2. **Standardizing `settings_ui.dart` for Embedded & Standalone Modes**:
   - Based on Observation 3, adding `isEmbedded: false` to `SettingsScaffold` allows detail panes to suppress redundant `AppBar`s and back buttons while resetting `topPadding` to a compact 16dp and `horizontalPadding` to 20dp.
   - Standardizing `SettingsSection` to `color: scheme.surfaceContainerLow` and `BorderRadius.circular(20)` ensures unified M3 Expressive card grouping across all screens.
   - Adding `isSelected` to `SettingsTile` allows the master pane to highlight the active section with `secondaryContainer` and `onSecondaryContainer` tokens.
   - Updating `SettingsSwitchTile` to `Switch.adaptive` aligns with Flutter M3 cross-platform guidelines.

3. **Sub-Screen Migration**:
   - Based on Observation 4, adding `this.isEmbedded = false` to all 9 sub-screens and passing it to `SettingsScaffold` guarantees full compatibility in both standalone route mode (mobile / deep link) and embedded Master-Detail detail pane mode (desktop).
   - Modernizing `settings_about_screen.dart` with `isEmbedded` support and standardized `surfaceContainerLow` cards harmonizes the entire settings subsystem.

---

## 3. Caveats

- **No Backend Changes**: All settings sub-screens interact with local storage (`LocalStorageService`, `UiSettingsNotifier`) and existing REST/WebSocket APIs (`AuthRepository`, `E2eeService`). No backend protocol changes are required.
- **Deep Link Navigation Parity**: When a user on desktop navigates directly to `/settings/appearance` via URL or external deep link, the router renders `SettingsAppearanceScreen(isEmbedded: false)` as a top-level route with a back button. This is expected and standard GoRouter behavior. Inside the main app shell (`/main/profile`), switching happens in-place via `desktopSelectedSettingsSectionProvider`.

---

## 4. Conclusion

The investigation confirms that implementing Milestone 2 & 3 requires:
1. Creating `pulse_flutter/lib/providers/settings_navigation_provider.dart` with `SettingsSectionId` enum and `desktopSelectedSettingsSectionProvider`.
2. Standardizing `pulse_flutter/lib/widgets/settings_ui.dart` with `isEmbedded: bool` in `SettingsScaffold`, `surfaceContainerLow` and 20dp radius in `SettingsSection`, `isSelected` styling in `SettingsTile`, and `Switch.adaptive` in `SettingsSwitchTile`.
3. Updating `main_shell_screen.dart` and `profile_screen.dart` to coordinator Master-Detail layout on wide screens ($\ge 760\text{dp}$) with 340dp master pane and expanded detail pane.
4. Refactoring all 9 settings sub-screens to support `isEmbedded` and standardized M3 Expressive tokens.
5. Creating dedicated widget and responsive tests in `test/widgets/settings_master_detail_test.dart` and `test/widgets/settings_screens_m3_test.dart`.

The full architecture, code contracts, and execution steps are documented in `f:\Niosmess V2\.agents\explorer_settings_1\plan.md`.

---

## 5. Verification Method

### Automated Testing & Static Analysis
1. **Unit & Widget Tests**:
   - Run: `flutter test test/widgets/settings_master_detail_test.dart`
   - Run: `flutter test test/widgets/settings_screens_m3_test.dart`
   - Run full test suite: `flutter test`
2. **Static Analysis**:
   - Run: `flutter analyze`
   - Expected: 0 issues, 0 warnings, 0 errors.
3. **Web Build Verification**:
   - Run: `flutter build web --profile` (or `flutter run -d chrome`)
4. **Visual & Responsive Inspection**:
   - Mobile ($360\text{dp}\times 800\text{dp}$): Stacked navigation, full `AppBar` on sub-screens.
   - Desktop ($1200\text{dp}\times 800\text{dp}$): 2-pane Master-Detail layout with active `secondaryContainer` highlight on selected master tile and in-place detail pane rendering without `AppBar`.
