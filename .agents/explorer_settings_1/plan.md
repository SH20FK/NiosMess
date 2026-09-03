# Settings Master-Detail Architecture & M3 Expressive Overhaul Plan (Milestone 2 & 3)

## 1. Executive Summary & Architectural Overview

This document specifies the technical architecture, component contracts, state management, and detailed per-screen refactoring plan for **Milestone 2 (Settings Master-Detail Architecture)** and **Milestone 3 (Settings Screens M3 Expressive Overhaul)** in `pulse_flutter`.

### Key Objectives
1. **Responsive 2-Pane Master-Detail**:
   - On wide viewports ($\ge 760\text{dp}$): A master navigation pane ($320\text{–}360\text{dp}$) displaying the user profile summary and active settings sections with tonal highlight (`secondaryContainer`), coupled with an expanded detail pane rendering the selected settings sub-screen in-place.
   - On mobile/compact viewports ($< 760\text{dp}$): Preserves the classic full-screen stacked navigation (`context.push('/settings/...')`) with zero regression.
2. **Standardized M3 Expressive Settings System (`settings_ui.dart`)**:
   - Standardize `SettingsScaffold` with `isEmbedded` parameter to eliminate redundant app bars and outer padding when hosted in the detail pane.
   - Standardize `SettingsSection` to strictly use `surfaceContainerLow`, 20dp smooth border radius, and subtle border outline.
   - Standardize `SettingsTile` with 44dp squircle tonal icon containers matching section category, chevron indicators, and selection highlight state.
   - Standardize `SettingsSwitchTile` with `Switch.adaptive`.
3. **Comprehensive Sub-Screen Overhaul**:
   - Refactor all 9 settings sub-screens (`settings_account_screen.dart`, `settings_appearance_screen.dart`, `settings_privacy_screen.dart`, `settings_storage_screen.dart`, `settings_language_region_screen.dart`, `settings_preferences_screen.dart`, `settings_about_screen.dart`, `e2ee_settings_screen.dart`, `sessions_screen.dart`) to conform strictly to `SettingsScaffold(isEmbedded: isEmbedded)`, `surfaceContainerLow`, and M3 Expressive tokens.

---

## 2. State Management: `desktopSelectedSettingsSectionProvider`

### 2.1 Provider Architecture
Location: `pulse_flutter/lib/providers/settings_navigation_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifiers for each settings section in Master-Detail.
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

class DesktopSettingsSectionNotifier extends Notifier<SettingsSectionId?> {
  @override
  SettingsSectionId? build() => SettingsSectionId.account;

  void setSelectedSection(SettingsSectionId? section) {
    state = section;
  }
}

final NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId?>
    desktopSelectedSettingsSectionProvider =
        NotifierProvider<DesktopSettingsSectionNotifier, SettingsSectionId?>(
  DesktopSettingsSectionNotifier.new,
);
```

### 2.2 Deep Link & Route Parity Contract
- **Direct Router Navigation**: Routes `/settings/account`, `/settings/appearance`, `/settings/privacy`, `/settings/storage`, `/settings/language-region`, `/settings/preferences`, `/settings/about`, `/settings/e2ee`, and `/settings/sessions` remain fully registered in `app_router.dart`.
- When accessed directly on web/mobile, each screen runs in standalone mode (`isEmbedded: false`).
- When accessed inside `/main/profile` on desktop ($\ge 760\text{dp}$), selecting any section sets the state in `desktopSelectedSettingsSectionProvider` and embeds the sub-screen in the detail pane with `isEmbedded: true`.

---

## 3. Standardized M3 Settings UI Framework (`lib/widgets/settings_ui.dart`)

### 3.1 `SettingsScaffold`
```dart
class SettingsScaffold extends ConsumerWidget {
  const SettingsScaffold({
    this.title,
    required this.children,
    this.onRefresh,
    this.isEmbedded = false,
    this.maxWidth = 920,
    super.key,
  });

  final String? title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final bool isEmbedded;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool optimize = settings.optimizeForWeakDevices;
    final bool hasNavBanner = children.isNotEmpty && children.first is SettingsNavBanner;
    
    final double topPadding = isEmbedded
        ? 16.0
        : (MediaQuery.paddingOf(context).top + kToolbarHeight + 8.0);
    final double horizontalPadding = isEmbedded ? 20.0 : AppConstants.screenHorizontalPadding;

    final Widget content = ListView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, 28),
      children: <Widget>[
        if (!hasNavBanner && title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
            ),
          ),
        ...children.asMap().entries.map((MapEntry<int, Widget> entry) {
          final Widget child = entry.value;
          if (optimize || isEmbedded) {
            return child;
          }
          final int index = entry.key;
          final int delayMs = (index < 6) ? index * 45 : 0;
          return child
              .animate()
              .fade(
                duration: const Duration(milliseconds: 260),
                delay: Duration(milliseconds: delayMs),
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: 0.05,
                end: 0,
                duration: const Duration(milliseconds: 260),
                delay: Duration(milliseconds: delayMs),
                curve: Curves.easeOutCubic,
              );
        }),
      ],
    );

    final Widget bodyContent = onRefresh != null
        ? RefreshIndicator(onRefresh: onRefresh!, child: content)
        : content;

    if (isEmbedded) {
      return ColoredBox(
        color: scheme.surface,
        child: PulseScaffoldBody(
          maxWidth: maxWidth,
          expand: true,
          topSafe: false,
          bottomSafe: true,
          child: bodyContent,
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Material(
                  color: scheme.surface.withValues(alpha: 0.78),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              )
            : null,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.035),
                scheme.surface,
              ),
              scheme.surface,
            ],
          ),
        ),
        child: PulseScaffoldBody(
          maxWidth: maxWidth,
          child: bodyContent,
        ),
      ),
    );
  }
}
```

### 3.2 `SettingsSection`
- **Surface**: `scheme.surfaceContainerLow`
- **Border Radius**: `BorderRadius.circular(20)`
- **Border**: `Border.all(color: scheme.outlineVariant.withValues(alpha: 0.15))`
- **Child Dividers**: `Divider(height: 1, indent: 68, endIndent: 16, color: scheme.outlineVariant.withValues(alpha: 0.15))`

### 3.3 `SettingsTile`
- **Icon Container**: 44x44dp squircle with `BorderRadius.circular(14)`, `color: resolvedIconColor.withValues(alpha: 0.12)`.
- **Selection State (`isSelected`)**:
  - Background: `scheme.secondaryContainer` (or `scheme.primaryContainer.withValues(alpha: 0.6)`).
  - Text color: `scheme.onSecondaryContainer` with `FontWeight.w700`.
  - Icon container: `color: scheme.primary`, icon color: `scheme.onPrimary`.
- **Trailing Indicator**: `Icons.chevron_right_rounded` with `color: scheme.onSurfaceVariant.withValues(alpha: 0.6)`.

### 3.4 `SettingsSwitchTile`
- Replaces raw `Switch` with `Switch.adaptive(value: value, onChanged: ...)`.
- 44x44dp squircle icon container with category tonal tint.

---

## 4. Master-Detail Coordinator (`profile_screen.dart` & `main_shell_screen.dart`)

### 4.1 `MainShellScreen` Tab Canvas
In `pulse_flutter/lib/screens/main_shell_screen.dart`, line 191:
- Replace `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: const ProfileScreen())` with `const ProfileScreen()`.
- This unconstrains the `ProfileScreen` so it can span the full width in desktop split mode.

### 4.2 `ProfileScreen` Master-Detail Coordinator
- On desktop / wide viewports ($\ge 760\text{dp}$):
  - **Left Master Pane** ($340\text{dp}$ fixed width):
    1. Header: Avatar (with upload photo trigger), Display Name, `@username`, Bio, "Редактировать профиль" action button.
    2. Master List of Sections (`SettingsTile` with `isSelected` active highlight):
       - **Аккаунт и безопасность**:
         * `SettingsSectionId.account` (Аккаунт, 2FA, Биометрия)
         * `SettingsSectionId.sessions` (Активные сессии)
       - **Интерфейс и персонализация**:
         * `SettingsSectionId.appearance` (Внешний вид и палитра)
         * `SettingsSectionId.languageRegion` (Язык и часовой пояс)
       - **Приватность и шифрование**:
         * `SettingsSectionId.privacy` (Приватность и статус в сети)
         * `SettingsSectionId.e2ee` (Сквозное E2EE шифрование)
       - **Хранилище и уведомления**:
         * `SettingsSectionId.preferences` (Уведомления, звуки и отклик)
         * `SettingsSectionId.storage` (Хранилище и кэш)
       - **О приложении**:
         * `SettingsSectionId.about` (О приложении, FAQ, команда, правовые документы)
    3. Logout Button at bottom with errorContainer styling.
  - **Vertical Divider**: 1px divider with `scheme.outlineVariant.withValues(alpha: 0.2)`.
  - **Right Detail Pane** (`Expanded`):
    - Renders the selected sub-screen with `isEmbedded: true` wrapped in `PageTransitionSwitcher` or `AnimatedSwitcher`.

- On mobile / compact viewports ($< 760\text{dp}$):
  - Renders single scrollable column with `SliverPersistentHeader` profile hero and stacked navigation (`context.push('/settings/...')`).

---

## 5. Sub-Screen Refactoring Specification

| Screen | Target File | Embedded Mode Support | Key UI Updates |
|---|---|---|---|
| **Account** | `lib/screens/settings_account_screen.dart` | `isEmbedded: bool` added, passed to `SettingsScaffold` | `surfaceContainerLow`, `Switch.adaptive` for 2FA/Biometric, deep session navigation link to `sessions` |
| **Appearance** | `lib/screens/settings_appearance_screen.dart` | `isEmbedded: bool` added, passed to `SettingsScaffold` | `surfaceContainerLow` for theme cards, responsive `_MeshWithOrbs` viewport, font scale segmented button |
| **Privacy** | `lib/screens/settings_privacy_screen.dart` | `isEmbedded: bool` added, passed to `SettingsScaffold` | `surfaceContainerLow` 20dp cards, `Switch.adaptive` for online status and battery modes |
| **Storage** | `lib/screens/settings_storage_screen.dart` | `isEmbedded: bool` added, passed to `SettingsScaffold` | `surfaceContainerLow` summary card, responsive category cards (`App Data`, `Cache`, `Drafts`) with 20dp radius |
| **Language & Region** | `lib/screens/settings_language_region_screen.dart` | `isEmbedded: bool` added, passed to `SettingsScaffold` | `surfaceContainerLow` sections, segmented language selector, responsive time zone bottom sheet/dialog |
| **Preferences** | `lib/screens/settings_preferences_screen.dart` | `isEmbedded: bool` added, passed to `SettingsScaffold` | `surfaceContainerLow` sections, `Switch.adaptive`, tonal volume slider, reset confirmation |
| **About** | `lib/screens/settings_about_screen.dart` | `isEmbedded: bool` added, suppresses top `AppBar` when embedded | Standardized `_DeveloperCard`, `_ReleaseCard`, `_LegalCard` with `surfaceContainerLow` and 20dp radius |
| **E2EE** | `lib/screens/e2ee_settings_screen.dart` | `isEmbedded: bool` added, passed to `SettingsScaffold` | `surfaceContainerLow`, squircle tonal icon containers for key rotation and erase secret chats |
| **Sessions** | `lib/screens/sessions_screen.dart` | `isEmbedded: bool` added, passed to `SettingsScaffold` | `surfaceContainerLow` session cards, 48dp squircle device icons, revoke tonal action buttons |

---

## 6. Implementation Steps

1. **Step 1: Create State Provider**
   - Create `pulse_flutter/lib/providers/settings_navigation_provider.dart` with `SettingsSectionId` enum and `desktopSelectedSettingsSectionProvider` (`NotifierProvider`).
2. **Step 2: Standardize `settings_ui.dart`**
   - Update `SettingsScaffold` with `isEmbedded: bool` parameter, suppress `AppBar` and adapt padding when `isEmbedded == true`.
   - Update `SettingsSection` to use `surfaceContainerLow` and 20dp radius.
   - Update `SettingsTile` to support `isSelected` styling and squircle containers.
   - Update `SettingsSwitchTile` to use `Switch.adaptive`.
3. **Step 3: Update `main_shell_screen.dart` & `profile_screen.dart`**
   - Unconstrain `ProfileScreen` in `MainShellScreen` for wide screens.
   - Implement Master-Detail layout in `ProfileScreen` with left master pane (340dp) and right detail pane rendering `_buildDetailPane(selectedSection)`.
4. **Step 4: Update All 9 Settings Screens**
   - Add `isEmbedded: bool` parameter to each sub-screen constructor and propagate to `SettingsScaffold`.
   - Ensure all cards, switches, and sliders use standardized M3 Expressive tokens.
5. **Step 5: Write Comprehensive Test Suite**
   - Create `test/widgets/settings_master_detail_test.dart` and `test/widgets/settings_screens_m3_test.dart` covering desktop/mobile viewports, section switching, embedded mode, and M3 Expressive token assertions.
6. **Step 6: Static Analysis & Validation**
   - Run `flutter analyze` and `flutter test` to ensure 0 errors and 0 warnings.
