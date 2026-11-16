import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class OrdinaryE2eeNotice extends ConsumerWidget {
  const OrdinaryE2eeNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(ordinaryE2eeProvider);
    if (service == null) return const SizedBox.shrink();
    final l = context.l10n;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.initialised || !service.locked) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  service.autoWaiting
                      ? l.inboxE2eeWaitingActiveDevice
                      : l.inboxE2eeWaitingKeys,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/settings/e2ee'),
                child: Text(l.noticeOpen),
              ),
            ],
          ),
        );
      },
    );
  }
}
