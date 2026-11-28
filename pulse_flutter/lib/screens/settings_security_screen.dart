import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/widgets/settings/account_security_section.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// What guards the app, apart from who is allowed to see what: the app lock
/// with its timeout, the entry into the secret chats, and the switches that
/// harden them. The visibility rules stay on the Privacy screen, so each page
/// answers one question.
///
/// The route `/settings/security` opens this screen (wired by the router
/// owner); search anchors for its rows are registered in the settings
/// registry by the same integration.
class SettingsSecurityScreen extends ConsumerWidget {
  const SettingsSecurityScreen({this.isEmbedded = false, super.key});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLocalizations l = context.l10n;

    // The same three-way turn the Privacy screen takes: the web keeps one
    // address, a desktop pane switches its section, a phone pushes the page.
    void openSecretChats() {
      if (kIsWeb) {
        context.go('/main/settings?section=e2ee');
      } else if (isEmbedded) {
        ref
            .read(desktopSelectedSettingsSectionProvider.notifier)
            .setSelectedSection(SettingsSectionId.e2ee);
      } else {
        context.push('/settings/e2ee');
      }
    }

    return SettingsShell(
      title: l.settingsSecurityTitle,
      isEmbedded: isEmbedded,
      children: <Widget>[
        // App lock, its timeout and the Nios ID page.
        const AccountSecuritySection(),
        SettingsSection(
          children: <Widget>[
            SettingsRow(
              leading: Icon(
                Icons.enhanced_encryption_rounded,
                color: scheme.primary,
              ),
              title: l.settingsSecretChatsTitle,
              subtitle: l.settingsSecretChatsSubtitle,
              control: const NavigationControl(),
              onTap: openSecretChats,
            ),
            // Link previews and the screenshot guard are stored in
            // UiSettingsState, but nothing consumes them yet: there is no
            // preview pipeline and no platform secure-window flag. They stay
            // out of the UI until the behaviour lands, so the screen does not
            // promise a switch that changes nothing.
          ],
        ),
      ],
    );
  }
}
