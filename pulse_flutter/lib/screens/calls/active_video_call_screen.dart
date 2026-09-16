import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/call_video_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/widgets/calls/call_control_dock.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

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

  int _retryStateCount = 0;
  int _retryVideoCount = 0;

  void _listenToState() {
    final session = ref.read(callSessionProvider)?.session;
    if (session == null) {
      if (_retryStateCount++ < 5) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _listenToState();
        });
      }
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
      if (_retryVideoCount++ < 5) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _listenToVideo();
        });
      }
      return;
    }

    final videoOutput = session.videoOutput;
    if (videoOutput == null) {
      if (_retryVideoCount++ < 5) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _listenToVideo();
        });
      }
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
      return const Scaffold(backgroundColor: Color(0xFF0D0B14));
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
        : (data.peerName?.isNotEmpty == true
            ? data.peerName!
            : context.l10n.callsInProgress);
    const String? participantAvatar = null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B14),
      body: SizedBox.expand(
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            fit: StackFit.expand,
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
                      scheme.scrim.withValues(alpha: 0.65),
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
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: scheme.onSurface,
                        size: 30,
                      ),
                      tooltip: context.l10n.callMinimize,
                      onPressed: () {
                        HapticService.tap();
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
                              if (session.currentData.isListener) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    context.l10n.callListenerModeNotice,
                                    style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.w600),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                            style: textTheme.labelLarge?.copyWith(
                              fontFamily: 'monospace',
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
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
                    borderRadius: BorderRadius.circular(CallTokens.pipBorderRadius),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.20),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CallTokens.pipBorderRadius - 1.5),
                    child: Stack(
                      children: <Widget>[
                        const Positioned.fill(
                          child: _LocalCameraPreview(),
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
                                color: scheme.surfaceContainerHigh.withValues(alpha: 0.75),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.flip_camera_ios_rounded,
                                size: 16,
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
                    session.setLocalVideoEnabled(!data.isSelfVideoEnabled);
                  },
                  onFlipCamera: () {
                    HapticService.tap();
                    session.switchCamera();
                  },
                  onMinimize: () {
                    HapticService.tap();
                    Navigator.of(context).pop();
                  },
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
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.35),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: PulseAvatar(
                  name: name,
                  avatarUrl: avatarUrl,
                  radius: 55,
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

    final scheme = Theme.of(context).colorScheme;

    if (!isEnabled) {
      return Center(
        child: Icon(Icons.videocam_off_rounded, color: scheme.onSurface.withValues(alpha: 0.38), size: 28),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: AppLoadingIndicator(size: 20, color: scheme.onSurface.withValues(alpha: 0.38)),
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
