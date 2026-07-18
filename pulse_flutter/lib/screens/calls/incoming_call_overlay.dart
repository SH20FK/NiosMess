import 'dart:typed_data';
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
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';

class IncomingCallOverlay extends ConsumerStatefulWidget {
  const IncomingCallOverlay({super.key});

  @override
  ConsumerState<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _pulseController;

  IncomingCallData? _lastIncoming;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: CallTokens.incomingOverlayAnimationDuration,
    );

    _slideAnimation = Tween<double>(begin: -150.0, end: 0.0).animate(
      CurvedAnimation(parent: _slideController, curve: CallTokens.incomingOverlayCurve),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: CallTokens.incomingOverlayCurve,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.vibrate();
  }

  @override
  Widget build(BuildContext context) {
    final incoming = ref.watch(incomingCallProvider);

    if (incoming != null && _lastIncoming == null) {
      _lastIncoming = incoming;
      _slideController.forward();
      Future.microtask(_triggerHaptic);
    } else if (incoming == null && _lastIncoming != null) {
      _slideController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _lastIncoming = null;
          });
        }
      });
    }

    final data = _lastIncoming;
    if (data == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Positioned(
          top: 16 + _slideAnimation.value,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: RepaintBoundary(
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! > 10) {
              _acceptCall(context, ref, data);
            } else if (details.primaryDelta! < -10) {
              _declineCall();
            }
          },
          child: Card(
            elevation: CallTokens.cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CallTokens.cardBorderRadius),
            ),
            color: scheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: CallTokens.avatarSmallSize + (24 * _pulseController.value),
                            height: CallTokens.avatarSmallSize + (24 * _pulseController.value),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primary.withValues(alpha: 0.2 * (1.0 - _pulseController.value)),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: CallTokens.avatarSmallSize,
                        height: CallTokens.avatarSmallSize,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          data.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                          color: scheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.initiatorName,
                          style: textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          data.isVideo ? context.l10n.callIncomingVideo : context.l10n.callIncomingVoice,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _declineCall,
                        icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.error,
                          minimumSize: const Size(CallTokens.incomingButtonSize, CallTokens.incomingButtonSize),
                          maximumSize: const Size(CallTokens.incomingButtonSize, CallTokens.incomingButtonSize),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _acceptCall(context, ref, data),
                        icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.primary,
                          minimumSize: const Size(CallTokens.incomingButtonSize, CallTokens.incomingButtonSize),
                          maximumSize: const Size(CallTokens.incomingButtonSize, CallTokens.incomingButtonSize),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _declineCall() {
    ref.read(incomingCallProvider.notifier).set(null);
  }

  Future<void> _acceptCall(BuildContext context, WidgetRef ref, IncomingCallData incoming) async {
    ref.read(incomingCallProvider.notifier).set(null);

    try {
      await ref.read(callRepositoryProvider).join(
        chatId: incoming.chatId,
        roomId: incoming.roomId,
        messageId: incoming.callId,
      );

      final e2ee = ref.read(e2eeServiceProvider);
      final aesKey = await e2ee.deriveCallKey(incoming.callId);
      final aesKeyBytes = Uint8List.fromList(await aesKey.extractBytes());

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
