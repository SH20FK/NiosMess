import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'android_abi.dart';
import 'update_asset_selector.dart';

/// Information about an available application update.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.tagName,
    required this.downloadUrl,
    required this.changelog,
    this.apkSize,
    this.publishedAt,
    this.sha256,
  });

  /// Whether a newer version is available.
  final bool hasUpdate;

  /// Currently installed version string (e.g. "3.47.0+98").
  final String currentVersion;

  /// Latest remote release version string (e.g. "3.49.1+102").
  final String latestVersion;

  /// Git tag name of the release (e.g. "v3.49.1" or "latest").
  final String tagName;

  /// Direct browser download URL for the APK file.
  final String downloadUrl;

  /// Release notes and changelog.
  final String changelog;

  /// File size in bytes, if reported by update service.
  final int? apkSize;

  /// Generic file size in bytes (alias to apkSize for cross-platform support).
  int? get fileSize => apkSize;

  /// Date and time when the release was published.
  final DateTime? publishedAt;
  final String? sha256;
}

/// A parsed release entry from CHANGELOG.md.
class ChangelogRelease {
  const ChangelogRelease({
    required this.version,
    required this.rawHeader,
    required this.changes,
    this.date,
  });

  /// The parsed version string (e.g. "3.60.0").
  final String version;

  /// The original markdown header line.
  final String rawHeader;

  /// List of bullet points or change descriptions.
  final List<String> changes;

  /// Optional date string if present in the header.
  final String? date;
}

/// Service for checking and downloading OTA updates for NiosMess.
class AppUpdateService {
  const AppUpdateService({
    this.repoOwner = 'SH20FK',
    this.repoName = 'NiosMess',
    this.httpClient,
    this.androidAbi,
  });

  final String repoOwner;
  final String repoName;
  final http.Client? httpClient;
  final String? androidAbi;

  String get _latestReleaseUrl =>
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Compares two Semantic Versioning strings (e.g. "3.49.1+102" vs "3.47.0+98").
  /// Returns `true` if [latest] is strictly greater than [current].
  static bool isNewerVersion(String latest, String current) {
    final List<int> latestParts = _parseSemVer(latest);
    final List<int> currentParts = _parseSemVer(current);

    for (int i = 0; i < 3; i++) {
      final int l = i < latestParts.length ? latestParts[i] : 0;
      final int c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }

    // If major.minor.patch are equal, check build numbers if available
    final int latestBuild = _parseBuildNumber(latest);
    final int currentBuild = _parseBuildNumber(current);
    if (latestBuild > 0 && currentBuild > 0) {
      return latestBuild > currentBuild;
    } else if (latestBuild > 0 && currentBuild == 0) {
      return true;
    }

    return false;
  }

  static List<int> _parseSemVer(String ver) {
    final String clean = ver
        .trim()
        .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
        .split('+')
        .first
        .split('-')
        .first;
    final List<String> segments = clean.split('.');
    return segments.map((String s) => int.tryParse(s) ?? 0).toList();
  }

  static int _parseBuildNumber(String ver) {
    if (!ver.contains('+')) return 0;
    final String buildStr = ver.split('+').last;
    return int.tryParse(buildStr) ?? 0;
  }

  /// Parses markdown changelog and extracts strictly ONLY the notes for [targetVersion]
  /// or the latest topmost section (ignoring all prior history).
  static String parseChangelog(String markdown, [String? targetVersion]) {
    final String trimmedInput = markdown.trim();
    if (trimmedInput.isEmpty) return '';

    // If input has no markdown headers, return as-is (e.g. plain bullet list)
    if (!trimmedInput.contains('## ')) {
      return trimmedInput;
    }

    final List<String> lines = trimmedInput.split('\n');
    final StringBuffer buffer = StringBuffer();
    bool capturing = false;

    final String cleanTarget = targetVersion != null
        ? targetVersion
              .split('+')
              .first
              .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
              .trim()
        : '';

    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.startsWith('## ')) {
        if (capturing) {
          // Strictly stop at the start of any older version section
          break;
        }
        final headerVersion = RegExp(
          r'^##\s*\[?v?(\d+\.\d+\.\d+)',
          caseSensitive: false,
        ).firstMatch(trimmed)?.group(1);
        if (cleanTarget.isEmpty || headerVersion == cleanTarget) {
          capturing = true;
          continue;
        }
      } else if (capturing) {
        buffer.writeln(line);
      }
    }

    return buffer.toString().trim();
  }

  /// Parses the entire markdown changelog into structured release items.
  static List<ChangelogRelease> parseAllReleases(String markdown) {
    final String trimmedInput = markdown.trim();
    if (trimmedInput.isEmpty) return const <ChangelogRelease>[];

    final List<String> lines = trimmedInput.split('\n');
    final List<ChangelogRelease> releases = <ChangelogRelease>[];

    String currentVersion = '';
    String currentHeader = '';
    String? currentDate;
    final List<String> currentChanges = <String>[];

    void saveCurrent() {
      if (currentVersion.isNotEmpty && currentChanges.isNotEmpty) {
        releases.add(
          ChangelogRelease(
            version: currentVersion,
            rawHeader: currentHeader,
            changes: List<String>.unmodifiable(currentChanges),
            date: currentDate,
          ),
        );
      }
      currentChanges.clear();
    }

    final RegExp headerRegex = RegExp(
      r'^##\s*\\?\[?([0-9]+\.[0-9]+\.[0-9]+[^\]\n]*)\]?(.*)$',
    );

    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.startsWith('## ')) {
        saveCurrent();
        final Match? match = headerRegex.firstMatch(trimmed);
        if (match != null) {
          currentVersion = match.group(1)?.trim() ?? '';
          currentHeader = trimmed;
          final String trailing = match.group(2)?.trim() ?? '';
          if (trailing.startsWith('-') || trailing.startsWith('—')) {
            currentDate = trailing.replaceAll(RegExp(r'^[-—\s]+'), '').trim();
          } else {
            currentDate = null;
          }
        } else {
          currentVersion = trimmed.replaceAll(RegExp(r'[^0-9.]'), '').trim();
          currentHeader = trimmed;
          currentDate = null;
        }
      } else if (trimmed.isNotEmpty && currentVersion.isNotEmpty) {
        String item = trimmed;
        if (item.startsWith('• ') ||
            item.startsWith('- ') ||
            item.startsWith('* ')) {
          item = item.substring(2).trim();
        }
        if (item.isNotEmpty) {
          currentChanges.add(item);
        }
      }
    }
    saveCurrent();

    return releases;
  }

  /// Checks for a newer version of the application using multi-source verification.
  Future<AppUpdateInfo> checkForUpdate() async {
    final package = await PackageInfo.fromPlatform();
    final current =
        '${package.version}${package.buildNumber.isEmpty ? '' : '+${package.buildNumber}'}';
    final client = httpClient ?? http.Client();
    Future<Map<String, dynamic>?> readJson(String url) async {
      try {
        final response = await client
            .get(
              Uri.parse(url),
              headers: {
                'User-Agent': 'NiosMess-App-Updater',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) return null;
        final body = jsonDecode(response.body);
        return body is Map<String, dynamic> ? body : null;
      } catch (_) {
        return null;
      }
    }

    try {
      final fallbackManifestUrl =
          'https://github.com/$repoOwner/$repoName/releases/latest/download/version.json';
      final responses = await Future.wait([
        readJson(_latestReleaseUrl),
        readJson(fallbackManifestUrl),
      ]);
      final release = responses[0];
      final releaseAssets = release?['assets'] as List<dynamic>? ?? [];
      final manifestAssetUrl =
          releaseAssets
                  .whereType<Map<String, dynamic>>()
                  .where((asset) => asset['name'] == 'version.json')
                  .firstOrNull?['browser_download_url']
              as String?;
      final releaseTag = release?['tag_name'] as String?;
      final manifestUrl =
          manifestAssetUrl ??
          (releaseTag == null
              ? fallbackManifestUrl
              : 'https://github.com/$repoOwner/$repoName/releases/download/${Uri.encodeComponent(releaseTag)}/version.json');
      final metadata = manifestUrl == fallbackManifestUrl
          ? responses[1]
          : await readJson(manifestUrl);
      final versionPattern = RegExp(r'v?(\d+\.\d+\.\d+(?:\+\d+)?)');
      final publishedVersion = versionPattern
          .firstMatch('${release?['name'] ?? ''} ${release?['tag_name'] ?? ''}')
          ?.group(1);
      final metadataVersion =
          metadata?['version'] is String &&
              RegExp(
                r'^\d+\.\d+\.\d+(?:\+\d+)?$',
              ).hasMatch(metadata!['version'] as String)
          ? metadata['version'] as String
          : null;
      final matchingMetadata =
          metadata != null &&
          metadataVersion != null &&
          (publishedVersion == null || metadataVersion == publishedVersion);
      final latest = publishedVersion ?? metadataVersion ?? current;
      final windows =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      final abi = androidAbi ?? currentAndroidAbi();
      final selected = selectUpdateAsset(
        releaseAssets,
        windows: windows,
        androidAbi: abi,
      );
      final androidAssets = matchingMetadata
          ? metadata['android_assets']
          : null;
      final manifestAsset = windows
          ? (matchingMetadata ? metadata['windows_asset'] : null)
          : androidAssets is Map
          ? androidAssets.values
                    .whereType<Map>()
                    .where(
                      (asset) => sameUpdateAssetUrl(
                        asset['url'],
                        selected?['browser_download_url'],
                      ),
                    )
                    .firstOrNull ??
                (androidAssets[abi] ?? androidAssets['universal'])
          : null;
      String url = selected?['browser_download_url'] as String? ?? '';
      int? size = selected?['size'] as int?;
      String? digest = updateSha256(selected?['digest']);
      // A mutable `latest` release can expose its new name before all uploads
      // finish. Never combine that name with assets from an older manifest.
      var consistent = matchingMetadata;
      if (matchingMetadata) {
        if (url.isEmpty) {
          url =
              (manifestAsset is Map
                      ? manifestAsset['url']
                      : windows
                      ? metadata['windows_download_url']
                      : metadata['download_url'])
                  as String? ??
              '';
          if (manifestAsset is Map) {
            size = manifestAsset['size'] as int?;
            digest = updateSha256(manifestAsset['sha256']);
          }
        } else if (manifestAsset is Map) {
          final manifestDigest = updateSha256(manifestAsset['sha256']);
          final manifestSize = manifestAsset['size'] as int?;
          consistent =
              sameUpdateAssetUrl(manifestAsset['url'], url) &&
              (size == null || manifestSize == null || size == manifestSize) &&
              (digest == null ||
                  manifestDigest == null ||
                  digest == manifestDigest);
          digest ??= manifestDigest;
          size ??= manifestSize;
        }
        // The new manifest format guarantees authenticated artifact hashes.
        // Legacy manifests remain readable until their next published release.
        final hasManifestAssets = windows
            ? metadata.containsKey('windows_asset')
            : androidAssets is Map;
        if (hasManifestAssets &&
            (manifestAsset is! Map ||
                updateSha256(manifestAsset['sha256']) == null ||
                (manifestAsset['size'] as int? ?? 0) <= 0 ||
                digest == null)) {
          consistent = false;
        }
      }
      final notes = matchingMetadata ? metadata['changelog'] as String? : null;
      return AppUpdateInfo(
        hasUpdate:
            consistent && isNewerVersion(latest, current) && url.isNotEmpty,
        currentVersion: current,
        latestVersion: latest,
        tagName:
            releaseTag ??
            (matchingMetadata ? metadata['tag_name'] as String? : null) ??
            'latest',
        downloadUrl: url,
        changelog:
            notes ??
            parseChangelog(
              release?['body'] as String? ?? '',
              latest.split('+').first,
            ),
        apkSize: size,
        sha256: digest,
        publishedAt: DateTime.tryParse(
          ((matchingMetadata ? metadata['published_at'] : null) ??
                  release?['published_at'] ??
                  '')
              .toString(),
        ),
      );
    } finally {
      if (httpClient == null) client.close();
    }
  }
}

/// Riverpod provider for [AppUpdateService].
final Provider<AppUpdateService> appUpdateServiceProvider =
    Provider<AppUpdateService>((Ref ref) => const AppUpdateService());
