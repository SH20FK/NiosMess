import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';
import 'package:pulse_flutter/services/calls/call_starter.dart';

/// Shows "Join" for an ongoing group call in this chat.
class ActiveGroupCallBanner extends ConsumerStatefulWidget {
  const ActiveGroupCallBanner({required this.chatId, super.key});

  final int chatId;

  @override
  ConsumerState<ActiveGroupCallBanner> createState() =>
      _ActiveGroupCallBannerState();
}

class _ActiveGroupCallBannerState extends ConsumerState<ActiveGroupCallBanner> {
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    unawaited(_hydrate());
  }

  Future<void> _hydrate() async {
    final info = await ref
        .read(callRepositoryProvider)
        .getActiveCall(widget.chatId);
    if (!mounted) return;
    final notifier = ref.read(activeChatCallsProvider.notifier);
    if (info == null || info['is_group'] != true) {
      notifier.remove(widget.chatId);
      return;
    }
    notifier.upsert(
      ActiveChatCall(
        chatId: widget.chatId,
        roomId: info['room_id'].toString(),
        callId: (info['message_id'] as num?)?.toInt() ?? 0,
        isVideo: info['is_video'] == true,
        participantsCount: (info['participants_count'] as num?)?.toInt() ?? 1,
        status: info['status']?.toString() ?? 'active',
      ),
    );
  }

  Future<void> _join(ActiveChatCall call) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await startIncomingCall(
        ref: ref,
        chatId: call.chatId,
        callId: call.callId,
        roomId: call.roomId,
        isVideo: call.isVideo,
      );
    } catch (_) {
      // Call may have ended; refresh the banner state.
      await _hydrate();
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(
      activeChatCallsProvider.select((m) => m[widget.chatId]),
    );
    final inCall = ref.watch(callSessionProvider)?.roomId == call?.roomId;
    if (call == null || !call.isGroup || inCall) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: ListTile(
        dense: true,
        leading: Icon(
          call.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
          color: scheme.onPrimaryContainer,
        ),
        title: Text(
          'Идёт групповой звонок · ${call.participantsCount}',
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
        trailing: FilledButton(
          onPressed: _joining ? null : () => _join(call),
          child: const Text('Присоединиться'),
        ),
      ),
    );
  }
}
