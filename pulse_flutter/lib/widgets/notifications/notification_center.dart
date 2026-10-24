import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';

Future<void> showNotificationCenter(BuildContext context) async {
  if (MediaQuery.sizeOf(context).width >= 700) {
    await showAppDialog<void>(
      context: context,
      builder: (context) => Dialog(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: SizedBox(
          width: 480,
          height: MediaQuery.sizeOf(context).height * .75,
          child: const NotificationCenter(),
        ),
      ),
    );
  } else {
    await AppBottomSheets.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: .8,
        child: NotificationCenter(),
      ),
    );
  }
}

class NotificationCenter extends ConsumerWidget {
  const NotificationCenter({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.noticeTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l10n.noticeClose,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (state.notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (state.unreadCount > 0)
                      TextButton(
                        onPressed: notifier.markAllRead,
                        child: Text(l10n.noticeMarkAllRead),
                      ),
                    TextButton(
                      onPressed: notifier.clear,
                      child: Text(l10n.noticeClear),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: state.notifications.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 48,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noticeEmpty,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noticeEmptyHint,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: state.notifications.length,
                    itemBuilder: (context, index) {
                      final n = state.notifications[index];
                      final event = n.event;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: n.isRead
                              ? scheme.surfaceContainerLow
                              : scheme.secondaryContainer,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              notifier.markRead(n.id);
                              if (event.target != null) {
                                Navigator.pop(context);
                                context.push(event.target!);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(switch (n.type) {
                                    AppNotificationType.message =>
                                      Icons.chat_bubble_outline_rounded,
                                    AppNotificationType.postLike =>
                                      Icons.favorite_outline_rounded,
                                    _ => Icons.alternate_email_rounded,
                                  }, color: scheme.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.title,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: n.isRead
                                                    ? FontWeight.w500
                                                    : FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          n.body,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          DateFormat.MMMd(
                                            Localizations.localeOf(
                                              context,
                                            ).languageCode,
                                          ).add_Hm().format(
                                            n.createdAt.toLocal(),
                                          ),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!n.isRead)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 8,
                                        top: 6,
                                      ),
                                      child: Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: scheme.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
