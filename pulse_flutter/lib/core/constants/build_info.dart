/// Compile-time build and version metadata for NiosMess.
///
/// Kept equal to the version in pubspec.yaml by hand: a test in
/// `test/unit/settings_integrity_test.dart` fails when the two drift apart.
class BuildInfo {
  const BuildInfo._();

  /// Semantic version (e.g. "3.63.0").
  static const String version = '3.145.4';

  /// Build number (e.g. "147").
  static const String buildNumber = '4330';

  /// Version with 'v' prefix (e.g. "v3.63.1").
  static const String versionWithPrefix = 'v$version';

  /// Full version with build number (e.g. "v3.63.1+147").
  static const String fullVersion = '$versionWithPrefix+$buildNumber';

  /// Git commit hash of this release.
  static const String commitHash = String.fromEnvironment(
    'NIOSMESS_BUILD_COMMIT',
    defaultValue: 'unknown',
  );

  /// Release channel (e.g. "stable", "beta", "alpha").
  static const String buildChannel = 'stable';

  /// Release date string (YYYY-MM-DD).
  static const String buildDate = '2026-11-22';
}
