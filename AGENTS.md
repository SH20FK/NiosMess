# AGENTS.md

## Project Overview
**NiosMess (pulse_flutter)** — A Flutter-based secure messaging application with NiosGram (social feed), calls, E2EE, and Material 3 Expressive design.

## Tech Stack
- **Framework**: Flutter 3.x (Dart 3.10.7)
- **State Management**: flutter_riverpod (v3.x, NotifierProvider pattern)
- **Routing**: go_router (v17.x)
- **UI**: Material 3 Expressive, dynamic_color, flutter_animate, mesh_gradient
- **Networking**: http, web_socket_channel, universal_io (cross-platform)
- **Storage**: shared_preferences, hive/hive_flutter, flutter_secure_storage
- **Media**: just_audio, audio_session, video_player, camera, audio_waveforms
- **Auth**: firebase_core, firebase_messaging, flutter_local_notifications, app_links
- **Security**: cryptography, local_auth, flutter_secure_storage
- **Localization**: intl (RU/EN), app_localizations.dart generated via `flutter gen-l10n`

## Architecture
- **lib/main.dart** — Entry point, providers, theme, router
- **lib/router/app_router.dart** — go_router with public/auth/main shells
- **lib/core/** — Theme, providers, utils, network, storage
- **lib/providers/** — Riverpod providers (Notifier/AsyncNotifier pattern)
- **lib/screens/** — UI screens organized by feature
- **lib/widgets/** — Reusable widgets (chat, settings, avatar, etc.)
- **lib/services/** — Business logic (E2EE, calls, media, notifications)
- **lib/models/** — Data models (Freezed/JSON serializable)
- **lib/repositories/** — Data layer (API, auth, storage)
- **lib/l10n/** — Localization (intl, generated .arb)

## Key Conventions
- **Riverpod 3.x**: Use `NotifierProvider` / `AsyncNotifierProvider` (no `StateNotifierProvider`)
- **No `StateProvider`** — Only `NotifierProvider` for mutable state
- **No `dart:io`** — Use `package:universal_io/io.dart` for cross-platform
- **Material 3 Expressive** — Dynamic Color via `dynamic_color`, `ThemeData.from(...)` with tonal palettes
- **L10n**: All user-facing strings via `context.l10n.key` (no hardcoded strings)
- **Assets**: Declared in pubspec.yaml under `flutter.assets`
- **Fonts**: BricolageGrotesque (headlines/display), Onest (UI/labels/titles), GolosText (body/reading), PlusJakartaSans/Inter (fallbacks) — variable fonts

## CI/CD (GitHub Actions)
- **.github/workflows/build.yml** — Triggers on push/PR to `main`
- Jobs: `build-android` (release), `build-android-debug`, `build-web`
- Uses `subosito/flutter-action@v2` (stable channel) + JDK 17 (Temurin)
- Artifacts: Android APK (release/debug), Web build
- Secrets: Google-services.json injected at build time

## Local Development
```bash
cd pulse_flutter
flutter pub get
flutter run                    # Debug
flutter run --release          # Release
flutter build apk --release    # Build APK
flutter build web --release    # Build Web
flutter gen-l10n               # Generate l10n after adding .arb keys
dart test                      # Run tests via Dart (preferred & faster)
flutter test                   # Widget/integration tests (when flutter_test/dart:ui required)
flutter test integration_test/ # Integration tests
flutter analyze                # Static analysis
```

## Common Commands
- `flutter pub get` — Install deps
- `flutter pub upgrade` — Update deps
- `flutter pub outdated` — Check outdated
- `flutter pub run build_runner build` — Codegen (if needed)
- `flutter clean && flutter pub get` — Clean rebuild

## Testing
- **Always run tests via Dart (`dart test`)**: Significantly faster than `flutter test`. Preferred for all test executions.
- **Unit/Logic**: `dart test` (fastest execution)
- **Widget/UI**: `flutter test` (when `flutter_test`/`dart:ui` framework bindings are explicitly required)
- **Integration**: `flutter test integration_test/` (integration_test SDK)
- Location: `test/` (unit/widget), `integration_test/` (integration)

## Material 3 Expressive Component Protocol (MANDATORY FOR ALL TASKS)
Always prioritize true Material 3 Expressive (M3E) components over legacy Material 2 (MD2) widgets. Before using any standard Flutter Material widget, verify against [m3.material.io/components](https://m3.material.io/components) to confirm whether it is a modern M3 Expressive component or a legacy MD2 remnant.

### STRICTLY PROHIBITED (without explicit justification):
1. **Direct `CircularProgressIndicator` / `LinearProgressIndicator`**:
   - MUST use `AppLoadingIndicator` (`package:pulse_flutter/widgets/pulse_loading_indicator.dart`).
   - It wraps `loading_indicator_m3e` — true M3 Expressive morphing/wave animated indicator, never a bare circle or bar.
2. **`ElevatedButton` with elevation > 0**:
   - MD3 buttons are flat by default (`elevation: 0`).
   - Elevation is only permitted for `FloatingActionButton` (and kept minimal).
3. **`Card` / `Container` with harsh `BoxShadow` drop shadows**:
   - Visual depth and layering MUST be achieved through tonal color surfaces (`colorScheme.surfaceContainer`, `surfaceContainerLow`, `surfaceContainerHigh`, `surfaceContainerHighest`), NOT drop shadows.
4. **`PopupMenuButton` for user actions**:
   - Prefer `MenuAnchor` (modern Flutter M3 API) or a custom inline expressive action panel / sheet (similar to the chat action bar).
5. **Plain rectangular `Container` for accent icons/badges/logos**:
   - Use `flutter_m3shapes` (already installed) or expressively rounded squircles instead of plain squares or circles.
6. **Unchecked `Switch` / `Checkbox`**:
   - Ensure the widget uses M3 styling with `useMaterial3: true` explicitly guaranteed in the theme. Always prefer M3 Expressive switches/checkboxes.
7. **Always Material 3 Expressive**:
   - Whenever an M3 Expressive component, spring motion curve (`M3SpringCurves`), tonal elevation, or expressive shape exists, ALWAYS use it across all tasks and screens without exception.

## Code Style / Lints
- `flutter_lints: ^6.0.0` (via `analysis_options.yaml`)
- Run `flutter analyze` before commit
- No `Colors.white` / `Colors.black` — use `colorScheme.onSurface`, `colorScheme.surface`, etc.
- Use `withValues(alpha:)` not `withOpacity()`
- Use `WidgetStatePropertyAll<Color>(color)` (explicit generic)
- No `StateProvider` — use `NotifierProvider`
- No `dart:io` imports — use `package:universal_io/io.dart`

## Common Patterns
- **Riverpod**: `ref.read(provider.notifier).method()` for mutations
- **Routing**: `context.push('/path')` / `context.go('/path')`
- **Error handling**: `AppToast.showError(context, message)` / `AppToast.showSuccess()`
- **Bottom sheets**: `AppBottomSheets.show(context, builder: ...)`
- **Dialogs**: `showAppConfirmDialog()`, `showAppDialog()`
- **Haptics**: `HapticService.tap()` / `HapticService.reaction()` / `HapticService.confirm()`
- **Sounds**: `ref.read(appSoundProvider).playUiTick()` / `playReaction()`

## Motion & Performance Protocol (MANDATORY ANTI-REGRESSION RULES)
Strict rules to preserve 60-120 FPS fluidity across all platforms and prevent UI jank regressions:
1. **Zero Per-Frame Blur Rasterization**: Never invoke `MaskFilter.blur(...)` or `BackdropFilter` inside repeating render loops or scrollable list tiles. Static decorative blurs must be pre-rendered into `ui.Image` via `PictureRecorder` + `toImageSync` and rendered via `RawImage` or lightweight transforms.
2. **Eliminate Save-Layers in Lists**: Reusable tiles and wrappers (`TouchContainer`, list items) MUST default to `clipBehavior: Clip.none`. Avoid `Clip.antiAlias` unless anti-aliased content actually overflows the boundary.
3. **Strict O(1) List Index Resolution**: Never use `messages.indexWhere(...)` inside `findChildIndexCallback` or layout passes. Always maintain and use an O(1) `idToIndex` cache map.
4. **Input Area Repaint Boundary**: The text input field and voice recording indicator must be wrapped in `RepaintBoundary` and decoupled from message lists so cursor blinks and typing do not trigger rebuilds or repaints of the message stream.
5. **Normalized M3 Springs**: Always use `M3SpringCurves` from `core/motion/m3_spring_constants.dart`. All spring curves MUST satisfy $f(0.0) = 0.0$ and $f(1.0) = 1.0$ mathematically without boundary clamps. Never use overshoot curves (`bouncy`, `easeOutBack`) on `Opacity` or `FadeTransition`.
6. **No Side-Effects in `build()`**: Never create, start, or stop an `AnimationController` inside a `build()` method. All controller lifecycles must reside in `initState`, `didUpdateWidget`, or `dispose`.
7. **No Unbounded `shrinkWrap: true`**: Never nest a `shrinkWrap: true` scroll view inside another scrollable viewport without an explicit bounded height constraint.
8. **Parallelized Cold Start**: Independent storage, disk caches, and background services must be initialized in parallel via `Future.wait` or deferred to `WidgetsBinding.instance.addPostFrameCallback`.

## Common Files to Modify
- **Theme**: `lib/core/theme/app_theme.dart`
- **Router**: `lib/router/app_router.dart`
- **Providers**: `lib/providers/*.dart`
- **Screens**: `lib/screens/**/*.dart`
- **Widgets**: `lib/widgets/**/*.dart`
- **Models**: `lib/models/**/*.dart`
- **Localization**: `lib/l10n/app_*.arb`

## Important Notes
- `server_core/` is excluded from git (separate backend)
- Local Dart SDK is 3.10.7; CI uses latest stable Flutter
- `pure_dart_quic` requires Dart SDK ≥3.11.5 — only works in CI (local SDK is 3.10.7)
- `mock_quic/` is local mock for `pure_dart_quic` (not committed)
- APK is built on CI only — not locally

## Git Workflow
- All code written locally, pushed to GitHub
- CI builds APK & runs tests on push/PR to `main`
- Never commit secrets (google-services.json, certs, keys)

## Automated Semantic Versioning (SemVer) & Changelog Protocol
At the conclusion of EVERY task or feature implementation, inspect all completed changes (`git status`, `git diff`) and automatically bump the version in `pulse_flutter/pubspec.yaml` (`version: X.Y.Z+build`):
- **MAJOR (X.0.0+N)**: Global architectural changes, fundamental protocol breaks, major multi-module rewrites, or breaking database/API changes.
- **MINOR (X.Y.0+N)**: New user-facing features, new screens, significant visual redesigns of core modules, or substantial new functionality added without breaking existing APIs.
- **PATCH / Micro-minor (X.Y.Z+N)**: Small bug fixes, micro styling tweaks, padding/radius polishes, typo fixes, linter/test corrections, and documentation updates.
Always increment the build number (`+N`) and report the new version in the final task summary.

### Changelog & Sub-version Prompt Rule
- **Sub-version / Minor updates (e.g. x.Y.x)**: Whenever bumping a sub-version or releasing a feature update, explicitly notify the user and ask them for a short, simple summary in their own words.
- Never write corporate AI buzzwords or "нейрослоп" into release notes.
- The user's provided description is placed directly at the top of `CHANGELOG.md` under `## [X.Y.Z]`.
- **Single-Version Display**: In the application (`AppUpdateDialog`), strictly display ONLY the changelog section for the latest version being updated to, never old historical changelog blocks.

## Files to Avoid Editing
- Generated files: `lib/l10n/app_localizations.dart`, `*.g.dart`, `*.freezed.dart`
- `pubspec.lock` (updated via `flutter pub get`)
- Build outputs: `build/`, `*.apk`, `build/web/`
- Platform-specific generated files: `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`