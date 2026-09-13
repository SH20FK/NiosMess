import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

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

  /// Date and time when the release was published.
  final DateTime? publishedAt;
}

/// Service for checking and downloading OTA updates for NiosMess.
class AppUpdateService {
  const AppUpdateService({
    this.repoOwner = 'SH20FK',
    this.repoName = 'NiosMess',
  });

  final String repoOwner;
  final String repoName;

  /// Remote raw pubspec URL to reliably fetch latest version without API rate limits.
  String get _rawPubspecUrl =>
      'https://raw.githubusercontent.com/$repoOwner/$repoName/main/pulse_flutter/pubspec.yaml';

  /// Remote raw CHANGELOG.md URL to fetch release notes directly.
  String get _rawChangelogUrl =>
      'https://raw.githubusercontent.com/$repoOwner/$repoName/main/CHANGELOG.md';

  /// Release API URL for latest release notes and assets.
  String get _latestReleaseUrl =>
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Canonical fallback direct download URL for latest APK.
  String get _canonicalApkUrl =>
      'https://github.com/$repoOwner/$repoName/releases/download/latest/niosmess.apk';

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

  /// Parses markdown changelog and extracts notes for [targetVersion] or top section.
  static String parseChangelog(String markdown, [String? targetVersion]) {
    if (markdown.trim().isEmpty) return '';
    final List<String> lines = markdown.split('\n');
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
          break;
        }
        if (cleanTarget.isEmpty || trimmed.contains(cleanTarget)) {
          capturing = true;
          continue;
        }
      } else if (capturing) {
        buffer.writeln(line);
      }
    }

    if (buffer.isEmpty && cleanTarget.isNotEmpty) {
      return parseChangelog(markdown, null);
    }

    return buffer.toString().trim();
  }

  /// Checks for a newer version of the application using multi-source verification.
  Future<AppUpdateInfo> checkForUpdate() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentBaseVersion = packageInfo.version;
    final String currentBuildNumber = packageInfo.buildNumber;
    final String fullCurrentVersion = currentBuildNumber.isNotEmpty
        ? '$currentBaseVersion+$currentBuildNumber'
        : currentBaseVersion;

    String latestVersion = '';
    String tagName = 'latest';
    String downloadUrl = _canonicalApkUrl;
    String changelog = '';
    int? apkSize;
    DateTime? publishedAt;

    // 1. Primary: Read version directly from raw pubspec.yaml on main branch
    // (Fast, 100% reliable, zero GitHub API rate limits)
    try {
      final http.Response pubspecResponse = await http.get(
        Uri.parse(_rawPubspecUrl),
        headers: <String, String>{
          'User-Agent': 'NiosMess-App-Updater',
        },
      ).timeout(const Duration(seconds: 8));

      if (pubspecResponse.statusCode == 200) {
        final String content = pubspecResponse.body;
        for (final String line in content.split('\n')) {
          final String trimmed = line.trim();
          if (trimmed.startsWith('version:')) {
            latestVersion = trimmed.replaceFirst('version:', '').trim();
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error fetching raw pubspec: $e');
    }

    // 2. Fetch clean human-friendly CHANGELOG.md without API rate limits
    try {
      final http.Response changelogResponse = await http.get(
        Uri.parse(_rawChangelogUrl),
        headers: <String, String>{
          'User-Agent': 'NiosMess-App-Updater',
        },
      ).timeout(const Duration(seconds: 8));

      if (changelogResponse.statusCode == 200) {
        final String parsed = parseChangelog(
          changelogResponse.body,
          latestVersion.isNotEmpty ? latestVersion : null,
        );
        if (parsed.isNotEmpty) {
          changelog = parsed;
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error fetching raw CHANGELOG.md: $e');
    }

    // 3. Secondary: Query release metadata for assets, size and fallback changelog
    try {
      final http.Response response = await http.get(
        Uri.parse(_latestReleaseUrl),
        headers: <String, String>{
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'NiosMess-App-Updater',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          tagName = decoded['tag_name'] as String? ?? 'latest';
          final String releaseName = decoded['name'] as String? ?? '';
          final String releaseBody = decoded['body'] as String? ?? '';
          final String? publishedAtStr = decoded['published_at'] as String?;

          if (publishedAtStr != null) {
            publishedAt = DateTime.tryParse(publishedAtStr);
          }

          if (changelog.isEmpty &&
              releaseBody.isNotEmpty &&
              !releaseBody.contains('Full Changelog')) {
            changelog = releaseBody;
          }

          // If latestVersion was not retrieved from pubspec, extract from release
          if (latestVersion.isEmpty) {
            final String cleanTag =
                tagName.replaceFirst(RegExp(r'^v', caseSensitive: false), '').trim();
            if (cleanTag.isNotEmpty && cleanTag.toLowerCase() != 'latest') {
              latestVersion = cleanTag;
            } else if (releaseName.isNotEmpty) {
              final RegExp verRegex = RegExp(r'v?(\d+\.\d+\.\d+(?:\+\d+)?)');
              final RegExpMatch? match = verRegex.firstMatch(releaseName);
              if (match != null) {
                latestVersion = match.group(1)!;
              }
            }
          }

          final List<dynamic> assets =
              decoded['assets'] as List<dynamic>? ?? <dynamic>[];

          for (final dynamic asset in assets) {
            if (asset is Map<String, dynamic>) {
              final String name = (asset['name'] as String? ?? '').toLowerCase();
              if (name.endsWith('.apk')) {
                final String? url = asset['browser_download_url'] as String?;
                if (url != null && url.isNotEmpty) {
                  downloadUrl = url;
                }
                apkSize = asset['size'] as int?;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error fetching release metadata: $e');
    }

    if (latestVersion.isEmpty) {
      latestVersion = fullCurrentVersion;
    }

    final bool hasUpdate = isNewerVersion(latestVersion, fullCurrentVersion) &&
        downloadUrl.isNotEmpty;

    return AppUpdateInfo(
      hasUpdate: hasUpdate,
      currentVersion: fullCurrentVersion,
      latestVersion: latestVersion,
      tagName: tagName,
      downloadUrl: downloadUrl,
      changelog: changelog,
      apkSize: apkSize,
      publishedAt: publishedAt,
    );
  }

  /// Downloads the APK file from [downloadUrl] into the device temporary folder,
  /// following redirects explicitly and streaming download progress via [onProgress] (0.0 to 1.0).
  ///
  /// Upon successful download, triggers [OpenFile.open] with APK MIME type to launch
  /// the system package installer.
  Future<OpenResult> downloadAndInstall({
    required String downloadUrl,
    required void Function(
      double progress,
      int receivedBytes,
      int totalBytes,
    ) onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Установка APK не поддерживается в веб-версии.');
    }

    final Directory tempDir = await getTemporaryDirectory();
    final File apkFile = File('${tempDir.path}/niosmess_update.apk');

    if (await apkFile.exists()) {
      try {
        await apkFile.delete();
      } catch (_) {}
    }

    final http.Client client = http.Client();
    try {
      Uri currentUri = Uri.parse(downloadUrl);
      http.StreamedResponse? streamedResponse;
      int redirectCount = 0;

      while (redirectCount < 5) {
        final http.Request request = http.Request('GET', currentUri);
        request.headers['User-Agent'] = 'NiosMess-App-Updater';
        request.followRedirects = true;
        request.maxRedirects = 5;

        final http.StreamedResponse resp = await client.send(request);
        if (resp.statusCode == 301 ||
            resp.statusCode == 302 ||
            resp.statusCode == 307 ||
            resp.statusCode == 308) {
          final String? loc = resp.headers['location'];
          if (loc != null && loc.isNotEmpty) {
            currentUri = Uri.parse(loc);
            redirectCount++;
            continue;
          }
        }
        streamedResponse = resp;
        break;
      }

      if (streamedResponse == null || streamedResponse.statusCode != 200) {
        throw HttpException(
          'Не удалось скачать файл обновления: HTTP ${streamedResponse?.statusCode}',
          uri: currentUri,
        );
      }

      final int totalBytes = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;

      final IOSink sink = apkFile.openWrite();

      await for (final List<int> chunk in streamedResponse.stream) {
        receivedBytes += chunk.length;
        sink.add(chunk);

        if (totalBytes > 0) {
          final double progress =
              (receivedBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(progress, receivedBytes, totalBytes);
        } else {
          onProgress(-1.0, receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();

      // Launch the Android package installer with explicit APK MIME type
      final OpenResult openResult = await OpenFile.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );
      return openResult;
    } finally {
      client.close();
    }
  }
}

/// Riverpod provider for [AppUpdateService].
final Provider<AppUpdateService> appUpdateServiceProvider =
    Provider<AppUpdateService>((Ref ref) => const AppUpdateService());
