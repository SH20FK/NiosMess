import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

/// A brief notice replaces the existing subtitle; it never blocks the composer.
class OrdinaryPeerKeyNotice extends ConsumerWidget {
  const OrdinaryPeerKeyNotice({
    required this.chatId,
    required this.child,
    super.key,
  });
  final int chatId;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(ordinaryE2eeProvider);
    if (service == null) return child;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final epoch = service.contactKeyChange(chatId);
        if (epoch == null) return child;
        return _BriefNotice(
          key: ValueKey((service, chatId, epoch)),
          onSeen: () => service.dismissContactKeyChange(chatId, epoch),
        );
      },
    );
  }
}

class _BriefNotice extends StatefulWidget {
  const _BriefNotice({required this.onSeen, super.key});
  final Future<void> Function() onSeen;
  @override
  State<_BriefNotice> createState() => _BriefNoticeState();
}

class _BriefNoticeState extends State<_BriefNotice> {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted) unawaited(widget.onSeen().catchError((Object _) {}));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      'Ключ изменился',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
