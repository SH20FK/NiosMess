import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/adaptive/adaptive_glass.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Center(
      child: Container(
        margin: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: bottomInset > 0 ? bottomInset + 12 : 28,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CallTokens.dockBorderRadius),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AdaptiveGlass(
          borderRadius: BorderRadius.circular(CallTokens.dockBorderRadius),
          tierASigma: CallTokens.glassBlur,
          tierBSigma: 8.0,
          tintColor: scheme.surface.withValues(alpha: 0.16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: 0.12),
            width: CallTokens.glassBorderWidth,
          ),
          child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Mute / Unmute
                  CallShapeButton(
                    icon: data.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: data.isMuted ? context.l10n.callUnmute : context.l10n.callMute,
                    isActive: data.isMuted,
                    activeBackgroundColor: scheme.errorContainer.withValues(alpha: 0.85),
                    activeForegroundColor: scheme.onErrorContainer,
                    inactiveBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
                    inactiveForegroundColor: scheme.onSurface,
                    shape: Shapes.c9_sided_cookie,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      session.setMuted(!data.isMuted);
                    },
                  ),
                  const SizedBox(width: 14),

                  // Speaker (or Camera flip if video call)
                  if (!isVideoCall)
                    CallShapeButton(
                      icon: data.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      label: data.isSpeakerOn ? context.l10n.callSpeakerOff : context.l10n.callSpeakerOn,
                      isActive: data.isSpeakerOn,
                      activeBackgroundColor: scheme.tertiaryContainer.withValues(alpha: 0.9),
                      activeForegroundColor: scheme.onTertiaryContainer,
                      inactiveBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
                      inactiveForegroundColor: scheme.onSurface,
                      shape: Shapes.c9_sided_cookie,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        session.setSpeakerOn(!data.isSpeakerOn);
                      },
                    )
                  else if (onFlipCamera != null)
                    CallShapeButton(
                      icon: Icons.flip_camera_ios_rounded,
                      label: context.l10n.mediaViewerFlipCamera,
                      isActive: false,
                      activeBackgroundColor: scheme.primaryContainer,
                      activeForegroundColor: scheme.onPrimaryContainer,
                      inactiveBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
                      inactiveForegroundColor: scheme.onSurface,
                      shape: Shapes.c9_sided_cookie,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onFlipCamera!();
                      },
                    ),

                  // Video Toggle (if enabled)
                  if (isVideoCall && onToggleVideo != null) ...[
                    const SizedBox(width: 14),
                    CallShapeButton(
                      icon: data.isVideo ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                      label: data.isVideo ? context.l10n.activeCallCameraOff : context.l10n.activeCallCameraOn,
                      isActive: data.isVideo,
                      activeBackgroundColor: scheme.primaryContainer.withValues(alpha: 0.9),
                      activeForegroundColor: scheme.onPrimaryContainer,
                      inactiveBackgroundColor: scheme.errorContainer.withValues(alpha: 0.85),
                      inactiveForegroundColor: scheme.onErrorContainer,
                      shape: Shapes.c9_sided_cookie,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onToggleVideo!();
                      },
                    ),
                  ],

                  const SizedBox(width: 14),

                  // End Call Button (Hero Expressive Shape)
                  CallShapeButton(
                    icon: Icons.call_end_rounded,
                    label: context.l10n.callEnd,
                    isDestructive: true,
                    size: CallTokens.endCallButtonSize,
                    iconSize: 28,
                    activeBackgroundColor: scheme.error,
                    activeForegroundColor: scheme.onError,
                    inactiveBackgroundColor: scheme.error,
                    inactiveForegroundColor: scheme.onError,
                    shape: Shapes.c9_sided_cookie,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onEnd();
                    },
                  ),

                  // Minimize Button
                  if (onMinimize != null) ...[
                    const SizedBox(width: 14),
                    CallShapeButton(
                      icon: Icons.fullscreen_exit_rounded,
                      label: context.l10n.callMinimize,
                      isActive: false,
                      size: 48,
                      iconSize: 22,
                      activeBackgroundColor: scheme.surfaceContainerHigh,
                      activeForegroundColor: scheme.onSurface,
                      inactiveBackgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                      inactiveForegroundColor: scheme.onSurface.withValues(alpha: 0.75),
                      shape: Shapes.c9_sided_cookie,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onMinimize!();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
  }
}

class CallShapeButton extends StatelessWidget {
  const CallShapeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isDestructive = false,
    this.size = CallTokens.controlButtonSize,
    this.iconSize = 24.0,
    required this.activeBackgroundColor,
    required this.activeForegroundColor,
    required this.inactiveBackgroundColor,
    required this.inactiveForegroundColor,
    this.shape = Shapes.c9_sided_cookie,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDestructive;
  final double size;
  final double iconSize;
  final Color activeBackgroundColor;
  final Color activeForegroundColor;
  final Color inactiveBackgroundColor;
  final Color inactiveForegroundColor;
  final Shapes shape;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDestructive
        ? activeBackgroundColor
        : (isActive ? activeBackgroundColor : inactiveBackgroundColor);
    final fgColor = isDestructive
        ? activeForegroundColor
        : (isActive ? activeForegroundColor : inactiveForegroundColor);

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            width: size,
            height: size,
            child: M3Container(
              shape,
              color: bgColor,
              child: Center(
                child: Icon(
                  icon,
                  color: fgColor,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
