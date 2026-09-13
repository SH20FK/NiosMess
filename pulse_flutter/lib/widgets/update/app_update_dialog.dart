import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// An expressive Material 3 bottom sheet informing the user about an available update
/// with release notes, live streaming progress, and seamless background download capability.
class AppUpdateDialog extends ConsumerWidget {
  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
  });

  final AppUpdateInfo updateInfo;

  /// Shows the update bottom sheet sliding up smoothly from the bottom.
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo updateInfo,
  ) {
    return AppBottomSheets.show<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          AppUpdateDialog(updateInfo: updateInfo),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
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
    final String latestChangelog = AppUpdateService.parseChangelog(
      updateInfo.changelog,
      updateInfo.latestVersion,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
                  gradient: LinearGradient(
                    colors: <Color>[
                      scheme.primaryContainer,
                      scheme.primary.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.system_update_rounded,
                    color: scheme.primary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.updateAvailable,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'v${updateInfo.latestVersion}',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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

          // Changelog Section (Strictly latest version only)
          if (!isDownloading && latestChangelog.isNotEmpty) ...<Widget>[
            Text(
              context.l10n.updateWhatsNew,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: SingleChildScrollView(
                child: Text(
                  latestChangelog,
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
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: otaState.progress > 0 ? otaState.progress : null,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
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
                      ? context.l10n.updateDownloadingProgress((otaState.progress * 100).toInt())
                      : context.l10n.updateDownloadingPackage,
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
                color: scheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_outline_rounded,
                      color: scheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.updateReadyToInstall,
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.error_outline_rounded,
                      color: scheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      otaState.errorMessage ?? context.l10n.updateDownloadFailed,
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
            TouchContainer(
              onTap: () {
                HapticService.tap();
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
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
                        context.l10n.updateDownloadInBackground,
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
              ),
              child: Text(context.l10n.updateCancelDownload),
            ),
          ] else if (isReady) ...<Widget>[
            TouchContainer(
              onTap: () {
                HapticService.confirm();
                notifier.installApk(context: context);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
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
                        context.l10n.updateInstallNow,
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
              ),
              child: Text(context.l10n.updateClose),
            ),
          ] else if (isInstalling) ...<Widget>[
            SizedBox(
              height: 48,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppLoadingIndicator(
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.updateStartingInstaller,
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
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
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
                        isError ? context.l10n.updateRetry : context.l10n.updateNow,
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
              ),
              child: Text(context.l10n.updateLater),
            ),
          ],
        ],
      ),
    );
  }
}
