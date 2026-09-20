import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/services/calls/call_starter.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

/// Material 3 Expressive heads-up incoming call overlay banner.
class IncomingCallOverlay extends ConsumerStatefulWidget {
  const IncomingCallOverlay({super.key});

  @override
  ConsumerState<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  // Pulsing animated tonal ring around avatar
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  IncomingCallData? _lastIncoming;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: CallTokens.incomingOverlayAnimationDuration,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: CallTokens.incomingOverlayCurve,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseScale = Tween<double>(begin: 1.0, end: 1.45).animate(
      CurvedAnimation(parent: _pulseController, curve: M3SpringCurves.gentle),
    );
    _pulseOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    ref.read(appSoundProvider).stopLoop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incoming = ref.watch(incomingCallProvider);

    if (incoming != null && _lastIncoming == null) {
      _lastIncoming = incoming;
      _slideController.forward();
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
      Future.microtask(() {
        HapticService.notification();
        ref.read(appSoundProvider).startLoop(SoundEvent.callIncoming);
      });
    } else if (incoming == null && _lastIncoming != null) {
      ref.read(appSoundProvider).stopLoop();
      _slideController.reverse().then((_) {
        if (mounted) setState(() => _lastIncoming = null);
      });
    }

    final data = _lastIncoming;
    if (data == null) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final safeTop = MediaQuery.paddingOf(context).top;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: safeTop + 10, left: 16, right: 16),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(CallTokens.cardBorderRadius),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v > 120) _acceptCall(context, ref, data);
                  if (v < -120) _declineCall(data);
                },
                child: Row(
                  children: [
                    // Pulsing Icon in M3 Shape
                    _PulsingCallIcon(
                      isVideo: data.isVideo,
                      pulseScale: _pulseScale,
                      pulseOpacity: _pulseOpacity,
                      scheme: scheme,
                    ),
                    const SizedBox(width: 14),

                    // Name + Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data.initiatorName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.isVideo
                                ? context.l10n.callIncomingVideo
                                : context.l10n.callIncomingVoice,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Decline Button (M3 ErrorContainer)
                    TouchContainer(
                      scaleDown: 0.90,
                      onTap: () => _declineCall(data),
                      child: Container(
                        width: CallTokens.incomingButtonSize,
                        height: CallTokens.incomingButtonSize,
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.call_end_rounded,
                            color: scheme.onErrorContainer,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Accept Button (M3 Primary)
                    TouchContainer(
                      scaleDown: 0.90,
                      onTap: () => _acceptCall(context, ref, data),
                      child: Container(
                        width: CallTokens.incomingButtonSize,
                        height: CallTokens.incomingButtonSize,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            data.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                            color: scheme.onPrimary,
                            size: 24,
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
      ),
    );
  }

  void _declineCall(IncomingCallData incoming) {
    HapticService.tap();
    ref.read(incomingCallProvider.notifier).set(null);
    unawaited(PushNotificationService.cancelCallNotification());
    unawaited(
      ref.read(callRepositoryProvider).decline(
        chatId: incoming.chatId,
        roomId: incoming.roomId,
        messageId: incoming.callId,
      ).catchError((Object e) {
        debugPrint('[IncomingCallOverlay] decline signal failed: $e');
      }),
    );
  }

  Future<void> _acceptCall(BuildContext context, WidgetRef ref, IncomingCallData incoming) async {
    HapticService.confirm();
    ref.read(incomingCallProvider.notifier).set(null);
    unawaited(PushNotificationService.cancelCallNotification());

    final isAlreadyInCall = ref.read(callSessionProvider) != null;
    if (isAlreadyInCall) {
      if (context.mounted) {
        AppToast.showError(context, 'Уже идет другой звонок');
      }
      return;
    }

    try {
      await startIncomingCall(
        ref: ref,
        chatId: incoming.chatId,
        callId: incoming.callId,
        roomId: incoming.roomId,
        isVideo: incoming.isVideo,
        peerName: incoming.initiatorName,
      );

      ref.read(appRouterProvider).push('/call/${incoming.callId}');
    } on CallStartException catch (e) {
      if (context.mounted) {
        AppToast.showError(
          context,
          e.failure == CallStartFailure.permissions
              ? context.l10n.chatCallPermissionRequired
              : context.l10n.chatCallFailed(e),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, e);
      }
    }
  }
}

// ── Pulsing Icon ─────────────────────────────────────────────────────────────

class _PulsingCallIcon extends StatelessWidget {
  const _PulsingCallIcon({
    required this.isVideo,
    required this.pulseScale,
    required this.pulseOpacity,
    required this.scheme,
  });

  final bool isVideo;
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: pulseScale,
            builder: (context, _) => Transform.scale(
              scale: pulseScale.value,
              child: Opacity(
                opacity: pulseOpacity.value,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.30),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
            ),
            child: Center(
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                color: scheme.onPrimaryContainer,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
