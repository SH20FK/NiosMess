import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/features/sessions/application/sessions_controller.dart';
import 'package:pulse_flutter/features/sessions/domain/session_model.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';

class SessionDetailsSheet extends ConsumerWidget {
  const SessionDetailsSheet({
    required this.session,
    super.key,
  });

  final AccountSession session;

  static IconData platformIcon(String platform) {
    return switch (platform.toLowerCase()) {
      'android' => Icons.phone_android_rounded,
      'ios' => Icons.phone_iphone_rounded,
      'windows' => Icons.laptop_windows_rounded,
      'macos' => Icons.laptop_mac_rounded,
      'linux' => Icons.laptop_chromebook_rounded,
      'web' => Icons.language_rounded,
      _ => Icons.devices_rounded,
    };
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Завершить сессию?',
      subtitle: 'Устройство «${session.deviceName}» будет отключено от вашего аккаунта.',
      confirmLabel: 'Завершить',
      cancelLabel: 'Отмена',
      destructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed != true) return;

    final bool ok = await ref.read(sessionsControllerProvider.notifier).revokeSession(session.id);
    if (context.mounted) {
      Navigator.of(context).maybePop();
      if (ok) {
        AppToast.showSuccess(context, 'Сессия завершена');
      } else {
        AppToast.showError(context, 'Не удалось завершить сессию');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: session.isCurrent
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    platformIcon(session.platform),
                    color: session.isCurrent ? scheme.primary : scheme.onSurfaceVariant,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        session.deviceName,
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.isCurrent ? 'Текущее устройство' : session.platform,
                        style: textTheme.bodySmall?.copyWith(
                          color: session.isCurrent ? scheme.primary : scheme.onSurfaceVariant,
                          fontWeight: session.isCurrent ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _infoRow(context, 'Приложение', '${session.appName} ${session.appVersion}'.trim()),
            _infoRow(context, 'IP-адрес', session.ipAddress),
            if (session.approximateRegion != null)
              _infoRow(context, 'Местоположение', session.approximateRegion!),
            _infoRow(context, 'Первый вход', dateFormat.format(session.createdAt.toLocal())),
            _infoRow(context, 'Последняя активность', dateFormat.format(session.lastActiveAt.toLocal())),
            const SizedBox(height: 24),
            if (!session.isCurrent)
              FilledButton.tonal(
                onPressed: () => _revoke(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.errorContainer.withValues(alpha: 0.4),
                  foregroundColor: scheme.error,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Завершить эту сессию', style: TextStyle(fontWeight: FontWeight.w600)),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Закрыть'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          Text(value, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
