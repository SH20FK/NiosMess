// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'secret_chat_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SecretChatLocalizationsEn extends SecretChatLocalizations {
  SecretChatLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get secretTitle => 'Secret chat';

  @override
  String get secretProtected => 'Your conversation is protected';

  @override
  String get secretDescription =>
      'Messages are available only on your two devices. Protection is set up automatically.';

  @override
  String get secretQueued => 'Messages are saved and will send automatically';

  @override
  String get secretPreparing => 'Preparing a secure connection';

  @override
  String get secretUpdateRequired =>
      'Your contact needs to update the app. Your messages are saved.';

  @override
  String get secretKeyChanged => 'Your contact\'s security key changed';

  @override
  String get secretKeyChangedBody =>
      'Your messages are saved on this device. Confirm the new key to resume sending.';

  @override
  String get secretAcceptKey => 'Continue with the new key';

  @override
  String get secretOtherDevice => 'This chat belongs to another device';

  @override
  String get secretSignatureInvalid =>
      'Protection could not be verified. Sending is paused.';

  @override
  String get secretAdvanced => 'Verify protection';

  @override
  String get secretCompare =>
      'Optionally compare this code with your contact in person or through another trusted channel. This is not required to chat.';

  @override
  String get secretCodesMatch => 'The codes match';

  @override
  String get secretVerified => 'Code verified';

  @override
  String get secretUnavailable =>
      'This message is not yet available on this device';

  @override
  String get secretSaveFailed =>
      'Could not save the message. Your text is still in the composer.';

  @override
  String get secretCreateFailed =>
      'Could not open the secret chat. Please try again.';

  @override
  String get secretAttachmentSaveFailed =>
      'Could not save the attachment. Please try sending it again.';

  @override
  String get secretLocalOnly =>
      'Secret chat content is not shared with bots or AI.';

  @override
  String get secretLogoutWarning =>
      'Logging out deletes secret history and unsent messages on this device. Your contact\'s history is kept.';

  @override
  String get secretRetry => 'Retry sending';

  @override
  String get secretDeleteWarning =>
      'History, attachments and unsent messages on this device will be deleted. The other person\'s history will remain.';

  @override
  String get secretVerificationFailed =>
      'Could not save the key verification. Your messages have not been deleted.';
}
