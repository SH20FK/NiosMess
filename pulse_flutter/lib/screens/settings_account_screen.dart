import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
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
                title: context.l10n.profileUsername,
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
