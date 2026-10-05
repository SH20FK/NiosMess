import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/features/sessions/application/sessions_controller.dart';
import 'package:pulse_flutter/features/sessions/domain/session_model.dart';
import 'package:pulse_flutter/features/sessions/presentation/session_details_sheet.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_responsive_shell.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  Future<void> _terminateOthers(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Завершить все остальные сессии?',
      subtitle: 'Все устройства, кроме этого, будут отключены от вашего аккаунта.',
      confirmLabel: 'Завершить все',
      cancelLabel: 'Отмена',
      icon: Icons.devices_other_rounded,
      destructive: true,
    );

    if (confirmed != true) return;

    final bool ok = await ref.read(sessionsControllerProvider.notifier).terminateOtherSessions();
    if (context.mounted) {
      if (ok) {
        AppToast.showSuccess(context, 'Все остальные сессии успешно завершены');
      } else {
        AppToast.showError(context, 'Не удалось завершить сессии');
      }
    }
  }

  void _openDetails(BuildContext context, AccountSession session) {
    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) => SessionDetailsSheet(session: session),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionsState state = ref.watch(sessionsControllerProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final Widget body = switch (state) {
      SessionsLoading() => const Center(child: AppLoadingIndicator()),
      SessionsFailure(:final String message) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.error_outline_rounded, color: scheme.error, size: 48),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center, style: textTheme.bodyLarge),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.read(sessionsControllerProvider.notifier).load(),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      SessionsReady(
        :final List<AccountSession> sessions,
        :final int? currentSessionId,
        :final bool terminatingOthers,
      ) =>
        RefreshIndicator(
          onRefresh: () => ref.read(sessionsControllerProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: <Widget>[
              // Current session card
              if (sessions.any((s) => s.isCurrent)) ...<Widget>[
                Text(
                  'ТЕКУЩЕЕ УСТРОЙСТВО',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                ...sessions.where((s) => s.isCurrent).map((AccountSession session) {
                  return Card(
                    elevation: 0,
                    color: scheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          SessionDetailsSheet.platformIcon(session.platform),
                          color: scheme.primary,
                        ),
                      ),
                      title: Text(
                        session.deviceName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${session.appName} • ${session.ipAddress}',
                        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'В сети',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      onTap: () => _openDetails(context, session),
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],

              // Terminate all others button (authoritative: enabled only if currentSessionId != null)
              if (sessions.any((s) => !s.isCurrent)) ...<Widget>[
                FilledButton.tonalIcon(
                  onPressed: (currentSessionId != null && !terminatingOthers)
                      ? () => _terminateOthers(context, ref)
                      : null,
                  icon: terminatingOthers
                      ? const SizedBox(width: 18, height: 18, child: AppLoadingIndicator(size: 18))
                      : const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Завершить все остальные сессии'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.errorContainer.withValues(alpha: 0.35),
                    foregroundColor: scheme.error,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'АКТИВНЫЕ СЕССИИ (${sessions.where((s) => !s.isCurrent).length})',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: sessions.where((s) => !s.isCurrent).map((AccountSession session) {
                      final dateFormat = DateFormat('dd.MM.yy HH:mm');
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: scheme.surfaceContainerHighest,
                          child: Icon(
                            SessionDetailsSheet.platformIcon(session.platform),
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(session.deviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${session.ipAddress} • ${dateFormat.format(session.lastActiveAt.toLocal())}',
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openDetails(context, session),
                      );
                    }).toList(),
                  ),
                ),
              ] else if (!sessions.any((s) => !s.isCurrent)) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.devices_other_rounded, size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'Нет других активных сессий',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Вы вошли в аккаунт только с этого устройства.',
                          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
    };

    return SettingsResponsiveShell(
      title: 'Устройства и сессии',
      isEmbedded: isEmbedded,
      mobileBody: body,
      desktopBody: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: body,
        ),
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.read(sessionsControllerProvider.notifier).load(),
          tooltip: 'Обновить',
        ),
      ],
    );
  }
}
