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

  // Breathing ring around avatar
  late final AnimationController _breathController;
  // Controls fade for bottom bar
  late final AnimationController _controlsFadeController;
  late final Animation<double> _controlsFadeAnimation;
  bool _areControlsVisible = true;
  Timer? _controlsAutoHideTimer;

  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  StreamSubscription<CallSessionData>? _stateSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

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

    WidgetsBinding.instance.addPostFrameCallback((_) => _listenToState());
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

  @override
  void dispose() {
    _breathController.dispose();
    _controlsFadeController.dispose();
    _controlsAutoHideTimer?.cancel();
    _stateSubscription?.cancel();
    _timerNotifier.dispose();
    super.dispose();
  }

  void _resetControlsTimer() {
    _controlsAutoHideTimer?.cancel();
    _controlsAutoHideTimer = Timer(CallTokens.controlsAutoHideDuration, () {
      if (mounted && _areControlsVisible) _hideControls();
    });
  }

  void _showControls() {
    if (!_areControlsVisible) {
      setState(() => _areControlsVisible = true);
      _controlsFadeController.forward();
    }
    _resetControlsTimer();
  }

  void _hideControls() {
    setState(() => _areControlsVisible = false);
    _controlsFadeController.reverse();
  }

  void _toggleControls() {
    if (_areControlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
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

    final participants = data.remoteParticipants;
    final participantName = participants.isNotEmpty
        ? participants.map((p) => p.nickname).join(', ')
        : context.l10n.callConnecting;

    // Tonal background: primary + tertiary blended
    final bgColor = Color.lerp(scheme.primaryContainer, scheme.tertiaryContainer, 0.45)!
        .withValues(alpha: 1.0);
    // Darken for a deeper feel
    final bgDark = HSLColor.fromColor(bgColor)
        .withLightness((HSLColor.fromColor(bgColor).lightness * 0.45).clamp(0.0, 1.0))
        .toColor();

    return Scaffold(
      backgroundColor: bgDark,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ── Animated tonal mesh background ──────────────────────────
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _breathController,
                  builder: (context, _) {
                    final t = _breathController.value;
                    return CustomPaint(
                      painter: _TonalBlobPainter(
                        t: t,
                        primary: scheme.primary.withValues(alpha: 0.25),
                        tertiary: scheme.tertiary.withValues(alpha: 0.18),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Center content ───────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Status label (connecting / in call)
                  Text(
                    _statusLabel(data.state, context),
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Avatar with breathing ring
                  _BreathingAvatar(
                    controller: _breathController,
                    isMuted: data.isMuted,
                    scheme: scheme,
                    inCall: data.state == CallSessionState.inCall,
                  ),
                  const SizedBox(height: 28),

                  // Participant name
                  Text(
                    participantName,
                    style: textTheme.headlineMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Timer
                  ValueListenableBuilder<int>(
                    valueListenable: _timerNotifier,
                    builder: (context, seconds, _) {
                      if (data.state != CallSessionState.inCall) {
                        return const SizedBox.shrink();
                      }
                      final m = seconds ~/ 60;
                      final s = seconds % 60;
                      return Text(
                        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                        style: textTheme.titleLarge?.copyWith(
                          fontFamily: 'monospace',
                          color: scheme.onPrimary.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w400,
                        ),
                      );
                    },
                  ),

                  // E2EE verification emojis
                  if (data.verificationEmojis.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _VerificationRow(emojis: data.verificationEmojis, scheme: scheme, textTheme: textTheme),
                  ],

                  const Spacer(flex: 3),
                ],
              ),
            ),

            // ── Bottom control bar ────────────────────────────────────────
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
                child: _VoiceControlBar(
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

  String _statusLabel(CallSessionState state, BuildContext ctx) {
    return switch (state) {
      CallSessionState.connecting || CallSessionState.connected => ctx.l10n.callConnecting.toUpperCase(),
      CallSessionState.inCall => ctx.l10n.callStatusInCall.toUpperCase(),
      CallSessionState.reconnecting => 'RECONNECTING...',
      _ => '',
    };
  }
}

// ── Breathing avatar ──────────────────────────────────────────────────────────

class _BreathingAvatar extends StatelessWidget {
  const _BreathingAvatar({
    required this.controller,
    required this.isMuted,
    required this.scheme,
    required this.inCall,
  });

  final AnimationController controller;
  final bool isMuted;
  final ColorScheme scheme;
  final bool inCall;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final ringScale = 1.0 + 0.12 * t;
        final ringOpacity = (0.35 * (1.0 - t)).clamp(0.0, 1.0);

        return SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring (only while in call)
              if (inCall && !isMuted)
                Transform.scale(
                  scale: ringScale,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.onPrimary.withValues(alpha: ringOpacity),
                        width: 2,
                      ),
                    ),
                  ),
                ),

              // Avatar circle
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  border: Border.all(
                    color: scheme.onPrimary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isMuted ? Icons.mic_off_rounded : Icons.person_rounded,
                  size: 48,
                  color: scheme.onPrimary.withValues(alpha: isMuted ? 0.5 : 0.9),
                ),
              ),

              // Muted badge
              if (isMuted)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mic_off_rounded, size: 14, color: scheme.onError),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Verification row ──────────────────────────────────────────────────────────

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({
    required this.emojis,
    required this.scheme,
    required this.textTheme,
  });

  final List<String> emojis;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.onPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: emojis
                .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.callE2eeSecurityCode,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onPrimary.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

// ── Bottom control bar ────────────────────────────────────────────────────────

class _VoiceControlBar extends StatelessWidget {
  const _VoiceControlBar({
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
    final surfaceColor = scheme.surface.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute
              _ControlButton(
                icon: data.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: data.isMuted ? context.l10n.callUnmute : context.l10n.callMute,
                active: data.isMuted,
                activeColor: scheme.error,
                baseColor: surfaceColor,
                iconColor: scheme.onSurface,
                onTap: () {
                  HapticFeedback.lightImpact();
                  session.setMuted(!data.isMuted);
                },
              ),

              // End call (larger)
              _EndCallButton(onTap: onEnd, scheme: scheme),

              // Speaker
              _ControlButton(
                icon: data.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                label: data.isSpeakerOn ? context.l10n.callSpeakerOff : context.l10n.callSpeakerOn,
                active: data.isSpeakerOn,
                activeColor: scheme.tertiary,
                baseColor: surfaceColor,
                iconColor: scheme.onSurface,
                onTap: () {
                  HapticFeedback.lightImpact();
                  session.setSpeakerOn(!data.isSpeakerOn);
                },
              ),
            ],
          ),

          // Minimize hint
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Text(
              context.l10n.callMinimize,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.baseColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final Color baseColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: active ? activeColor.withValues(alpha: 0.25) : baseColor,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: active
                    ? Border.all(color: activeColor.withValues(alpha: 0.6), width: 1.5)
                    : null,
              ),
              child: Icon(icon, color: active ? activeColor : iconColor, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: active ? activeColor : iconColor.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.onTap, required this.scheme});

  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: scheme.error,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: const SizedBox(
              width: 72,
              height: 72,
              child: Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.callEnd,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.error,
          ),
        ),
      ],
    );
  }
}

// ── Tonal blob background painter ────────────────────────────────────────────

class _TonalBlobPainter extends CustomPainter {
  _TonalBlobPainter({
    required this.t,
    required this.primary,
    required this.tertiary,
  });

  final double t;
  final Color primary;
  final Color tertiary;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Blob 1 — upper left area
    final paint1 = Paint()
      ..color = primary
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
    final b1x = cx - 80 + 40 * sin(t * pi);
    final b1y = cy * 0.55 + 30 * sin(t * pi * 0.7);
    canvas.drawCircle(Offset(b1x, b1y), 160, paint1);

    // Blob 2 — lower right area
    final paint2 = Paint()
      ..color = tertiary
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    final b2x = cx + 70 + 30 * sin(t * pi * 1.3);
    final b2y = cy * 1.45 + 20 * sin(t * pi);
    canvas.drawCircle(Offset(b2x, b2y), 140, paint2);
  }

  @override
  bool shouldRepaint(_TonalBlobPainter old) =>
      old.t != t || old.primary != primary || old.tertiary != tertiary;
}
