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
- **Fonts**: PlusJakartaSans (primary), Inter (secondary) — variable fonts

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
flutter test                   # Unit/widget tests
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
- **Unit/Widget**: `flutter test` (flutter_test SDK)
- **Integration**: `flutter test integration_test/` (integration_test SDK)
- Location: `test/` (unit/widget), `integration_test/` (integration)

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

## Files to Avoid Editing
- Generated files: `lib/l10n/app_localizations.dart`, `*.g.dart`, `*.freezed.dart`
- `pubspec.lock` (updated via `flutter pub get`)
- Build outputs: `build/`, `*.apk`, `build/web/`
- Platform-specific generated files: `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`