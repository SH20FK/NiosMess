import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/providers/in_app_notification_provider.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/services/update/update_integrity.dart';

class _QuietNotifications extends InAppNotificationNotifier {
  @override
  InAppNotificationItem? build() => null;
  @override
  void show(InAppNotificationItem item) {}
}

class _DelayedUpdateService extends AppUpdateService {
  final response = Completer<AppUpdateInfo>();
  @override
  Future<AppUpdateInfo> checkForUpdate() => response.future;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  late ProviderContainer container;
  late OtaUpdateNotifier notifier;
  late Uint8List fixture;
  late String fixtureHash;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ota-artifact-');
    fixture = Uint8List.fromList(List.generate(1000107, (i) => i % 251));
    fixtureHash = sha256.convert(fixture).toString();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      paths,
      (_) async => directory.path,
    );
    container = ProviderContainer(
      overrides: [
        inAppNotificationProvider.overrideWith(_QuietNotifications.new),
      ],
    );
    notifier = container.read(otaUpdateProvider.notifier);
  });
  tearDown(() async {
    container.dispose();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
    debugDefaultTargetPlatformOverride = null;
    await directory.delete(recursive: true);
  });

  AppUpdateInfo info({
    String version = '3.100.0+229',
    String? url,
    int? size,
    String? digest,
    String notes = 'fixture',
  }) => AppUpdateInfo(
    hasUpdate: true,
    currentVersion: '3.99.2+227',
    latestVersion: version,
    tagName: 'latest',
    downloadUrl: url ?? 'https://fixture.invalid/$version.apk',
    changelog: notes,
    apkSize: size ?? fixture.length,
    sha256: digest ?? fixtureHash,
  );

  Future<File> cached(AppUpdateInfo artifact, {String ext = 'apk'}) => File(
    '${directory.path}/niosmess_${artifact.latestVersion.replaceAll('+', '_')}.$ext',
  ).writeAsBytes(fixture, flush: true);

  test(
    'cached explicit release owns state and a new release clears the ready package',
    () async {
      final old = info(version: '3.99.3+228', digest: 'b' * 64);
      final target = info();
      notifier.setUpdateInfo(old);
      final file = await cached(target);
      await notifier.startDownload(info: target);
      var state = container.read(otaUpdateProvider);
      expect(state.status, OtaStatus.readyToInstall);
      expect(state.updateInfo, same(target));
      expect(state.downloadedFilePath, file.path);
      expect(
        await UpdateIntegrity.verify(
          file,
          size: state.updateInfo!.apkSize,
          sha: state.updateInfo!.sha256,
        ),
        isTrue,
      );
      notifier.setUpdateInfo(info(notes: 'updated notes, same artifact'));
      expect(
        container.read(otaUpdateProvider).status,
        OtaStatus.readyToInstall,
      );
      expect(container.read(otaUpdateProvider).downloadedFilePath, file.path);
      notifier.setUpdateInfo(info(version: '3.100.1+230'));
      state = container.read(otaUpdateProvider);
      expect(state.status, OtaStatus.available);
      expect(state.downloadedFilePath, isNull);
      expect(state.progress, 0);
      expect(state.receivedBytes, 0);
      expect(state.errorMessage, isNull);
    },
  );

  test(
    'artifact URL, size and digest each invalidate an existing ready package',
    () async {
      final original = info();
      await cached(original);
      for (final changed in [
        info(url: 'https://fixture.invalid/arm64.apk'),
        info(size: fixture.length + 1),
        info(digest: 'b' * 64),
      ]) {
        await notifier.startDownload(info: original);
        expect(
          container.read(otaUpdateProvider).status,
          OtaStatus.readyToInstall,
        );
        notifier.setUpdateInfo(changed);
        expect(container.read(otaUpdateProvider).downloadedFilePath, isNull);
        expect(container.read(otaUpdateProvider).status, OtaStatus.available);
        expect(container.read(otaUpdateProvider).updateInfo, same(changed));
      }
    },
  );

  test(
    'Windows cached installer keeps its matching artifact integrity metadata',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final target = info(url: 'https://fixture.invalid/setup.exe');
      final file = await cached(target, ext: 'exe');
      notifier.setUpdateInfo(info(version: '3.99.3+228'));
      await notifier.startDownload(info: target);
      final state = container.read(otaUpdateProvider);
      expect(state.status, OtaStatus.readyToInstall);
      expect(state.downloadedFilePath, file.path);
      expect(state.updateInfo, same(target));
      expect(
        await UpdateIntegrity.verify(
          file,
          size: state.updateInfo!.fileSize,
          sha: state.updateInfo!.sha256,
        ),
        isTrue,
      );
    },
  );

  test(
    'integrity failure cannot leave a stale package attached to another release',
    () async {
      final target = info();
      final file = await cached(target);
      await notifier.startDownload(info: target);
      await file.writeAsBytes(Uint8List(fixture.length), flush: true);
      await notifier
          .installUpdate(); // Fails integrity before any native installer.
      expect(
        container.read(otaUpdateProvider).errorMessage,
        UpdateIntegrity.errorCode,
      );
      notifier.setUpdateInfo(info(version: '3.100.1+230'));
      final state = container.read(otaUpdateProvider);
      expect(state.errorMessage, isNull);
      expect(state.downloadedFilePath, isNull);
      expect(state.status, OtaStatus.available);
    },
  );

  test(
    'concurrent starts and metadata changes cannot replace an active HTTP download',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        entered.complete();
        await release.future;
        return http.Response.bytes(fixture, 200);
      });
      addTearDown(client.close);
      final target = info();
      final active = http.runWithClient(
        () => notifier.startDownload(info: target),
        () => client,
      );
      await entered.future;
      notifier.setUpdateInfo(info(version: '3.100.1+230'));
      await notifier.startDownload(info: info(version: '3.100.1+230'));
      expect(requests, 1);
      expect(container.read(otaUpdateProvider).updateInfo, same(target));
      release.complete();
      await active;
      final state = container.read(otaUpdateProvider);
      expect(state.status, OtaStatus.readyToInstall);
      expect(state.updateInfo, same(target));
    },
  );

  test('a cancelled cache lookup cannot later publish ready state', () async {
    final target = info();
    await cached(target);
    final entered = Completer<void>();
    final release = Completer<void>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (_) async {
      entered.complete();
      await release.future;
      return directory.path;
    });
    final active = notifier.startDownload(info: target);
    await entered.future;
    notifier.cancelDownload();
    release.complete();
    await active;
    final state = container.read(otaUpdateProvider);
    expect(state.status, OtaStatus.available);
    expect(state.downloadedFilePath, isNull);
    expect(state.updateInfo, same(target));
  });

  test(
    'a slow metadata check cannot overwrite a download that started afterwards',
    () async {
      final service = _DelayedUpdateService();
      container.dispose();
      container = ProviderContainer(
        overrides: [
          inAppNotificationProvider.overrideWith(_QuietNotifications.new),
          appUpdateServiceProvider.overrideWithValue(service),
        ],
      );
      notifier = container.read(otaUpdateProvider.notifier);
      final checking = notifier.checkForUpdate();
      final target = info(version: '3.100.1+230');
      await cached(target);
      await notifier.startDownload(info: target);
      service.response.complete(info());
      await checking;
      expect(
        container.read(otaUpdateProvider).status,
        OtaStatus.readyToInstall,
      );
      expect(container.read(otaUpdateProvider).updateInfo, same(target));
    },
  );
}
