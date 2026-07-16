import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'active_voice_call_screen.dart';
import 'active_video_call_screen.dart';

class ActiveCallScreen extends ConsumerWidget {
  const ActiveCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(callSessionProvider)?.session;
    if (session == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final isVideo = session.currentData.isVideo;
    if (isVideo) {
      return const ActiveVideoCallScreen();
    } else {
      return const ActiveVoiceCallScreen();
    }
  }
}
