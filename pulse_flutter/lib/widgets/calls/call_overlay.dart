import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';

class CallOverlay extends ConsumerWidget {
  const CallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide overlay completely when full-screen call screen is open
    final bool isCallScreenOpen = ref.watch(isCallScreenOpenProvider);
    if (isCallScreenOpen) return const SizedBox.shrink();

    final router = ref.watch(appRouterProvider);
    final String currentPath =
        router.routeInformationProvider.value.uri.path;
    if (currentPath.startsWith('/call/')) {
      return const SizedBox.shrink();
    }

    final manager = ref.watch(callSessionProvider);
    final session = manager?.session;
    if (session == null) return const SizedBox.shrink();

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        heightFactor: 1.0,
        widthFactor: 1.0,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 96, right: 16),
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
                  : data.peerName;

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
                  final current =
                      router.routeInformationProvider.value.uri.path;
                  if (!current.startsWith('/call/')) {
                    router.push('/call/${data.callId}');
                  }
                },
                onEnd: () async {
                  HapticService.tap();
                  await manager?.end();
                },
              );
            },
          ),
        ),
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
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Call icon indicator
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                      color: isActive
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                      size: 16,
                    ),
                  ),
                ),
                if (participantName != null && participantName!.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      participantName!,
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (isActive) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    timerLabel,
                    style: textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                // End Call button
                GestureDetector(
                  onTap: onEnd,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.error,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: scheme.error.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.call_end_rounded,
                        color: scheme.onError,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
