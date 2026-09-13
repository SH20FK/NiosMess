import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

/// An expressive Material 3 dialog informing the user about an available update
/// with release notes, streaming progress, and background download capability.
class AppUpdateDialog extends ConsumerWidget {
  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
  });

  final AppUpdateInfo updateInfo;

  /// Shows the [AppUpdateDialog] with an expressive entrance.
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo updateInfo,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          AppUpdateDialog(updateInfo: updateInfo),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 МБ';
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} МБ';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final OtaUpdateState otaState = ref.watch(otaUpdateProvider);
    final OtaUpdateNotifier notifier = ref.read(otaUpdateProvider.notifier);

    final bool isDownloading = otaState.status == OtaStatus.downloading;
    final bool isReady = otaState.status == OtaStatus.readyToInstall;
    final bool isInstalling = otaState.status == OtaStatus.installing;
    final bool isError = otaState.status == OtaStatus.error;

    return Dialog(
      backgroundColor: scheme.surfaceContainerHigh,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.lgRadius,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Hero Icon Header
              Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isReady
                          ? scheme.primaryContainer
                          : (isError ? scheme.errorContainer : scheme.primaryContainer),
                      borderRadius: AppRadii.mdRadius,
                    ),
                    child: Center(
                      child: Icon(
                        isReady
                            ? Icons.check_circle_rounded
                            : (isDownloading
                                ? Icons.cloud_download_rounded
                                : (isError
                                    ? Icons.error_outline_rounded
                                    : Icons.system_update_rounded)),
                        size: 28,
                        color: isReady
                            ? scheme.primary
                            : (isError ? scheme.error : scheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isReady
                              ? 'Обновление готово'
                              : (isDownloading
                                  ? 'Загрузка обновления'
                                  : 'Доступно обновление'),
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              'v${updateInfo.currentVersion}',
                              style: textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: scheme.primary,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: AppRadii.smRadius,
                              ),
                              child: Text(
                                'v${updateInfo.latestVersion}',
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (updateInfo.apkSize != null)
                              Text(
                                _formatBytes(updateInfo.apkSize!),
                                style: textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Changelog Section (hide when downloading to keep concise)
              if (!isDownloading && updateInfo.changelog.trim().isNotEmpty) ...<Widget>[
                Text(
                  'Что нового:',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: AppRadii.mdRadius,
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      updateInfo.changelog.trim(),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Downloading Progress State
              if (isDownloading) ...<Widget>[
                ClipRRect(
                  borderRadius: AppRadii.fullRadius,
                  child: LinearProgressIndicator(
                    value: otaState.progress > 0 ? otaState.progress : null,
                    minHeight: 10,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      otaState.progress > 0
                          ? 'Загрузка: ${(otaState.progress * 100).toInt()}%'
                          : 'Загрузка пакета...',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    if (otaState.totalBytes > 0)
                      Text(
                        '${_formatBytes(otaState.receivedBytes)} / ${_formatBytes(otaState.totalBytes)}',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Ready State message
              if (isReady) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: AppRadii.mdRadius,
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.check_circle_outline_rounded,
                          color: scheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Пакет обновления полностью загружен и готов к установке.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Error banner
              if (isError) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: AppRadii.mdRadius,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.error_outline_rounded,
                          color: scheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          otaState.errorMessage ?? 'Ошибка при скачивании файла обновления',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              if (isDownloading) ...<Widget>[
                // Seamless background minimize button
                TouchContainer(
                  onTap: () {
                    HapticService.tap();
                    Navigator.of(context).pop();
                  },
                  borderRadius: AppRadii.fullRadius,
                  child: Container(
                    height: AppHeights.lg,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: AppRadii.fullRadius,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: scheme.onPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Скачивать в фоне',
                            style: textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    HapticService.tap();
                    notifier.cancelDownload();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Отменить загрузку'),
                ),
              ] else if (isReady) ...<Widget>[
                TouchContainer(
                  onTap: () {
                    HapticService.confirm();
                    notifier.installApk(context: context);
                  },
                  borderRadius: AppRadii.fullRadius,
                  child: Container(
                    height: AppHeights.lg,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: AppRadii.fullRadius,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.system_update_rounded,
                            color: scheme.onPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Установить сейчас',
                            style: textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    HapticService.tap();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Закрыть'),
                ),
              ] else if (isInstalling) ...<Widget>[
                SizedBox(
                  height: AppHeights.lg,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Запуск установщика...',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...<Widget>[
                TouchContainer(
                  onTap: () {
                    HapticService.confirm();
                    notifier.startDownload(info: updateInfo);
                  },
                  borderRadius: AppRadii.fullRadius,
                  child: Container(
                    height: AppHeights.lg,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: AppRadii.fullRadius,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            isError ? Icons.refresh_rounded : Icons.download_rounded,
                            color: scheme.onPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isError ? 'Повторить попытку' : 'Обновить сейчас',
                            style: textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    HapticService.tap();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Позже'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
