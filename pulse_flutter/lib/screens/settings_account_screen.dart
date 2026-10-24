import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
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

    return SettingsShell(
      title: context.l10n.settingsAccountTitle,
      isEmbedded: isEmbedded,
      children: <Widget>[
        SettingsSection(
          children: <Widget>[
            SettingsRow(
              anchor: SettingId.accountDisplayName.value,
              leading: Icon(
                Icons.person_outline_rounded,
                color: scheme.primary,
              ),
              title: context.l10n.profileDisplayName,
              control: ValueControl(displayName),
            ),
            if (username.isNotEmpty)
              SettingsRow(
                anchor: SettingId.accountUsername.value,
                leading: Icon(
                  Icons.alternate_email_rounded,
                  color: scheme.primary,
                ),
                title: context.l10n.profileUsername,
                control: ValueControl('@$username'),
              ),
            if (niosId != null && niosId.isNotEmpty)
              SettingsRow(
                anchor: SettingId.accountNiosId.value,
                leading: Icon(Icons.badge_outlined, color: scheme.primary),
                title: 'Nios ID',
                control: ValueControl(niosId),
              ),
          ],
        ),
        SettingsSection(
          children: [
            SettingsListItem.nav(
              icon: Icons.shield_outlined,
              title: context.l10n.settingsV2SecurityLink,
              subtitle: context.l10n.settingsV2SecurityLinkHint,
              onTap: () {
                if (kIsWeb) {
                  context.go('/main/settings?section=privacy');
                } else if (isEmbedded) {
                  ref
                      .read(desktopSelectedSettingsSectionProvider.notifier)
                      .setSelectedSection(SettingsSectionId.privacy);
                } else {
                  context.push('/settings/privacy');
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
