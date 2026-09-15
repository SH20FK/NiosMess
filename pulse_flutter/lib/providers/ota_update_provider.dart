import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/in_app_notification_provider.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:universal_io/io.dart';

enum OtaStatus {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  installing,
  error,
}

class OtaUpdateState {
  const OtaUpdateState({
    this.status = OtaStatus.idle,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.downloadedApkPath,
    this.updateInfo,
    this.errorMessage,
  });

  final OtaStatus status;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final String? downloadedApkPath;
  final AppUpdateInfo? updateInfo;
  final String? errorMessage;

  OtaUpdateState copyWith({
    OtaStatus? status,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? downloadedApkPath,
    AppUpdateInfo? updateInfo,
    String? errorMessage,
  }) {
    return OtaUpdateState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedApkPath: downloadedApkPath ?? this.downloadedApkPath,
      updateInfo: updateInfo ?? this.updateInfo,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class OtaUpdateNotifier extends Notifier<OtaUpdateState> {
  static const int _notificationId = 9999;
  DateTime _lastNotificationUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastNotificationProgress = 0.0;
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastUiProgress = 0.0;
  http.Client? _downloadClient;

  @override
  OtaUpdateState build() {
    return const OtaUpdateState();
  }

  void setUpdateInfo(AppUpdateInfo info) {
    state = state.copyWith(
      updateInfo: info,
      status: state.status == OtaStatus.readyToInstall
          ? OtaStatus.readyToInstall
          : OtaStatus.available,
    );
  }

  Future<void> checkForUpdate() async {
    if (state.status == OtaStatus.checking ||
        state.status == OtaStatus.downloading) {
      return;
    }

    state = state.copyWith(status: OtaStatus.checking, errorMessage: null);

    try {
      final AppUpdateService service = ref.read(appUpdateServiceProvider);
      final AppUpdateInfo info = await service.checkForUpdate();

      if (info.hasUpdate) {
        // Check if APK was already downloaded and is ready
        final Directory tempDir = await getTemporaryDirectory();
        final String safeVer = info.latestVersion.replaceAll('+', '_');
        final File apkFile = File('${tempDir.path}/niosmess_$safeVer.apk');

        if (await apkFile.exists()) {
          final int length = await apkFile.length();
          if (info.apkSize != null && length == info.apkSize && length > 1000000) {
            state = state.copyWith(
              status: OtaStatus.readyToInstall,
              updateInfo: info,
              downloadedApkPath: apkFile.path,
              progress: 1.0,
            );
            return;
          }
        }

        state = state.copyWith(
          status: OtaStatus.available,
          updateInfo: info,
        );
      } else {
        state = state.copyWith(
          status: OtaStatus.idle,
          updateInfo: info,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: OtaStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> startDownload({AppUpdateInfo? info}) async {
    final AppUpdateInfo? targetInfo = info ?? state.updateInfo;
    if (targetInfo == null || targetInfo.downloadUrl.isEmpty) return;

    if (kIsWeb) {
      state = state.copyWith(
        status: OtaStatus.error,
        errorMessage: 'Установка APK не поддерживается в веб-версии.',
      );
      return;
    }

    // Check if already downloaded
    final Directory tempDir = await getTemporaryDirectory();
    final String safeVer = targetInfo.latestVersion.replaceAll('+', '_');
    final File apkFile = File('${tempDir.path}/niosmess_$safeVer.apk');

    if (await apkFile.exists()) {
      final int length = await apkFile.length();
      if (targetInfo.apkSize != null && length == targetInfo.apkSize && length > 1000000) {
        state = state.copyWith(
          status: OtaStatus.readyToInstall,
          downloadedApkPath: apkFile.path,
          progress: 1.0,
          receivedBytes: length,
          totalBytes: length,
        );
        _notifyDownloadComplete(targetInfo, apkFile.path);
        return;
      }
    }

    state = state.copyWith(
      status: OtaStatus.downloading,
      progress: 0.0,
      receivedBytes: 0,
      totalBytes: targetInfo.apkSize ?? 0,
      errorMessage: null,
      updateInfo: targetInfo,
    );

    _showProgressNotification(targetInfo, 0.0);

    try {
      _downloadClient = http.Client();
      Uri currentUri = Uri.parse(targetInfo.downloadUrl);
      http.StreamedResponse? streamedResponse;
      int redirectCount = 0;

      while (redirectCount < 5) {
        final http.Request request = http.Request('GET', currentUri);
        request.headers['User-Agent'] = 'NiosMess-App-Updater';
        request.followRedirects = true;
        request.maxRedirects = 5;

        final http.StreamedResponse resp = await _downloadClient!.send(request);
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
        throw HttpException('Ошибка сервера: HTTP ${streamedResponse?.statusCode}');
      }

      final int total = streamedResponse.contentLength ?? (targetInfo.apkSize ?? 0);
      int received = 0;

      if (await apkFile.exists()) {
        try {
          await apkFile.delete();
        } catch (_) {}
      }

      final IOSink sink = apkFile.openWrite();

      await for (final List<int> chunk in streamedResponse.stream) {
        if (state.status != OtaStatus.downloading) {
          await sink.close();
          try {
            await apkFile.delete();
          } catch (_) {}
          _cancelProgressNotification();
          return;
        }

        received += chunk.length;
        sink.add(chunk);

        final double currentProgress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

        final DateTime now = DateTime.now();
        if (now.difference(_lastUiUpdate).inMilliseconds >= 33 ||
            (currentProgress - _lastUiProgress).abs() >= 0.005) {
          _lastUiUpdate = now;
          _lastUiProgress = currentProgress;
          state = state.copyWith(
            progress: currentProgress,
            receivedBytes: received,
            totalBytes: total,
          );
        }

        if (now.difference(_lastNotificationUpdate).inMilliseconds > 650 &&
            (currentProgress - _lastNotificationProgress).abs() >= 0.03) {
          _lastNotificationUpdate = now;
          _lastNotificationProgress = currentProgress;
          _showProgressNotification(targetInfo, currentProgress);
        }
      }

      await sink.flush();
      await sink.close();

      state = state.copyWith(
        status: OtaStatus.readyToInstall,
        downloadedApkPath: apkFile.path,
        progress: 1.0,
        receivedBytes: total > 0 ? total : received,
        totalBytes: total > 0 ? total : received,
      );

      _notifyDownloadComplete(targetInfo, apkFile.path);
    } catch (e) {
      debugPrint('[OtaUpdateNotifier] Download error: $e');
      state = state.copyWith(
        status: OtaStatus.error,
        errorMessage: 'Ошибка при загрузке: $e',
      );
      _cancelProgressNotification();
    } finally {
      _downloadClient?.close();
      _downloadClient = null;
    }
  }

  void cancelDownload() {
    _downloadClient?.close();
    _downloadClient = null;
    state = state.copyWith(
      status: state.updateInfo != null ? OtaStatus.available : OtaStatus.idle,
      progress: 0.0,
    );
    _cancelProgressNotification();
  }

  Future<void> installApk({BuildContext? context}) async {
    final String? path = state.downloadedApkPath;
    if (path == null || path.isEmpty) {
      if (state.updateInfo != null) {
        startDownload();
      }
      return;
    }

    final File apkFile = File(path);
    if (!await apkFile.exists()) {
      state = state.copyWith(
        status: OtaStatus.available,
        errorMessage: 'Файл обновления не найден. Загрузка перезапущена.',
      );
      startDownload();
      return;
    }

    // Check REQUEST_INSTALL_PACKAGES permission on Android
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final PermissionStatus status =
            await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          final PermissionStatus reqStatus =
              await Permission.requestInstallPackages.request();
          if (!reqStatus.isGranted) {
            if (context != null && context.mounted) {
              await _showPermissionDialog(context);
            } else {
              await openAppSettings();
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('[OtaUpdateNotifier] Permission check warning: $e');
      }
    }

    state = state.copyWith(status: OtaStatus.installing);

    try {
      final OpenResult result = await OpenFile.open(
        path,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        state = state.copyWith(
          status: OtaStatus.readyToInstall,
          errorMessage: result.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: OtaStatus.readyToInstall,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _showPermissionDialog(BuildContext context) async {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        icon: Icon(
          Icons.security_rounded,
          size: 36,
          color: scheme.primary,
        ),
        title: Text(
          'Разрешение на установку',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Для обновления приложения необходимо включить пункт «Разрешить установку из этого источника» для NiosMess в настройках безопасности Android.',
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Отмена',
              style: Theme.of(ctx)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.outline),
            ),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }

  void _showProgressNotification(AppUpdateInfo targetInfo, double progress) {
    if (kIsWeb) return;
    try {
      final int percent = (progress * 100).toInt().clamp(0, 100);
      PushNotificationService.localNotifications.show(
        id: _notificationId,
        title: 'Загрузка обновления NiosMess',
        body: 'Версия v${targetInfo.latestVersion} • $percent%',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'niosmess_updates',
            'NiosMess Updates',
            importance: Importance.low,
            priority: Priority.low,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF0D6EFD),
            showProgress: true,
            maxProgress: 100,
            progress: percent,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
          ),
        ),
      );
    } catch (_) {}
  }

  void _notifyDownloadComplete(AppUpdateInfo targetInfo, String apkPath) {
    if (kIsWeb) return;

    // 1. Android Status Bar Notification
    try {
      PushNotificationService.localNotifications.show(
        id: _notificationId,
        title: 'Обновление NiosMess готово',
        body: 'Нажмите для завершения установки v${targetInfo.latestVersion}',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'niosmess_updates',
            'NiosMess Updates',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF0D6EFD),
            autoCancel: true,
            ongoing: false,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('notification'),
          ),
        ),
        payload: jsonEncode(<String, dynamic>{
          'action': 'install_update',
          'apk_path': apkPath,
        }),
      );
    } catch (_) {}

    // 2. In-App Banner Overlay
    ref.read(inAppNotificationProvider.notifier).show(
      InAppNotificationItem(
        id: 'ota_ready_${targetInfo.latestVersion}',
        title: 'Обновление загружено',
        body: 'Версия v${targetInfo.latestVersion} готова к установке. Нажмите для обновления.',
        icon: Icons.system_update_rounded,
        timestamp: DateTime.now(),
      ),
    );

    HapticService.confirm();
  }

  void _cancelProgressNotification() {
    if (kIsWeb) return;
    try {
      PushNotificationService.localNotifications.cancel(id: _notificationId);
    } catch (_) {}
  }
}

final otaUpdateProvider =
    NotifierProvider<OtaUpdateNotifier, OtaUpdateState>(
  OtaUpdateNotifier.new,
);
