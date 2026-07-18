import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/voice_recorder_service.dart';

class VoiceRecordingPanel extends StatefulWidget {
  const VoiceRecordingPanel({
    required this.elapsed,
    required this.dragOffset,
    required this.isLocked,
    required this.onSend,
    required this.onCancel,
    super.key,
  });

  final Duration elapsed;
  final Offset dragOffset;
  final bool isLocked;
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
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (widget.isLocked) {
      return _buildLockedMode(scheme, context);
    }
    return _buildDraggingMode(scheme, context);
  }

  double get _cancelProgress {
    if (widget.dragOffset.dx >= 0) return 0.0;
    return (-widget.dragOffset.dx / 120.0).clamp(0.0, 1.0);
  }

  bool get _showLockIndicator => widget.dragOffset.dy < -20;

  Widget _pulsingMic() {
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
          color: Theme.of(context).colorScheme.error,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic_rounded,
          color: Theme.of(context).colorScheme.onError,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildDraggingMode(ColorScheme scheme, BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double cancelOpacity = _cancelProgress;
    final bool showLock = _showLockIndicator;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cancelOpacity > 0.3
            ? scheme.errorContainer.withValues(alpha: 0.6)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Center: pulsing mic + timer
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _pulsingMic(),
              const SizedBox(width: 10),
              Text(
                VoiceRecorderService.formatDuration(widget.elapsed),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          // Left: slide to cancel
          if (cancelOpacity > 0)
            Positioned(
              left: 0,
              child: Opacity(
                opacity: cancelOpacity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.arrow_back_rounded,
                      color: scheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.chatSlideToCancel,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Right: lock indicator
          if (showLock)
            Positioned(
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    context.l10n.chatLock,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.lock_outline_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLockedMode(ColorScheme scheme, BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: <Widget>[
          // Lock icon
          Icon(Icons.lock_rounded, color: scheme.primary, size: 18),
          const SizedBox(width: 8),
          // Pulsing mic
          _pulsingMic(),
          const SizedBox(width: 10),
          // Timer
          Text(
            VoiceRecorderService.formatDuration(widget.elapsed),
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          // Cancel button
          IconButton(
            onPressed: widget.onCancel,
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          ),
          const SizedBox(width: 4),
          // Send button
          GestureDetector(
            onTap: widget.onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    scheme.primary,
                    scheme.primary.withValues(alpha: 0.82),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send_rounded, color: scheme.onPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
