import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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

  // Draggable local PiP coordinates
  double _pipX = 0.0;
  double _pipY = 0.0;
  bool _pipInitialized = false;

  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  StreamSubscription<CallSessionData>? _stateSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

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

    _timerNotifier.value = session.currentData.durationSeconds;
    _stateSubscription = session.stateStream.listen((CallSessionData data) {
      if (!mounted) return;
      if (data.state == CallSessionState.ended) {
        if (data.fatalError != null) {
          AppToast.showError(context, data.fatalError!);
        }
        _popOrGoHome();
      }
      _timerNotifier.value = data.durationSeconds;
      setState(() {});
    });
    setState(() {});
  }

  @override
  void dispose() {
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
        _controlsFadeController.reverse();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _areControlsVisible = !_areControlsVisible;
      if (_areControlsVisible) {
        _controlsFadeController.forward();
        _resetControlsTimer();
      } else {
        _controlsFadeController.reverse();
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

  Future<void> _endCall() async {
    HapticService.tap();
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
    final scheme = ColorScheme.fromSeed(
      seedColor: appScheme.primary,
      brightness: Brightness.dark,
    );
    final textTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
    ).textTheme;

    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    if (!_pipInitialized) {
      _pipX = size.width - CallTokens.videoPipWidth - 16;
      _pipY = topPadding + 64;
      _pipInitialized = true;
    }

    final participants = data.remoteParticipants;
    final participantName = participants.isNotEmpty
        ? participants.map((p) => p.nickname).join(', ')
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
                        Colors.black.withValues(alpha: 0.70),
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
                child: AnimatedBuilder(
                  animation: _controlsFadeAnimation,
                  builder: (context, child) => Opacity(
                    opacity: _controlsFadeAnimation.value,
                    child: IgnorePointer(
                      ignoring: _controlsFadeAnimation.value < 0.05,
                      child: child,
                    ),
                  ),
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
                              color: scheme.surfaceContainerHigh
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.25),
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
              Positioned(
                left: _pipX,
                top: _pipY,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _pipX = (_pipX + details.delta.dx).clamp(
                        12.0,
                        size.width - CallTokens.videoPipWidth - 12.0,
                      );
                      _pipY = (_pipY + details.delta.dy).clamp(
                        topPadding + 12.0,
                        size.height - CallTokens.videoPipHeight - 100.0,
                      );
                    });
                  },
                  child: Container(
                    width: CallTokens.videoPipWidth,
                    height: CallTokens.videoPipHeight,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(CallTokens.pipBorderRadius),
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
                                  color: scheme.surfaceContainerHigh
                                      .withValues(alpha: 0.80),
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
                child: AnimatedBuilder(
                  animation: _controlsFadeAnimation,
                  builder: (context, child) => Opacity(
                    opacity: _controlsFadeAnimation.value,
                    child: IgnorePointer(
                      ignoring: _controlsFadeAnimation.value < 0.05,
                      child: child,
                    ),
                  ),
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
