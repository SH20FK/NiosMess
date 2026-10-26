# NiosMess

Flutter client for ordinary and device-bound secret chats, calls, NiosGram and media. Presence of a UI control is not proof of a platform capability; check the runtime gates and tests for the target platform.

## Environment

Use `flutter --version` and `dart --version` as the local source of truth. The audited Windows environment is Flutter 3.44.6 / Dart 3.12.2; CI pins Flutter 3.47.5 in `.github/workflows/build.yml`. Historical SDK numbers in other local notes can be stale. Dependencies resolve through pubspec.yaml/pubspec.lock and the local packages in ../packages.

## Checks

```sh
flutter pub get
flutter gen-l10n
dart test test/pure_dart
flutter test test/suite_test.dart --timeout 90s
flutter analyze --fatal-infos
```

Browser tests live in test/web and require a browser runner. Physical Android, real FCM delivery and real bidirectional call media require separate device verification; an active call timer is insufficient. APKs are built only in CI.

Application endpoints are defined in lib/core/network/api_constants.dart. Keep credentials, signing files, actual conversations and local server configuration out of Git. Backend deployments require the owner's separate approval.

## Data and compatibility

See [client data lifecycle](../docs/client-data-lifecycle.md), [ordinary E2EE](../docs/ordinary-e2ee.md), [notifications](../docs/notifications-v2.md), and the source/tests under lib/services/secret_chat/secret_chat_engine.dart and lib/providers/secret_chat_provider.dart. Server regressions for the approved 2026-10-26 fixes are in [backend_changes/full_audit_20261026](../backend_changes/full_audit_20261026/README.md).

The current detailed audit artifacts are kept locally under output/full-audit-2026-10-26/ at the repository root. They distinguish live checks, isolated tests, code-only findings and unavailable checks.
