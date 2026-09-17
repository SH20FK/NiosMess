/// Compile-time build and version metadata for NiosMess.
///
/// Single source of truth for application versioning alongside pubspec.yaml.
class BuildInfo {
  const BuildInfo._();

  /// Semantic version (e.g. "3.63.0").
  static const String version = '3.73.1';

  /// Build number (e.g. "147").
  static const String buildNumber = '161';

  /// Version with 'v' prefix (e.g. "v3.63.1").
  static const String versionWithPrefix = 'v3.73.1';

  /// Full version with build number (e.g. "v3.63.1+147").
  static const String fullVersion = 'v3.73.1+161';

  /// Git commit hash of this release.
  static const String commitHash = '422a971';

  /// Release channel (e.g. "stable", "beta", "alpha").
  static const String buildChannel = 'stable';

  /// Release date string (YYYY-MM-DD).
  static const String buildDate = '2026-09-17';
}
