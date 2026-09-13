import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/widgets/calls/call_audio_ripple.dart';
import 'package:pulse_flutter/widgets/calls/call_control_dock.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

class ActiveVoiceCallScreen extends ConsumerStatefulWidget {
  const ActiveVoiceCallScreen({super.key});

  @override
  ConsumerState<ActiveVoiceCallScreen> createState() =>
      _ActiveVoiceCallScreenState();
}

class _ActiveVoiceCallScreenState extends ConsumerState<ActiveVoiceCallScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _breathController;
  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  StreamSubscription<CallSessionData>? _stateSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      vsync: this,
      duration: CallTokens.rippleAnimationDuration,
    )..repeat();

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
    _stateSubscription = session.stateStream.listen((CallSessionData data) {
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
    _stateSubscription?.cancel();
    _timerNotifier.dispose();
    super.dispose();
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

    final CallSessionData data = session.currentData;
    final ColorScheme appScheme = Theme.of(context).colorScheme;

    // Enforce dedicated high-contrast dark tonal scheme for immersive calls
    final ColorScheme callScheme = ColorScheme.fromSeed(
      seedColor: appScheme.primary,
      brightness: Brightness.dark,
    );

    final participants = data.remoteParticipants;
    final String participantName = participants.isNotEmpty
        ? participants.map((p) => p.nickname).join(', ')
        : (data.peerName?.isNotEmpty == true
            ? data.peerName!
            : context.l10n.callsInProgress);

    final tier =
        ref.watch(adaptivePerformanceProvider.select((s) => s.tier));
    final optimize = ref.watch(
        uiSettingsProvider.select((s) => s.optimizeForWeakDevices));

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B14),
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // ── Ambient Background Gradient ───────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFF141022),
                    Color(0xFF0D0B14),
                    Color(0xFF0A0810),
                  ],
                ),
              ),
            ),
          ),

          // ── Animated Ambient Breathing Blobs ─────────────────────────
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _breathController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _TonalBlobPainter(
                      t: _breathController.value,
                      primary: callScheme.primary.withValues(alpha: 0.18),
                      tertiary: callScheme.tertiary.withValues(alpha: 0.14),
                      tier: tier,
                      optimizeForWeakDevices: optimize,
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Top Bar (Minimize & E2EE Info) ───────────────────────────
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 32,
                  ),
                  tooltip: context.l10n.callMinimize,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: Color(0xFF22C55E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'E2EE ЗАЩИЩЕНО',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48), // Balance for back button
              ],
            ),
          ),

          // ── Center Content: Avatar, Name, Status, Timer ──────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const Spacer(flex: 3),

                  // Call Status Pill
                  _StatusPill(
                    state: data.state,
                    scheme: callScheme,
                  ),
                  const SizedBox(height: 24),

                  // Centered Avatar with Breathing Audio Ripple
                  CallAudioRipple(
                    animation: _breathController,
                    scheme: callScheme,
                    isActive: data.state == CallSessionState.inCall &&
                        !data.isMuted,
                    size: 136,
                    child: Container(
                      width: 136,
                      height: 136,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: callScheme.primary.withValues(alpha: 0.35),
                          width: 2.5,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: callScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: PulseAvatar(
                          name: participantName,
                          avatarUrl: null,
                          radius: 68,
                          fallbackColor: callScheme.primaryContainer,
                          textColor: callScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Participant Name (Crisp White Typography)
                  Text(
                    participantName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Monospace Call Duration Timer
                  ValueListenableBuilder<int>(
                    valueListenable: _timerNotifier,
                    builder: (context, seconds, _) {
                      if (data.state != CallSessionState.inCall) {
                        return const SizedBox(height: 32);
                      }
                      final int m = seconds ~/ 60;
                      final int s = seconds % 60;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white.withValues(alpha: 0.90),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                      );
                    },
                  ),

                  // E2EE verification emojis row
                  if (data.verificationEmojis.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    _VerificationRow(
                      emojis: data.verificationEmojis,
                      scheme: callScheme,
                    ),
                  ],

                  const Spacer(flex: 4),
                  const SizedBox(height: 90), // Space for bottom dock
                ],
              ),
            ),
          ),

          // ── Permanently Visible Bottom Control Dock ────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CallControlDock(
              session: session,
              data: data,
              scheme: callScheme,
              onEnd: _endCall,
              onMinimize: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Pill Badge ─────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.state,
    required this.scheme,
  });

  final CallSessionState state;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (state) {
      CallSessionState.connecting || CallSessionState.connected => (
          context.l10n.callConnecting,
          Icons.sync_rounded,
          const Color(0xFF60A5FA), // Crisp Sky Blue
        ),
      CallSessionState.inCall => (
          context.l10n.callStatusInCall,
          Icons.phone_in_talk_rounded,
          const Color(0xFF22C55E), // Crisp Emerald Green
        ),
      CallSessionState.reconnecting => (
          'ПЕРЕПОДКЛЮЧЕНИЕ...',
          Icons.cloud_sync_rounded,
          const Color(0xFFF87171),
        ),
      _ => ('', Icons.phone_rounded, Colors.white),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Verification Row (E2EE) ──────────────────────────────────────────────────

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({
    required this.emojis,
    required this.scheme,
  });

  final List<String> emojis;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: emojis
                .map((String e) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.callE2eeSecurityCode,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Tonal Blob Background Painter ────────────────────────────────────────────

class _TonalBlobPainter extends CustomPainter {
  _TonalBlobPainter({
    required this.t,
    required this.primary,
    required this.tertiary,
    this.tier = PerformanceTier.tierB,
    this.optimizeForWeakDevices = false,
  });

  final double t;
  final Color primary;
  final Color tertiary;
  final PerformanceTier tier;
  final bool optimizeForWeakDevices;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final double b1x = cx - 70 + 40 * sin(t * 2 * pi);
    final double b1y = cy * 0.65 + 30 * cos(t * 2 * pi);

    final double b2x = cx + 60 + 35 * cos(t * 2 * pi);
    final double b2y = cy * 1.35 + 25 * sin(t * 2 * pi);

    if (tier == PerformanceTier.tierC || optimizeForWeakDevices) {
      final paint1 = Paint()
        ..shader = RadialGradient(
          colors: <Color>[primary, primary.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(b1x, b1y), radius: 170));
      canvas.drawCircle(Offset(b1x, b1y), 170, paint1);

      final paint2 = Paint()
        ..shader = RadialGradient(
          colors: <Color>[tertiary, tertiary.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(b2x, b2y), radius: 150));
      canvas.drawCircle(Offset(b2x, b2y), 150, paint2);
      return;
    }

    final double blur1 = (tier == PerformanceTier.tierA) ? 80.0 : 28.0;
    final double blur2 = (tier == PerformanceTier.tierA) ? 90.0 : 32.0;

    final Paint paint1 = Paint()
      ..color = primary
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur1);
    canvas.drawCircle(Offset(b1x, b1y), 170, paint1);

    final Paint paint2 = Paint()
      ..color = tertiary
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur2);
    canvas.drawCircle(Offset(b2x, b2y), 150, paint2);
  }

  @override
  bool shouldRepaint(_TonalBlobPainter old) =>
      old.t != t ||
      old.primary != primary ||
      old.tertiary != tertiary ||
      old.tier != tier ||
      old.optimizeForWeakDevices != optimizeForWeakDevices;
}
