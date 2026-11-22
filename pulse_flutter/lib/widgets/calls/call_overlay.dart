import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:motor/motor.dart' show SingleMotionController;
import 'package:pulse_flutter/core/motion/m3_motion.dart';
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
/// - Draggable positioning; snaps to an edge on [M3Motion.spatialDefault],
///   starting with the finger's velocity
/// - Fades in and out instead of popping
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
  static const double _edgeMargin = 16.0;
  static const double _minFlingVelocity = 700.0;

  // The position lives in listenables: a drag moves the overlay without
  // rebuilding the call tile or its live video.
  late final SingleMotionController _x;
  final ValueNotifier<double> _y = ValueNotifier<double>(0.0);
  late final Listenable _position = Listenable.merge(<Listenable>[_x, _y]);
  bool _placed = false;

  @override
  void initState() {
    super.initState();
    _x = SingleMotionController(motion: M3Motion.spatialDefault, vsync: this);
  }

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  /// Adopts the default position the first time the overlay is shown.
  void _place(double x, double y) {
    if (_placed) return;
    _placed = true;
    _x.value = x;
    _y.value = y;
  }

  /// Springs to the nearer edge, or to the edge a fling points at, starting
  /// with the finger's velocity.
  void _snapToEdge(
    DragEndDetails details,
    double screenWidth,
    double itemWidth,
  ) {
    final double velocity = details.velocity.pixelsPerSecond.dx;
    final bool toStart = velocity.abs() >= _minFlingVelocity
        ? velocity < 0
        : _x.value + itemWidth / 2 < screenWidth / 2;
    _x.springTo(
      toStart ? _edgeMargin : screenWidth - itemWidth - _edgeMargin,
      velocity: velocity,
      reduceMotion: context.reduceMotion,
    );
  }

  Future<void> _endCall(CallSessionManager manager) async {
    final CallSessionState state = manager.currentData.state;
    // The tile stays tappable while it fades out after the call has ended.
    if (state == CallSessionState.ended || state == CallSessionState.idle) {
      return;
    }
    HapticService.tap();
    await manager.end();
  }

  static const Widget _hidden = SizedBox.shrink(
    key: ValueKey<String>('call-overlay-hidden'),
  );

  /// Fades the overlay in and out instead of popping it.
  Widget _presence(Widget child) => AnimatedSwitcher(
    duration: context.motionDuration(M3Durations.effectsDefault),
    switchInCurve: M3SpringCurves.effectsDefault,
    switchOutCurve: M3SpringCurves.effectsFast,
    child: child,
  );

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
    // Hidden while the full-screen call screen is open
    final bool isCallScreenOpen = ref.watch(isCallScreenOpenProvider);
    final router = ref.watch(appRouterProvider);
    final String currentPath = router.routeInformationProvider.value.uri.path;
    final manager = ref.watch(callSessionProvider);
    if (isCallScreenOpen ||
        currentPath.startsWith('/call/') ||
        manager == null) {
      return _presence(_hidden);
    }

    return _presence(
      StreamBuilder<CallSessionData>(
        key: ObjectKey(manager),
        stream: manager.stateStream,
        initialData: manager.currentData,
        builder: (context, snapshot) {
          final data = snapshot.data ?? manager.currentData;
          final bool live =
              data.state != CallSessionState.ended &&
              data.state != CallSessionState.idle;
          return _presence(live ? _buildTile(context, manager, data) : _hidden);
        },
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    CallSessionManager manager,
    CallSessionData data,
  ) {
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

    _place(
      screenWidth - itemWidth - _edgeMargin,
      screenHeight - bottomInset - itemHeight - 96.0,
    );

    final participantName = data.remoteParticipants.isNotEmpty
        ? data.remoteParticipants.first.nickname
        : (data.peerName?.isNotEmpty == true ? data.peerName! : 'Собеседник');

    final m = data.durationSeconds ~/ 60;
    final s = data.durationSeconds % 60;
    final timerLabel =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final bool reduceMotion = context.reduceMotion;
    // The spring may overshoot the edge margin but never leaves the screen.
    final double maxLeft = math.max(0.0, screenWidth - itemWidth);

    return Stack(
      key: const ValueKey<String>('call-overlay-tile'),
      children: [
        AnimatedBuilder(
          animation: _position,
          builder: (context, child) => Positioned(
            left: _x.value.clamp(0.0, maxLeft),
            top: _y.value,
            child: child!,
          ),
          child: GestureDetector(
            onPanStart: (_) => _x.stop(canceled: true),
            onPanUpdate: (details) {
              _x.value = (_x.value + details.delta.dx).clamp(
                8.0,
                screenWidth - itemWidth - 8.0,
              );
              _y.value = (_y.value + details.delta.dy).clamp(
                topInset + 8.0,
                screenHeight - bottomInset - itemHeight - 8.0,
              );
            },
            onPanEnd: (details) =>
                _snapToEdge(details, screenWidth, itemWidth),
            // Entrance pop; the fade comes from [_presence].
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: reduceMotion ? 1.0 : 0.85, end: 1.0),
              duration: reduceMotion ? Duration.zero : M3Durations.spatialFast,
              curve: M3SpringCurves.spatialFast,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: isVideo
                  ? _VideoOverlayTile(
                      manager: manager,
                      data: data,
                      scheme: scheme,
                      participantName: participantName,
                      timerLabel: timerLabel,
                      onTap: () => _expandCall(data.callId),
                      onEnd: () => _endCall(manager),
                    )
                  : _VoiceOverlayPill(
                      manager: manager,
                      data: data,
                      scheme: scheme,
                      textTheme: textTheme,
                      participantName: participantName,
                      timerLabel: timerLabel,
                      onTap: () => _expandCall(data.callId),
                      onEnd: () => _endCall(manager),
                    ),
            ),
          ),
        ),
      ],
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
                      color: scheme.scrim.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      timerLabel,
                      style: const TextStyle(
                        color: CallTokens.onDarkSurface,
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
                            color: scheme.scrim.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            data.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            size: 15,
                            color: data.isMuted
                                ? scheme.error
                                : CallTokens.onDarkSurface,
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

