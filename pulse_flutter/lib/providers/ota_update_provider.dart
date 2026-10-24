import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
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
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/in_app_notification_provider.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/services/update/update_integrity.dart';
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
  String? get downloadedFilePath => downloadedApkPath;
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
  bool _downloadActive = false;
  int _downloadEpoch = 0;

  @override
  OtaUpdateState build() {
    ref.onDispose(() {
      _downloadEpoch++;
      _downloadClient?.close();
    });
    return const OtaUpdateState();
  }

  void setUpdateInfo(AppUpdateInfo info) {
    if (_downloadActive || state.status == OtaStatus.installing) return;
    _downloadEpoch++;
    final ready =
        state.status == OtaStatus.readyToInstall &&
        _sameArtifact(state.updateInfo, info);
    state = OtaUpdateState(
      updateInfo: info,
      status: ready ? OtaStatus.readyToInstall : OtaStatus.available,
      downloadedApkPath: ready ? state.downloadedApkPath : null,
      progress: ready ? state.progress : 0,
      receivedBytes: ready ? state.receivedBytes : 0,
      totalBytes: ready ? state.totalBytes : 0,
    );
  }

  static bool _sameArtifact(AppUpdateInfo? previous, AppUpdateInfo next) =>
      previous != null &&
      previous.latestVersion == next.latestVersion &&
      previous.downloadUrl == next.downloadUrl &&
      previous.apkSize == next.apkSize &&
      previous.sha256 == next.sha256;

  bool _currentDownload(int epoch) =>
      ref.mounted && _downloadEpoch == epoch && _downloadActive;

  Future<File> _resolveTargetFile(String version) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String safeVer = version.replaceAll('+', '_');
    final String ext =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
        ? 'exe'
        : 'apk';
    return File('${tempDir.path}/niosmess_$safeVer.$ext');
  }

  Future<void> checkForUpdate() async {
    if (state.status == OtaStatus.checking ||
        state.status == OtaStatus.installing ||
        _downloadActive) {
      return;
    }
    final epoch = ++_downloadEpoch;

    state = state.copyWith(status: OtaStatus.checking, errorMessage: null);

    try {
      final AppUpdateService service = ref.read(appUpdateServiceProvider);
      final AppUpdateInfo info = await service.checkForUpdate();
      if (_downloadActive || !ref.mounted || epoch != _downloadEpoch) return;

      if (info.hasUpdate) {
        // Check if update package was already downloaded and is ready
        final File updateFile = await _resolveTargetFile(info.latestVersion);
        if (_downloadActive || !ref.mounted || epoch != _downloadEpoch) return;

        if (await updateFile.exists()) {
          final int length = await updateFile.length();
          if (info.apkSize != null &&
              length > 1000000 &&
              await UpdateIntegrity.verify(
                updateFile,
                size: info.apkSize,
                sha: info.sha256,
              ) &&
              !_downloadActive &&
              ref.mounted &&
              epoch == _downloadEpoch) {
            state = OtaUpdateState(
              status: OtaStatus.readyToInstall,
              updateInfo: info,
              downloadedApkPath: updateFile.path,
              progress: 1.0,
            );
            return;
          }
        }

        if (_downloadActive || !ref.mounted || epoch != _downloadEpoch) return;
        state = OtaUpdateState(status: OtaStatus.available, updateInfo: info);
      } else {
        state = OtaUpdateState(status: OtaStatus.idle, updateInfo: info);
      }
    } catch (e) {
      if (_downloadActive || !ref.mounted || epoch != _downloadEpoch) return;
      state = state.copyWith(
        status: OtaStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> startDownload({AppUpdateInfo? info}) async {
    if (_downloadActive || state.status == OtaStatus.installing) return;
    final AppUpdateInfo? targetInfo = info ?? state.updateInfo;
    if (targetInfo == null || targetInfo.downloadUrl.isEmpty) return;
    _downloadActive = true;
    final epoch = ++_downloadEpoch;
    state = OtaUpdateState(
      status: OtaStatus.downloading,
      totalBytes: targetInfo.apkSize ?? 0,
      updateInfo: targetInfo,
    );
    try {
      await _startDownload(targetInfo, epoch);
    } catch (error) {
      if (!_currentDownload(epoch)) return;
      state = OtaUpdateState(
        status: OtaStatus.error,
        updateInfo: targetInfo,
        errorMessage: error.toString(),
      );
    } finally {
      _downloadActive = false;
    }
  }

  Future<void> _startDownload(AppUpdateInfo targetInfo, int epoch) async {
    if (kIsWeb) {
      state = state.copyWith(
        status: OtaStatus.error,
        errorMessage: 'Установка обновлений не поддерживается в веб-версии.',
      );
      return;
    }

    // Check if already downloaded
    final File updateFile = await _resolveTargetFile(targetInfo.latestVersion);
    if (!_currentDownload(epoch)) return;

    if (await updateFile.exists()) {
      final int length = await updateFile.length();
      if (targetInfo.apkSize != null &&
          length > 1000000 &&
          await UpdateIntegrity.verify(
            updateFile,
            size: targetInfo.apkSize,
            sha: targetInfo.sha256,
          ) &&
          _currentDownload(epoch)) {
        state = OtaUpdateState(
          status: OtaStatus.readyToInstall,
          updateInfo: targetInfo,
          downloadedApkPath: updateFile.path,
          progress: 1.0,
          receivedBytes: length,
          totalBytes: length,
        );
        _notifyDownloadComplete(targetInfo, updateFile.path);
        return;
      }
    }

    if (!_currentDownload(epoch)) return;

    _showProgressNotification(targetInfo, 0.0);

    IOSink? output;
    var published = false;
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
        if (!_currentDownload(epoch)) return;
        if (resp.statusCode == 301 ||
            resp.statusCode == 302 ||
            resp.statusCode == 307 ||
            resp.statusCode == 308) {
          final String? loc = resp.headers['location'];
          if (loc != null && loc.isNotEmpty) {
            currentUri = Uri.parse(loc);
            if (currentUri.scheme != 'https') {
              throw HttpException(
                'Небезопасный протокол перенаправления: ${currentUri.scheme}',
              );
            }
            redirectCount++;
            continue;
          }
        }
        streamedResponse = resp;
        break;
      }

      if (streamedResponse == null || streamedResponse.statusCode != 200) {
        throw HttpException(
          'Ошибка сервера: HTTP ${streamedResponse?.statusCode}',
        );
      }

      final int total =
          streamedResponse.contentLength ?? (targetInfo.apkSize ?? 0);
      int received = 0;

      if (await updateFile.exists()) {
        try {
          await updateFile.delete();
        } catch (_) {}
      }

      final IOSink sink = updateFile.openWrite();
      output = sink;

      await for (final List<int> chunk in streamedResponse.stream) {
        if (!_currentDownload(epoch)) {
          await sink.close();
          try {
            await updateFile.delete();
          } catch (_) {}
          _cancelProgressNotification();
          return;
        }

        received += chunk.length;
        sink.add(chunk);

        final double currentProgress = total > 0
            ? (received / total).clamp(0.0, 1.0)
            : 0.0;

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
      if (!_currentDownload(epoch)) return;

      if (!await UpdateIntegrity.verify(
        updateFile,
        size: targetInfo.apkSize,
        sha: targetInfo.sha256,
      )) {
        await updateFile.delete();
        throw StateError(UpdateIntegrity.errorCode);
      }
      if (!_currentDownload(epoch)) return;
      published = true;

      state = state.copyWith(
        status: OtaStatus.readyToInstall,
        downloadedApkPath: updateFile.path,
        progress: 1.0,
        receivedBytes: total > 0 ? total : received,
        totalBytes: total > 0 ? total : received,
      );

      _notifyDownloadComplete(targetInfo, updateFile.path);
    } catch (e) {
      if (!_currentDownload(epoch)) return;
      debugPrint('[OtaUpdateNotifier] Download error: $e');
      state = state.copyWith(
        status: OtaStatus.error,
        errorMessage: e is StateError && e.message == UpdateIntegrity.errorCode
            ? UpdateIntegrity.errorCode
            : 'Ошибка при загрузке: $e',
      );
      _cancelProgressNotification();
    } finally {
      _downloadClient?.close();
      _downloadClient = null;
      await output?.close();
      if (output != null && !published && await updateFile.exists()) {
        await updateFile.delete();
      }
    }
  }

  void cancelDownload() {
    _downloadEpoch++;
    _downloadClient?.close();
    _downloadClient = null;
    state = OtaUpdateState(
      status: state.updateInfo != null ? OtaStatus.available : OtaStatus.idle,
      updateInfo: state.updateInfo,
    );
    _cancelProgressNotification();
  }

  Future<void> installApk({BuildContext? context}) async =>
      installUpdate(context: context);

  Future<void> installUpdate({BuildContext? context}) async {
    final String? path = state.downloadedApkPath;
    if (path == null || path.isEmpty) {
      if (state.updateInfo != null) {
        startDownload();
      }
      return;
    }

    final File updateFile = File(path);
    if (!await updateFile.exists()) {
      state = state.copyWith(
        status: OtaStatus.available,
        errorMessage: 'Файл обновления не найден. Загрузка перезапущена.',
      );
      startDownload();
      return;
    }

    if (!await UpdateIntegrity.verify(
      updateFile,
      size: state.updateInfo?.apkSize,
      sha: state.updateInfo?.sha256,
    )) {
      state = state.copyWith(
        status: OtaStatus.error,
        errorMessage: UpdateIntegrity.errorCode,
      );
      return;
    }

    // Windows OTA installation (Hardened per Forensic Audit P0 #4):
    // Silent automatic execution disabled until cryptographically signed manifest is verified.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      if (context != null && context.mounted) {
        final bool confirmed = await AppModal.confirm(
          context: context,
          icon: Icons.system_update_rounded,
          title: 'Установка обновления',
          message:
              'Скачан официальный инсталлятор ${state.updateInfo?.latestVersion ?? ""}.\n'
              'Путь: $path\n\n'
              'Запустить установщик NiosMess?',
          confirmLabel: 'Запустить',
          cancelLabel: 'Отмена',
        );
        if (!confirmed) {
          state = state.copyWith(status: OtaStatus.readyToInstall);
          return;
        }
      }

      state = state.copyWith(status: OtaStatus.installing);
      try {
        // Run installer with standard user UI (interactive, not silent)
        await Process.start(path, <String>[], mode: ProcessStartMode.detached);
        exit(0);
      } catch (e) {
        debugPrint(
          '[OtaUpdateNotifier] Windows installer execution failed: $e',
        );
        state = state.copyWith(
          status: OtaStatus.readyToInstall,
          errorMessage: 'Не удалось запустить установщик: $e',
        );
      }
      return;
    }

    // Check REQUEST_INSTALL_PACKAGES permission on Android
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final PermissionStatus status =
            await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          final PermissionStatus reqStatus = await Permission
              .requestInstallPackages
              .request();
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
    final bool confirmed = await AppModal.confirm(
      context: context,
      icon: Icons.security_rounded,
      title: 'Разрешение на установку',
      message:
          'Для обновления приложения необходимо включить пункт «Разрешить установку из этого источника» для NiosMess в настройках безопасности Android.',
      confirmLabel: 'Настройки',
      cancelLabel: 'Отмена',
    );
    if (confirmed) {
      await openAppSettings();
    }
  }

  AppLocalizations get _notificationStrings => lookupAppLocalizations(
    Locale(
      ref
          .read(uiSettingsProvider)
          .effectiveLocaleCode(
            WidgetsBinding.instance.platformDispatcher.locale.languageCode,
          ),
    ),
  );

  void _showProgressNotification(AppUpdateInfo targetInfo, double progress) {
    if (kIsWeb) return;
    try {
      final int percent = (progress * 100).toInt().clamp(0, 100);
      unawaited(
        PushNotificationService.localNotifications
            .show(
              id: _notificationId,
              title: _notificationStrings.noticeUpdateDownloading,
              body:
                  '${_notificationStrings.noticeVersion} v${targetInfo.latestVersion} • $percent%',
              notificationDetails: NotificationDetails(
                android: AndroidNotificationDetails(
                  'niosmess_updates',
                  _notificationStrings.noticeUpdatesChannel,
                  importance: Importance.low,
                  priority: Priority.low,
                  icon: '@mipmap/ic_launcher',
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
            )
            .catchError((Object _) {}),
      );
    } catch (_) {}
  }

  void _notifyDownloadComplete(AppUpdateInfo targetInfo, String apkPath) {
    if (kIsWeb) return;

    // 1. Android Status Bar Notification
    try {
      unawaited(
        PushNotificationService.localNotifications
            .show(
              id: _notificationId,
              title: _notificationStrings.noticeUpdateReady,
              body:
                  '${_notificationStrings.noticeUpdateTap} v${targetInfo.latestVersion}',
              notificationDetails: NotificationDetails(
                android: AndroidNotificationDetails(
                  'niosmess_updates',
                  _notificationStrings.noticeUpdatesChannel,
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
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
            )
            .catchError((Object _) {}),
      );
    } catch (_) {}

    // 2. In-App Banner Overlay
    ref
        .read(inAppNotificationProvider.notifier)
        .show(
          InAppNotificationItem(
            id: 'ota_ready_${targetInfo.latestVersion}',
            title: _notificationStrings.noticeUpdateReady,
            body:
                '${_notificationStrings.noticeUpdateTap} v${targetInfo.latestVersion}',
            icon: Icons.system_update_rounded,
            timestamp: DateTime.now(),
          ),
        );

    HapticService.confirm();
  }

  void _cancelProgressNotification() {
    if (kIsWeb) return;
    try {
      unawaited(
        PushNotificationService.localNotifications
            .cancel(id: _notificationId)
            .catchError((Object _) {}),
      );
    } catch (_) {}
  }
}

final otaUpdateProvider = NotifierProvider<OtaUpdateNotifier, OtaUpdateState>(
  OtaUpdateNotifier.new,
);
