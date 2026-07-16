# NiosMess (Pulse) - UI/UX Design System & Code Guidelines

This document serves as the absolute source of truth for generating UI screens and components for the NiosMess (Pulse) Flutter application. When generating code, you MUST adhere strictly to these rules.

## 1. Core Architecture & Tech Stack
*   **Framework:** Flutter (latest stable).
*   **State Management:** Riverpod (`flutter_riverpod`). UI components should extend `ConsumerWidget` or `ConsumerStatefulWidget`.
*   **Routing:** `go_router`. Use `context.push()`, `context.go()`, or `context.pop()`.
*   **Localization:** Auto-generated `AppLocalizations`. Access via extension: `context.l10n.yourStringKey`. **NEVER hardcode text strings in the UI.**

## 2. Design Language: Strict Material Design 3 (MD3)
The app strictly follows Google's Material Design 3 guidelines. We do not use custom styling where an MD3 equivalent exists. 

### Colors (Dynamic & Themed)
**Rule: NEVER use hardcoded colors (e.g., `Color(0xFF...)` or `Colors.red`).**
All colors must be derived from `Theme.of(context).colorScheme`.
*   **Backgrounds:** `scheme.surface` (main background), `scheme.surfaceContainer`, `scheme.surfaceContainerHigh` (cards, dialogs), `scheme.surfaceContainerHighest` (search bars, heavy elements).
*   **Text/Icons:** `scheme.onSurface` (primary text), `scheme.onSurfaceVariant` (secondary text/icons).
*   **Primary Action:** `scheme.primary` (buttons, active states), `scheme.onPrimary` (text on primary buttons).
*   **Secondary/Tertiary:** `scheme.secondaryContainer`, `scheme.tertiary` (used for distinct accents, e.g., E2EE locks, special badges).
*   **Destructive:** `scheme.error`, `scheme.onError`.

### Typography
**Rule: NEVER use hardcoded font sizes or weights.**
All text styles must be derived from `Theme.of(context).textTheme`.
*   `displayLarge/Medium/Small` - Huge numbers/counters.
*   `headlineLarge/Medium/Small` - Screen titles, modal headers.
*   `titleLarge/Medium/Small` - List tile titles, app bar titles.
*   `bodyLarge/Medium/Small` - Regular message text, descriptions.
*   `labelLarge/Medium/Small` - Button text, small timestamps, badges.
*   *Modification:* You may use `.copyWith(color: ...)` to change text color using the ColorScheme.

### Shapes & Corners
MD3 uses heavily rounded corners. 
*   **Cards & Dialogs:** `BorderRadius.circular(24)` or `28`.
*   **Buttons:** Stadium borders (fully rounded) or `BorderRadius.circular(16)`.
*   **Message Bubbles:** `BorderRadius.circular(20)`, with one corner sharp depending on the sender.
*   **Images/Avatars:** Circular (`ClipOval` or `BoxShape.circle`) or squircle (`BorderRadius.circular(16)`).

### Elevation
**Rule: Avoid traditional drop shadows (`boxShadow`).**
MD3 achieves depth through surface color mapping (e.g., `surfaceContainer` is slightly darker/lighter than `surface`). Use `ElevationOverlay.applySurfaceTint` or just rely on MD3 surface containers.

## 3. Standard Components

### App Bars
*   Prefer `SliverAppBar.large` or `SliverAppBar.medium` for main screens (scrolled inside a `CustomScrollView`).
*   Use standard `AppBar` for sub-screens.
*   Keep `scrolledUnderElevation: 0` or rely on default MD3 tinting.

### Buttons
Use semantic M3 buttons:
*   `FilledButton` - Primary, high-emphasis action.
*   `FilledButton.tonal` - Secondary, medium-emphasis (uses `secondaryContainer`).
*   `OutlinedButton` - Medium/low emphasis.
*   `TextButton` - Low emphasis, dialog actions.
*   `SegmentedButton` - For mutually exclusive choices (e.g., themes, modes).
*   `IconButton.filledTonal` - Standalone icon actions.

### Lists & Layouts
*   **Padding:** Standard screen horizontal padding is `16.0`.
*   **Lists:** Use `ListView.builder` or `SliverList` (with `SliverChildBuilderDelegate`). **Always use `findChildIndexCallback` for dynamic lists.**
*   **Tiles:** Use standard `ListTile` when possible, or build custom rows using `Row`, `Expanded`, `Column`, and `Padding`.
*   **Refresh:** Wrap lists in `RefreshIndicator` if they fetch network data.

## 4. UI Patterns Specific to NiosMess

### Chat List (`ChatTile`)
*   Uses a custom `ChatTile` widget.
*   Swipe-to-delete uses `Dismissible` with a custom background (`scheme.error.withValues(alpha: 0.14)`).

### Message Bubbles
*   Handled by `MessageBubble` widget.
*   Uses `RepaintBoundary` for performance.
*   Animations use `flutter_animate` (e.g., `.animate().fade().slideY()`).

### Settings Screens
*   Settings screens follow a specific pattern: `SettingsScaffold` containing multiple `SettingsSection` widgets, which contain `SettingsTile` or `SettingsSwitchTile`.

## 5. Code Generation Checklist for Stitch
1.  **Imports:** Ensure `package:flutter_riverpod/flutter_riverpod.dart` and localizations are imported.
2.  **Stateless:** Prefer `ConsumerWidget`. Use `ConsumerStatefulWidget` only if local animation controllers or complex focus nodes are needed.
3.  **Null Safety:** Strictly adhere to Dart null safety.
4.  **Extract Widgets:** Do not create massive `build` methods. Extract logical blocks (like a Header, a specific Card, a BottomSheet) into private classes (e.g., `_ProfileHeader`).
5.  **No `const` on localized strings:** `context.l10n.xyz` is dynamic, so the widget wrapping it cannot be `const`.
6.  **Responsiveness:** Use `SafeArea`. Avoid hardcoded heights/widths. Use `Flexible` or `Expanded` inside Rows/Columns.

## Example: Perfect MD3 Component
```dart
class MyCustomCard extends ConsumerWidget {
  const MyCustomCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.myTitleKey,
            style: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.mySubtitleKey,
            style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () {},
              child: Text(context.l10n.actionSave),
            ),
          ),
        ],
      ),
    );
  }
}
```