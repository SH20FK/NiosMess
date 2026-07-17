import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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

  // Smooth breathing animation controller — replaces random visualizer.
  // Two slow sine waves with slightly different periods create a natural
  // "voice activity" feel without fake randomness.
  late final AnimationController _breathController;

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

    // Smooth breathing animation: 3.5 s loop, repeats forever.
    // The UI reads _breathController.value and derives scale/rotation via sin()
    // — no randomness, no Timers, no dropped frames.
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

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
    _breathController.dispose();
    _controlsAutoHideTimer?.cancel();
    _stateSubscription?.cancel();
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
        : context.l10n.callConnecting;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // Generative MD3 shapes background — smooth breathing animation.
              // Two ellipses pulsate via sin() at slightly different phases.
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _breathController,
                    builder: (context, _) {
                      final t = _breathController.value * 2 * pi;
                      final scale1 = 1.0 + 0.08 * sin(t);
                      final scale2 = 1.0 + 0.06 * sin(t + pi * 0.6);
                      final rotation = 0.12 * sin(t * 0.7);

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: rotation,
                            child: Transform.scale(
                              scale: scale1,
                              child: Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.12),
                                  borderRadius: const BorderRadius.all(
                                    Radius.elliptical(120, 160),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: -rotation * 0.8,
                            child: Transform.scale(
                              scale: scale2 * 0.9,
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  color: scheme.tertiary.withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.all(
                                    Radius.elliptical(160, 100),
                                  ),
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
                              context.l10n.callE2eeSecurityCode,
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
