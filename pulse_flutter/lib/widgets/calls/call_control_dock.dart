import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';

class CallControlDock extends StatelessWidget {
  const CallControlDock({
    super.key,
    required this.session,
    required this.data,
    required this.scheme,
    required this.onEnd,
    this.onToggleVideo,
    this.onFlipCamera,
    this.onMinimize,
    this.isVideoCall = false,
  });

  final CallSession session;
  final CallSessionData data;
  final ColorScheme scheme;
  final VoidCallback onEnd;
  final VoidCallback? onToggleVideo;
  final VoidCallback? onFlipCamera;
  final VoidCallback? onMinimize;
  final bool isVideoCall;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Center(
      child: Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomInset > 0 ? bottomInset + 8 : 24,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(CallTokens.dockBorderRadius),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            width: 1.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Mute / Unmute
            _CallActionButton(
              icon: data.isMuted
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              label: data.isMuted
                  ? context.l10n.callUnmute
                  : context.l10n.callMute,
              isActive: data.isMuted,
              activeBg: scheme.errorContainer,
              activeFg: scheme.onErrorContainer,
              inactiveBg: scheme.surfaceContainerHighest,
              inactiveFg: scheme.onSurface,
              onTap: () {
                HapticService.tap();
                session.setMuted(!data.isMuted);
              },
            ),
            const SizedBox(width: 12),

            // Speaker (or Flip Camera in Video call)
            if (!isVideoCall)
              _CallActionButton(
                icon: data.isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_down_rounded,
                label: data.isSpeakerOn
                    ? context.l10n.callSpeakerOff
                    : context.l10n.callSpeakerOn,
                isActive: data.isSpeakerOn,
                activeBg: scheme.primary,
                activeFg: scheme.onPrimary,
                inactiveBg: scheme.surfaceContainerHighest,
                inactiveFg: scheme.onSurface,
                onTap: () {
                  HapticService.tap();
                  session.setSpeakerOn(!data.isSpeakerOn);
                },
              )
            else if (onFlipCamera != null)
              _CallActionButton(
                icon: Icons.flip_camera_ios_rounded,
                label: context.l10n.mediaViewerFlipCamera,
                isActive: false,
                activeBg: scheme.primary,
                activeFg: scheme.onPrimary,
                inactiveBg: scheme.surfaceContainerHighest,
                inactiveFg: scheme.onSurface,
                onTap: () {
                  HapticService.tap();
                  onFlipCamera!();
                },
              ),

            // Video button
            if (onToggleVideo != null) ...<Widget>[
              const SizedBox(width: 12),
              _CallActionButton(
                icon: data.isVideo
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                label: data.isVideo
                    ? context.l10n.activeCallCameraOff
                    : context.l10n.activeCallCameraOn,
                isActive: data.isVideo,
                activeBg: scheme.primary,
                activeFg: scheme.onPrimary,
                inactiveBg: scheme.surfaceContainerHighest,
                inactiveFg: scheme.onSurface,
                onTap: () {
                  HapticService.tap();
                  onToggleVideo!();
                },
              ),
            ],

            const SizedBox(width: 14),

            // End Call Button (Prominent M3 Error Button)
            Semantics(
              button: true,
              label: context.l10n.callEnd,
              child: Tooltip(
                message: context.l10n.callEnd,
                child: GestureDetector(
                  onTap: () {
                    HapticService.tap();
                    onEnd();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: CallTokens.controlButtonSize,
                    height: CallTokens.controlButtonSize,
                    decoration: BoxDecoration(
                      color: scheme.error,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: scheme.error.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.call_end_rounded,
                        color: scheme.onError,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isActive,
    required this.activeBg,
    required this.activeFg,
    required this.inactiveBg,
    required this.inactiveFg,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeBg;
  final Color activeFg;
  final Color inactiveBg;
  final Color inactiveFg;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isActive ? activeBg : inactiveBg;
    final Color fgColor = isActive ? activeFg : inactiveFg;

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                color: fgColor,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
