/// Compile-time build and version metadata for NiosMess.
///
/// Single source of truth for application versioning alongside pubspec.yaml.
class BuildInfo {
  const BuildInfo._();

  /// Semantic version (e.g. "3.63.0").
  static const String version = '3.88.2';

  /// Build number (e.g. "147").
  static const String buildNumber = '188';

  /// Version with 'v' prefix (e.g. "v3.63.1").
  static const String versionWithPrefix = 'v3.88.2';

  /// Full version with build number (e.g. "v3.63.1+147").
  static const String fullVersion = 'v3.88.2+188';

  /// Git commit hash of this release.
  static const String commitHash = '758176a';

  /// Release channel (e.g. "stable", "beta", "alpha").
  static const String buildChannel = 'stable';

  /// Release date string (YYYY-MM-DD).
  static const String buildDate = '2026-09-20';
}
