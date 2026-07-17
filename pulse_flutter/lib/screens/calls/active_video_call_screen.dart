import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
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

    _listenToState();
    _listenToVideo();
  }

  void _listenToState() {
    final session = ref.read(callSessionProvider)?.session;
    if (session == null) return;

    _timerNotifier.value = session.currentData.durationSeconds;
    _stateSubscription = session.stateStream.listen((data) {
      if (data.state == CallSessionState.ended) {
        if (mounted) Navigator.of(context).pop();
      }
      _timerNotifier.value = data.durationSeconds;
      setState(() {});
    });
  }

  void _listenToVideo() {
    final session = ref.read(callSessionProvider)?.session;
    if (session == null) return;

    final videoOutput = session.videoOutput;
    if (videoOutput == null) return;

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
        _toggleControls();
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

  void _endCall() async {
    HapticFeedback.mediumImpact();
    final manager = ref.read(callSessionProvider);
    await manager?.end();
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute(CallSession session, CallSessionData data) {
    session.setMuted(!data.isMuted);
  }

  void _toggleSpeaker(CallSession session, CallSessionData data) {
    session.setSpeakerOn(!data.isSpeakerOn);
  }

  void _toggleCamera() {
    final session = ref.read(callSessionProvider)?.session;
    if (session == null) return;
    session.switchCamera();
  }

  void _showVerificationBottomSheet(BuildContext context, CallSessionData data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Код безопасности E2EE',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (data.verificationEmojis.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: data.verificationEmojis
                      .map((emoji) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 40),
                            ),
                          ))
                      .toList(),
                )
              else
                Text(
                  'Генерация кода...',
                  style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              const SizedBox(height: 12),
              Text(
                'Сравните эти эмодзи на обоих экранах звонка, чтобы убедиться в защите от постороннего вмешательства.',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = ref.watch(callSessionProvider)?.session;
    if (session == null) return const Scaffold(backgroundColor: Colors.black);

    final data = session.currentData;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final remoteFrame = ref.watch(remoteVideoFrameProvider);

    final participants = data.remoteParticipants;
    final participantLabel = participants.isNotEmpty
        ? participants.map((p) => p.nickname).join(', ')
        : 'Подключение...';

    // 1 participant (fullscreen + PiP) or multi-party (grid)
    final bool isMultiParty = participants.length >= 2;

    // Initialize PiP position to bottom right once screen size is known
    if (!_pipInitialized) {
      final size = MediaQuery.of(context).size;
      _pipX = size.width - CallTokens.videoPipWidth - 16;
      _pipY = size.height - CallTokens.videoPipHeight - 140;
      _pipInitialized = true;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // Main content (fullscreen remote video or Grid)
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isMultiParty
                        ? _buildMultiPartyGrid(participants, remoteFrame)
                        : _buildFullscreenFeed(context, remoteFrame, data),
                  ),
                ),
              ),

              // Local Camera preview PiP (Draggable)
              if (!isMultiParty)
                Positioned(
                  left: _pipX,
                  top: _pipY,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _pipX += details.delta.dx;
                        _pipY += details.delta.dy;
                      });
                    },
                    onVerticalDragEnd: (details) {
                      // Toggle camera on vertical swipe gesture on PiP
                      if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 200) {
                        _toggleCamera();
                      }
                    },
                    child: RepaintBoundary(
                      child: Container(
                        width: CallTokens.videoPipWidth,
                        height: CallTokens.videoPipHeight,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            _LocalCameraPreview(),
                            // Swipe line indicator
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 6,
                              child: Center(
                                child: Container(
                                  width: 24,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(1.5),
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

              // Overlay Information (visible by default, can be toggled)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      participantLabel,
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black.withValues(alpha: 0.85), blurRadius: 8)],
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _timerNotifier,
                      builder: (context, seconds, _) {
                        final m = seconds ~/ 60;
                        final s = seconds % 60;
                        return Text(
                          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                          style: textTheme.labelLarge?.copyWith(
                            fontFamily: 'monospace',
                            color: Colors.white.withValues(alpha: 0.8),
                            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.85), blurRadius: 8)],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Controls Layout (Tap to show/hide)
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _controlsFadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _controlsFadeAnimation.value,
                      child: IgnorePointer(
                        ignoring: _controlsFadeAnimation.value < 0.1,
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Minimize button
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.2),
                          minimumSize: const Size(CallTokens.controlButtonSize, CallTokens.controlButtonSize),
                        ),
                      ),
                      // Mute Button
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _toggleMute(session, data);
                        },
                        icon: Icon(
                          data.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: data.isMuted
                              ? scheme.error.withValues(alpha: 0.3)
                              : scheme.surfaceContainerLow.withValues(alpha: 0.2),
                          minimumSize: const Size(CallTokens.controlButtonSize, CallTokens.controlButtonSize),
                        ),
                      ),
                      // Hangup Button
                      IconButton(
                        onPressed: _endCall,
                        icon: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.error,
                          minimumSize: const Size(CallTokens.controlButtonSize, CallTokens.controlButtonSize),
                        ),
                      ),
                      // Camera Switch Button
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _toggleCamera();
                        },
                        icon: const Icon(
                          Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.2),
                          minimumSize: const Size(CallTokens.controlButtonSize, CallTokens.controlButtonSize),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenFeed(BuildContext context, Uint8List? remoteFrame, CallSessionData data) {
    if (remoteFrame == null || remoteFrame.isEmpty) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showVerificationBottomSheet(context, data),
      child: Image.memory(
        remoteFrame,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildMultiPartyGrid(List<dynamic> participants, Uint8List? remoteFrame) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: participants.length + 1,
        itemBuilder: (context, index) {
          if (index == participants.length) {
            // Local preview cell in grid
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black,
                child: _LocalCameraPreview(),
              ),
            );
          }

          // Remote participant cell
          if (remoteFrame == null || remoteFrame.isEmpty) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(Icons.person_rounded, size: 48, color: Colors.white54),
                ),
              ),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              remoteFrame,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
        },
      ),
    );
  }
}

class _LocalCameraPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(localVideoEnabledProvider);
    if (!isEnabled) {
      return const Center(
        child: Icon(
          Icons.videocam_off_rounded,
          color: Colors.white54,
          size: 32,
        ),
      );
    }
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Icon(
          Icons.videocam_rounded,
          color: Colors.white38,
          size: 36,
        ),
      ),
    );
  }
}
