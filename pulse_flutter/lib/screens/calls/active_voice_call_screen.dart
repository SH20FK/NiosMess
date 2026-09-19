import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/widgets/calls/call_audio_ripple.dart';
import 'package:pulse_flutter/widgets/calls/call_control_dock.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

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

  int _retryCount = 0;

  void _listenToState() {
    final session = ref.read(callSessionProvider)?.session;
    if (session == null) {
      if (_retryCount++ < 5) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _listenToState();
        });
      }
      return;
    }

    CallSessionState lastState = session.currentData.state;
    _timerNotifier.value = session.currentData.durationSeconds;
    _stateSubscription = session.stateStream.listen((CallSessionData data) {
      if (!mounted) return;
      if (data.state == CallSessionState.connected && lastState != CallSessionState.connected) {
        ref.read(appSoundProvider).playEvent(SoundEvent.callConnected);
      }
      lastState = data.state;
      if (data.state == CallSessionState.ended) {
        ref.read(appSoundProvider).playEvent(SoundEvent.callEnded);
        if (data.fatalError != null) {
          AppToast.showError(context, data.fatalError!);
        }
        _popOrGoHome();
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

  void _popOrGoHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      ref.read(appRouterProvider).go('/main/chats');
    }
  }

  Future<void> _endCall() async {
    HapticService.confirm();
    ref.read(appSoundProvider).playEvent(SoundEvent.callEnded);
    final manager = ref.read(callSessionProvider);
    await manager?.end();
    if (mounted) _popOrGoHome();
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
    final textTheme = Theme.of(context).textTheme;

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

    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: CallTokens.darkSurface,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F14),
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.28),
            radius: 1.15,
            colors: [
              callScheme.primary.withValues(alpha: 0.18),
              callScheme.tertiary.withValues(alpha: 0.07),
              const Color(0xFF0B0C10),
            ],
            stops: const [0.0, 0.50, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // ── Top Navigation & Status Bar ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: callScheme.onSurface,
                        size: 32,
                      ),
                      tooltip: context.l10n.callMinimize,
                      onPressed: () {
                        HapticService.tap();
                        _popOrGoHome();
                      },
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: callScheme.surfaceContainerHigh.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: callScheme.outlineVariant.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.lock_rounded,
                            size: 13,
                            color: callScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'E2EE ЗАЩИЩЕНО',
                            style: TextStyle(
                              color: callScheme.onSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Central Hero Stage ───────────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Avatar with animated breathing ripples
                        CallAudioRipple(
                          animation: _rippleController,
                          scheme: callScheme,
                          isActive: data.state == CallSessionState.inCall ||
                              data.state == CallSessionState.connecting ||
                              data.state == CallSessionState.connected,
                          size: 140,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: callScheme.primary.withValues(alpha: 0.35),
                                width: 2.5,
                              ),
                            ),
                            child: ClipOval(
                              child: PulseAvatar(
                                name: participantName,
                                avatarUrl: data.peerAvatarUrl,
                                radius: 70,
                                fallbackColor: callScheme.primaryContainer,
                                textColor: callScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Participant Name
                        Text(
                          participantName,
                          style: textTheme.headlineMedium?.copyWith(
                            color: callScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Username (if present)
                        if (data.peerUsername != null && data.peerUsername!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@${data.peerUsername}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: callScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Call Status Pill
                        ValueListenableBuilder<int>(
                          valueListenable: _timerNotifier,
                          builder: (context, seconds, _) {
                            if (data.state == CallSessionState.inCall) {
                              final int m = seconds ~/ 60;
                              final int s = seconds % 60;
                              final timerText =
                                  '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: callScheme.surfaceContainerHigh
                                      .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: callScheme.outlineVariant
                                        .withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.statusOnline,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      timerText,
                                      style: TextStyle(
                                        color: callScheme.onSurface,
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (data.state == CallSessionState.reconnecting) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: callScheme.errorContainer
                                      .withValues(alpha: 0.70),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: callScheme.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Переподключение...',
                                      style: TextStyle(
                                        color: callScheme.onErrorContainer,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: callScheme.surfaceContainerHigh
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: callScheme.outlineVariant
                                      .withValues(alpha: 0.22),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  AppLoadingIndicator(
                                    size: 14,
                                    color: callScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    data.direction == CallDirection.outgoing
                                        ? 'Звоним...'
                                        : context.l10n.callConnecting,
                                    style: TextStyle(
                                      color: callScheme.onSurfaceVariant,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Verification Emojis (if present)
                        if (data.verificationEmojis.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Tooltip(
                            message: 'Ключ сквозного шифрования (E2EE)',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: callScheme.surfaceContainerHigh
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: callScheme.outlineVariant
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user_rounded,
                                    size: 14,
                                    color: callScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  ...data.verificationEmojis.map(
                                    (String e) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: Text(
                                        e,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Listener Notice (if microphone unavailable)
                        if (data.isListener) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: callScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hearing_rounded,
                                    size: 14, color: callScheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  context.l10n.callListenerModeNotice,
                                  style: TextStyle(
                                    color: callScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom Control Dock ──────────────────────────────────
              CallControlDock(
                session: session,
                data: data,
                scheme: callScheme,
                onEnd: _endCall,
                onToggleVideo: () {
                  HapticService.tap();
                  session.toggleVideo();
                },
                onMinimize: () {
                  HapticService.tap();
                  _popOrGoHome();
                },
              ),
              SizedBox(height: bottomInset > 0 ? 0 : 8),
            ],
          ),
        ),
      ),
    );
  }
}

