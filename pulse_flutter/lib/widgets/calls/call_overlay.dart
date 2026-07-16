import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';

class CallOverlay extends ConsumerWidget {
  const CallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(callSessionProvider);
    final session = manager?.session;
    if (session == null) return const SizedBox.shrink();

    return StreamBuilder<CallSessionData>(
      stream: session.stateStream,
      initialData: session.currentData,
      builder: (context, snapshot) {
        final data = snapshot.data ?? session.currentData;
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      data.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 28,
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
