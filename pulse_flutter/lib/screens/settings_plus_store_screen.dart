import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/plus_purchase_options.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// Everything on the Nios+ page that spends or activates money: the catalogue
/// of plans, the FunPay checkout with its device-hash consent, and the
/// activation link of a purchase made elsewhere.
///
/// It is split from the settings page in `settings_plus_screen.dart` so that
/// page can stay a status page: what the subscription is, what it gives, and
/// one way in here.
class SettingsPlusStoreScreen extends ConsumerWidget {
  const SettingsPlusStoreScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The catalogue belongs to one account: a different session gets a fresh
    // widget instead of plans that were priced for somebody else.
    final (int?, String?) account = ref.watch(
      authProvider.select(
        (auth) => (auth.session?.userId, auth.session?.accessToken),
      ),
    );

    return SettingsShell(
      title: context.l10n.auditPlusPurchaseTitle,
      isEmbedded: isEmbedded,
      // The catalogue is the page, so the section needs no second heading.
      children: <Widget>[
        SettingsSection(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PlusPurchaseOptions(
                key: ValueKey<(int?, String?)>(account),
                onChanged: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}
