import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/l10n/secret/generated/secret_chat_localizations.dart';

extension SecretChatL10n on AppLocalizations {
  SecretChatLocalizations get _secret =>
      lookupSecretChatLocalizations(Locale(localeName.split('_').first));
  String get secretTitle => _secret.secretTitle;
  String get secretProtected => _secret.secretProtected;
  String get secretDescription => _secret.secretDescription;
  String get secretQueued => _secret.secretQueued;
  String get secretPreparing => _secret.secretPreparing;
  String get secretUpdateRequired => _secret.secretUpdateRequired;
  String get secretKeyChanged => _secret.secretKeyChanged;
  String get secretKeyChangedBody => _secret.secretKeyChangedBody;
  String get secretAcceptKey => _secret.secretAcceptKey;
  String get secretOtherDevice => _secret.secretOtherDevice;
  String get secretSignatureInvalid => _secret.secretSignatureInvalid;
  String get secretAdvanced => _secret.secretAdvanced;
  String get secretCompare => _secret.secretCompare;
  String get secretCodesMatch => _secret.secretCodesMatch;
  String get secretVerified => _secret.secretVerified;
  String get secretUnavailable => _secret.secretUnavailable;
  String get secretSaveFailed => _secret.secretSaveFailed;
  String get secretCreateFailed => _secret.secretCreateFailed;
  String get secretAttachmentSaveFailed => _secret.secretAttachmentSaveFailed;
  String get secretLocalOnly => _secret.secretLocalOnly;
  String get secretLogoutWarning => _secret.secretLogoutWarning;
  String get secretRetry => _secret.secretRetry;
  String get secretDeleteWarning => _secret.secretDeleteWarning;
  String get secretVerificationFailed => _secret.secretVerificationFailed;
}
