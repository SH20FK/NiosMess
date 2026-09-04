import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
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
  ConsumerState<ActiveVoiceCallScreen> createState() => _ActiveVoiceCallScreenState();
}

class _ActiveVoiceCallScreenState extends ConsumerState<ActiveVoiceCallScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Breathing/ripple animation for avatar & soundwaves
  late final AnimationController _breathController;
  // Controls fade animation for bottom dock
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
      duration: CallTokens.rippleAnimationDuration,
    )..repeat();

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
    if (session == null) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(backgroundColor: scheme.surface);
    }

    final data = session.currentData;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final participants = data.remoteParticipants;
    final participantName = participants.isNotEmpty
        ? participants.map((p) => p.nickname).join(', ')
        : (data.peerName?.isNotEmpty == true
            ? data.peerName!
            : context.l10n.callsInProgress);
    const String? participantAvatar = null;

    // Dark tonal background for expressive calls
    final baseBg = Color.lerp(scheme.surfaceContainerLowest, scheme.surface, 0.4)!;
    final bgDark = HSLColor.fromColor(baseBg)
        .withLightness((HSLColor.fromColor(baseBg).lightness * 0.55).clamp(0.04, 0.2))
        .toColor();

    final tier = ref.watch(adaptivePerformanceProvider.select((s) => s.tier));
    final optimize = ref.watch(uiSettingsProvider.select((s) => s.optimizeForWeakDevices));

    return Scaffold(
      backgroundColor: bgDark,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Animated Tonal Mesh Background ──────────────────────────
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _breathController,
                  builder: (context, _) {
                    final t = _breathController.value;
                    return CustomPaint(
                      painter: _TonalBlobPainter(
                        t: t,
                        primary: scheme.primary.withValues(alpha: 0.18),
                        tertiary: scheme.tertiary.withValues(alpha: 0.14),
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
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurface.withValues(alpha: 0.8),
                      size: 32,
                    ),
                    tooltip: context.l10n.callMinimize,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.onSurface.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 13,
                          color: scheme.tertiary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'E2EE PROTECTED',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // Balancing spacer
                ],
              ),
            ),

            // ── Strictly Centered Content ────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Status Badge with icon
                    _StatusPill(
                      state: data.state,
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 20),

                    // Centered M3 Shape Hero Avatar with Audio Ripple
                    CallAudioRipple(
                      animation: _breathController,
                      scheme: scheme,
                      isActive: data.state == CallSessionState.inCall && !data.isMuted,
                      size: CallTokens.avatarLargeSize,
                      child: ClipPath(
                        clipper: M3Clipper(Shapes.c9_sided_cookie),
                        child: Container(
                          width: CallTokens.avatarLargeSize,
                          height: CallTokens.avatarLargeSize,
                          color: scheme.primaryContainer,
                          child: PulseAvatar(
                            name: participantName,
                            avatarUrl: participantAvatar,
                            radius: CallTokens.avatarLargeSize / 2,
                            fallbackColor: scheme.primaryContainer,
                            textColor: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Participant Name
                    Text(
                      participantName,
                      style: textTheme.headlineMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Monospace Timer
                    ValueListenableBuilder<int>(
                      valueListenable: _timerNotifier,
                      builder: (context, seconds, _) {
                        if (data.state != CallSessionState.inCall) {
                          return const SizedBox(height: 28);
                        }
                        final m = seconds ~/ 60;
                        final s = seconds % 60;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                            style: textTheme.titleMedium?.copyWith(
                              fontFamily: 'monospace',
                              color: scheme.onSurface.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                        );
                      },
                    ),

                    // E2EE verification emojis row
                    if (data.verificationEmojis.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _VerificationRow(
                        emojis: data.verificationEmojis,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                    ],

                    const Spacer(flex: 3),
                  ],
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
                  onEnd: _endCall,
                  onMinimize: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Pill Badge ─────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.state,
    required this.scheme,
    required this.textTheme,
  });

  final CallSessionState state;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (state) {
      CallSessionState.connecting || CallSessionState.connected => (
          context.l10n.callConnecting,
          Icons.sync_rounded,
          scheme.primary,
        ),
      CallSessionState.inCall => (
          context.l10n.callStatusInCall,
          Icons.phone_in_talk_rounded,
          scheme.tertiary,
        ),
      CallSessionState.reconnecting => (
          'RECONNECTING...',
          Icons.cloud_sync_rounded,
          scheme.error,
        ),
      _ => ('', Icons.phone_rounded, scheme.onSurface),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
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
            color: scheme.surface.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: emojis
                .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.callE2eeSecurityCode,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.45),
            fontSize: 11,
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
    final cx = size.width / 2;
    final cy = size.height / 2;

    final b1x = cx - 70 + 40 * sin(t * 2 * pi);
    final b1y = cy * 0.65 + 30 * cos(t * 2 * pi);

    final b2x = cx + 60 + 35 * cos(t * 2 * pi);
    final b2y = cy * 1.35 + 25 * sin(t * 2 * pi);

    if (tier == PerformanceTier.tierC || optimizeForWeakDevices) {
      // Fast tonal radial gradient fill — zero blur passes
      final paint1 = Paint()
        ..shader = RadialGradient(
          colors: [primary, primary.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(b1x, b1y), radius: 170));
      canvas.drawCircle(Offset(b1x, b1y), 170, paint1);

      final paint2 = Paint()
        ..shader = RadialGradient(
          colors: [tertiary, tertiary.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(b2x, b2y), radius: 150));
      canvas.drawCircle(Offset(b2x, b2y), 150, paint2);
      return;
    }

    final double blur1 = (tier == PerformanceTier.tierA) ? 80.0 : 24.0;
    final double blur2 = (tier == PerformanceTier.tierA) ? 90.0 : 28.0;

    // Blob 1 — upper floating glow
    final paint1 = Paint()
      ..color = primary
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur1);
    canvas.drawCircle(Offset(b1x, b1y), 170, paint1);

    // Blob 2 — lower floating glow
    final paint2 = Paint()
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
