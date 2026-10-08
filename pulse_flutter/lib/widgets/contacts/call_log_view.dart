import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/services/call_history_service.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

enum _CallFilter { all, missed }

class CallLogView extends ConsumerStatefulWidget {
  const CallLogView({super.key});

  @override
  ConsumerState<CallLogView> createState() => _CallLogViewState();
}

class _CallLogViewState extends ConsumerState<CallLogView> {
  _CallFilter _filter = _CallFilter.all;

  void _showEntryActions(BuildContext context, CallLogEntry entry) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: PulseAvatar(
                  radius: 20,
                  name: entry.peerDisplayName,
                  avatarUrl: entry.peerAvatarUrl,
                ),
                title: Text(
                  entry.peerDisplayName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: entry.peerUsername.isNotEmpty
                    ? Text('@${entry.peerUsername}')
                    : null,
              ),
              const Divider(height: 16),
              if (entry.peerUsername.isNotEmpty) ...<Widget>[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.phone_rounded,
                        color: scheme.primary, size: 20),
                  ),
                  title: const Text('Позвонить'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/call/dm/${entry.peerUsername}?isVideo=0');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.videocam_rounded,
                        color: scheme.secondary, size: 20),
                  ),
                  title: const Text('Видеозвонок'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/call/dm/${entry.peerUsername}?isVideo=1');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded,
                        color: scheme.onSurfaceVariant, size: 20),
                  ),
                  title: const Text('Открыть чат'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (entry.chatId > 0) {
                      context.push('/chat/${entry.chatId}');
                    } else {
                      context.push('/contact/${entry.peerUsername}');
                    }
                  },
                ),
              ],
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      color: scheme.error, size: 20),
                ),
                title: Text(
                  'Удалить из журнала',
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () {
                  ref.read(callHistoryProvider.notifier).removeEntry(entry.id);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Очистить историю звонков?',
      subtitle:
          'Все записи о вызовах будут удалены без возможности восстановления.',
      confirmLabel: 'Очистить',
      cancelLabel: 'Отмена',
      destructive: true,
    );
    if (confirmed == true) {
      ref.read(callHistoryProvider.notifier).clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<CallLogEntry> allEntries = ref.watch(callHistoryProvider);

    final List<CallLogEntry> filteredEntries = _filter == _CallFilter.all
        ? allEntries
        : allEntries.where((CallLogEntry e) => e.isMissed).toList(growable: false);

    return Column(
      children: <Widget>[
        // Filter bar & clear button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              // All calls filter chip
              FilterChip(
                selected: _filter == _CallFilter.all,
                label: Text('Все (${allEntries.length})'),
                onSelected: (_) {
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.tap();
                  }
                  setState(() => _filter = _CallFilter.all);
                },
                backgroundColor: scheme.surfaceContainerHigh,
                selectedColor: scheme.primaryContainer,
                labelStyle: TextStyle(
                  color: _filter == _CallFilter.all
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: _filter == _CallFilter.all
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 8),

              // Missed filter chip
              FilterChip(
                selected: _filter == _CallFilter.missed,
                label: Text(
                  'Пропущенные (${allEntries.where((CallLogEntry e) => e.isMissed).length})',
                ),
                onSelected: (_) {
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.tap();
                  }
                  setState(() => _filter = _CallFilter.missed);
                },
                backgroundColor: scheme.surfaceContainerHigh,
                selectedColor: scheme.errorContainer,
                labelStyle: TextStyle(
                  color: _filter == _CallFilter.missed
                      ? scheme.onErrorContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: _filter == _CallFilter.missed
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const Spacer(),

              // Clear button
              if (allEntries.isNotEmpty)
                IconButton(
                  onPressed: () => _confirmClearAll(context),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  tooltip: 'Очистить историю',
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),

        // List or Empty state
        if (filteredEntries.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _filter == _CallFilter.missed
                            ? Icons.phone_missed_rounded
                            : Icons.phone_callback_rounded,
                        size: 40,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _filter == _CallFilter.missed
                          ? 'Нет пропущенных звонков'
                          : 'Журнал звонков пуст',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _filter == _CallFilter.missed
                          ? 'Здесь будут появляться неотвеченные входящие вызовы'
                          : 'Совершайте безопасные аудио- и видеозвонки в 1 тап',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredEntries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final CallLogEntry entry = filteredEntries[index];

                final IconData typeIcon;
                final Color iconColor;
                final String statusText;

                if (entry.isMissed) {
                  typeIcon = Icons.call_missed_rounded;
                  iconColor = scheme.error;
                  statusText = 'Пропущенный';
                } else if (entry.isOutgoing) {
                  typeIcon = Icons.call_made_rounded;
                  iconColor = scheme.primary;
                  statusText = 'Исходящий';
                } else {
                  typeIcon = Icons.call_received_rounded;
                  iconColor = scheme.tertiary;
                  statusText = 'Входящий';
                }

                return Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () {
                      if (ref.read(uiSettingsProvider).haptics) {
                        HapticService.tap();
                      }
                      if (entry.peerUsername.isNotEmpty) {
                        context.push(
                          '/call/dm/${entry.peerUsername}?isVideo=${entry.isVideo ? 1 : 0}',
                        );
                      } else if (entry.chatId > 0) {
                        context.push('/chat/${entry.chatId}');
                      }
                    },
                    onLongPress: () {
                      if (ref.read(uiSettingsProvider).haptics) {
                        HapticService.confirm();
                      }
                      _showEntryActions(context, entry);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: <Widget>[
                          // Peer avatar
                          PulseAvatar(
                            radius: 22,
                            name: entry.peerDisplayName,
                            avatarUrl: entry.peerAvatarUrl,
                          ),
                          const SizedBox(width: 14),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        entry.peerDisplayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: entry.isMissed
                                              ? scheme.error
                                              : scheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (entry.isVideo) ...<Widget>[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.videocam_rounded,
                                        size: 16,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      typeIcon,
                                      size: 14,
                                      color: iconColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$statusText • ${formatRelativeTime(entry.timestamp)}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (entry.formattedDuration.isNotEmpty) ...<Widget>[
                                      const SizedBox(width: 4),
                                      Text(
                                        '(${entry.formattedDuration})',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Call back button
                          IconButton(
                            onPressed: () {
                              if (ref.read(uiSettingsProvider).haptics) {
                                HapticService.reaction();
                              }
                              if (entry.peerUsername.isNotEmpty) {
                                context.push(
                                  '/call/dm/${entry.peerUsername}?isVideo=${entry.isVideo ? 1 : 0}',
                                );
                              } else if (entry.chatId > 0) {
                                context.push('/chat/${entry.chatId}');
                              }
                            },
                            icon: Icon(
                              entry.isVideo
                                  ? Icons.videocam_outlined
                                  : Icons.phone_outlined,
                              color: scheme.primary,
                              size: 22,
                            ),
                            tooltip: 'Позвонить',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
