import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/api/upload_models.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class UploadProgressOverlay extends StatelessWidget {
  const UploadProgressOverlay({
    required this.stage,
    this.metrics,
    this.queuePosition,
    required this.progress,
    this.bytesSent,
    this.totalBytes,
    required this.isMine,
    required this.scheme,
    this.isCircle = false,
    this.onCancel,
    this.onRetry,
    super.key,
  });

  final UploadStage stage;
  final UploadMetrics? metrics;
  final int? queuePosition;
  final double? progress;
  final int? bytesSent;
  final int? totalBytes;
  final bool isMine;
  final ColorScheme scheme;
  final bool isCircle;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final double p = (progress ?? 0.0).clamp(0.0, 1.0);
    final int percent = (p * 100).toInt();

    final String progressLabel;
    if (stage == UploadStage.failed) {
      progressLabel = 'Не удалось отправить';
    } else if (stage == UploadStage.queued) {
      progressLabel = 'В очереди · позиция ${queuePosition ?? 1}';
    } else if (stage == UploadStage.processing) {
      progressLabel = 'Обработка...';
    } else if (stage == UploadStage.sendingMessage) {
      progressLabel = 'Отправка...';
    } else if (stage == UploadStage.uploading) {
      final String speedStr = UploadSpeedTracker.formatSpeed(
        metrics?.smoothedBytesPerSecond ?? 0,
      );
      final String etaStr = UploadSpeedTracker.formatEta(metrics?.eta);
      final List<String> parts = <String>['$percent%'];
      if (speedStr.isNotEmpty) parts.add(speedStr);
      if (etaStr.isNotEmpty) parts.add(etaStr);
      progressLabel = parts.join(' · ');
    } else {
      progressLabel = '$percent%';
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.38),
      child: Stack(
        children: [
          Center(
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stage == UploadStage.failed) ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        color: scheme.onErrorContainer,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.88,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        progressLabel,
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onRetry != null)
                          GestureDetector(
                            onTap: onRetry,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Повторить',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        if (onRetry != null && onCancel != null)
                          const SizedBox(width: 8),
                        if (onCancel != null)
                          GestureDetector(
                            onTap: onCancel,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Отменить',
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.88,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (stage == UploadStage.queued)
                            Icon(
                              Icons.hourglass_top_rounded,
                              size: 22,
                              color: scheme.primary,
                            )
                          else if (stage == UploadStage.processing ||
                              stage == UploadStage.sendingMessage)
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: AppLoadingIndicator(
                                size: 40,
                                color: scheme.primary,
                                backgroundColor: scheme.onSurface.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: AppLoadingIndicator(
                                size: 40,
                                value: p > 0.01 ? p : null,
                                backgroundColor: scheme.onSurface.withValues(
                                  alpha: 0.2,
                                ),
                                color: scheme.primary,
                              ),
                            ),
                          if (onCancel != null && stage != UploadStage.queued)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: scheme.onSurface,
                                size: 20,
                              ),
                              onPressed: onCancel,
                              tooltip: 'Отменить',
                            )
                          else if (onCancel != null &&
                              stage == UploadStage.queued)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: scheme.onSurface,
                                size: 18,
                              ),
                              onPressed: onCancel,
                              tooltip: 'Отменить',
                            )
                          else
                            Text(
                              '$percent%',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.88,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        progressLabel,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isCircle && stage != UploadStage.failed)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AppLoadingIndicator(
                value: (stage == UploadStage.processing ||
                        stage == UploadStage.sendingMessage)
                    ? null
                    : (stage == UploadStage.queued ? 0.0 : (p > 0.01 ? p : null)),
                minHeight: 3.0,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

