import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';

class CallOverlay extends ConsumerWidget {
  const CallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(callSessionProvider);
    final session = manager?.session;
    if (session == null) return const SizedBox.shrink();

    final data = session.currentData;
    if (data.state == CallSessionState.ended) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      bottom: 100,
      right: 16,
      child: Material(
        elevation: 8,
        shape: const CircleBorder(),
        color: scheme.primaryContainer,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push('/call/${data.callId}'),
          child: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            child: Icon(
              data.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
              color: scheme.onPrimaryContainer,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
