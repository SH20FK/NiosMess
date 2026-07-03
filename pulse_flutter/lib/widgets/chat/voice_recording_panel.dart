import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/voice_recorder_service.dart';

class VoiceRecordingPanel extends StatefulWidget {
  const VoiceRecordingPanel({
    required this.onSend,
    required this.onCancel,
    super.key,
  });

  final void Function(String filePath) onSend;
  final VoidCallback onCancel;

  @override
  State<VoiceRecordingPanel> createState() => _VoiceRecordingPanelState();
}

class _VoiceRecordingPanelState extends State<VoiceRecordingPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  Duration _elapsed = Duration.zero;
  bool _isRecording = false;

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
    _startRecording();
  }

  Future<void> _startRecording() async {
    final bool started = await VoiceRecorderService.startRecording(
      onTick: (Duration d) {
        if (mounted) setState(() => _elapsed = d);
      },
    );
    if (started && mounted) {
      setState(() => _isRecording = true);
      _pulseController.repeat(reverse: true);
    } else if (mounted) {
      widget.onCancel();
    }
  }

  Future<void> _handleSend() async {
    _pulseController.stop();
    HapticService.confirm();
    final String? path = await VoiceRecorderService.stopRecording();
    if (path != null && mounted) {
      widget.onSend(path);
    }
  }

  Future<void> _handleCancel() async {
    _pulseController.stop();
    HapticService.destructive();
    await VoiceRecorderService.cancelRecording();
    if (mounted) widget.onCancel();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    VoiceRecorderService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: <Widget>[
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (BuildContext context, Widget? child) {
              return Transform.scale(
                scale: _isRecording ? _pulseAnim.value : 1.0,
                child: child,
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  context.l10n.chatVoiceMessage,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  VoiceRecorderService.formatDuration(_elapsed),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleCancel,
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            tooltip: context.l10n.commonCancel,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[scheme.primary, scheme.primary.withValues(alpha: 0.82)],
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
