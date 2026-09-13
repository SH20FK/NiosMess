import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

/// Information about an available application update on GitHub Releases.
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

  /// Currently installed version string (e.g. "3.36.1").
  final String currentVersion;

  /// Latest remote release version string (e.g. "3.37.0").
  final String latestVersion;

  /// Git tag name of the release (e.g. "v3.37.0").
  final String tagName;

  /// Direct browser download URL for the APK file.
  final String downloadUrl;

  /// Markdown release notes and changelog from GitHub.
  final String changelog;

  /// File size in bytes, if reported by GitHub.
  final int? apkSize;

  /// Date and time when the release was published.
  final DateTime? publishedAt;
}

/// Service for checking and downloading OTA updates via GitHub Releases.
class AppUpdateService {
  const AppUpdateService({
    this.repoOwner = 'sh20fk',
    this.repoName = 'niosmess',
  });

  final String repoOwner;
  final String repoName;

  /// GitHub Releases API URL for the latest release.
  String get _latestReleaseUrl =>
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Compares two Semantic Versioning strings (e.g. "3.37.0" vs "3.36.1").
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
    }

    return false;
  }

  static List<int> _parseSemVer(String ver) {
    final String clean = ver
        .trim()
        .replaceFirst(RegExp(r'^v'), '')
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

  /// Checks GitHub Releases for a newer version of the application.
  Future<AppUpdateInfo> checkForUpdate() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentVersion = packageInfo.version;

    final http.Response response = await http.get(
      Uri.parse(_latestReleaseUrl),
      headers: <String, String>{
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'NiosMess-App-Updater',
      },
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'GitHub API error: HTTP ${response.statusCode}',
        uri: Uri.parse(_latestReleaseUrl),
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON response from GitHub API');
    }

    final String tagName = decoded['tag_name'] as String? ?? '';
    final String cleanLatestVersion =
        tagName.replaceFirst(RegExp(r'^v'), '').trim();
    final String changelog = decoded['body'] as String? ?? '';
    final String? publishedAtStr = decoded['published_at'] as String?;
    final DateTime? publishedAt =
        publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

    final List<dynamic> assets =
        decoded['assets'] as List<dynamic>? ?? <dynamic>[];

    String downloadUrl = '';
    int? apkSize;

    for (final dynamic asset in assets) {
      if (asset is Map<String, dynamic>) {
        final String name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? '';
          apkSize = asset['size'] as int?;
          break;
        }
      }
    }

    final bool hasUpdate = isNewerVersion(cleanLatestVersion, currentVersion) &&
        downloadUrl.isNotEmpty;

    return AppUpdateInfo(
      hasUpdate: hasUpdate,
      currentVersion: currentVersion,
      latestVersion: cleanLatestVersion.isNotEmpty
          ? cleanLatestVersion
          : currentVersion,
      tagName: tagName,
      downloadUrl: downloadUrl,
      changelog: changelog,
      apkSize: apkSize,
      publishedAt: publishedAt,
    );
  }

  /// Downloads the APK file from [downloadUrl] into the device temporary folder,
  /// streaming download progress via [onProgress] (0.0 to 1.0).
  ///
  /// Upon successful download, triggers [OpenFile.open] to launch the system
  /// package installer.
  Future<OpenResult> downloadAndInstall({
    required String downloadUrl,
    required void Function(
      double progress,
      int receivedBytes,
      int totalBytes,
    ) onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('APK installation is not supported on web.');
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
      final http.Request request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'NiosMess-App-Updater';

      final http.StreamedResponse streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw HttpException(
          'Failed to download APK: HTTP ${streamedResponse.statusCode}',
          uri: Uri.parse(downloadUrl),
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

      // Launch the Android package installer
      final OpenResult openResult = await OpenFile.open(apkFile.path);
      return openResult;
    } finally {
      client.close();
    }
  }
}

/// Riverpod provider for [AppUpdateService].
final Provider<AppUpdateService> appUpdateServiceProvider =
    Provider<AppUpdateService>((Ref ref) => const AppUpdateService());
