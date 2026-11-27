import 'dart:async';

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
import 'package:pulse_flutter/widgets/common/app_action_menu_item.dart';
import 'package:pulse_flutter/widgets/settings/account_profile_section.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsAccountScreen extends ConsumerWidget {
  const SettingsAccountScreen({this.isEmbedded = false, super.key});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

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
      // Who is signed in: the photo and the names. The hero is the only place
      // that states them; copying them again below would be the same row
      // twice.
      hero: AccountProfileHero(
        displayName: displayName,
        username: username,
        avatarUrl: auth.profile?.avatarUrl,
      ),
      children: <Widget>[
        const AccountProfileSection(),
        // The subscription belongs to who is signed in, so its status rides
        // the account page instead of a hub row of its own. One row, no
        // heading: the stars and the label name it already.
        SettingsSection(
          children: <Widget>[
            SettingsListItem.nav(
              key: const ValueKey('settings-account-plus'),
              icon: Icons.stars_rounded,
              title: 'Nios+',
              subtitle: context.l10n.settingsPlusSummary,
              value: auth.profile?.isNiosPlus ?? false
                  ? context.l10n.settingsPlusActive
                  : null,
              onTap: () => openSettingsPage(context, '/settings/plus'),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsAccountSignInTitle,
          accentIcon: Icons.key_rounded,
          children: <Widget>[
            if (niosId != null && niosId.isNotEmpty) _NiosIdRow(niosId: niosId),
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
          title: context.l10n.accountDeleteTitle,
          accentIcon: pendingDeletion
              ? Icons.auto_delete_outlined
              : Icons.delete_forever_rounded,
          accentColor: scheme.errorContainer,
          accentForeground: scheme.onErrorContainer,
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
}

/// One row for the Nios ID: what it is, and the two things that can be done
/// with it. Copying and the portal used to be two separate rows of the same
/// value, which read as two different IDs.
class _NiosIdRow extends StatefulWidget {
  const _NiosIdRow({required this.niosId});

  final String niosId;

  @override
  State<_NiosIdRow> createState() => _NiosIdRowState();
}

class _NiosIdRowState extends State<_NiosIdRow> {
  /// Where the ID is managed: password, sessions and connected applications.
  static const String _portalUrl = 'https://ni-os.ru/id/account';

  final MenuController _menu = MenuController();

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.niosId));
    if (!mounted) return;
    AppToast.showSuccess(context, context.l10n.settingsE2eeCopyToast);
  }

  Future<void> _openPortal() async {
    final bool opened = await AppUrlLauncher.openUrl(context, _portalUrl);
    if (!opened && mounted) {
      AppToast.showError(context, context.l10n.settingsCouldNotOpenLink);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsAnchor(
      id: SettingId.accountNiosId.value,
      child: MenuAnchor(
        controller: _menu,
        // The portal is a browser page, so its entry says so before it opens.
        menuChildren: <Widget>[
          AppActionMenuItem(
            label: context.l10n.settingsAccountNiosIdCopy,
            icon: Icons.copy_rounded,
            onPressed: () => unawaited(_copy()),
          ).toMenuItem(context),
          AppActionMenuItem(
            label: context.l10n.settingsAccountNiosIdOpenPortal,
            icon: Icons.open_in_new_rounded,
            onPressed: () => unawaited(_openPortal()),
          ).toMenuItem(context),
        ],
        child: SettingsListItem(
          key: const ValueKey('settings-account-nios-id'),
          type: SettingsListItemType.choice,
          icon: Icons.badge_outlined,
          title: 'Nios ID',
          value: widget.niosId,
          onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
        ),
      ),
    );
  }
}
