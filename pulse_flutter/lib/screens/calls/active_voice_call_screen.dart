import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
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
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  StreamSubscription<CallSessionData>? _stateSubscription;
  late final AnimationController _rippleController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
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
    _rippleController.dispose();
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
    final ColorScheme appScheme = Theme.of(context).colorScheme;
    final ColorScheme callScheme = ColorScheme.fromSeed(
      seedColor: appScheme.primary,
      brightness: Brightness.dark,
    );

    if (session == null) {
      return const Scaffold(backgroundColor: CallTokens.darkSurface);
    }

    final CallSessionData data = session.currentData;
    final participants = data.remoteParticipants;
    final String participantName = participants.isNotEmpty
        ? participants.map((p) => p.nickname).join(', ')
        : (data.peerName?.isNotEmpty == true
            ? data.peerName!
            : context.l10n.callsInProgress);

    return Scaffold(
      backgroundColor: CallTokens.meetSurface,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // ── Meet Top Bar ───────────────────────────────────────────
            Positioned(
              top: MediaQuery.paddingOf(context).top + 6,
              left: 12,
              right: 12,
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    tooltip: context.l10n.callMinimize,
                    onPressed: () {
                      HapticService.tap();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          participantName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        ValueListenableBuilder<int>(
                          valueListenable: _timerNotifier,
                          builder: (context, seconds, _) {
                            if (data.state == CallSessionState.inCall) {
                              final int m = seconds ~/ 60;
                              final int s = seconds % 60;
                              final timerText =
                                  '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    timerText,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Text(
                              data.state == CallSessionState.reconnecting
                                  ? 'Переподключение...'
                                  : context.l10n.callConnecting,
                              style: TextStyle(
                                color: data.state == CallSessionState.reconnecting
                                    ? callScheme.error
                                    : Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: CallTokens.meetTileBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: Color(0xFF8AB4F8),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'E2EE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Google Meet Participant Squircle Tile ──────────────────
            Positioned.fill(
              top: MediaQuery.paddingOf(context).top + 64,
              bottom: MediaQuery.paddingOf(context).bottom + 106,
              left: 14,
              right: 14,
              child: Container(
                decoration: BoxDecoration(
                  color: CallTokens.meetTileBackground,
                  borderRadius:
                      BorderRadius.circular(CallTokens.meetTileBorderRadius),
                  border: Border.all(
                    color: data.state == CallSessionState.inCall
                        ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    CallTokens.meetTileBorderRadius - 1.5,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      // Centered Avatar with Audio Ripple
                      Center(
                        child: CallAudioRipple(
                          animation: _rippleController,
                          scheme: callScheme,
                          isActive: data.state == CallSessionState.inCall ||
                              data.state == CallSessionState.connecting ||
                              data.state == CallSessionState.connected,
                          size: CallTokens.avatarLargeSize,
                          child: Container(
                            width: CallTokens.avatarLargeSize,
                            height: CallTokens.avatarLargeSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 24,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: PulseAvatar(
                                name: participantName,
                                avatarUrl: null,
                                radius: CallTokens.avatarLargeSize / 2,
                                fallbackColor: callScheme.primaryContainer,
                                textColor: callScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Verification Emojis in Tile Top-Right (if present)
                      if (data.verificationEmojis.isNotEmpty)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: CallTokens.meetChipBackground,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: data.verificationEmojis
                                  .map((String e) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: Text(
                                          e,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),

                      // Bottom-Left Meet Participant Chip (Name & Mic Pill)
                      Positioned(
                        left: 14,
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: CallTokens.meetChipBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  participantName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                data.isMuted
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded,
                                color: data.isMuted
                                    ? const Color(0xFFFFB4AB)
                                    : Colors.white,
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Google Meet Bottom Control Dock ────────────────────────
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
                  HapticService.tap();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

