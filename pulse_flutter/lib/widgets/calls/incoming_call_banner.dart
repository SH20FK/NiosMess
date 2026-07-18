import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';

class IncomingCallBanner extends ConsumerWidget {
  const IncomingCallBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingCallProvider);
    if (incoming == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.95),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  incoming.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      incoming.isVideo ? 'Video call' : 'Voice call',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '${incoming.initiatorName} is calling...',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _joinCall(context, ref, incoming),
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: const Text('Join'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  ref.read(incomingCallProvider.notifier).set(null);
                },
                icon: Icon(Icons.close_rounded, color: scheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinCall(BuildContext context, WidgetRef ref, IncomingCallData incoming) async {
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
