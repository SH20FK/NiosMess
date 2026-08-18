import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/call_video_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/widgets/calls/call_control_dock.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

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

  // Draggable PiP coordinates
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
    if (session == null) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(backgroundColor: scheme.surface);
    }

    final data = session.currentData;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final remoteFrame = ref.watch(remoteVideoFrameProvider);
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    if (!_pipInitialized) {
      _pipX = size.width - CallTokens.videoPipWidth - 18;
      _pipY = topPadding + 64;
      _pipInitialized = true;
    }

    final participants = data.remoteParticipants;
    final participantName = participants.isNotEmpty
        ? participants.map((p) => p.nickname).join(', ')
        : context.l10n.callConnecting;
    const String? participantAvatar = null;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ── Remote Video Stream / Placeholder ────────────────────────
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
                        avatarUrl: participantAvatar,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
              ),
            ),

            // ── Top Gradient Scrim ───────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topPadding + 100,
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

            // ── Centered Top Bar with Glassmorphic Style ─────────────────
            Positioned(
              top: topPadding + 8,
              left: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _controlsFadeAnimation,
                builder: (context, child) => Opacity(
                  opacity: _controlsFadeAnimation.value,
                  child: child,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      tooltip: context.l10n.callMinimize,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            participantName,
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
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
                                color: scheme.tertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'E2EE PROTECTED',
                                style: textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                            style: textTheme.labelMedium?.copyWith(
                              fontFamily: 'monospace',
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Draggable PiP (Self Camera) ──────────────────────────────
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
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(CallTokens.cardBorderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CallTokens.cardBorderRadius),
                    child: Container(
                      width: CallTokens.videoPipWidth,
                      height: CallTokens.videoPipHeight,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(CallTokens.cardBorderRadius),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: const _LocalCameraPreview(),
                    ),
                  ),
                ),
              ),
            ),

            // ── Floating Glassmorphic Control Dock ───────────────────────
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
                    HapticFeedback.lightImpact();
                    session.setLocalVideoEnabled(!data.isSelfVideoEnabled);
                  },
                  onFlipCamera: () {
                    HapticFeedback.lightImpact();
                    session.switchCamera();
                  },
                  onMinimize: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
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

// ── No Video Placeholder ──────────────────────────────────────────────────────

class _NoVideoPlaceholder extends StatelessWidget {
  const _NoVideoPlaceholder({
    required this.name,
    this.avatarUrl,
    required this.scheme,
    required this.textTheme,
  });

  final String name;
  final String? avatarUrl;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final baseBg = Color.lerp(scheme.surfaceContainerLowest, scheme.surface, 0.4)!;
    final dark = HSLColor.fromColor(baseBg)
        .withLightness((HSLColor.fromColor(baseBg).lightness * 0.55).clamp(0.04, 0.2))
        .toColor();

    return Container(
      color: dark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipPath(
              clipper: M3Clipper(Shapes.c9_sided_cookie),
              child: Container(
                width: 100,
                height: 100,
                color: scheme.primaryContainer,
                child: PulseAvatar(
                  name: name,
                  avatarUrl: avatarUrl,
                  radius: 50,
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
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 14,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Camera off',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
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

// ── Local Camera Preview ──────────────────────────────────────────────────────

class _LocalCameraPreview extends ConsumerWidget {
  const _LocalCameraPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(localVideoEnabledProvider);
    final controller = ref.watch(localCameraControllerProvider);

    if (!isEnabled) {
      return const Center(
        child: Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 28),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? CallTokens.videoPipWidth,
        height: controller.value.previewSize?.width ?? CallTokens.videoPipHeight,
        child: CameraPreview(controller),
      ),
    );
  }
}
