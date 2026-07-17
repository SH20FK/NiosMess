import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';

class ActiveVoiceCallScreen extends ConsumerStatefulWidget {
  const ActiveVoiceCallScreen({super.key});

  @override
  ConsumerState<ActiveVoiceCallScreen> createState() => _ActiveVoiceCallScreenState();
}

class _ActiveVoiceCallScreenState extends ConsumerState<ActiveVoiceCallScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controlsFadeController;
  late final Animation<double> _controlsFadeAnimation;
  bool _areControlsVisible = true;
  Timer? _controlsAutoHideTimer;

  // Visualizer volume notifier (tied to animated gradients)
  final ValueNotifier<double> _volumeNotifier = ValueNotifier<double>(0.0);
  Timer? _visualizerTimer;
  final Random _random = Random();

  // Timer ValueNotifier
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

    // Initial state: controls are visible, start autohide timer
    _controlsFadeController.value = 1.0;
    _resetControlsTimer();

    // Visualizer runs at <=15 FPS (Frame duration 66ms)
    _visualizerTimer = Timer.periodic(CallTokens.visualizerFrameDuration, (_) {
      // Simulate volume changes when call is active
      final session = ref.read(callSessionProvider)?.session;
      if (session != null && session.currentData.state == CallSessionState.inCall) {
        _volumeNotifier.value = _random.nextDouble();
      } else {
        _volumeNotifier.value = 0.0;
      }
    });

    _listenToState();
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
      // Triggers rebuild when remote participants or emojis change
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controlsFadeController.dispose();
    _controlsAutoHideTimer?.cancel();
    _visualizerTimer?.cancel();
    _stateSubscription?.cancel();
    _volumeNotifier.dispose();
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = ref.watch(callSessionProvider)?.session;
    if (session == null) return const Scaffold(backgroundColor: Colors.black);

    final data = session.currentData;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final participants = data.remoteParticipants;
    final participantLabel = participants.isNotEmpty
        ? participants.map((p) => p.nickname).join(', ')
        : 'Подключение...';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // Generative visualizer background (radial gradients)
              Positioned.fill(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _volumeNotifier,
                    builder: (context, volume, _) {
                      final dx1 = sin(volume * pi) * 30;
                      final dy1 = cos(volume * pi) * 30;
                      final dx2 = cos(volume * pi * 0.5) * 40;
                      final dy2 = sin(volume * pi * 0.5) * 40;

                      return Stack(
                        children: [
                          Transform.translate(
                            offset: Offset(dx1, dy1),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    scheme.primary.withValues(alpha: 0.15),
                                    Colors.transparent,
                                  ],
                                  center: Alignment.centerLeft,
                                  radius: 1.2,
                                ),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(dx2, dy2),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    scheme.tertiary.withValues(alpha: 0.15),
                                    Colors.transparent,
                                  ],
                                  center: Alignment.centerRight,
                                  radius: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Main active call content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulse Ring around Avatar if speaking, opacity reduced + lock icon if muted
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: data.isMuted ? 0.4 : 1.0,
                          child: Container(
                            width: CallTokens.avatarLargeSize,
                            height: CallTokens.avatarLargeSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.surfaceContainerLow,
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 48,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (data.isMuted)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mic_off_rounded,
                                size: 16,
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      participantLabel,
                      style: textTheme.headlineSmall?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Verification code (always visible under name)
                    if (data.verificationEmojis.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: data.verificationEmojis
                                  .map((emoji) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Код безопасности',
                              style: textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Monospace Timer via ValueListenableBuilder
                    ValueListenableBuilder<int>(
                      valueListenable: _timerNotifier,
                      builder: (context, seconds, _) {
                        final m = seconds ~/ 60;
                        final s = seconds % 60;
                        final timeString =
                            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
                        return Text(
                          timeString,
                          style: textTheme.labelLarge?.copyWith(
                            fontFamily: 'monospace',
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Controls layout (Tap to fade in/out)
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
                      // Mute button
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
                      // Hangup button
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
                      // Speaker button
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _toggleSpeaker(session, data);
                        },
                        icon: Icon(
                          data.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: data.isSpeakerOn
                              ? scheme.primary.withValues(alpha: 0.3)
                              : scheme.surfaceContainerLow.withValues(alpha: 0.2),
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
}
