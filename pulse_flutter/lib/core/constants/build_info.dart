/// Compile-time build and version metadata for NiosMess.
///
/// Single source of truth for application versioning alongside pubspec.yaml.
class BuildInfo {
  const BuildInfo._();

  /// Semantic version (e.g. "3.61.0").
  static const String version = '3.61.0';

  /// Build number (e.g. "144").
  static const String buildNumber = '144';

  /// Version with 'v' prefix (e.g. "v3.61.0").
  static const String versionWithPrefix = 'v3.61.0';

  /// Full version with build number (e.g. "v3.61.0+144").
  static const String fullVersion = 'v3.61.0+144';

  /// Git commit hash of this release.
  static const String commitHash = 'eca736a';

  /// Release channel (e.g. "stable", "beta", "alpha").
  static const String buildChannel = 'stable';

  /// Release date string (YYYY-MM-DD).
  static const String buildDate = '2026-09-15';
}
