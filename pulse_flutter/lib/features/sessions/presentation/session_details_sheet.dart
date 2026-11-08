import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/features/sessions/application/sessions_controller.dart';
import 'package:pulse_flutter/features/sessions/domain/session_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SessionDetailsSheet extends ConsumerWidget {
  const SessionDetailsSheet({
    required this.session,
    required this.accountId,
    required this.accountToken,
    super.key,
  });
  final AccountSession session;
  final int? accountId;
  final String? accountToken;

  static IconData platformIcon(String platform) =>
      switch (platform.toLowerCase()) {
        'android' => Icons.phone_android_rounded,
        'ios' => Icons.phone_iphone_rounded,
        'windows' => Icons.laptop_windows_rounded,
        'macos' => Icons.laptop_mac_rounded,
        'linux' => Icons.laptop_chromebook_rounded,
        'web' => Icons.language_rounded,
        _ => Icons.devices_rounded,
      };

  bool _sameAccount(WidgetRef ref) {
    final account = ref.read(authProvider).session;
    return accountId == account?.userId &&
        accountToken == account?.accessToken &&
        !ref.read(authProvider.notifier).isLoggingOut;
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    if (!_sameAccount(ref)) return;
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.modalSessionTitle,
      subtitle: context.l10n.modalSessionBody(session.deviceName),
      confirmLabel: context.l10n.modalSessionConfirm,
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!context.mounted || confirmed != true || !_sameAccount(ref)) return;
    final ok = await ref
        .read(sessionsControllerProvider.notifier)
        .revokeSession(session.id);
    if (!context.mounted || !_sameAccount(ref)) return;
    if (ok) {
      AppToast.showSuccess(context, context.l10n.sessionsRevokedSuccess);
      Navigator.of(context).pop();
    } else {
      AppToast.showError(context, context.l10n.settingsSessionsEndFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider.select((a) => a.session));
    // A root-navigator sheet can outlive the account that opened it.
    if (accountId != account?.userId || accountToken != account?.accessToken) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(sessionsControllerProvider);
    final ready = state is SessionsReady ? state : null;
    final pending =
        ready != null &&
        (ready.terminatingOthers || ready.revokingIds.isNotEmpty);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = DateFormat.yMd(context.l10n.localeName).add_Hm();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    platformIcon(session.platform),
                    color: scheme.onSecondaryContainer,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.deviceName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      session.isCurrent
                          ? context.l10n.settingsSessionsCurrentDevice
                          : session.platform,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSection(
            children: [
              _info(
                context.l10n.settingsSessionsApp,
                '${session.appName} ${session.appVersion}'.trim(),
              ),
              _info(context.l10n.settingsSessionsIp, session.ipAddress),
              if (session.approximateRegion case final region?)
                _info(context.l10n.settingsSessionsRegion, region),
              _info(
                context.l10n.settingsSessionsFirstSignIn,
                date.format(session.createdAt.toLocal()),
              ),
              _info(
                context.l10n.settingsSessionsLastActive,
                date.format(session.lastActiveAt.toLocal()),
              ),
            ],
          ),
          if (!session.isCurrent)
            FilledButton.tonalIcon(
              onPressed: pending || ready == null
                  ? null
                  : () => _revoke(context, ref),
              icon: pending
                  ? const AppLoadingIndicator(size: 20)
                  : const Icon(Icons.logout_rounded),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.errorContainer,
                foregroundColor: scheme.onErrorContainer,
                minimumSize: const Size.fromHeight(48),
              ),
              label: Text(
                context.l10n.settingsSessionsEndThis,
                textAlign: TextAlign.center,
              ),
            )
          else
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
        ],
      ),
    );
  }

  Widget _info(String title, String value) => SettingsListItem(
    icon: Icons.info_outline_rounded,
    title: title,
    value: value,
    showIcon: false,
    type: SettingsListItemType.value,
  );
}
