import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

/// Draggable Material 3 Expressive floating call overlay.
///
/// Features:
/// - Smooth draggable positioning with edge spring snapping (M3SpringCurves.spatial)
/// - Voice call: Compact tonal pill with participant avatar, timer, quick mute & end
/// - Video call: Mini floating video PiP with live RTCVideoView
/// - Tap to re-expand seamlessly to full-screen /call/:callId
class CallOverlay extends ConsumerStatefulWidget {
  const CallOverlay({super.key});

  @override
  ConsumerState<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends ConsumerState<CallOverlay>
    with SingleTickerProviderStateMixin {
  double? _x;
  double? _y;

  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onPanEnd(double screenWidth, double itemWidth) {
    if (_x == null) return;
    final double startX = _x!;
    final double targetX =
        (startX + itemWidth / 2 < screenWidth / 2) ? 16.0 : (screenWidth - itemWidth - 16.0);

    _snapAnimation = Tween<double>(begin: startX, end: targetX).animate(
      CurvedAnimation(parent: _snapController, curve: M3SpringCurves.spatial),
    )..addListener(() {
        if (mounted && _snapAnimation != null) {
          setState(() => _x = _snapAnimation!.value);
        }
      });

    _snapController.forward(from: 0.0);
  }

  void _expandCall(int callId) {
    HapticService.tap();
    final router = ref.read(appRouterProvider);
    final String current = router.routeInformationProvider.value.uri.path;
    if (!current.startsWith('/call/')) {
      router.push('/call/$callId');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide overlay completely when full-screen call screen is open
    final bool isCallScreenOpen = ref.watch(isCallScreenOpenProvider);
    if (isCallScreenOpen) return const SizedBox.shrink();

    final router = ref.watch(appRouterProvider);
    final String currentPath =
        router.routeInformationProvider.value.uri.path;
    if (currentPath.startsWith('/call/')) {
      return const SizedBox.shrink();
    }

    final manager = ref.watch(callSessionProvider);
    if (manager == null) return const SizedBox.shrink();

    return StreamBuilder<CallSessionData>(
      stream: manager.stateStream,
      initialData: manager.currentData,
      builder: (context, snapshot) {
        final data = snapshot.data ?? manager.currentData;
        if (data.state == CallSessionState.ended ||
            data.state == CallSessionState.idle) {
          return const SizedBox.shrink();
        }

        final scheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final mediaQuery = MediaQuery.of(context);
        final screenWidth = mediaQuery.size.width;
        final screenHeight = mediaQuery.size.height;
        final topInset = mediaQuery.padding.top;
        final bottomInset = mediaQuery.padding.bottom;

        final bool isVideo = data.isVideo && manager.remoteStreams.isNotEmpty;
        final double itemWidth = isVideo ? CallTokens.videoPipWidth : 250.0;
        final double itemHeight = isVideo ? CallTokens.videoPipHeight : 54.0;

        _x ??= screenWidth - itemWidth - 16.0;
        _y ??= screenHeight - bottomInset - itemHeight - 96.0;

        final participantName = data.remoteParticipants.isNotEmpty
            ? data.remoteParticipants.first.nickname
            : (data.peerName?.isNotEmpty == true ? data.peerName! : 'Собеседник');

        final m = data.durationSeconds ~/ 60;
        final s = data.durationSeconds % 60;
        final timerLabel =
            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

        return Stack(
          children: [
            Positioned(
              left: _x,
              top: _y,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _x = (_x! + details.delta.dx).clamp(
                      8.0,
                      screenWidth - itemWidth - 8.0,
                    );
                    _y = (_y! + details.delta.dy).clamp(
                      topInset + 8.0,
                      screenHeight - bottomInset - itemHeight - 8.0,
                    );
                  });
                },
                onPanEnd: (_) => _onPanEnd(screenWidth, itemWidth),
                child: isVideo
                    ? _VideoOverlayTile(
                        manager: manager,
                        data: data,
                        scheme: scheme,
                        participantName: participantName,
                        timerLabel: timerLabel,
                        onTap: () => _expandCall(data.callId),
                        onEnd: () async {
                          HapticService.tap();
                          await manager.end();
                        },
                      )
                    : _VoiceOverlayPill(
                        manager: manager,
                        data: data,
                        scheme: scheme,
                        textTheme: textTheme,
                        participantName: participantName,
                        timerLabel: timerLabel,
                        onTap: () => _expandCall(data.callId),
                        onEnd: () async {
                          HapticService.tap();
                          await manager.end();
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VoiceOverlayPill extends StatelessWidget {
  const _VoiceOverlayPill({
    required this.manager,
    required this.data,
    required this.scheme,
    required this.textTheme,
    required this.participantName,
    required this.timerLabel,
    required this.onTap,
    required this.onEnd,
  });

  final CallSessionManager manager;
  final CallSessionData data;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final String participantName;
  final String timerLabel;
  final VoidCallback onTap;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Expand tap target
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseAvatar(
                    name: participantName,
                    radius: 18,
                    fallbackColor: scheme.primaryContainer,
                    textColor: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 86),
                        child: Text(
                          participantName,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.statusOnline,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timerLabel,
                            style: textTheme.labelSmall?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Quick Mute button
            IconButton(
              icon: Icon(
                data.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: 20,
                color: data.isMuted ? scheme.error : scheme.onSurface,
              ),
              onPressed: () {
                HapticService.tap();
                manager.toggleMute();
              },
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),

            // Quick End button
            GestureDetector(
              onTap: onEnd,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.call_end_rounded,
                    color: scheme.onError,
                    size: 16,
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

class _VideoOverlayTile extends StatelessWidget {
  const _VideoOverlayTile({
    required this.manager,
    required this.data,
    required this.scheme,
    required this.participantName,
    required this.timerLabel,
    required this.onTap,
    required this.onEnd,
  });

  final CallSessionManager manager;
  final CallSessionData data;
  final ColorScheme scheme;
  final String participantName;
  final String timerLabel;
  final VoidCallback onTap;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: CallTokens.videoPipWidth,
          height: CallTokens.videoPipHeight,
          decoration: BoxDecoration(
            color: CallTokens.darkSurface,
            borderRadius: BorderRadius.circular(CallTokens.pipBorderRadius),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(CallTokens.pipBorderRadius - 1.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Live remote video stream
                RTCVideoView(
                  manager.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),

                // Top timer badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      timerLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Bottom actions (Mute & End)
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticService.tap();
                          manager.toggleMute();
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            data.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            size: 15,
                            color: data.isMuted ? scheme.error : Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onEnd,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: scheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.call_end_rounded,
                            size: 15,
                            color: scheme.onError,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

