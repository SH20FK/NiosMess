import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/services/calls/call_starter.dart';

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

  // Pulse ring around the call-type icon
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
      curve: CallTokens.incomingOverlayCurve,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _pulseScale = Tween<double>(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incoming = ref.watch(incomingCallProvider);

    if (incoming != null && _lastIncoming == null) {
      _lastIncoming = incoming;
      _slideController.forward();
      Future.microtask(() => HapticFeedback.vibrate());
    } else if (incoming == null && _lastIncoming != null) {
      _slideController.reverse().then((_) {
        if (mounted) setState(() => _lastIncoming = null);
      });
    }

    final data = _lastIncoming;
    if (data == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final safeTop = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: safeTop + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(CallTokens.cardBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(CallTokens.cardBorderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: CallTokens.glassBlur,
                    sigmaY: CallTokens.glassBlur,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(CallTokens.cardBorderRadius),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.3),
                        width: CallTokens.glassBorderWidth,
                      ),
                    ),
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

                          // Decline Button (M3 9-sided cookie shape)
                          _M3CallActionButton(
                            icon: Icons.call_end_rounded,
                            color: scheme.onError,
                            bg: scheme.error,
                            shape: Shapes.c9_sided_cookie,
                            label: context.l10n.callEnd,
                            onTap: () => _declineCall(data),
                          ),
                          const SizedBox(width: 10),

                          // Accept Button (M3 9-sided cookie shape)
                          _M3CallActionButton(
                            icon: data.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                            color: scheme.onPrimary,
                            bg: scheme.primary,
                            shape: Shapes.c9_sided_cookie,
                            label: 'Accept',
                            onTap: () => _acceptCall(context, ref, data),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _declineCall(IncomingCallData incoming) {
    ref.read(incomingCallProvider.notifier).set(null);
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
    ref.read(incomingCallProvider.notifier).set(null);

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
        AppToast.showError(context, context.l10n.chatCallFailed(e));
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
                    color: scheme.primary.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
          M3Container.c9SidedCookie(
            width: 44,
            height: 44,
            color: scheme.primaryContainer,
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

// ── Action Button with M3 Shape ───────────────────────────────────────────────

class _M3CallActionButton extends StatelessWidget {
  const _M3CallActionButton({
    required this.icon,
    required this.color,
    required this.bg,
    required this.shape,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final Shapes shape;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: SizedBox(
            width: CallTokens.incomingButtonSize,
            height: CallTokens.incomingButtonSize,
            child: M3Container(
              shape,
              color: bg,
              child: Center(
                child: Icon(icon, color: color, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
