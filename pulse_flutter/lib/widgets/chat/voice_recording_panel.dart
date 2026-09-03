import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double get _cancelProgress {
    if (widget.dragOffset.dx >= 0) return 0.0;
    return (-widget.dragOffset.dx / 120.0).clamp(0.0, 1.0);
  }

  bool get _showLockIndicator => widget.dragOffset.dy < -20;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (widget.isLocked) {
      return _buildLockedMode(scheme, context);
    }
    return _buildDraggingMode(scheme, context);
  }

  // ── Pulsing mic icon ──
  Widget _pulsingMic(ColorScheme scheme) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(
          scale: _pulseAnim.value,
          child: child,
        );
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: scheme.error,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.error.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          Icons.mic_rounded,
          color: scheme.onError,
          size: 20,
        ),
      ),
    );
  }

  // ── Amplitude waveform bars ──
  Widget _buildWaveform(ColorScheme scheme, {double height = 28}) {
    const int barCount = 24;
    final List<double> history = widget.amplitudeHistory;

    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List<Widget>.generate(barCount, (int i) {
          final int index = history.length - barCount + i;
          final double amp = (index >= 0 && index < history.length)
              ? history[index]
              : 0.0;
          final double barHeight =
              (amp * height * 0.85).clamp(3.0, height);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              curve: Curves.easeOut,
              width: 3.0,
              height: barHeight,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── DRAGGING MODE ──
  Widget _buildDraggingMode(ColorScheme scheme, BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double cancelOpacity = _cancelProgress;
    final bool showLock = _showLockIndicator;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cancelOpacity > 0.3
            ? scheme.errorContainer.withValues(alpha: 0.6)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: <Widget>[
          // Mic + timer
          _pulsingMic(scheme),
          const SizedBox(width: 10),
          Text(
            VoiceRecorderService.formatDuration(widget.elapsed),
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Waveform
          Expanded(
            child: _buildWaveform(scheme),
          ),
          const SizedBox(width: 12),
          // Cancel / Lock hints
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: cancelOpacity > 0.2
                ? Row(
                    key: const ValueKey<String>('cancel'),
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.chevron_left_rounded,
                        color: scheme.error,
                        size: 18,
                      ),
                      Text(
                        context.l10n.chatSlideToCancel,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : showLock
                    ? Icon(
                        Icons.lock_rounded,
                        key: const ValueKey<String>('lock'),
                        color: scheme.primary,
                        size: 20,
                      )
                    : Icon(
                        Icons.chevron_left_rounded,
                        key: const ValueKey<String>('chevron'),
                        color: scheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                        size: 20,
                      ),
          ),
        ],
      ),
    );
  }

  // ── LOCKED MODE ──
  Widget _buildLockedMode(ColorScheme scheme, BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        children: <Widget>[
          // Lock badge
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_rounded,
              color: scheme.primary,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          // Pulsing mic
          _pulsingMic(scheme),
          const SizedBox(width: 10),
          // Timer
          Text(
            VoiceRecorderService.formatDuration(widget.elapsed),
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Waveform
          Expanded(
            child: _buildWaveform(scheme, height: 24),
          ),
          const SizedBox(width: 8),
          // Cancel button
          Material(
            color: scheme.errorContainer.withValues(alpha: 0.6),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onCancel();
              },
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.error,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          Material(
            color: scheme.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onSend();
              },
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.send_rounded,
                  color: scheme.onPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
