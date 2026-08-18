import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
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

    return Positioned(
      bottom: 96,
      right: 14,
      child: StreamBuilder<CallSessionData>(
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

          return _CallPill(
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
              HapticFeedback.mediumImpact();
              await manager?.end();
            },
          );
        },
      ),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // M3 Expressive shape call icon
                    M3Container.c9SidedCookie(
                      width: 28,
                      height: 28,
                      color: isActive ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                          color: isActive ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                          size: 16,
                        ),
                      ),
                    ),
                    if (participantName != null) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          participantName!,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Text(
                        timerLabel,
                        style: textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    // End call button in M3 shape
                    GestureDetector(
                      onTap: onEnd,
                      child: M3Container.c9SidedCookie(
                        width: 28,
                        height: 28,
                        color: scheme.error,
                        child: Center(
                          child: Icon(
                            Icons.call_end_rounded,
                            color: scheme.onError,
                            size: 14,
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
}
