import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/services/update/update_asset_selector.dart';
import 'package:pulse_flutter/services/update/update_integrity.dart';
import 'package:universal_io/io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tag URL escaping is equivalent but another asset is not', () {
    expect(
      sameUpdateAssetUrl(
        'https://github.com/r/releases/download/v1.0.0+2/app.apk',
        'https://github.com/r/releases/download/v1.0.0%2B2/app.apk',
      ),
      isTrue,
    );
    expect(
      sameUpdateAssetUrl(
        'https://github.com/r/a.apk',
        'https://github.com/r/b.apk',
      ),
      isFalse,
    );
    expect(
      sameUpdateAssetUrl(
        'https://github.com/r/a.apk',
        'http://github.com/r/a.apk',
      ),
      isFalse,
    );
  });

  test(
    'ABI selection never picks another architecture and keeps universal fallback',
    () {
      final assets = [
        {'name': 'niosmess-x86_64.apk'},
        {'name': 'niosmess.apk'},
        {'name': 'niosmess-arm64-v8a.apk'},
      ];
      expect(
        selectUpdateAsset(
          assets,
          windows: false,
          androidAbi: 'arm64-v8a',
        )?['name'],
        'niosmess-arm64-v8a.apk',
      );
      expect(
        selectUpdateAsset(
          assets,
          windows: false,
          androidAbi: 'armeabi-v7a',
        )?['name'],
        'niosmess.apk',
      );
      expect(
        selectUpdateAsset(
          [assets.first],
          windows: false,
          androidAbi: 'arm64-v8a',
        ),
        isNull,
      );
    },
  );

  test(
    'same-length corrupted archive is rejected by streaming SHA256',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'niosmess_update_fixture',
      );
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/fixture.apk');
      final original = utf8.encode('authenticated APK fixture');
      await file.writeAsBytes(original);
      final hash = sha256.convert(original).toString();
      expect(
        await UpdateIntegrity.verify(file, size: original.length, sha: hash),
        isTrue,
      );
      await file.writeAsBytes(List<int>.filled(original.length, 0));
      expect(
        await UpdateIntegrity.verify(file, size: original.length, sha: hash),
        isFalse,
      );
      expect(
        await UpdateIntegrity.verify(file, size: original.length + 1),
        isFalse,
      );
    },
  );

  test(
    'update version comes from published assets rather than an unbuilt branch',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'fixture',
        packageName: 'fixture',
        version: '3.99.2',
        buildNumber: '227',
        buildSignature: 'fixture',
      );
      final client = MockClient((request) async {
        expect(request.url.host, isNot('raw.githubusercontent.com'));
        if (request.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode({
              'name': 'NiosMess v3.100.0+229',
              'tag_name': 'latest',
              'body': 'Published notes',
              'assets': [
                {
                  'name': 'niosmess-x86_64.apk',
                  'browser_download_url': 'https://github.com/fixture/x86.apk',
                  'size': 10,
                },
                {
                  'name': 'niosmess-arm64-v8a.apk',
                  'browser_download_url': 'https://github.com/fixture/arm.apk',
                  'size': 20,
                  'digest': 'sha256:${'a' * 64}',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'version': '3.100.0+229',
            'changelog': 'Published notes',
            'android_assets': {
              'arm64-v8a': {
                'url': 'https://github.com/fixture/arm.apk',
                'size': 20,
                'sha256': 'a' * 64,
              },
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      final update = await AppUpdateService(
        httpClient: client,
        androidAbi: 'arm64-v8a',
      ).checkForUpdate();
      expect(update.hasUpdate, isTrue);
      expect(update.latestVersion, '3.100.0+229');
      expect(update.downloadUrl, endsWith('/arm.apk'));
      expect(update.sha256, 'a' * 64);
      expect(update.changelog, 'Published notes');
    },
  );

  Future<AppUpdateInfo> checkSnapshot({
    String version = '3.100.0+229',
    String hash = 'a',
    int size = 20,
    bool missing = false,
    String changelog = "Published notes",
  }) async {
    PackageInfo.setMockInitialValues(
      appName: 'fixture',
      packageName: 'fixture',
      version: '3.99.2',
      buildNumber: '227',
      buildSignature: 'fixture',
    );
    final client = MockClient((request) async {
      if (request.url.host == 'api.github.com') {
        return http.Response(
          jsonEncode({
            'name': 'NiosMess v3.100.0+229',
            'tag_name': 'latest',
            'assets': [
              {
                'name': 'niosmess-arm64-v8a.apk',
                'browser_download_url': 'https://github.com/fixture/arm.apk',
                'size': 20,
                'digest': 'sha256:${'a' * 64}',
              },
            ],
          }),
          200,
        );
      }
      if (missing) return http.Response('unavailable', 503);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'version': version,
            'changelog': changelog,
            'android_assets': {
              'arm64-v8a': {
                'url': 'https://github.com/fixture/arm.apk',
                'size': size,
                'sha256': hash * 64,
              },
            },
          }),
        ),
        200,
        headers: {'content-type': 'application/octet-stream'},
      );
    });
    addTearDown(client.close);
    return AppUpdateService(
      httpClient: client,
      androidAbi: 'arm64-v8a',
    ).checkForUpdate();
  }

  test('Russian notes decode as UTF-8 with binary download headers', () async {
    const notes = '• Исправлена активация NiosPlus';
    expect((await checkSnapshot(changelog: notes)).changelog, notes);
  });

  test(
    'mixed release name and old manifest do not advertise an old APK as new',
    () async {
      expect((await checkSnapshot(version: '3.99.2+227')).hasUpdate, isFalse);
      expect((await checkSnapshot(missing: true)).hasUpdate, isFalse);
    },
  );

  test(
    'conflicting published size or digest defers update until publication agrees',
    () async {
      expect((await checkSnapshot(hash: 'b')).hasUpdate, isFalse);
      expect((await checkSnapshot(size: 19)).hasUpdate, isFalse);
      expect((await checkSnapshot()).hasUpdate, isTrue);
    },
  );

  test(
    'a tagged release reads its own manifest and escaped artifact URLs',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'fixture',
        packageName: 'fixture',
        version: '3.99.2',
        buildNumber: '227',
        buildSignature: 'fixture',
      );
      final requested = <Uri>[];
      const assetUrl =
          'https://github.com/fixture/releases/download/v3.100.0+229/niosmess-arm64-v8a.apk';
      const manifestUrl =
          'https://github.com/fixture/releases/download/v3.100.0%2B229/version.json';
      final client = MockClient((request) async {
        requested.add(request.url);
        if (request.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode({
              'name': 'NiosMess v3.100.0+229',
              'tag_name': 'v3.100.0+229',
              'assets': [
                {'name': 'version.json', 'browser_download_url': manifestUrl},
                {
                  'name': 'niosmess-arm64-v8a.apk',
                  'browser_download_url': assetUrl,
                  'size': 20,
                  'digest': 'sha256:${'a' * 64}',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.toString() == manifestUrl) {
          return http.Response(
            jsonEncode({
              'version': '3.100.0+229',
              'android_assets': {
                'arm64-v8a': {
                  'url': assetUrl.replaceFirst('+', '%2B'),
                  'size': 20,
                  'sha256': 'a' * 64,
                },
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'version': '3.99.2+227'}), 200);
      });
      addTearDown(client.close);
      final update = await AppUpdateService(
        httpClient: client,
        androidAbi: 'arm64-v8a',
      ).checkForUpdate();
      expect(update.hasUpdate, isTrue);
      expect(update.tagName, 'v3.100.0+229');
      expect(update.downloadUrl, assetUrl);
      expect(requested.map((url) => url.toString()), contains(manifestUrl));
    },
  );

  test('unified build upgrades every previously published ABI code', () async {
    for (final installedCode in [229, 1229, 2229, 4229]) {
      for (final includeSplit in [false, true]) {
        PackageInfo.setMockInitialValues(
          appName: 'fixture',
          packageName: 'fixture',
          version: '3.100.0',
          buildNumber: '$installedCode',
          buildSignature: 'fixture',
        );
        const baseUrl = 'https://github.com/fixture/releases/download/latest/';
        final assets = <String, Map<String, Object>>{
          'universal': {
            'url': '${baseUrl}niosmess.apk',
            'size': 20,
            'sha256': 'a' * 64,
          },
          if (includeSplit)
            'arm64-v8a': {
              'url': '${baseUrl}niosmess-arm64-v8a.apk',
              'size': 10,
              'sha256': 'b' * 64,
            },
        };
        final client = MockClient((request) async {
          if (request.url.host == 'api.github.com') {
            return http.Response(
              jsonEncode({
                'name': 'NiosMess v3.100.0+4230',
                'tag_name': 'latest',
                'assets': [
                  for (final entry in assets.entries)
                    {
                      'name': entry.key == 'universal'
                          ? 'niosmess.apk'
                          : 'niosmess-${entry.key}.apk',
                      'browser_download_url': entry.value['url'],
                      'size': entry.value['size'],
                      'digest': 'sha256:${entry.value['sha256']}',
                    },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({'version': '3.100.0+4230', 'android_assets': assets}),
            200,
          );
        });
        addTearDown(client.close);
        final result = await AppUpdateService(
          httpClient: client,
          androidAbi: 'arm64-v8a',
        ).checkForUpdate();
        expect(
          result.hasUpdate,
          isTrue,
          reason: 'installed code $installedCode',
        );
        expect(result.currentVersion, '3.100.0+$installedCode');
        expect(result.latestVersion, '3.100.0+4230');
        expect(
          result.downloadUrl,
          includeSplit
              ? assets['arm64-v8a']!['url']
              : assets['universal']!['url'],
        );
      }
    }
  });
}
