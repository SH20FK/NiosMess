import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/features/sessions/application/sessions_controller.dart';
import 'package:pulse_flutter/features/sessions/domain/session_model.dart';
import 'package:pulse_flutter/features/sessions/presentation/session_details_sheet.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({this.isEmbedded = false, super.key});
  final bool isEmbedded;

  Future<void> _terminateOthers(BuildContext context, WidgetRef ref) async {
    final owner = ref.read(authProvider).session;
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.modalSessionsTitle,
      subtitle: context.l10n.modalSessionsBody,
      confirmLabel: context.l10n.modalSessionsConfirm,
      cancelLabel: context.l10n.commonCancel,
      icon: Icons.devices_other_rounded,
      destructive: true,
    );
    if (!context.mounted ||
        confirmed != true ||
        owner != ref.read(authProvider).session) {
      return;
    }
    final ok = await ref
        .read(sessionsControllerProvider.notifier)
        .terminateOtherSessions();
    if (!context.mounted || owner != ref.read(authProvider).session) return;
    if (ok) {
      AppToast.showSuccess(context, context.l10n.settingsSessionsEndedOthers);
    } else {
      AppToast.showError(context, context.l10n.settingsSessionsEndFailed);
    }
  }

  void _openDetails(
    BuildContext context,
    WidgetRef ref,
    AccountSession session,
  ) {
    final account = ref.read(authProvider).session;
    AppBottomSheets.show<void>(
      context: context,
      builder: (_) => SessionDetailsSheet(
        session: session,
        accountId: account?.userId,
        accountToken: account?.accessToken,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionsControllerProvider);
    final ready = state is SessionsReady ? state : null;
    final pending =
        ready != null &&
        (ready.terminatingOthers || ready.revokingIds.isNotEmpty);
    final scheme = Theme.of(context).colorScheme;
    return SettingsShell(
      title: context.l10n.sessionsTitle,
      isEmbedded: isEmbedded,
      onRefresh: () => ref.read(sessionsControllerProvider.notifier).load(),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: pending || state is SessionsLoading
              ? null
              : () => ref.read(sessionsControllerProvider.notifier).load(),
          tooltip: context.l10n.refreshAction,
        ),
      ],
      children: [
        if (state is SessionsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: AppLoadingIndicator()),
          ),
        if (state is SessionsFailure)
          SettingsSection(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: scheme.error,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.settingsSessionsLoadFailed,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () =>
                          ref.read(sessionsControllerProvider.notifier).load(),
                      child: Text(context.l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (ready != null) ...[
          if (ready.currentSession case final current?)
            SettingsSection(
              title: context.l10n.settingsSessionsCurrentDevice,
              children: [_deviceRow(context, ref, current, pending)],
            ),
          if (ready.otherSessions.isNotEmpty) ...[
            SettingsSection(
              title: context.l10n.settingsSessionsOthers,
              children: [
                for (final session in ready.otherSessions)
                  _deviceRow(context, ref, session, pending),
              ],
            ),
            SettingsSection(
              children: [
                SettingsListItem(
                  icon: Icons.logout_rounded,
                  title: context.l10n.sessionsTerminateAll,
                  type: SettingsListItemType.danger,
                  pending: ready.terminatingOthers,
                  enabled: ready.currentSessionId != null && !pending,
                  onTap: () => _terminateOthers(context, ref),
                ),
              ],
            ),
          ] else
            SettingsSection(
              children: [
                SettingsListItem(
                  icon: Icons.verified_user_outlined,
                  title: context.l10n.settingsSessionsNoOtherDevices,
                  subtitle: context.l10n.settingsSessionsEmptyDescription,
                  type: SettingsListItemType.value,
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _deviceRow(
    BuildContext context,
    WidgetRef ref,
    AccountSession session,
    bool pending,
  ) => SettingsListItem(
    key: ValueKey('settings-session-${session.id}'),
    icon: SessionDetailsSheet.platformIcon(session.platform),
    title: session.deviceName,
    subtitle: session.isCurrent
        ? '${session.appName} · ${session.ipAddress}'
        : '${session.ipAddress} · ${DateFormat.yMd(context.l10n.localeName).add_Hm().format(session.lastActiveAt.toLocal())}',
    type: SettingsListItemType.nav,
    isSection: true,
    enabled: !pending,
    pending:
        ref.watch(sessionsControllerProvider) is SessionsReady &&
        (ref.read(sessionsControllerProvider) as SessionsReady).revokingIds
            .contains(session.id),
    onTap: () => _openDetails(context, ref, session),
  );
}
