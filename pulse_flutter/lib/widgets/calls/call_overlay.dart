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
        if (data.state == CallSessionState.ended ||
            data.state == CallSessionState.idle) {
          return const SizedBox.shrink();
        }

        final scheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        final participantName = data.remoteParticipants.isNotEmpty
            ? data.remoteParticipants.first.nickname
            : null;

        final m = data.durationSeconds ~/ 60;
        final s = data.durationSeconds % 60;
        final timerLabel =
            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

        return Positioned(
          bottom: 96,
          right: 12,
          child: _CallPill(
            scheme: scheme,
            textTheme: textTheme,
            isVideo: data.isVideo,
            isActive: data.state == CallSessionState.inCall,
            participantName: participantName,
            timerLabel: timerLabel,
            onTap: () {
              final router = GoRouter.of(context);
              final path =
                  router.routeInformationProvider.value.uri.path;
              if (!path.startsWith('/call/')) {
                context.push('/call/${data.callId}');
              }
            },
            onEnd: () async {
              await manager?.end();
            },
          ),
        );
      },
    );
  }
}

class _CallPill extends StatelessWidget {
  const _CallPill({
    required this.scheme,
    required this.textTheme,
    required this.isVideo,
    required this.isActive,
    required this.participantName,
    required this.timerLabel,
    required this.onTap,
    required this.onEnd,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool isVideo;
  final bool isActive;
  final String? participantName;
  final String timerLabel;
  final VoidCallback onTap;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(32),
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Call type icon with green dot when active
              Stack(
                children: [
                  Icon(
                    isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 22,
                  ),
                  if (isActive)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: scheme.tertiary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.primaryContainer,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (participantName != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Text(
                    participantName!,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (isActive) ...[
                const SizedBox(width: 6),
                Text(
                  timerLabel,
                  style: textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.65),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              // End call button
              GestureDetector(
                onTap: onEnd,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.call_end_rounded,
                    color: scheme.error,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
