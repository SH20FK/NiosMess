import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/features/account_deletion/presentation/account_deletion_texts.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/widgets/settings/account_profile_section.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsAccountScreen extends ConsumerWidget {
  const SettingsAccountScreen({this.isEmbedded = false, super.key});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authProvider);

    final String displayName =
        auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;
    final String username =
        auth.session?.username ?? auth.profile?.username ?? '';
    final String? niosId = auth.session?.niosId;
    final bool pendingDeletion = auth.profile?.isPendingDeletion ?? false;

    return SettingsShell(
      title: context.l10n.settingsAccountTitle,
      isEmbedded: isEmbedded,
      children: <Widget>[
        const AccountProfileSection(),
        SettingsSection(
          children: <Widget>[
            _copyableField(
              context,
              anchor: SettingId.accountDisplayName.value,
              icon: Icons.person_outline_rounded,
              title: context.l10n.profileDisplayName,
              value: displayName,
            ),
            if (username.isNotEmpty)
              _copyableField(
                context,
                anchor: SettingId.accountUsername.value,
                icon: Icons.alternate_email_rounded,
                title: context.l10n.settingsAccountUsername,
                value: '@$username',
              ),
            if (niosId != null && niosId.isNotEmpty)
              _copyableField(
                context,
                anchor: SettingId.accountNiosId.value,
                icon: Icons.badge_outlined,
                title: 'Nios ID',
                value: niosId,
              ),
          ],
        ),
        SettingsSection(
          children: [
            SettingsListItem.nav(
              key: const ValueKey('settings-account-nios-id'),
              icon: Icons.manage_accounts_outlined,
              title: context.l10n.settingsV2NiosId,
              onTap: () => AppUrlLauncher.openUrl(
                context,
                'https://ni-os.ru/id/account',
              ),
            ),
            SettingsAnchor(
              id: 'account.password',
              child: SettingsListItem.nav(
                key: const ValueKey('settings-account-password'),
                icon: Icons.password_rounded,
                title: context.l10n.settingsPasswordEntry,
                subtitle: context.l10n.settingsPasswordEntryHint,
                onTap: () =>
                    openSettingsPage(context, '/settings/account/password'),
              ),
            ),
          ],
        ),
        SettingsSection(
          children: [
            SettingsAnchor(
              id: 'account.delete',
              child: SettingsListItem.danger(
                key: const ValueKey('settings-account-delete'),
                icon: pendingDeletion
                    ? Icons.auto_delete_outlined
                    : Icons.delete_forever_outlined,
                title: pendingDeletion
                    ? accountDeletionPendingTitle(
                        context.l10n,
                        auth.profile?.deletionScheduledAt,
                      )
                    : context.l10n.accountDeleteEntry,
                subtitle: pendingDeletion
                    ? context.l10n.accountDeleteCancel
                    : context.l10n.accountDeleteEntryHint,
                onTap: () =>
                    openSettingsPage(context, '/settings/account/delete'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _copyableField(
    BuildContext context, {
    required String anchor,
    required IconData icon,
    required String title,
    required String value,
  }) => SettingsAnchor(
    id: anchor,
    child: SettingsListItem(
      icon: icon,
      title: title,
      value: value,
      type: SettingsListItemType.value,
      trailing: const Icon(Icons.copy_rounded, size: 20),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) {
          AppToast.showSuccess(context, context.l10n.settingsE2eeCopyToast);
        }
      },
    ),
  );
}
