import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/voice_recorder_service.dart';

class VoiceRecordingPanel extends StatefulWidget {
  const VoiceRecordingPanel({
    required this.elapsed,
    required this.dragOffset,
    required this.isLocked,
    required this.amplitudeHistory,
    required this.onSend,
    required this.onCancel,
    super.key,
  });

  final Duration elapsed;
  final Offset dragOffset;
  final bool isLocked;
  final List<double> amplitudeHistory;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  State<VoiceRecordingPanel> createState() => _VoiceRecordingPanelState();
}

class _VoiceRecordingPanelState extends State<VoiceRecordingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnim = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: M3SpringCurves.expressiveStandard,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!animate) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cancelProgress = (-widget.dragOffset.dx / 120).clamp(0.0, 1.0);
    final showCancel = !widget.isLocked && cancelProgress > 0.2;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : M3Durations.short3;

    return AnimatedContainer(
      duration: duration,
      curve: M3SpringCurves.expressiveDecel,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: showCancel ? scheme.errorContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) => Transform.scale(
              key: const ValueKey('voice-recording-pulse'),
              scale: _pulseAnim.value,
              child: child,
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.mic_rounded, color: scheme.error, size: 20),
                  if (widget.isLocked || widget.dragOffset.dy < -20)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(
                        Icons.lock_rounded,
                        color: scheme.primary,
                        size: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            VoiceRecorderService.formatDuration(widget.elapsed),
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: showCancel
                ? Text(
                    context.l10n.chatSlideToCancel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  )
                : _waveform(scheme),
          ),
          IconButton.filledTonal(
            tooltip: context.l10n.commonCancel,
            onPressed: widget.onCancel,
            icon: const Icon(Icons.delete_outline_rounded),
            style: IconButton.styleFrom(
              foregroundColor: scheme.error,
              backgroundColor: scheme.errorContainer,
              minimumSize: const Size(48, 48),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: context.l10n.mediaSendRecording,
            onPressed: widget.onSend,
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ],
      ),
    );
  }

  Widget _waveform(ColorScheme scheme) {
    const barCount = 24;
    final history = widget.amplitudeHistory;
    return SizedBox(
      height: 28,
      child: Row(
        children: List.generate(barCount, (i) {
          final index = history.length - barCount + i;
          final amplitude = index >= 0 && index < history.length
              ? history[index]
              : 0.0;
          return Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : M3Durations.short2,
                curve: M3SpringCurves.expressiveDecel,
                width: 3,
                height: (amplitude * 24).clamp(3, 28),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
