import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/call_video_provider.dart';
import 'package:pulse_flutter/services/calls/call_session.dart';

class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen>
    with WidgetsBindingObserver {
  StreamSubscription<CallSessionData>? _stateSub;
  StreamSubscription<Uint8List>? _videoSub;
  CallSessionData? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToState();
    _listenToVideo();
  }

  void _listenToState() {
    final manager = ref.read(callSessionProvider);
    final session = manager?.session;
    if (session == null) return;

    _data = session.currentData;
    _stateSub = session.stateStream.listen((data) {
      if (mounted) setState(() => _data = data);
    });
  }

  void _listenToVideo() {
    final manager = ref.read(callSessionProvider);
    final session = manager?.session;
    if (session == null) return;

    final videoOutput = session.videoOutput;
    if (videoOutput == null) return;

    _videoSub = videoOutput.frameStream.listen((frame) {
      ref.read(remoteVideoFrameProvider.notifier).state = frame;
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _videoSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {}
  }

  void _endCall() async {
    final manager = ref.read(callSessionProvider);
    await manager?.end();
    // BUG FIX #2: Explicitly set provider state to null after call ends
    // This triggers Riverpod listeners to rebuild UI and hide CallOverlay
    ref.read(callSessionProvider.notifier).state = null;
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    final session = ref.read(callSessionProvider)?.session;
    if (session == null || _data == null) return;
    session.setMuted(!_data!.isMuted);
  }

  void _toggleSpeaker() {
    final session = ref.read(callSessionProvider)?.session;
    if (session == null || _data == null) return;
    session.setSpeakerOn(!_data!.isSpeakerOn);
  }

  void _toggleCamera() {
    final session = ref.read(callSessionProvider)?.session;
    if (session == null) return;
    session.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final data = _data;
    final duration = data?.durationSeconds ?? 0;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    final timerText =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final participants = data?.remoteParticipants ?? [];
    final participantLabels =
        participants.map((p) => p.nickname).join(', ');
    final stateLabel = _stateLabel(data?.state, l10n);
    final isVideo = data?.isVideo ?? false;
    final remoteFrame = ref.watch(remoteVideoFrameProvider);

    final List<Widget> controls = [
      _CallControlButton(
        icon: data?.isMuted == true
            ? Icons.mic_off_rounded
            : Icons.mic_rounded,
        label: l10n.activeCallMute,
        isActive: data?.isMuted == true,
        onTap: _toggleMute,
      ),
      _CallControlButton(
        icon: Icons.phone_disabled_rounded,
        label: l10n.activeCallEnd,
        isDestructive: true,
        onTap: _endCall,
      ),
      _CallControlButton(
        icon: data?.isSpeakerOn == true
            ? Icons.volume_up_rounded
            : Icons.volume_down_rounded,
        label: l10n.activeCallSpeaker,
        isActive: data?.isSpeakerOn == true,
        onTap: _toggleSpeaker,
      ),
    ];

    if (isVideo) {
      controls.insert(
        0,
        _CallControlButton(
          icon: Icons.flip_camera_ios_rounded,
          label: 'Flip',
          onTap: _toggleCamera,
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.scrim,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video feed (full screen)
            if (isVideo && remoteFrame != null)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 640,
                    height: 480,
                    child: RemoteVideoView(frame: remoteFrame),
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Reconnection banner
                  if (data?.state == CallSessionState.connecting ||
                      data?.state == CallSessionState.reconnecting)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      color: scheme.error.withValues(alpha: 0.3),
                      child: Text(
                        stateLabel,
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  const Spacer(flex: 2),
                  // Remote avatar (voice call)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 60,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    participantLabels.isNotEmpty
                        ? participantLabels
                        : 'Calling...',
                    style: textTheme.headlineSmall
                        ?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data?.state == CallSessionState.inCall
                        ? timerText
                        : stateLabel,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            // Local video PiP
            if (isVideo)
              Positioned(
                top: 60,
                right: 12,
                child: Container(
                  width: 120,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: _LocalCameraPreview(),
                ),
              ),
            // Participant info overlay (video mode)
            if (isVideo)
              Positioned(
                top: 8,
                left: 16,
                child: Text(
                  participantLabels.isNotEmpty
                      ? participantLabels
                      : 'Calling...',
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            if (isVideo)
              Positioned(
                top: 8,
                right: 16,
                child: Text(
                  data?.state == CallSessionState.inCall
                      ? timerText
                      : stateLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            // Controls
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: controls,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stateLabel(CallSessionState? state, Object? _) {
    switch (state) {
      case CallSessionState.connecting:
        return 'Connecting...';
      case CallSessionState.reconnecting:
        return 'Reconnecting...';
      case CallSessionState.connected:
        return 'Connected';
      case CallSessionState.inCall:
        return 'In call';
      case CallSessionState.ended:
        return 'Call ended';
      default:
        return '';
    }
  }
}

class RemoteVideoView extends StatelessWidget {
  const RemoteVideoView({required this.frame, super.key});

  final Uint8List frame;

  @override
  Widget build(BuildContext context) {
    if (frame.isEmpty) return const SizedBox.shrink();
    return Image.memory(
      frame,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

class _LocalCameraPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(localVideoEnabledProvider);
    if (!isEnabled) {
      return Center(
        child: Icon(
          Icons.videocam_off_rounded,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: _CameraPreviewWidget(),
    );
  }
}

class _CameraPreviewWidget extends StatefulWidget {
  @override
  State<_CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<_CameraPreviewWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Icon(
          Icons.videocam_rounded,
          size: 32,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isDestructive
              ? scheme.error
              : isActive
                  ? scheme.primary.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.15),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
        ),
      ],
    );
  }
}
