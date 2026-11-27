import 'package:pulse_flutter/widgets/calls/call_devices_dialog.dart';
import 'package:pulse_flutter/widgets/calls/screen_share_picker_dialog.dart';
import 'package:pulse_flutter/widgets/calls/call_quality_badge.dart';
import 'package:pulse_flutter/widgets/calls/voice_effect_picker_sheet.dart';
import 'package:pulse_flutter/services/audio/voice_filter_preset.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

/// Material 3 Expressive Call Control Dock.
///
/// Provides quick toggles for microphone, speaker / flip camera, video, and hang up.
/// Uses tonal surfaces, 0 elevation, and tactile spring haptic response.
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

  final CallSessionManager session;
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
    final bool isVideoActive =
        isVideoCall ? data.isSelfVideoEnabled : data.isVideo;

    return Center(
      child: Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomInset > 0 ? bottomInset + 8 : 24,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: CallTokens.darkSurfaceContainerHigh.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(CallTokens.dockBorderRadius),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.20),
            width: 1.0,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CallQualityBadge(data: data), const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            IconButton.filledTonal(tooltip: context.l10n.callDevicesTitle,
              onPressed: () => showCallDevicesDialog(context, video: isVideoCall, onApply: session.setDevices),
              icon: const Icon(Icons.tune_rounded)),
            // ── Mute / Unmute ──────────────────────────────────────────
            _CallDockButton(
              icon: data.isMuted
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              tooltip: data.isMuted
                  ? context.l10n.callUnmute
                  : context.l10n.callMute,
              isActive: data.isMuted,
              activeBg: scheme.errorContainer,
              activeFg: scheme.onErrorContainer,
              inactiveBg: CallTokens.darkSurfaceContainerHighest,
              inactiveFg: scheme.onSurface,
              onTap: () {
                HapticService.tap();
                session.setMuted(!data.isMuted);
              },
            ),

            // ── Speaker ────────────────────────────────────────────────
            if (!isVideoCall && !kIsWeb) ...[
              _CallDockButton(
                icon: data.isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_down_rounded,
                tooltip: data.isSpeakerOn
                    ? context.l10n.callSpeakerOff
                    : context.l10n.callSpeakerOn,
                isActive: data.isSpeakerOn,
                activeBg: scheme.primary,
                activeFg: scheme.onPrimary,
                inactiveBg: CallTokens.darkSurfaceContainerHighest,
                inactiveFg: scheme.onSurface,
                onTap: () {
                  HapticService.tap();
                  session.setSpeakerOn(!data.isSpeakerOn);
                },
              ),
              ],

            // ── Flip Camera (Video call only) ──────────────────────────
            if (isVideoCall && onFlipCamera != null) ...[
              _CallDockButton(
                icon: Icons.flip_camera_ios_rounded,
                tooltip: context.l10n.mediaViewerFlipCamera,
                isActive: false,
                activeBg: scheme.primary,
                activeFg: scheme.onPrimary,
                inactiveBg: CallTokens.darkSurfaceContainerHighest,
                inactiveFg: scheme.onSurface,
                onTap: () {
                  HapticService.tap();
                  onFlipCamera!();
                },
              ),
              ],

            // ── Video Toggle Button ────────────────────────────────────
            if (onToggleVideo != null) ...<Widget>[
              _CallDockButton(
                icon: isVideoActive
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                tooltip: isVideoActive
                    ? context.l10n.activeCallCameraOff
                    : context.l10n.activeCallCameraOn,
                isActive: isVideoActive,
                activeBg: scheme.primary,
                activeFg: scheme.onPrimary,
                inactiveBg: CallTokens.darkSurfaceContainerHighest,
                inactiveFg: scheme.onSurface,
                onTap: () {
                  HapticService.tap();
                  onToggleVideo!();
                },
              ),
              ],

            // ── Screen share ───────────────────────────────────────────
            if (!data.isListener)
              _CallDockButton(
                icon: data.isScreenSharing
                    ? Icons.stop_screen_share_rounded
                    : Icons.screen_share_rounded,
                tooltip: data.isScreenSharing
                    ? 'Остановить демонстрацию'
                    : 'Демонстрация экрана',
                isActive: data.isScreenSharing,
                activeBg: scheme.primary,
                activeFg: scheme.onPrimary,
                inactiveBg: CallTokens.darkSurfaceContainerHighest,
                inactiveFg: scheme.onSurface,
                onTap: () async {
                  HapticService.tap();
                  if (data.isScreenSharing) {
                    await session.stopScreenShare();
                    return;
                  }
                  final choice = await showScreenSharePicker(
                    context,
                    maxScreenHeight: data.maxScreenHeight,
                  );
                  if (choice == null) return;
                  try {
                    await session.startScreenShare(sourceId: choice.sourceId);
                  } catch (_) {}
                },
              ),

            // ── VPN / TCP relay ────────────────────────────────────────
            _CallDockButton(
              icon: Icons.vpn_lock_rounded,
              tooltip: data.forceRelay
                  ? 'Режим VPN (TCP/TLS) включён'
                  : 'Включить режим VPN (TCP/TLS)',
              isActive: data.forceRelay,
              activeBg: scheme.tertiary,
              activeFg: scheme.onTertiary,
              inactiveBg: CallTokens.darkSurfaceContainerHighest,
              inactiveFg: scheme.onSurface,
              onTap: () {
                HapticService.tap();
                session.setForceRelay(!data.forceRelay);
              },
            ),

            // ── Hand Raise ─────────────────────────────────────────────
            _CallDockButton(
              icon: Icons.front_hand_rounded,
              tooltip: data.isHandRaised
                  ? 'Опустить руку'
                  : 'Поднять руку',
              isActive: data.isHandRaised,
              activeBg: scheme.secondary,
              activeFg: scheme.onSecondary,
              inactiveBg: CallTokens.darkSurfaceContainerHighest,
              inactiveFg: scheme.onSurface,
              onTap: () {
                HapticService.tap();
                session.toggleHandRaise();
              },
            ),

            // ── Quick Call Reactions ───────────────────────────────────
            PopupMenuButton<String>(
              tooltip: 'Реакция',
              color: CallTokens.darkSurfaceContainerHigh,
              onSelected: (emoji) {
                HapticService.tap();
                session.sendReaction(emoji);
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: '👍', child: Text('👍  Класс')),
                PopupMenuItem(value: '❤️', child: Text('❤️  Сердце')),
                PopupMenuItem(value: '🔥', child: Text('🔥  Огонь')),
                PopupMenuItem(value: '👏', child: Text('👏  Аплодисменты')),
                PopupMenuItem(value: '😂', child: Text('😂  Смех')),
                PopupMenuItem(value: '🤯', child: Text('🤯  Шок')),
              ],
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: data.localReaction != null
                      ? scheme.primaryContainer
                      : CallTokens.darkSurfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_reaction_rounded,
                  color: data.localReaction != null
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  size: 22,
                ),
              ),
            ),

            // ── Voice Effect Preset ────────────────────────────────────
            if (!data.isListener)
              _CallDockButton(
                icon: Icons.graphic_eq_rounded,
                tooltip: data.voiceEffect == VoiceFilterPreset.none
                    ? 'Фильтр голоса'
                    : 'Фильтр: ${data.voiceEffect.title}',
                isActive: data.voiceEffect != VoiceFilterPreset.none,
                activeBg: scheme.primary,
                activeFg: scheme.onPrimary,
                inactiveBg: CallTokens.darkSurfaceContainerHighest,
                inactiveFg: scheme.onSurface,
                onTap: () async {
                  HapticService.tap();
                  final picked = await showVoiceEffectPickerSheet(
                    context,
                    selected: data.voiceEffect,
                    title: 'Фильтр голоса в звонке',
                  );
                  if (picked != null) {
                    await session.setVoiceEffect(picked);
                  }
                },
              ),

            // ── End Call Button (M3 Expressive Red Stadium Pill) ────────
            Tooltip(
              message: context.l10n.callEnd,
              child: TouchContainer(
                width: CallTokens.meetEndButtonWidth,
                height: CallTokens.meetEndButtonHeight,
                borderRadius: BorderRadius.circular(CallTokens.meetEndButtonHeight / 2),
                color: scheme.error,
                scaleDown: 0.94,
                releaseCurve: M3SpringCurves.spatialFast,
                enableHaptics: true,
                onTap: () {
                  HapticService.confirm();
                  onEnd();
                },
                child: Center(
                  child: Icon(
                    Icons.call_end_rounded,
                    color: scheme.onError,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
        ]),
      ),
    );
  }
}

class _CallDockButton extends StatelessWidget {
  const _CallDockButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isActive,
    required this.activeBg,
    required this.activeFg,
    required this.inactiveBg,
    required this.inactiveFg,
  });

  final IconData icon;
  final String tooltip;
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

    return Tooltip(
      message: tooltip,
      child: TouchContainer(
        width: 52,
        height: 52,
        borderRadius: BorderRadius.circular(CallTokens.buttonBorderRadius),
        color: bgColor,
        scaleDown: 0.92,
        releaseCurve: M3SpringCurves.spatialFast,
        enableHaptics: true,
        onTap: onTap,
        child: Center(
          child: Icon(
            icon,
            color: fgColor,
            size: 24,
          ),
        ),
      ),
    );
  }
}
