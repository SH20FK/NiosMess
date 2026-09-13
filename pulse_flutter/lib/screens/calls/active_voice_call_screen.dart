import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/widgets/calls/call_control_dock.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

class ActiveVoiceCallScreen extends ConsumerStatefulWidget {
  const ActiveVoiceCallScreen({super.key});

  @override
  ConsumerState<ActiveVoiceCallScreen> createState() =>
      _ActiveVoiceCallScreenState();
}

class _ActiveVoiceCallScreenState extends ConsumerState<ActiveVoiceCallScreen>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  StreamSubscription<CallSessionData>? _stateSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
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
    _stateSubscription?.cancel();
    _timerNotifier.dispose();
    super.dispose();
  }

  Future<void> _endCall() async {
    HapticService.tap();
    final manager = ref.read(callSessionProvider);
    await manager?.end();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = ref.watch(callSessionProvider)?.session;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    if (session == null) {
      return Scaffold(backgroundColor: scheme.surfaceContainerLowest);
    }

    final CallSessionData data = session.currentData;
    final participants = data.remoteParticipants;
    final String participantName = participants.isNotEmpty
        ? participants.map((p) => p.nickname).join(', ')
        : (data.peerName?.isNotEmpty == true
            ? data.peerName!
            : context.l10n.callsInProgress);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // ── Adaptive M3 Surface Background ───────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    scheme.surfaceContainerLowest,
                    scheme.surfaceContainerLow,
                    scheme.surface,
                  ],
                ),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'E2EE ЗАЩИЩЕНО',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48), // Balance for minimize button
              ],
            ),
          ),

          // ── Center Content: Status, Avatar, Name, Timer ──────────────
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
                    scheme: scheme,
                  ),
                  const SizedBox(height: 28),

                  // Minimalist M3 Avatar
                  Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.35),
                        width: 3.0,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: PulseAvatar(
                        name: participantName,
                        avatarUrl: null,
                        radius: 68,
                        fallbackColor: scheme.primaryContainer,
                        textColor: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Participant Name
                  Text(
                    participantName,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Monospace Call Duration Timer
                  ValueListenableBuilder<int>(
                    valueListenable: _timerNotifier,
                    builder: (context, seconds, _) {
                      if (data.state != CallSessionState.inCall) {
                        return const SizedBox(height: 36);
                      }
                      final int m = seconds ~/ 60;
                      final int s = seconds % 60;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                          style: textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                            color: scheme.onSurface,
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
                      scheme: scheme,
                    ),
                  ],

                  const Spacer(flex: 4),
                  const SizedBox(height: 90), // Space for bottom dock
                ],
              ),
            ),
          ),

          // ── Permanently Visible Bottom M3 Pill Dock ────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CallControlDock(
              session: session,
              data: data,
              scheme: scheme,
              onEnd: _endCall,
              onMinimize: () {
                HapticService.tap();
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
    final (label, icon, fg, bg) = switch (state) {
      CallSessionState.connecting || CallSessionState.connected => (
          context.l10n.callConnecting,
          Icons.sync_rounded,
          scheme.primary,
          scheme.primaryContainer.withValues(alpha: 0.6),
        ),
      CallSessionState.inCall => (
          context.l10n.callStatusInCall,
          Icons.phone_in_talk_rounded,
          const Color(0xFF16A34A),
          const Color(0xFF16A34A).withValues(alpha: 0.12),
        ),
      CallSessionState.reconnecting => (
          'ПЕРЕПОДКЛЮЧЕНИЕ...',
          Icons.cloud_sync_rounded,
          scheme.error,
          scheme.errorContainer,
        ),
      _ => ('', Icons.phone_rounded, scheme.onSurface, scheme.surfaceContainer),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: fg.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
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
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
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
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
