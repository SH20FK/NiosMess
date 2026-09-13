import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

enum _DownloadStatus { idle, downloading, installing, error }

/// An expressive Material 3 dialog informing the user about an available update
/// with release notes and a streaming in-app progress bar.
class AppUpdateDialog extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog> {
  _DownloadStatus _status = _DownloadStatus.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 МБ';
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} МБ';
  }

  Future<void> _startDownload() async {
    setState(() {
      _status = _DownloadStatus.downloading;
      _progress = 0.0;
      _errorMessage = null;
    });

    HapticService.confirm();

    final AppUpdateService service = ref.read(appUpdateServiceProvider);

    try {
      final OpenResult result = await service.downloadAndInstall(
        downloadUrl: widget.updateInfo.downloadUrl,
        onProgress: (double progress, int received, int total) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );

      if (!mounted) return;

      if (result.type == ResultType.done) {
        setState(() {
          _status = _DownloadStatus.installing;
        });
        Navigator.of(context).pop();
      } else {
        setState(() {
          _status = _DownloadStatus.error;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _DownloadStatus.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

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
                      color: scheme.primaryContainer,
                      borderRadius: AppRadii.mdRadius,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 28,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Доступно обновление',
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
                              'v${widget.updateInfo.currentVersion}',
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
                                'v${widget.updateInfo.latestVersion}',
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (widget.updateInfo.apkSize != null)
                              Text(
                                _formatBytes(widget.updateInfo.apkSize!),
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

              // Changelog Section
              if (widget.updateInfo.changelog.trim().isNotEmpty) ...<Widget>[
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
                      widget.updateInfo.changelog.trim(),
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
              if (_status == _DownloadStatus.downloading) ...<Widget>[
                ClipRRect(
                  borderRadius: AppRadii.fullRadius,
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
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
                      _progress > 0
                          ? 'Загрузка: ${(_progress * 100).toInt()}%'
                          : 'Загрузка пакета...',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    if (_totalBytes > 0)
                      Text(
                        '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Error banner
              if (_status == _DownloadStatus.error) ...<Widget>[
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
                          _errorMessage ?? 'Ошибка при скачивании файла обновления',
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

              // Primary & Secondary Action Buttons
              if (_status == _DownloadStatus.downloading)
                SizedBox(
                  height: AppHeights.lg,
                  child: Center(
                    child: Text(
                      'Пожалуйста, не закрывайте приложение...',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TouchContainer(
                      onTap: _startDownload,
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
                                _status == _DownloadStatus.error
                                    ? Icons.refresh_rounded
                                    : Icons.download_rounded,
                                color: scheme.onPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _status == _DownloadStatus.error
                                    ? 'Повторить попытку'
                                    : 'Обновить сейчас',
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
