import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/theme/app_surfaces.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:motor/motor.dart' show SingleMotionController;
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/widgets/calls/call_control_dock.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

/// Material 3 Expressive 1:1 active video call screen.
///
/// Features:
/// - Hardware-accelerated full-screen remote RTCVideoView with cover aspect ratio
/// - Draggable, squircle local RTCVideoView thumbnail with spring edge snapping
/// - Expressive top info pill (name, E2EE status, monospace timer, minimize button)
/// - Auto-hiding Material 3 Expressive CallControlDock with zero drop shadows
class ActiveVideoCallScreen extends ConsumerStatefulWidget {
  const ActiveVideoCallScreen({super.key});

  @override
  ConsumerState<ActiveVideoCallScreen> createState() =>
      _ActiveVideoCallScreenState();
}

class _ActiveVideoCallScreenState extends ConsumerState<ActiveVideoCallScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controlsFadeController;
  late final Animation<double> _controlsFadeAnimation;
  bool _areControlsVisible = true;
  Timer? _controlsAutoHideTimer;

  static const double _pipEdgeMargin = 12.0;
  static const double _pipMinFlingVelocity = 700.0;

  // The local PiP position lives in listenables: a drag moves the tile
  // without rebuilding the remote video.
  late final SingleMotionController _pipX;
  final ValueNotifier<double> _pipY = ValueNotifier<double>(0.0);
  late final Listenable _pipPosition = Listenable.merge(<Listenable>[
    _pipX,
    _pipY,
  ]);
  bool _pipInitialized = false;

  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  StreamSubscription<CallSessionData>? _stateSubscription;

  // Seed-derived schemes (CAM16) and their TextTheme are expensive and this
  // screen rebuilds on every call tick, so they are memoized per seed color.
  Color? _cachedSeed;
  ColorScheme? _cachedScheme;
  TextTheme? _cachedTextTheme;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _pipX = SingleMotionController(
      motion: M3Motion.spatialDefault,
      vsync: this,
    );
    _controlsFadeController = AnimationController(
      vsync: this,
      duration: CallTokens.controlsFadeDuration,
    );
    _controlsFadeAnimation = CurvedAnimation(
      parent: _controlsFadeController,
      curve: CallTokens.controlsFadeCurve,
    );
    _controlsFadeController.value = 1.0;
    _resetControlsTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndListen();
    });
  }

  Future<void> _initAndListen() async {
    final session = ref.read(callSessionProvider);
    if (session == null) return;

    await session.initRenderers();
    if (!mounted) return;

    CallSessionState lastState = session.currentData.state;
    _timerNotifier.value = session.currentData.durationSeconds;
    _stateSubscription = session.stateStream.listen((CallSessionData data) {
      if (!mounted) return;
      if (data.state == CallSessionState.connected &&
          lastState != CallSessionState.connected) {
        ref.read(appSoundProvider).playEvent(SoundEvent.callConnected);
      }
      lastState = data.state;
      if (data.state == CallSessionState.ended) {
        ref.read(appSoundProvider).playEvent(SoundEvent.callEnded);
        if (data.fatalError != null) {
          AppToast.showError(
            context,
            context.l10n.callFailureMessage(data.fatalError!),
          );
        }
        _popOrGoHome();
      }
      // The screen already rebuilds from callSessionProvider and the timer is a
      // ValueNotifier, so a setState here only doubled the per-tick cost.
      _timerNotifier.value = data.durationSeconds;
    });
    setState(() {});
  }

  @override
  void dispose() {
    _pipX.dispose();
    _pipY.dispose();
    _controlsFadeController.dispose();
    _controlsAutoHideTimer?.cancel();
    _stateSubscription?.cancel();
    _timerNotifier.dispose();
    super.dispose();
  }

  void _resetControlsTimer() {
    _controlsAutoHideTimer?.cancel();
    _controlsAutoHideTimer = Timer(CallTokens.controlsAutoHideDuration, () {
      if (mounted && _areControlsVisible) {
        setState(() => _areControlsVisible = false);
        if (context.reduceMotion) {
          _controlsFadeController.value = 0;
        } else {
          _controlsFadeController.reverse();
        }
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _areControlsVisible = !_areControlsVisible;
      if (_areControlsVisible) {
        if (context.reduceMotion) {
          _controlsFadeController.value = 1;
        } else {
          _controlsFadeController.forward();
        }
        _resetControlsTimer();
      } else {
        if (context.reduceMotion) {
          _controlsFadeController.value = 0;
        } else {
          _controlsFadeController.reverse();
        }
      }
    });
  }

  void _popOrGoHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      ref.read(appRouterProvider).go('/main/chats');
    }
  }

  void _minimize() {
    HapticService.tap();
    _popOrGoHome();
  }

  /// Springs the PiP to the nearer side edge, or to the one a fling points
  /// at, starting with the finger's velocity.
  void _snapPip(DragEndDetails details, double screenWidth) {
    final double velocity = details.velocity.pixelsPerSecond.dx;
    const double width = CallTokens.videoPipWidth;
    final bool toStart = velocity.abs() >= _pipMinFlingVelocity
        ? velocity < 0
        : _pipX.value + width / 2 < screenWidth / 2;
    _pipX.springTo(
      toStart ? _pipEdgeMargin : screenWidth - width - _pipEdgeMargin,
      velocity: velocity,
      reduceMotion: context.reduceMotion,
    );
  }

  Future<void> _endCall() async {
    HapticService.tap();
    ref.read(appSoundProvider).playEvent(SoundEvent.callEnded);
    final manager = ref.read(callSessionProvider);
    await manager?.end();
    if (mounted) _popOrGoHome();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = ref.watch(callSessionProvider);
    if (session == null) {
      return const Scaffold(backgroundColor: CallTokens.darkSurface);
    }

    final data = session.currentData;
    final appScheme = Theme.of(context).colorScheme;
    if (_cachedScheme == null || _cachedSeed != appScheme.primary) {
      _cachedSeed = appScheme.primary;
      _cachedScheme = AppSurfaces.neutralize(
        ColorScheme.fromSeed(
          seedColor: appScheme.primary,
          brightness: Brightness.dark,
        ),
      );
      _cachedTextTheme = ThemeData(
        brightness: Brightness.dark,
        colorScheme: _cachedScheme,
      ).textTheme;
    }
    final scheme = _cachedScheme!;
    final textTheme = _cachedTextTheme!;

    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    if (!_pipInitialized) {
      _pipX.value = size.width - CallTokens.videoPipWidth - _pipEdgeMargin;
      _pipY.value = topPadding + 64;
      _pipInitialized = true;
    }
    // The spring may overshoot the edge margin but never leaves the screen.
    final double pipMaxLeft = (size.width - CallTokens.videoPipWidth).clamp(
      0.0,
      double.infinity,
    );

    final participants = data.remoteParticipants;
    final participantName = participants.isNotEmpty
        ? participants
            .map((p) => p.audioEnabled ? p.nickname : '${p.nickname} 🔇')
            .join(', ')
        : (data.peerName?.isNotEmpty == true
              ? data.peerName!
              : context.l10n.callsInProgress);

    final bool hasRemoteVideo = session.remoteStreams.isNotEmpty;

    return Scaffold(
      backgroundColor: CallTokens.darkSurface,
      body: SizedBox.expand(
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Remote Video Stream / Placeholder ────────────────────────
              Positioned.fill(
                child: hasRemoteVideo
                    ? RTCVideoView(
                        session.remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : _NoVideoPlaceholder(
                        name: participantName,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
              ),

              // ── Top Gradient Scrim ───────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topPadding + 90,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scheme.scrim.withValues(alpha: 0.70),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Centered Top Bar with Glassmorphic Style ─────────────────
              Positioned(
                top: topPadding + 6,
                left: 12,
                right: 12,
                child: _CallControlsFade(
                  opacity: _controlsFadeAnimation,
                  visible: _areControlsVisible,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: scheme.onSurface,
                          size: 28,
                        ),
                        tooltip: context.l10n.callMinimize,
                        onPressed: _minimize,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              participantName,
                              style: textTheme.titleMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 12,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'E2EE ЗАЩИЩЕНО',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                if (data.isListener) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      context.l10n.callListenerModeNotice,
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _timerNotifier,
                        builder: (context, seconds, _) {
                          final m = seconds ~/ 60;
                          final s = seconds % 60;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh.withValues(
                                alpha: 0.85,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Text(
                              '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                              style: textTheme.labelLarge?.copyWith(
                                fontFamily: 'monospace',
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Draggable M3 Squircle PiP (Self Camera) ─────────────────
              AnimatedBuilder(
                animation: _pipPosition,
                builder: (context, child) => Positioned(
                  left: _pipX.value.clamp(0.0, pipMaxLeft),
                  top: _pipY.value,
                  child: child!,
                ),
                child: GestureDetector(
                  onPanStart: (_) => _pipX.stop(canceled: true),
                  onPanUpdate: (details) {
                    _pipX.value = (_pipX.value + details.delta.dx).clamp(
                      _pipEdgeMargin,
                      size.width - CallTokens.videoPipWidth - _pipEdgeMargin,
                    );
                    _pipY.value = (_pipY.value + details.delta.dy).clamp(
                      topPadding + _pipEdgeMargin,
                      size.height - CallTokens.videoPipHeight - 100.0,
                    );
                  },
                  onPanEnd: (details) => _snapPip(details, size.width),
                  child: Container(
                    width: CallTokens.videoPipWidth,
                    height: CallTokens.videoPipHeight,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        CallTokens.pipBorderRadius,
                      ),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        CallTokens.pipBorderRadius - 1.5,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if (session.isLocalVideoEnabled &&
                              session.localStream != null)
                            RTCVideoView(
                              session.localRenderer,
                              mirror: true,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            )
                          else
                            Center(
                              child: Icon(
                                Icons.videocam_off_rounded,
                                color: scheme.onSurfaceVariant,
                                size: 28,
                              ),
                            ),

                          // Quick flip camera button inside PiP
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () {
                                HapticService.tap();
                                session.switchCamera();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh.withValues(
                                    alpha: 0.80,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.flip_camera_ios_rounded,
                                  size: 15,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Floating M3 Control Dock ────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _CallControlsFade(
                  opacity: _controlsFadeAnimation,
                  visible: _areControlsVisible,
                  child: CallControlDock(
                    session: session,
                    data: data,
                    scheme: scheme,
                    isVideoCall: true,
                    onToggleVideo: () {
                      HapticService.tap();
                      session.toggleVideo();
                    },
                    onFlipCamera: () {
                      HapticService.tap();
                      session.switchCamera();
                    },
                    onMinimize: _minimize,
                    onEnd: _endCall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── No Video Placeholder ──────────────────────────────────────────────────────

/// Fades call controls in and out. Hidden or leaving controls ignore taps.
class _CallControlsFade extends StatelessWidget {
  const _CallControlsFade({
    required this.opacity,
    required this.visible,
    required this.child,
  });

  final Animation<double> opacity;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: FadeTransition(opacity: opacity, child: child),
    );
  }
}

class _NoVideoPlaceholder extends StatelessWidget {
  const _NoVideoPlaceholder({
    required this.name,
    required this.scheme,
    required this.textTheme,
  });

  final String name;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CallTokens.darkSurface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: PulseAvatar(
                  name: name,
                  radius: 56,
                  fallbackColor: scheme.primaryContainer,
                  textColor: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              name,
              style: textTheme.titleLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Камера выключена',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
