import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'package:pulse_flutter/services/calls/call_starter.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';

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

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Positioned(
          top: safeTop + 8,
          left: 12,
          right: 12,
          child: RepaintBoundary(
            child: Material(
              elevation: 6,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(28),
              color: scheme.surfaceContainerHigh,
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v > 120) _acceptCall(context, ref, data);
                  if (v < -120) _declineCall(data);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Pulsing icon
                      _PulsingCallIcon(
                        isVideo: data.isVideo,
                        pulseScale: _pulseScale,
                        pulseOpacity: _pulseOpacity,
                        scheme: scheme,
                      ),
                      const SizedBox(width: 14),

                      // Name + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data.initiatorName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
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
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Decline
                      _CallActionButton(
                        icon: Icons.call_end_rounded,
                        color: scheme.onError,
                        bg: scheme.error,
                        onTap: () => _declineCall(data),
                      ),
                      const SizedBox(width: 8),

                      // Accept
                      _CallActionButton(
                        icon: data.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                        color: scheme.onPrimary,
                        bg: scheme.primary,
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

    try {
      await ref.read(callRepositoryProvider).join(
        chatId: incoming.chatId,
        roomId: incoming.roomId,
        messageId: incoming.callId,
      );

      final aesKeyBytes = await deriveCallMediaKey(
        ref,
        chatId: incoming.chatId,
        callId: incoming.callId,
      );

      final manager = CallSessionManager(
        ref: ref,
        chatId: incoming.chatId,
        callId: incoming.callId,
        roomId: incoming.roomId,
        isVideo: incoming.isVideo,
        direction: CallDirection.incoming,
        displayName: ref.read(authProvider).session?.displayName ?? 'User',
        aesKeyBytes: aesKeyBytes,
      );

      manager.start();
      ref.read(callSessionProvider.notifier).setSession(manager);

      if (context.mounted) {
        context.push('/call/${incoming.callId}');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, 'Failed to join call: $e');
      }
    }
  }
}

// ── Pulsing icon ──────────────────────────────────────────────────────────────

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
    const size = 46.0;
    return SizedBox(
      width: size + 20,
      height: size + 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring
          AnimatedBuilder(
            animation: pulseScale,
            builder: (context, _) => Transform.scale(
              scale: pulseScale.value,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: pulseOpacity.value),
                ),
              ),
            ),
          ),
          // Icon circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
            ),
            child: Icon(
              isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
              color: scheme.onPrimaryContainer,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Call action button ────────────────────────────────────────────────────────

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = CallTokens.incomingButtonSize;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
