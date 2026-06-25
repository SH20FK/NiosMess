import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';

extension L10nBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this) ?? (throw StateError(
    'AppLocalizations not found in context. '
    'Ensure this BuildContext is below a Localizations widget with AppLocalizations delegate.',
  ));
}
