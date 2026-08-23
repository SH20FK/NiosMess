import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'active_voice_call_screen.dart';
import 'active_video_call_screen.dart';

class ActiveCallScreen extends ConsumerWidget {
  const ActiveCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(callSessionProvider)?.session;
    final scheme = Theme.of(context).colorScheme;
    if (session == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                ref.read(appRouterProvider).go('/main/chats');
              }
            },
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
      );
    }

    final isVideo = session.currentData.isVideo;
    if (isVideo) {
      return const ActiveVideoCallScreen();
    } else {
      return const ActiveVoiceCallScreen();
    }
  }
}
