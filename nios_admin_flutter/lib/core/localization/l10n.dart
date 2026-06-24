import 'package:flutter/widgets.dart';
import 'package:nios_admin_flutter/l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
