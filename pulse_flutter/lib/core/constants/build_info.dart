/// Compile-time build and version metadata for NiosMess.
///
/// Single source of truth for application versioning alongside pubspec.yaml.
class BuildInfo {
  const BuildInfo._();

  /// Semantic version (e.g. "3.60.6").
  static const String version = '3.60.6';

  /// Build number (e.g. "142").
  static const String buildNumber = '142';

  /// Version with 'v' prefix (e.g. "v3.60.6").
  static const String versionWithPrefix = 'v3.60.6';

  /// Full version with build number (e.g. "v3.60.6+142").
  static const String fullVersion = 'v3.60.6+142';

  /// Git commit hash of this release.
  static const String commitHash = '128d117';

  /// Release channel (e.g. "stable", "beta", "alpha").
  static const String buildChannel = 'stable';

  /// Release date string (YYYY-MM-DD).
  static const String buildDate = '2026-09-14';
}
