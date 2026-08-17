import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/call_video_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';

class ActiveVideoCallScreen extends ConsumerStatefulWidget {
  const ActiveVideoCallScreen({super.key});

  @override
  ConsumerState<ActiveVideoCallScreen> createState() => _ActiveVideoCallScreenState();
}

class _ActiveVideoCallScreenState extends ConsumerState<ActiveVideoCallScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controlsFadeController;
  late final Animation<double> _controlsFadeAnimation;
  bool _areControlsVisible = true;
  Timer? _controlsAutoHideTimer;

  // PiP position
  double _pipX = 0.0;
  double _pipY = 0.0;
  bool _pipInitialized = false;

  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  StreamSubscription<CallSessionData>? _stateSubscription;
  StreamSubscription<Uint8List>? _videoSubscription;

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
      _listenToState();
      _listenToVideo();
    });
  }

  void _listenToState() {
    final session = ref.read(callSessionProvider)?.session;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _listenToState();
      });
      return;
    }

    _timerNotifier.value = session.currentData.durationSeconds;
    _stateSubscription = session.stateStream.listen((data) {
      if (!mounted) return;
      if (data.state == CallSessionState.ended) {
        if (data.fatalError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data.fatalError!)),
          );
        }
        Navigator.of(context).pop();
      }
      _timerNotifier.value = data.durationSeconds;
      setState(() {});
    });
  }

  void _listenToVideo() {
    final session = ref.read(callSessionProvider)?.session;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _listenToVideo();
      });
      return;
    }

    final videoOutput = session.videoOutput;
    if (videoOutput == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _listenToVideo();
      });
      return;
    }

    _videoSubscription = videoOutput.frameStream.listen((frame) {
      ref.read(remoteVideoFrameProvider.notifier).set(frame);
    });
  }

  @override
  void dispose() {
    _controlsFadeController.dispose();
    _controlsAutoHideTimer?.cancel();
    _stateSubscription?.cancel();
    _videoSubscription?.cancel();
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

  Future<void> _endCall() async {
    HapticFeedback.mediumImpact();
    final manager = ref.read(callSessionProvider);
    await manager?.end();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = ref.watch(callSessionProvider)?.session;
    if (session == null) return const Scaffold(backgroundColor: Colors.black);

    final data = session.currentData;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final remoteFrame = ref.watch(remoteVideoFrameProvider);
    final size = MediaQuery.sizeOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    if (!_pipInitialized) {
      _pipX = size.width - CallTokens.videoPipWidth - 16;
      _pipY = size.height - CallTokens.videoPipHeight - 160;
      _pipInitialized = true;
    }

    final participants = data.remoteParticipants;
    final participantName = participants.isNotEmpty
        ? participants.map((p) => p.nickname).join(', ')
        : context.l10n.callConnecting;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ── Remote video / placeholder ───────────────────────────────
            Positioned.fill(
              child: RepaintBoundary(
                child: remoteFrame != null && remoteFrame.isNotEmpty
                    ? Image.memory(
                        remoteFrame,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : _NoVideoPlaceholder(
                        name: participantName,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
              ),
            ),

            // ── Gradient scrim top (name + timer) ───────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Gradient scrim bottom (controls) ────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 200 + safeBottom,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Top bar: name + timer ────────────────────────────────────
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      participantName,
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: _timerNotifier,
                    builder: (context, seconds, _) {
                      final m = seconds ~/ 60;
                      final s = seconds % 60;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                          style: textTheme.labelMedium?.copyWith(
                            fontFamily: 'monospace',
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Draggable PiP (self camera) ──────────────────────────────
            Positioned(
              left: _pipX,
              top: _pipY,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _pipX = (_pipX + details.delta.dx)
                        .clamp(0, size.width - CallTokens.videoPipWidth);
                    _pipY = (_pipY + details.delta.dy)
                        .clamp(0, size.height - CallTokens.videoPipHeight);
                  });
                },
                child: RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: CallTokens.videoPipWidth,
                      height: CallTokens.videoPipHeight,
                      child: Stack(
                        children: [
                          const _LocalCameraPreview(),
                          // Thin border overlay
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
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
            ),

            // ── Controls bar (fade in/out) ───────────────────────────────
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
                child: _VideoControlBar(
                  session: session,
                  data: data,
                  scheme: scheme,
                  onEnd: _endCall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── No video placeholder ──────────────────────────────────────────────────────

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
    final bgColor = Color.lerp(scheme.primaryContainer, scheme.tertiaryContainer, 0.4)!;
    final dark = HSLColor.fromColor(bgColor)
        .withLightness((HSLColor.fromColor(bgColor).lightness * 0.4).clamp(0.0, 1.0))
        .toColor();

    return Container(
      color: dark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer.withValues(alpha: 0.3),
                border: Border.all(
                  color: scheme.onPrimary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.videocam_off_rounded,
                size: 40,
                color: scheme.onPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: textTheme.titleLarge?.copyWith(color: scheme.onPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Камера выключена',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Video control bar ─────────────────────────────────────────────────────────

class _VideoControlBar extends StatelessWidget {
  const _VideoControlBar({
    required this.session,
    required this.data,
    required this.scheme,
    required this.onEnd,
  });

  final CallSession session;
  final CallSessionData data;
  final ColorScheme scheme;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final iconColor = Colors.white;
    final baseBg = Colors.white.withValues(alpha: 0.15);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: safeBottom + 20,
        top: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Minimize
          _VideoButton(
            icon: Icons.grid_view_rounded,
            label: context.l10n.callMinimize,
            bg: baseBg,
            iconColor: iconColor,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
          ),

          // Mute
          _VideoButton(
            icon: data.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: data.isMuted ? context.l10n.callUnmute : context.l10n.callMute,
            bg: data.isMuted ? scheme.error.withValues(alpha: 0.8) : baseBg,
            iconColor: iconColor,
            onTap: () {
              HapticFeedback.lightImpact();
              session.setMuted(!data.isMuted);
            },
          ),

          // End call
          _VideoEndButton(onTap: onEnd),

          // Camera toggle
          _VideoButton(
            icon: data.isSelfVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            label: data.isSelfVideoEnabled ? 'Камера' : 'Камера выкл.',
            bg: !data.isSelfVideoEnabled ? scheme.error.withValues(alpha: 0.8) : baseBg,
            iconColor: iconColor,
            onTap: () {
              HapticFeedback.lightImpact();
              session.setLocalVideoEnabled(!data.isSelfVideoEnabled);
            },
          ),

          // Switch camera
          _VideoButton(
            icon: Icons.flip_camera_ios_rounded,
            label: 'Камера',
            bg: baseBg,
            iconColor: iconColor,
            onTap: () {
              HapticFeedback.lightImpact();
              session.switchCamera();
            },
          ),
        ],
      ),
    );
  }
}

class _VideoButton extends StatelessWidget {
  const _VideoButton({
    required this.icon,
    required this.label,
    required this.bg,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

class _VideoEndButton extends StatelessWidget {
  const _VideoEndButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: const SizedBox(
              width: 64,
              height: 56,
              child: Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          context.l10n.callEnd,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }
}

// ── Local camera preview ──────────────────────────────────────────────────────

class _LocalCameraPreview extends ConsumerWidget {
  const _LocalCameraPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(localVideoEnabledProvider);
    final controller = ref.watch(localCameraControllerProvider);

    if (!isEnabled) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 28),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
          ),
        ),
      );
    }

    return CameraPreview(controller);
  }
}
