# NiosMess (Pulse) Design System & UI Guidelines

This document describes the architectural patterns, UI components, and Material Design 3 (M3) design system used in the NiosMess (Pulse) Flutter messenger. Use this guide to generate new screens and components that perfectly match the existing codebase.

## 1. Core Principles
- **Strict Material Design 3 (M3):** The app heavily relies on M3. Never use hardcoded colors. Always use `Theme.of(context).colorScheme` and `Theme.of(context).textTheme`.
- **Dynamic Color:** The app supports system dynamic colors (Monet on Android) and user-defined seed colors. Colors must be semantic (e.g., `scheme.primary`, `scheme.surfaceContainerHigh`).
- **Riverpod for State:** Use `ConsumerWidget` or `ConsumerStatefulWidget`. Watch providers using `ref.watch()`.
- **GoRouter for Navigation:** Use `context.push()`, `context.go()`, or `context.pop()`. Never use `Navigator.push`.
- **Localization:** Use `context.l10n` for all strings. No hardcoded text strings in UI.
- **Null Safety & Types:** Use strict typing. Always specify `<Type>` parameters for generics (e.g., `List<Widget>`, `Future<void>`).

## 2. Color Scheme Mapping (M3)
Always extract the color scheme at the top of the `build` method:
```dart
final ColorScheme scheme = Theme.of(context).colorScheme;
final TextTheme textTheme = Theme.of(context).textTheme;
```

- **Backgrounds:** `scheme.surface` (default app background).
- **Cards / Containers:** 
  - `scheme.surfaceContainerLow` / `scheme.surfaceContainer` (base cards)
  - `scheme.surfaceContainerHigh` / `scheme.surfaceContainerHighest` (elevated/highlighted cards)
- **Primary Actions (FABs, Main Buttons):** `scheme.primary` (bg) and `scheme.onPrimary` (text/icon).
- **Secondary Actions:** `scheme.secondaryContainer` (bg) and `scheme.onSecondaryContainer` (text/icon).
- **Text:**
  - Main text: `scheme.onSurface`
  - Subtitles/Hints: `scheme.onSurfaceVariant`
- **Dividers/Borders:** `scheme.outlineVariant`.
- **Errors/Destructive:** `scheme.error` and `scheme.onError`.

## 3. Typography
Use M3 TextTheme. Do not hardcode font sizes or weights.
- `textTheme.headlineMedium` / `titleLarge`: Screen titles, large headers.
- `textTheme.titleMedium`: List item titles, button text, dialog titles.
- `textTheme.bodyLarge`: Main body text, message bubbles.
- `textTheme.bodyMedium`: Secondary body text.
- `textTheme.bodySmall`: Subtitles, timestamps, captions (`color: scheme.onSurfaceVariant`).
- `textTheme.labelLarge`: Prominent labels, tabs.

## 4. Core UI Components & Patterns

### 4.1. Screens & Scaffolds
For standard screens (especially settings or detail screens), do not use a raw `Scaffold`. Use custom wrappers if applicable, or build custom scrollable views.
- **`PulseScaffoldBody`**: A common wrapper for custom sliver-based app bars and backgrounds.
- **`SettingsScaffold`**: Used for all screens in the settings section. Provides a consistent collapsing header and sliver list layout.
  ```dart
  SettingsScaffold(
    title: context.l10n.screenTitle,
    children: [ ... ],
  )
  ```

### 4.2. Lists & Settings UI
For building lists (like profile or settings), use the existing `settings_ui.dart` components. They provide perfectly rounded M3 cards with grouped items.
- **`SettingsSection`**: Groups a list of tiles into an M3 card with an optional title.
- **`SettingsTile`**: A standard clickable row with an icon, title, subtitle, and trailing widget.
- **`SettingsSwitchTile`**: A toggle row.
```dart
SettingsSection(
  title: context.l10n.sectionTitle,
  children: <Widget>[
    SettingsTile(
      icon: Icons.person_rounded,
      title: context.l10n.profile,
      subtitle: context.l10n.profileDesc,
      onTap: () => context.push('/profile'),
    ),
    SettingsSwitchTile(
      icon: Icons.notifications_rounded,
      title: context.l10n.notifications,
      value: isEnabled,
      onChanged: (bool val) { ... },
    ),
  ],
)
```

### 4.3. Dialogs
Use `showAppDialog` and `AppDialog` for alert dialogs. They provide smooth M3 styling and consistent button layouts.
```dart
showAppDialog<void>(
  context: context,
  builder: (BuildContext ctx) => AppDialog(
    title: context.l10n.dialogTitle,
    content: Text(context.l10n.dialogMessage),
    actions: <AppDialogAction>[
      AppDialogAction(
        label: context.l10n.commonCancel,
        onPressed: () => Navigator.of(ctx).pop(),
      ),
      AppDialogAction(
        label: context.l10n.commonConfirm,
        isPrimary: true,
        onPressed: () { ... },
      ),
    ],
  ),
);
```

### 4.4. Bottom Sheets
Use `showModalBottomSheet` with `showDragHandle: true` and `backgroundColor: Colors.transparent` (or rely on theme defaults). Build the content using `SafeArea` and standard padding.
- Containers inside bottom sheets often use `scheme.surfaceContainerHigh` with `borderRadius: BorderRadius.circular(28)`.

### 4.5. Inputs and TextFields
- Use `TextField` with `InputDecoration`.
- Borders are typically `OutlineInputBorder` with `borderRadius: BorderRadius.circular(16)`.
- Use `filled: true` and `fillColor: scheme.surfaceContainerHighest`.
- Use `PrefixIcon` and `SuffixIcon` for actions.

### 4.6. Loading States & Indicators
- Use `AppLoadingIndicator` (from `pulse_loading_indicator.dart`) instead of `CircularProgressIndicator` for a branded, smooth loading animation.
- For lists, use `PulseSkeleton` / `ChatListSkeleton` for shimmer loading effects instead of raw spinners.

### 4.7. Avatars
Use `PulseAvatar`. It automatically handles caching, initials fallback, and color generation.
```dart
PulseAvatar(
  radius: 24, // Note: radius, not size
  name: user.displayName,
  avatarUrl: user.avatarUrl,
  fallbackColor: scheme.primary,
  textColor: scheme.onPrimary,
)
```

## 5. Async Data Handling (Riverpod)
When watching `AsyncValue` providers, use `.when()` and return slivers or widgets based on context.
```dart
final AsyncValue<Data> dataAsync = ref.watch(dataProvider);

return dataAsync.when(
  data: (Data data) => BuildDataWidget(data),
  loading: () => const Center(child: AppLoadingIndicator()),
  error: (error, stack) => CenteredNote(error.toString(), icon: Icons.error),
);
```

## 6. Spacing & Layout Constraints
- **Standard Screen Padding:** `AppConstants.screenHorizontalPadding` (usually 16.0).
- **Border Radii:** 
  - Cards/Dialogs: `28.0` or `24.0`
  - Buttons/Small elements: `12.0` or `16.0`
  - Fully rounded (Pills): `999.0` (or `StadiumBorder`)
- **Spacing:** Use `SizedBox(height: 8/16/24)` for vertical spacing and `SizedBox(width: 8/12/16)` for horizontal.

## 7. Folder Structure (`lib/`)
- `core/`: Constants, l10n, network clients, utilities.
- `models/`: Immutable data classes (often ending in `_model.dart`).
- `providers/`: Riverpod state notifiers and providers.
- `repositories/`: API communication layer (called by providers).
- `router/`: GoRouter configuration (`app_router.dart`).
- `screens/`: Full-page UI widgets.
- `widgets/`: Reusable UI components (buttons, tiles, dialogs, inputs).