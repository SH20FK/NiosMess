import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'secret_chat_localizations_en.dart';
import 'secret_chat_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of SecretChatLocalizations
/// returned by `SecretChatLocalizations.of(context)`.
///
/// Applications need to include `SecretChatLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/secret_chat_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: SecretChatLocalizations.localizationsDelegates,
///   supportedLocales: SecretChatLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the SecretChatLocalizations.supportedLocales
/// property.
abstract class SecretChatLocalizations {
  SecretChatLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static SecretChatLocalizations? of(BuildContext context) {
    return Localizations.of<SecretChatLocalizations>(
      context,
      SecretChatLocalizations,
    );
  }

  static const LocalizationsDelegate<SecretChatLocalizations> delegate =
      _SecretChatLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @updateIntegrityFailed.
  ///
  /// In en, this message translates to:
  /// **'The update file is incomplete or corrupted. Download it again.'**
  String get updateIntegrityFailed;

  /// No description provided for @callMediaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not access the microphone or camera. Check app permissions and try again.'**
  String get callMediaUnavailable;

  /// No description provided for @callConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect the call. Please try again.'**
  String get callConnectionFailed;

  /// No description provided for @callConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'The call disconnected. Please call again.'**
  String get callConnectionLost;

  /// No description provided for @callSignalingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not establish a secure call connection. Please try again.'**
  String get callSignalingFailed;

  /// No description provided for @callSoloTimeout.
  ///
  /// In en, this message translates to:
  /// **'Call ended: no one else joined.'**
  String get callSoloTimeout;

  /// No description provided for @callDurationLimit.
  ///
  /// In en, this message translates to:
  /// **'The call duration limit has been reached.'**
  String get callDurationLimit;

  /// No description provided for @secretTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret chat'**
  String get secretTitle;

  /// No description provided for @secretProtected.
  ///
  /// In en, this message translates to:
  /// **'Your conversation is protected'**
  String get secretProtected;

  /// No description provided for @secretDescription.
  ///
  /// In en, this message translates to:
  /// **'Messages are available only on your two devices. Protection is set up automatically.'**
  String get secretDescription;

  /// No description provided for @secretQueued.
  ///
  /// In en, this message translates to:
  /// **'Messages are saved and will send automatically'**
  String get secretQueued;

  /// No description provided for @secretPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing a secure connection'**
  String get secretPreparing;

  /// No description provided for @secretUpdateRequired.
  ///
  /// In en, this message translates to:
  /// **'Your contact needs to update the app. Your messages are saved.'**
  String get secretUpdateRequired;

  /// No description provided for @secretKeyChanged.
  ///
  /// In en, this message translates to:
  /// **'Your contact\'s security key changed'**
  String get secretKeyChanged;

  /// No description provided for @secretKeyChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Your messages are saved on this device. Confirm the new key to resume sending.'**
  String get secretKeyChangedBody;

  /// No description provided for @secretAcceptKey.
  ///
  /// In en, this message translates to:
  /// **'Continue with the new key'**
  String get secretAcceptKey;

  /// No description provided for @secretOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'This chat belongs to another device'**
  String get secretOtherDevice;

  /// No description provided for @secretSignatureInvalid.
  ///
  /// In en, this message translates to:
  /// **'Protection could not be verified. Sending is paused.'**
  String get secretSignatureInvalid;

  /// No description provided for @secretAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Verify protection'**
  String get secretAdvanced;

  /// No description provided for @secretCompare.
  ///
  /// In en, this message translates to:
  /// **'Optionally compare this code with your contact in person or through another trusted channel. This is not required to chat.'**
  String get secretCompare;

  /// No description provided for @secretCodesMatch.
  ///
  /// In en, this message translates to:
  /// **'The codes match'**
  String get secretCodesMatch;

  /// No description provided for @secretVerified.
  ///
  /// In en, this message translates to:
  /// **'Code verified'**
  String get secretVerified;

  /// No description provided for @secretUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This message is not yet available on this device'**
  String get secretUnavailable;

  /// No description provided for @secretSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the message. Your text is still in the composer.'**
  String get secretSaveFailed;

  /// No description provided for @secretCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the secret chat. Please try again.'**
  String get secretCreateFailed;

  /// No description provided for @secretAttachmentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the attachment. Please try sending it again.'**
  String get secretAttachmentSaveFailed;

  /// No description provided for @secretLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Secret chat content is not shared with bots or AI.'**
  String get secretLocalOnly;

  /// No description provided for @secretLogoutWarning.
  ///
  /// In en, this message translates to:
  /// **'Logging out deletes secret history and unsent messages on this device. Your contact\'s history is kept.'**
  String get secretLogoutWarning;

  /// No description provided for @secretRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry sending'**
  String get secretRetry;

  /// No description provided for @secretDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'History, attachments and unsent messages on this device will be deleted. The other person\'s history will remain.'**
  String get secretDeleteWarning;

  /// No description provided for @secretVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the key verification. Your messages have not been deleted.'**
  String get secretVerificationFailed;

  /// No description provided for @modalDeleteChatBody.
  ///
  /// In en, this message translates to:
  /// **'Remove this conversation from your chat list?'**
  String get modalDeleteChatBody;

  /// No description provided for @modalSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'End this session?'**
  String get modalSessionTitle;

  /// No description provided for @modalSessionBody.
  ///
  /// In en, this message translates to:
  /// **'The device “{device}” will be disconnected from your account.'**
  String modalSessionBody(String device);

  /// No description provided for @modalSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get modalSessionConfirm;

  /// No description provided for @modalSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'End all other sessions?'**
  String get modalSessionsTitle;

  /// No description provided for @modalSessionsBody.
  ///
  /// In en, this message translates to:
  /// **'Every device except this one will be disconnected from your account.'**
  String get modalSessionsBody;

  /// No description provided for @modalSessionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'End all other sessions'**
  String get modalSessionsConfirm;

  /// No description provided for @inboxActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get inboxActions;

  /// No description provided for @backgroundsPaused.
  ///
  /// In en, this message translates to:
  /// **'Backgrounds are temporarily disabled'**
  String get backgroundsPaused;

  /// No description provided for @inboxChatType.
  ///
  /// In en, this message translates to:
  /// **'Chat type'**
  String get inboxChatType;

  /// No description provided for @inboxCreateMenu.
  ///
  /// In en, this message translates to:
  /// **'Create…'**
  String get inboxCreateMenu;

  /// No description provided for @inboxComposeTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get inboxComposeTitle;

  /// No description provided for @inboxComposePersonHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a person or search by @username'**
  String get inboxComposePersonHint;

  /// No description provided for @inboxComposeGroupHint.
  ///
  /// In en, this message translates to:
  /// **'A conversation with several people'**
  String get inboxComposeGroupHint;

  /// No description provided for @inboxComposeChannelHint.
  ///
  /// In en, this message translates to:
  /// **'Posts for your subscribers'**
  String get inboxComposeChannelHint;

  /// No description provided for @inboxComposeSecretHint.
  ///
  /// In en, this message translates to:
  /// **'A private conversation with end-to-end encryption'**
  String get inboxComposeSecretHint;

  /// No description provided for @inboxJoinLink.
  ///
  /// In en, this message translates to:
  /// **'Join with a link'**
  String get inboxJoinLink;

  /// No description provided for @inboxJoinLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Open a group or channel invitation'**
  String get inboxJoinLinkHint;

  /// No description provided for @inboxEncryptedPreview.
  ///
  /// In en, this message translates to:
  /// **'Encrypted message'**
  String get inboxEncryptedPreview;

  /// No description provided for @inboxNoUnread.
  ///
  /// In en, this message translates to:
  /// **'You’re all caught up'**
  String get inboxNoUnread;

  /// No description provided for @inboxCategoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No chats in this category yet'**
  String get inboxCategoryEmpty;

  /// No description provided for @inboxFilterResetHint.
  ///
  /// In en, this message translates to:
  /// **'Select All to return to every chat'**
  String get inboxFilterResetHint;

  /// No description provided for @inboxSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get inboxSearchEmpty;

  /// No description provided for @inboxSearchEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Try another search'**
  String get inboxSearchEmptyHint;

  /// No description provided for @inboxWaitingToSend.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get inboxWaitingToSend;

  /// No description provided for @inboxSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent — retry in the chat'**
  String get inboxSendFailed;

  /// No description provided for @inboxDraftSemantics.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get inboxDraftSemantics;

  /// No description provided for @inboxDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'Draft:'**
  String get inboxDraftLabel;

  /// No description provided for @inboxDeleted.
  ///
  /// In en, this message translates to:
  /// **'Conversation deleted'**
  String get inboxDeleted;

  /// No description provided for @inboxDeleteNamed.
  ///
  /// In en, this message translates to:
  /// **'Delete chat “{name}”?'**
  String inboxDeleteNamed(String name);

  /// No description provided for @inboxLeaveNamed.
  ///
  /// In en, this message translates to:
  /// **'Leave “{name}”?'**
  String inboxLeaveNamed(String name);

  /// No description provided for @inboxRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh your chats. Try again.'**
  String get inboxRefreshFailed;

  /// No description provided for @interactiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get interactiveTitle;

  /// No description provided for @interactivePoll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get interactivePoll;

  /// No description provided for @interactiveQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get interactiveQuiz;

  /// No description provided for @interactiveList.
  ///
  /// In en, this message translates to:
  /// **'Shared list'**
  String get interactiveList;

  /// No description provided for @interactiveTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get interactiveTitleField;

  /// No description provided for @interactiveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get interactiveQuestion;

  /// No description provided for @interactiveTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get interactiveTitleRequired;

  /// No description provided for @interactiveQuestionRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a question'**
  String get interactiveQuestionRequired;

  /// No description provided for @interactiveOptions.
  ///
  /// In en, this message translates to:
  /// **'Answer options'**
  String get interactiveOptions;

  /// No description provided for @interactiveQuizOptions.
  ///
  /// In en, this message translates to:
  /// **'Answer options. Choose the correct one'**
  String get interactiveQuizOptions;

  /// No description provided for @interactiveFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Complete this field'**
  String get interactiveFieldRequired;

  /// No description provided for @interactiveDuplicateOptions.
  ///
  /// In en, this message translates to:
  /// **'Options must be different'**
  String get interactiveDuplicateOptions;

  /// No description provided for @interactiveItemNumber.
  ///
  /// In en, this message translates to:
  /// **'Item {number}'**
  String interactiveItemNumber(int number);

  /// No description provided for @interactiveOptionNumber.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String interactiveOptionNumber(int number);

  /// No description provided for @interactiveRemoveItem.
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get interactiveRemoveItem;

  /// No description provided for @interactiveRemoveOption.
  ///
  /// In en, this message translates to:
  /// **'Remove option'**
  String get interactiveRemoveOption;

  /// No description provided for @interactiveAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get interactiveAddItem;

  /// No description provided for @interactiveAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get interactiveAddOption;

  /// No description provided for @interactiveCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get interactiveCorrectAnswer;

  /// No description provided for @interactiveMultiple.
  ///
  /// In en, this message translates to:
  /// **'Multiple answers'**
  String get interactiveMultiple;

  /// No description provided for @interactiveExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation (optional)'**
  String get interactiveExplanation;

  /// No description provided for @interactiveExplanationHint.
  ///
  /// In en, this message translates to:
  /// **'Shown after answering'**
  String get interactiveExplanationHint;

  /// No description provided for @interactiveVotesVisible.
  ///
  /// In en, this message translates to:
  /// **'Participants can see who voted for each option.'**
  String get interactiveVotesVisible;

  /// No description provided for @interactiveSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get interactiveSend;

  /// No description provided for @interactiveSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send. Retry in the chat.'**
  String get interactiveSendFailed;

  /// No description provided for @interactiveSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Try again.'**
  String get interactiveSaveFailed;

  /// No description provided for @interactiveVoters.
  ///
  /// In en, this message translates to:
  /// **'Votes'**
  String get interactiveVoters;

  /// No description provided for @interactiveParticipant.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get interactiveParticipant;

  /// No description provided for @interactiveClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get interactiveClosed;

  /// No description provided for @interactiveOpenPoll.
  ///
  /// In en, this message translates to:
  /// **'Public poll'**
  String get interactiveOpenPoll;

  /// No description provided for @interactiveQuizClosed.
  ///
  /// In en, this message translates to:
  /// **'Quiz closed'**
  String get interactiveQuizClosed;

  /// No description provided for @interactivePollClosed.
  ///
  /// In en, this message translates to:
  /// **'Poll closed'**
  String get interactivePollClosed;

  /// No description provided for @interactiveQuizSingle.
  ///
  /// In en, this message translates to:
  /// **'Quiz, one answer'**
  String get interactiveQuizSingle;

  /// No description provided for @interactivePollMultiple.
  ///
  /// In en, this message translates to:
  /// **'Public poll, multiple answers'**
  String get interactivePollMultiple;

  /// No description provided for @interactivePollSingle.
  ///
  /// In en, this message translates to:
  /// **'Public poll, one answer'**
  String get interactivePollSingle;

  /// No description provided for @interactiveCorrectAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get interactiveCorrectAnswerLabel;

  /// No description provided for @interactiveItemReopened.
  ///
  /// In en, this message translates to:
  /// **'Item reopened'**
  String get interactiveItemReopened;

  /// No description provided for @interactiveItemCompleted.
  ///
  /// In en, this message translates to:
  /// **'Item completed'**
  String get interactiveItemCompleted;

  /// No description provided for @interactiveQuizAnswer.
  ///
  /// In en, this message translates to:
  /// **'Quiz answer'**
  String get interactiveQuizAnswer;

  /// No description provided for @interactiveCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get interactiveCorrect;

  /// No description provided for @interactiveIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get interactiveIncorrect;

  /// No description provided for @interactiveVoteEvent.
  ///
  /// In en, this message translates to:
  /// **'Poll vote'**
  String get interactiveVoteEvent;

  /// No description provided for @interactiveVote.
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get interactiveVote;

  /// No description provided for @interactiveChangeVote.
  ///
  /// In en, this message translates to:
  /// **'Change vote'**
  String get interactiveChangeVote;

  /// No description provided for @interactiveVoteRevoked.
  ///
  /// In en, this message translates to:
  /// **'Vote withdrawn'**
  String get interactiveVoteRevoked;

  /// No description provided for @interactiveRevoke.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get interactiveRevoke;

  /// No description provided for @interactiveLoadRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load. Retry'**
  String get interactiveLoadRetry;

  /// No description provided for @interactiveLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading updates…'**
  String get interactiveLoading;

  /// No description provided for @interactiveAfterSend.
  ///
  /// In en, this message translates to:
  /// **'Available after sending'**
  String get interactiveAfterSend;

  /// No description provided for @interactiveFinishList.
  ///
  /// In en, this message translates to:
  /// **'Close this list?'**
  String get interactiveFinishList;

  /// No description provided for @interactiveFinishPoll.
  ///
  /// In en, this message translates to:
  /// **'Close voting?'**
  String get interactiveFinishPoll;

  /// No description provided for @interactiveFinishBody.
  ///
  /// In en, this message translates to:
  /// **'Participants will no longer be able to change their answers.'**
  String get interactiveFinishBody;

  /// No description provided for @interactiveFinish.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get interactiveFinish;

  /// No description provided for @interactiveFinishedEvent.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get interactiveFinishedEvent;

  /// No description provided for @interactiveYourWrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer, incorrect'**
  String get interactiveYourWrongAnswer;

  /// No description provided for @interactiveYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get interactiveYourAnswer;

  /// No description provided for @interactiveSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get interactiveSaving;

  /// No description provided for @interactiveParticipantNumber.
  ///
  /// In en, this message translates to:
  /// **'Participant {id}'**
  String interactiveParticipantNumber(int id);

  /// No description provided for @interactiveCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'Completed {count} of {total}'**
  String interactiveCompletedCount(int count, int total);

  /// No description provided for @interactiveVoterCount.
  ///
  /// In en, this message translates to:
  /// **'Voters: {count}'**
  String interactiveVoterCount(int count);

  /// No description provided for @attachmentPhotoVideo.
  ///
  /// In en, this message translates to:
  /// **'Photo or video'**
  String get attachmentPhotoVideo;

  /// No description provided for @attachmentDocument.
  ///
  /// In en, this message translates to:
  /// **'File or document'**
  String get attachmentDocument;

  /// No description provided for @attachmentAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio file'**
  String get attachmentAudio;

  /// No description provided for @attachmentRecordCircle.
  ///
  /// In en, this message translates to:
  /// **'Record a video message'**
  String get attachmentRecordCircle;

  /// No description provided for @recordCircleDesktopHint.
  ///
  /// In en, this message translates to:
  /// **'Video message: click to record, right-click for microphone'**
  String get recordCircleDesktopHint;

  /// No description provided for @recordVoiceDesktopHint.
  ///
  /// In en, this message translates to:
  /// **'Voice message: click to record, right-click for video'**
  String get recordVoiceDesktopHint;

  /// No description provided for @recordSwitchVoice.
  ///
  /// In en, this message translates to:
  /// **'Switch to microphone'**
  String get recordSwitchVoice;

  /// No description provided for @recordSwitchCircle.
  ///
  /// In en, this message translates to:
  /// **'Switch to video message'**
  String get recordSwitchCircle;

  /// No description provided for @deliverySent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get deliverySent;

  /// No description provided for @deliveryRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get deliveryRead;

  /// No description provided for @webWorkspaceHint.
  ///
  /// In en, this message translates to:
  /// **'Select a chat on the left. Ctrl + Alt + N starts a conversation.'**
  String get webWorkspaceHint;

  /// No description provided for @videoPreview.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get videoPreview;

  /// No description provided for @webAutoDownload.
  ///
  /// In en, this message translates to:
  /// **'Download media automatically'**
  String get webAutoDownload;

  /// No description provided for @webMotionTitle.
  ///
  /// In en, this message translates to:
  /// **'Motion and performance'**
  String get webMotionTitle;

  /// No description provided for @webDownloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get webDownloadStarted;

  /// No description provided for @pasteImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Send image?'**
  String get pasteImageTitle;

  /// No description provided for @pasteImageCaption.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get pasteImageCaption;

  /// No description provided for @pasteImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the clipboard image'**
  String get pasteImageFailed;

  /// No description provided for @pasteImageLimit.
  ///
  /// In en, this message translates to:
  /// **'Paste up to 8 images, totaling up to 40 MB'**
  String get pasteImageLimit;

  /// No description provided for @pasteImageSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the attachment. The image is still here; try sending again.'**
  String get pasteImageSendFailed;

  /// No description provided for @pasteImageCount.
  ///
  /// In en, this message translates to:
  /// **'Images remaining: {count}'**
  String pasteImageCount(int count);

  /// No description provided for @webStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser data'**
  String get webStorageTitle;

  /// No description provided for @webStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'Your browser manages this site’s storage. Disk usage and system temporary files are unavailable here. Clearing site data in your browser also deletes local secret chats and the outgoing queue.'**
  String get webStorageDescription;

  /// No description provided for @webStorageDrafts.
  ///
  /// In en, this message translates to:
  /// **'Regular chat drafts'**
  String get webStorageDrafts;

  /// No description provided for @webStorageDraftsDescription.
  ///
  /// In en, this message translates to:
  /// **'Saved in this browser. Secret drafts are stored separately.'**
  String get webStorageDraftsDescription;

  /// No description provided for @callDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio and camera'**
  String get callDevicesTitle;

  /// No description provided for @callDevicesLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Tests stay on this device: audio and video are not sent anywhere.'**
  String get callDevicesLocalHint;

  /// No description provided for @callDevicesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not list devices'**
  String get callDevicesUnavailable;

  /// No description provided for @callDevicesPermission.
  ///
  /// In en, this message translates to:
  /// **'Could not open the microphone or camera. Check permissions or select another device.'**
  String get callDevicesPermission;

  /// No description provided for @callDevicesApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch devices. Select an available device and try again.'**
  String get callDevicesApplyFailed;

  /// No description provided for @callDeviceDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get callDeviceDefault;

  /// No description provided for @callDeviceMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get callDeviceMicrophone;

  /// No description provided for @callDeviceCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get callDeviceCamera;

  /// No description provided for @callDeviceOutput.
  ///
  /// In en, this message translates to:
  /// **'Headphones and speakers'**
  String get callDeviceOutput;

  /// No description provided for @callDeviceSpeak.
  ///
  /// In en, this message translates to:
  /// **'Say something: the meter shows your microphone level'**
  String get callDeviceSpeak;

  /// No description provided for @callDeviceLevelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Microphone is open. This device does not report its input level.'**
  String get callDeviceLevelUnavailable;

  /// No description provided for @callDeviceTest.
  ///
  /// In en, this message translates to:
  /// **'Test microphone and camera'**
  String get callDeviceTest;

  /// No description provided for @callDeviceTestSound.
  ///
  /// In en, this message translates to:
  /// **'Test speakers'**
  String get callDeviceTestSound;

  /// No description provided for @callDeviceTestSystemSound.
  ///
  /// In en, this message translates to:
  /// **'Test system audio'**
  String get callDeviceTestSystemSound;

  /// No description provided for @callDeviceOutputUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This output cannot be selected. Check your devices and browser or system sound settings.'**
  String get callDeviceOutputUnavailable;

  /// No description provided for @callDeviceStart.
  ///
  /// In en, this message translates to:
  /// **'Start call'**
  String get callDeviceStart;

  /// No description provided for @callQualityReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get callQualityReconnecting;

  /// No description provided for @callQualityMeasuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring connection…'**
  String get callQualityMeasuring;

  /// No description provided for @callQualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good connection'**
  String get callQualityGood;

  /// No description provided for @callQualityFair.
  ///
  /// In en, this message translates to:
  /// **'Unstable connection'**
  String get callQualityFair;

  /// No description provided for @callQualityPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor connection'**
  String get callQualityPoor;

  /// No description provided for @callQualityLatency.
  ///
  /// In en, this message translates to:
  /// **'high latency'**
  String get callQualityLatency;

  /// No description provided for @callQualityLoss.
  ///
  /// In en, this message translates to:
  /// **'packet loss'**
  String get callQualityLoss;

  /// No description provided for @callQualityJitter.
  ///
  /// In en, this message translates to:
  /// **'uneven packet timing'**
  String get callQualityJitter;

  /// No description provided for @callQualityBandwidth.
  ///
  /// In en, this message translates to:
  /// **'limited bandwidth'**
  String get callQualityBandwidth;

  /// No description provided for @callQualityCpu.
  ///
  /// In en, this message translates to:
  /// **'device is struggling to encode video'**
  String get callQualityCpu;

  /// No description provided for @stickerHubSearch.
  ///
  /// In en, this message translates to:
  /// **'Search emoji and pack names'**
  String get stickerHubSearch;

  /// No description provided for @stickerHubRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get stickerHubRecent;

  /// No description provided for @stickerHubEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stickers here yet'**
  String get stickerHubEmpty;

  /// No description provided for @stickerHubEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a pack or create your own. Sent stickers appear in Recent.'**
  String get stickerHubEmptyHint;

  /// No description provided for @stickerHubLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load stickers'**
  String get stickerHubLoadError;

  /// No description provided for @stickerHubCreate.
  ///
  /// In en, this message translates to:
  /// **'Create pack'**
  String get stickerHubCreate;

  /// No description provided for @stickerHubAdd.
  ///
  /// In en, this message translates to:
  /// **'Add stickers'**
  String get stickerHubAdd;

  /// No description provided for @stickerHubDetails.
  ///
  /// In en, this message translates to:
  /// **'Pack details'**
  String get stickerHubDetails;

  /// No description provided for @stickerHubEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get stickerHubEmoji;

  /// No description provided for @stickerHubStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get stickerHubStickers;

  /// No description provided for @stickerHubNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get stickerHubNoResults;

  /// No description provided for @chatDropFiles.
  ///
  /// In en, this message translates to:
  /// **'Drop files to preview'**
  String get chatDropFiles;

  /// No description provided for @chatDropError.
  ///
  /// In en, this message translates to:
  /// **'Could not read these files. Try the attachment button.'**
  String get chatDropError;

  /// No description provided for @chatBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Send attachments?'**
  String get chatBatchTitle;

  /// No description provided for @chatBatchAlbum.
  ///
  /// In en, this message translates to:
  /// **'Group photos into an album'**
  String get chatBatchAlbum;

  /// No description provided for @chatBatchSeparate.
  ///
  /// In en, this message translates to:
  /// **'Send as separate files'**
  String get chatBatchSeparate;

  /// No description provided for @chatBatchRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get chatBatchRemove;

  /// No description provided for @chatBatchLimit.
  ///
  /// In en, this message translates to:
  /// **'Add up to 10 files, totaling up to 100 MB'**
  String get chatBatchLimit;

  /// No description provided for @chatAlbumOpen.
  ///
  /// In en, this message translates to:
  /// **'Open album'**
  String get chatAlbumOpen;

  /// No description provided for @chatAlbumPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous photo'**
  String get chatAlbumPrevious;

  /// No description provided for @chatAlbumNext.
  ///
  /// In en, this message translates to:
  /// **'Next photo'**
  String get chatAlbumNext;

  /// No description provided for @callDeviceMissing.
  ///
  /// In en, this message translates to:
  /// **'device unavailable'**
  String get callDeviceMissing;

  /// No description provided for @noticeOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get noticeOpenChat;

  /// No description provided for @noticeOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get noticeOpen;

  /// No description provided for @noticeReadChat.
  ///
  /// In en, this message translates to:
  /// **'Read entire chat'**
  String get noticeReadChat;

  /// No description provided for @noticeMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get noticeMarkAllRead;

  /// No description provided for @noticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get noticeTitle;

  /// No description provided for @noticeEmpty.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get noticeEmpty;

  /// No description provided for @noticeEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Messages and activity for this account are saved here.'**
  String get noticeEmptyHint;

  /// No description provided for @noticeClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get noticeClose;

  /// No description provided for @noticeClear.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get noticeClear;

  /// No description provided for @noticePermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'System notifications are allowed'**
  String get noticePermissionGranted;

  /// No description provided for @noticePermissionMissing.
  ///
  /// In en, this message translates to:
  /// **'Push requires system permission'**
  String get noticePermissionMissing;

  /// No description provided for @noticePermissionHint.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications for NiosMess in your browser or device settings.'**
  String get noticePermissionHint;

  /// No description provided for @noticeDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'These preferences apply to this device. The open chat does not show duplicate alerts.'**
  String get noticeDeviceHint;

  /// No description provided for @noticeMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get noticeMessages;

  /// No description provided for @noticeCalls.
  ///
  /// In en, this message translates to:
  /// **'Incoming calls'**
  String get noticeCalls;

  /// No description provided for @noticeActivity.
  ///
  /// In en, this message translates to:
  /// **'NiosGram activity'**
  String get noticeActivity;

  /// No description provided for @noticePreview.
  ///
  /// In en, this message translates to:
  /// **'Show message preview'**
  String get noticePreview;

  /// No description provided for @noticePreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Secret message contents are always hidden in system push.'**
  String get noticePreviewHint;

  /// No description provided for @noticeSound.
  ///
  /// In en, this message translates to:
  /// **'Notification sound'**
  String get noticeSound;

  /// No description provided for @noticeSoundHint.
  ///
  /// In en, this message translates to:
  /// **'System channel sounds can also be changed in OS settings.'**
  String get noticeSoundHint;

  /// No description provided for @noticeMessagesChannel.
  ///
  /// In en, this message translates to:
  /// **'NiosMess messages'**
  String get noticeMessagesChannel;

  /// No description provided for @noticeCallsChannel.
  ///
  /// In en, this message translates to:
  /// **'NiosMess calls'**
  String get noticeCallsChannel;

  /// No description provided for @noticeUpdatesChannel.
  ///
  /// In en, this message translates to:
  /// **'NiosMess updates'**
  String get noticeUpdatesChannel;

  /// No description provided for @noticeIncomingCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get noticeIncomingCall;

  /// No description provided for @noticeIncomingVideo.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get noticeIncomingVideo;

  /// No description provided for @noticeAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get noticeAccept;

  /// No description provided for @noticeDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get noticeDecline;

  /// No description provided for @noticeNewMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get noticeNewMessage;

  /// No description provided for @noticeEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted message'**
  String get noticeEncrypted;

  /// No description provided for @noticeBackground.
  ///
  /// In en, this message translates to:
  /// **'Background operation is enabled'**
  String get noticeBackground;

  /// No description provided for @noticeEconomy.
  ///
  /// In en, this message translates to:
  /// **'Save battery'**
  String get noticeEconomy;

  /// No description provided for @noticeSoundTest.
  ///
  /// In en, this message translates to:
  /// **'Test sound'**
  String get noticeSoundTest;

  /// No description provided for @noticeSoundTestHint.
  ///
  /// In en, this message translates to:
  /// **'Tap, message, success and error'**
  String get noticeSoundTestHint;

  /// No description provided for @noticeSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update push on the server. Your preference is saved and will retry on connection.'**
  String get noticeSyncFailed;

  /// No description provided for @noticeCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get noticeCopied;

  /// No description provided for @noticeUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading NiosMess update'**
  String get noticeUpdateDownloading;

  /// No description provided for @noticeUpdateReady.
  ///
  /// In en, this message translates to:
  /// **'NiosMess update is ready'**
  String get noticeUpdateReady;

  /// No description provided for @noticeUpdateTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to install'**
  String get noticeUpdateTap;

  /// No description provided for @noticeVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get noticeVersion;

  /// No description provided for @noticeInAppOnly.
  ///
  /// In en, this message translates to:
  /// **'This device supports in-app notifications'**
  String get noticeInAppOnly;

  /// No description provided for @noticePostLike.
  ///
  /// In en, this message translates to:
  /// **'Reaction to your post'**
  String get noticePostLike;

  /// No description provided for @noticePostComment.
  ///
  /// In en, this message translates to:
  /// **'Comment on your post'**
  String get noticePostComment;

  /// No description provided for @noticeAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get noticeAttachment;

  /// No description provided for @noticeReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get noticeReply;

  /// No description provided for @noticeMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get noticeMarkRead;

  /// No description provided for @noticeReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get noticeReplyHint;

  /// No description provided for @noticeSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get noticeSend;

  /// No description provided for @noticeSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get noticeSending;

  /// No description provided for @noticeReplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send. Your text is still here — try again.'**
  String get noticeReplyFailed;

  /// No description provided for @noticeReplySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the draft. Your text is still here.'**
  String get noticeReplySaveFailed;

  /// No description provided for @noticeDeviceRegistered.
  ///
  /// In en, this message translates to:
  /// **'This device is registered for push'**
  String get noticeDeviceRegistered;

  /// No description provided for @noticeDevicePending.
  ///
  /// In en, this message translates to:
  /// **'Push registration is waiting for connection'**
  String get noticeDevicePending;

  /// No description provided for @noticeUiSoundsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap and action sounds. Notification sounds are configured separately.'**
  String get noticeUiSoundsHint;

  /// No description provided for @noticeSilentMessages.
  ///
  /// In en, this message translates to:
  /// **'Silent messages'**
  String get noticeSilentMessages;

  /// No description provided for @settingsV2Appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsV2Appearance;

  /// No description provided for @settingsV2AppearanceHint.
  ///
  /// In en, this message translates to:
  /// **'Theme, palette, text and interface density'**
  String get settingsV2AppearanceHint;

  /// No description provided for @settingsV2Chats.
  ///
  /// In en, this message translates to:
  /// **'Chats and calls'**
  String get settingsV2Chats;

  /// No description provided for @settingsV2ChatsHint.
  ///
  /// In en, this message translates to:
  /// **'Typing, reactions, microphone and camera'**
  String get settingsV2ChatsHint;

  /// No description provided for @settingsV2Notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications and sounds'**
  String get settingsV2Notifications;

  /// No description provided for @settingsV2NotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Push, message previews, sound and vibration'**
  String get settingsV2NotificationsHint;

  /// No description provided for @settingsV2Privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get settingsV2Privacy;

  /// No description provided for @settingsV2PrivacyHint.
  ///
  /// In en, this message translates to:
  /// **'Visibility, account access and encryption'**
  String get settingsV2PrivacyHint;

  /// No description provided for @settingsV2Storage.
  ///
  /// In en, this message translates to:
  /// **'Data and storage'**
  String get settingsV2Storage;

  /// No description provided for @settingsV2StorageHint.
  ///
  /// In en, this message translates to:
  /// **'Cache, media downloads and device data'**
  String get settingsV2StorageHint;

  /// No description provided for @settingsV2Motion.
  ///
  /// In en, this message translates to:
  /// **'Motion and battery'**
  String get settingsV2Motion;

  /// No description provided for @settingsV2MotionHint.
  ///
  /// In en, this message translates to:
  /// **'Stickers, emoji and performance'**
  String get settingsV2MotionHint;

  /// No description provided for @settingsV2Language.
  ///
  /// In en, this message translates to:
  /// **'Language and time'**
  String get settingsV2Language;

  /// No description provided for @settingsV2LanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Interface language and time zone'**
  String get settingsV2LanguageHint;

  /// No description provided for @settingsV2About.
  ///
  /// In en, this message translates to:
  /// **'Help and about'**
  String get settingsV2About;

  /// No description provided for @settingsV2AboutHint.
  ///
  /// In en, this message translates to:
  /// **'Version, updates, help and documents'**
  String get settingsV2AboutHint;

  /// No description provided for @settingsV2GroupCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication and appearance'**
  String get settingsV2GroupCommunication;

  /// No description provided for @settingsV2GroupPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and data'**
  String get settingsV2GroupPrivacy;

  /// No description provided for @settingsV2GroupApplication.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get settingsV2GroupApplication;

  /// No description provided for @settingsV2Search.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsV2Search;

  /// No description provided for @settingsV2SearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Find a setting by its name or action'**
  String get settingsV2SearchEmpty;

  /// No description provided for @settingsV2SearchNone.
  ///
  /// In en, this message translates to:
  /// **'No results. Try a different word.'**
  String get settingsV2SearchNone;

  /// No description provided for @settingsV2AccountHint.
  ///
  /// In en, this message translates to:
  /// **'Profile and account management'**
  String get settingsV2AccountHint;

  /// No description provided for @settingsV2NiosId.
  ///
  /// In en, this message translates to:
  /// **'Manage Nios ID'**
  String get settingsV2NiosId;

  /// No description provided for @settingsV2Qr.
  ///
  /// In en, this message translates to:
  /// **'My QR code'**
  String get settingsV2Qr;

  /// No description provided for @settingsV2Share.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get settingsV2Share;

  /// No description provided for @settingsV2More.
  ///
  /// In en, this message translates to:
  /// **'Profile actions'**
  String get settingsV2More;

  /// No description provided for @settingsV2Advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsV2Advanced;

  /// No description provided for @settingsV2GeometryHint.
  ///
  /// In en, this message translates to:
  /// **'Corners of cards and system panels'**
  String get settingsV2GeometryHint;

  /// No description provided for @settingsV2Density.
  ///
  /// In en, this message translates to:
  /// **'Interface density'**
  String get settingsV2Density;

  /// No description provided for @settingsV2Graphics.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get settingsV2Graphics;

  /// No description provided for @settingsV2OptimizeHint.
  ///
  /// In en, this message translates to:
  /// **'Simplify visual effects for smoother performance'**
  String get settingsV2OptimizeHint;

  /// No description provided for @settingsV2ChatAnimations.
  ///
  /// In en, this message translates to:
  /// **'Chat animations'**
  String get settingsV2ChatAnimations;

  /// No description provided for @settingsV2ChatAnimationsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose which effects play automatically'**
  String get settingsV2ChatAnimationsHint;

  /// No description provided for @settingsV2Stickers.
  ///
  /// In en, this message translates to:
  /// **'Animated stickers'**
  String get settingsV2Stickers;

  /// No description provided for @settingsV2StickersHint.
  ///
  /// In en, this message translates to:
  /// **'Play sticker animations in messages'**
  String get settingsV2StickersHint;

  /// No description provided for @settingsV2Emoji.
  ///
  /// In en, this message translates to:
  /// **'Animated emoji'**
  String get settingsV2Emoji;

  /// No description provided for @settingsV2EmojiHint.
  ///
  /// In en, this message translates to:
  /// **'Play emoji animations in messages'**
  String get settingsV2EmojiHint;

  /// No description provided for @settingsV2Off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsV2Off;

  /// No description provided for @settingsV2Reset.
  ///
  /// In en, this message translates to:
  /// **'Reset local preferences'**
  String get settingsV2Reset;

  /// No description provided for @settingsV2ResetHint.
  ///
  /// In en, this message translates to:
  /// **'Restore default appearance and behavior. Message history is kept.'**
  String get settingsV2ResetHint;

  /// No description provided for @settingsV2LockTimeout.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get settingsV2LockTimeout;

  /// No description provided for @settingsV2LockTimeoutHint.
  ///
  /// In en, this message translates to:
  /// **'When to lock the app after it goes to the background'**
  String get settingsV2LockTimeoutHint;

  /// No description provided for @settingsV2BiometricFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not verify your identity'**
  String get settingsV2BiometricFailure;

  /// No description provided for @settingsV2ReadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Read receipts'**
  String get settingsV2ReadReceipts;

  /// No description provided for @settingsV2ReadReceiptsHint.
  ///
  /// In en, this message translates to:
  /// **'Show when you have read a message'**
  String get settingsV2ReadReceiptsHint;

  /// No description provided for @settingsV2Typing.
  ///
  /// In en, this message translates to:
  /// **'Typing indicator'**
  String get settingsV2Typing;

  /// No description provided for @settingsV2TypingHint.
  ///
  /// In en, this message translates to:
  /// **'Let others see when you are typing'**
  String get settingsV2TypingHint;

  /// No description provided for @settingsV2ReadSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save read receipt settings'**
  String get settingsV2ReadSaveFailed;

  /// No description provided for @settingsV2TypingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save typing settings'**
  String get settingsV2TypingSaveFailed;

  /// No description provided for @settingsV2StorageDetails.
  ///
  /// In en, this message translates to:
  /// **'Storage usage'**
  String get settingsV2StorageDetails;

  /// No description provided for @settingsV2StorageDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Downloaded media and temporary files'**
  String get settingsV2StorageDetailsHint;

  /// No description provided for @settingsV2AutoDownload.
  ///
  /// In en, this message translates to:
  /// **'Automatic media downloads'**
  String get settingsV2AutoDownload;

  /// No description provided for @settingsV2AutoDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'Choose when to download photos, videos and voice messages'**
  String get settingsV2AutoDownloadHint;

  /// No description provided for @settingsV2Wifi.
  ///
  /// In en, this message translates to:
  /// **'On Wi-Fi'**
  String get settingsV2Wifi;

  /// No description provided for @settingsV2MobileData.
  ///
  /// In en, this message translates to:
  /// **'On mobile data'**
  String get settingsV2MobileData;

  /// No description provided for @settingsV2MobileDataHint.
  ///
  /// In en, this message translates to:
  /// **'May use your mobile data allowance'**
  String get settingsV2MobileDataHint;

  /// No description provided for @settingsV2SecretCache.
  ///
  /// In en, this message translates to:
  /// **'Secret chat cache'**
  String get settingsV2SecretCache;

  /// No description provided for @settingsV2SecretCacheHint.
  ///
  /// In en, this message translates to:
  /// **'Decrypted messages on this device'**
  String get settingsV2SecretCacheHint;

  /// No description provided for @settingsV2ClearSecretCache.
  ///
  /// In en, this message translates to:
  /// **'Clear secret chat cache'**
  String get settingsV2ClearSecretCache;

  /// No description provided for @settingsV2Diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Device diagnostics'**
  String get settingsV2Diagnostics;

  /// No description provided for @settingsV2DiagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'System and hardware information'**
  String get settingsV2DiagnosticsHint;

  /// No description provided for @settingsV2StorageImages.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get settingsV2StorageImages;

  /// No description provided for @settingsV2StorageVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get settingsV2StorageVideos;

  /// No description provided for @settingsV2StorageAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsV2StorageAudio;

  /// No description provided for @settingsV2StorageFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get settingsV2StorageFiles;

  /// No description provided for @settingsV2StorageStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get settingsV2StorageStickers;

  /// No description provided for @settingsV2StorageAvatars.
  ///
  /// In en, this message translates to:
  /// **'Avatars'**
  String get settingsV2StorageAvatars;

  /// No description provided for @settingsV2StorageDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get settingsV2StorageDrafts;

  /// No description provided for @settingsV2StorageOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settingsV2StorageOther;

  /// No description provided for @settingsV2SecurityLink.
  ///
  /// In en, this message translates to:
  /// **'Security settings'**
  String get settingsV2SecurityLink;

  /// No description provided for @settingsV2SecurityLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Sessions, app lock and account protection'**
  String get settingsV2SecurityLinkHint;

  /// No description provided for @settingsV2ProfileCopied.
  ///
  /// In en, this message translates to:
  /// **'Profile link copied'**
  String get settingsV2ProfileCopied;

  /// No description provided for @settingsV2IdCopied.
  ///
  /// In en, this message translates to:
  /// **'Nios ID copied'**
  String get settingsV2IdCopied;

  /// No description provided for @settingsV2Economy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get settingsV2Economy;

  /// No description provided for @settingsV2Reliable.
  ///
  /// In en, this message translates to:
  /// **'Reliable'**
  String get settingsV2Reliable;

  /// No description provided for @settingsV2BackgroundOff.
  ///
  /// In en, this message translates to:
  /// **'The background connection is off. Push notifications still use FCM.'**
  String get settingsV2BackgroundOff;

  /// No description provided for @settingsV2Preview.
  ///
  /// In en, this message translates to:
  /// **'Show message text'**
  String get settingsV2Preview;

  /// No description provided for @settingsV2StorageError.
  ///
  /// In en, this message translates to:
  /// **'Could not load storage data'**
  String get settingsV2StorageError;

  /// No description provided for @settingsV2ClearCategory.
  ///
  /// In en, this message translates to:
  /// **'Clear files in this category?'**
  String get settingsV2ClearCategory;

  /// No description provided for @settingsV2ClearCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Files in this category will be removed from the local cache.'**
  String get settingsV2ClearCategoryHint;

  /// No description provided for @settingsV2SecretCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'All decrypted secret-chat messages on this device will be deleted. This cannot be undone.'**
  String get settingsV2SecretCacheConfirm;

  /// No description provided for @settingsV2ResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset local preferences?'**
  String get settingsV2ResetConfirm;

  /// No description provided for @settingsV2ResetBody.
  ///
  /// In en, this message translates to:
  /// **'Appearance, language, sounds, notifications and other app preferences will reset. Chats, files, keys and server privacy settings will remain.'**
  String get settingsV2ResetBody;

  /// No description provided for @settingsV2ResetDone.
  ///
  /// In en, this message translates to:
  /// **'Local preferences reset'**
  String get settingsV2ResetDone;

  /// No description provided for @settingsV2ResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reset preferences'**
  String get settingsV2ResetFailed;

  /// No description provided for @pickerClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get pickerClearSearch;

  /// No description provided for @pickerFaces.
  ///
  /// In en, this message translates to:
  /// **'Smileys'**
  String get pickerFaces;

  /// No description provided for @pickerAnimals.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get pickerAnimals;

  /// No description provided for @pickerFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get pickerFood;

  /// No description provided for @pickerActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get pickerActivities;

  /// No description provided for @pickerTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get pickerTravel;

  /// No description provided for @pickerObjects.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get pickerObjects;

  /// No description provided for @pickerSymbols.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get pickerSymbols;

  /// No description provided for @pickerFlags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get pickerFlags;

  /// No description provided for @pickerSearchEmoji.
  ///
  /// In en, this message translates to:
  /// **'Search emoji'**
  String get pickerSearchEmoji;

  /// No description provided for @pickerNoRecents.
  ///
  /// In en, this message translates to:
  /// **'Your recent emoji will appear here'**
  String get pickerNoRecents;

  /// No description provided for @pickerCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get pickerCustom;

  /// No description provided for @pickerCompact.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get pickerCompact;

  /// No description provided for @pickerLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get pickerLibrary;

  /// No description provided for @pickerSearchPacks.
  ///
  /// In en, this message translates to:
  /// **'Search packs'**
  String get pickerSearchPacks;

  /// No description provided for @pickerManage.
  ///
  /// In en, this message translates to:
  /// **'Manage packs'**
  String get pickerManage;

  /// No description provided for @customEmojiTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom emoji'**
  String get customEmojiTitle;

  /// No description provided for @customContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get customContinue;

  /// No description provided for @customCreateSet.
  ///
  /// In en, this message translates to:
  /// **'Create emoji pack'**
  String get customCreateSet;

  /// No description provided for @customSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get customSetTitle;

  /// No description provided for @customSetName.
  ///
  /// In en, this message translates to:
  /// **'Pack name in Latin letters'**
  String get customSetName;

  /// No description provided for @customAddSet.
  ///
  /// In en, this message translates to:
  /// **'Add emoji pack'**
  String get customAddSet;

  /// No description provided for @customAddEmoji.
  ///
  /// In en, this message translates to:
  /// **'Add emoji'**
  String get customAddEmoji;

  /// No description provided for @customRemoveSet.
  ///
  /// In en, this message translates to:
  /// **'Remove from my packs'**
  String get customRemoveSet;

  /// No description provided for @customShortcode.
  ///
  /// In en, this message translates to:
  /// **'Shortcode: letters, numbers, _'**
  String get customShortcode;

  /// No description provided for @customFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Choose an image up to 512 KB'**
  String get customFileTooLarge;

  /// No description provided for @customTooManyFrames.
  ///
  /// In en, this message translates to:
  /// **'Too many frames in this emoji'**
  String get customTooManyFrames;

  /// No description provided for @customEmptySet.
  ///
  /// In en, this message translates to:
  /// **'This pack has no emoji yet'**
  String get customEmptySet;

  /// No description provided for @auditSystemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get auditSystemLanguage;

  /// No description provided for @auditPostPublished.
  ///
  /// In en, this message translates to:
  /// **'Post published'**
  String get auditPostPublished;

  /// No description provided for @auditCommentSend.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get auditCommentSend;

  /// No description provided for @auditCommentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete comment?'**
  String get auditCommentDeleteTitle;

  /// No description provided for @auditCommentDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Replies will remain in the discussion.'**
  String get auditCommentDeleteBody;

  /// No description provided for @auditCommentLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more comments'**
  String get auditCommentLoadMore;

  /// No description provided for @auditCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Comment or ask @ai'**
  String get auditCommentHint;

  /// No description provided for @auditCommentEditing.
  ///
  /// In en, this message translates to:
  /// **'Editing comment'**
  String get auditCommentEditing;

  /// No description provided for @auditCommentReply.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}'**
  String auditCommentReply(String name);

  /// No description provided for @auditCommentReported.
  ///
  /// In en, this message translates to:
  /// **'Quality report sent'**
  String get auditCommentReported;

  /// No description provided for @auditCommentAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get auditCommentAuthor;

  /// No description provided for @auditCommentChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get auditCommentChannel;

  /// No description provided for @auditPostMedia.
  ///
  /// In en, this message translates to:
  /// **'Media file'**
  String get auditPostMedia;

  /// No description provided for @auditPostQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get auditPostQuiz;

  /// No description provided for @auditPostPoll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get auditPostPoll;

  /// No description provided for @auditPlusSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with NiosID'**
  String get auditPlusSignIn;

  /// No description provided for @auditPlusCatalogUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plans are unavailable'**
  String get auditPlusCatalogUnavailable;

  /// No description provided for @auditPlusCatalogLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load plans. You can still activate a purchased link below.'**
  String get auditPlusCatalogLoadFailed;

  /// No description provided for @auditPlusActivationLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'Paste the full activation link from your order'**
  String get auditPlusActivationLinkInvalid;

  /// No description provided for @auditPlusAccountChanged.
  ///
  /// In en, this message translates to:
  /// **'Account changed. Refresh plans before purchasing.'**
  String get auditPlusAccountChanged;

  /// No description provided for @auditPlusProductUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The product address is unavailable. Try refreshing plans.'**
  String get auditPlusProductUnavailable;

  /// No description provided for @auditPlusOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open FunPay'**
  String get auditPlusOpenFailed;

  /// No description provided for @auditPlusNativeOnly.
  ///
  /// In en, this message translates to:
  /// **'Purchase and activation are available in the mobile and desktop NiosMess app.'**
  String get auditPlusNativeOnly;

  /// No description provided for @auditPlusSupportedPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Purchase and activation are currently available on Android, Windows and Linux.'**
  String get auditPlusSupportedPlatforms;

  /// No description provided for @auditPlusPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase and renewal'**
  String get auditPlusPurchaseTitle;

  /// No description provided for @auditPlusPromoLimit.
  ///
  /// In en, this message translates to:
  /// **'Once per account, IP address and device'**
  String get auditPlusPromoLimit;

  /// No description provided for @auditPlusBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get auditPlusBuy;

  /// No description provided for @auditPlusSalesPending.
  ///
  /// In en, this message translates to:
  /// **'Sales have not opened yet. You can activate a purchased link below.'**
  String get auditPlusSalesPending;

  /// No description provided for @auditPlusRefreshPlans.
  ///
  /// In en, this message translates to:
  /// **'Refresh plans'**
  String get auditPlusRefreshPlans;

  /// No description provided for @auditPlusAlreadyPurchased.
  ///
  /// In en, this message translates to:
  /// **'Already purchased NiosPlus?'**
  String get auditPlusAlreadyPurchased;

  /// No description provided for @auditPlusActivationLink.
  ///
  /// In en, this message translates to:
  /// **'Activation link'**
  String get auditPlusActivationLink;

  /// No description provided for @auditPlusCheckSubscription.
  ///
  /// In en, this message translates to:
  /// **'Check subscription'**
  String get auditPlusCheckSubscription;

  /// No description provided for @auditPlusContinuePurchase.
  ///
  /// In en, this message translates to:
  /// **'Continue to purchase'**
  String get auditPlusContinuePurchase;

  /// No description provided for @auditPlusPurchaseInstructions.
  ///
  /// In en, this message translates to:
  /// **'FunPay will give you a single-use link. Open it in NiosMess to activate your purchase.'**
  String get auditPlusPurchaseInstructions;

  /// No description provided for @auditPlusFeeNotice.
  ///
  /// In en, this message translates to:
  /// **'A payment gateway fee is added to the price. FunPay will show the total before payment.'**
  String get auditPlusFeeNotice;

  /// No description provided for @auditPlusDeviceHashConsent.
  ///
  /// In en, this message translates to:
  /// **'I agree to share the SHA-256 device hash during activation'**
  String get auditPlusDeviceHashConsent;

  /// No description provided for @auditPlusDeviceHashPurpose.
  ///
  /// In en, this message translates to:
  /// **'This protects your purchase. Promotional plans also check your account and IP address.'**
  String get auditPlusDeviceHashPurpose;

  /// No description provided for @auditPlusOpenFunPay.
  ///
  /// In en, this message translates to:
  /// **'Open FunPay'**
  String get auditPlusOpenFunPay;

  /// No description provided for @auditAppLockCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check the app lock. Try again.'**
  String get auditAppLockCheckFailed;

  /// No description provided for @auditAppLockTitle.
  ///
  /// In en, this message translates to:
  /// **'NiosMess is locked'**
  String get auditAppLockTitle;

  /// No description provided for @auditAppLockDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm your identity to access messages and data'**
  String get auditAppLockDescription;

  /// No description provided for @auditAppLockAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get auditAppLockAuthenticating;

  /// No description provided for @auditAppLockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get auditAppLockUnlock;

  /// No description provided for @auditAppLockMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get auditAppLockMinimize;

  /// No description provided for @savedMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Messages'**
  String get savedMessagesTitle;

  /// No description provided for @savedMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notes and saved messages'**
  String get savedMessagesSubtitle;

  /// No description provided for @niosgramPageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more posts'**
  String get niosgramPageLoadFailed;

  /// No description provided for @niosgramVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get niosgramVideoTitle;

  /// No description provided for @niosgramVideoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this video'**
  String get niosgramVideoUnavailable;

  /// No description provided for @niosgramPlayVideo.
  ///
  /// In en, this message translates to:
  /// **'Open video'**
  String get niosgramPlayVideo;

  /// No description provided for @niosgramSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved posts'**
  String get niosgramSavedTitle;

  /// No description provided for @niosgramSavedLocalNotice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device for this account. Copies may be out of date and are removed when you sign out.'**
  String get niosgramSavedLocalNotice;

  /// No description provided for @niosgramSavedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved posts yet'**
  String get niosgramSavedEmpty;

  /// No description provided for @niosgramRemoveSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get niosgramRemoveSaved;

  /// No description provided for @niosgramSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update saved posts. Try again.'**
  String get niosgramSaveFailed;

  /// No description provided for @niosgramDraftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the draft. Your edits are still here; try again before leaving.'**
  String get niosgramDraftSaveFailed;

  /// No description provided for @niosgramDraftRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the draft. It hasn\'t been deleted.'**
  String get niosgramDraftRestoreFailed;

  /// No description provided for @niosgramScrollTop.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get niosgramScrollTop;

  /// No description provided for @niosgramLikeAction.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get niosgramLikeAction;

  /// No description provided for @niosgramDislikeAction.
  ///
  /// In en, this message translates to:
  /// **'Show fewer posts like this'**
  String get niosgramDislikeAction;

  /// No description provided for @niosgramCommentAction.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get niosgramCommentAction;

  /// No description provided for @niosgramShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share post'**
  String get niosgramShareAction;

  /// No description provided for @niosgramSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save post'**
  String get niosgramSaveAction;

  /// No description provided for @niosgramPublishToFeed.
  ///
  /// In en, this message translates to:
  /// **'Post in NiosGram'**
  String get niosgramPublishToFeed;

  /// No description provided for @niosgramAnonymousPoll.
  ///
  /// In en, this message translates to:
  /// **'Anonymous poll'**
  String get niosgramAnonymousPoll;

  /// No description provided for @niosgramAnonymousQuiz.
  ///
  /// In en, this message translates to:
  /// **'Anonymous quiz'**
  String get niosgramAnonymousQuiz;

  /// No description provided for @niosgramRemovePoll.
  ///
  /// In en, this message translates to:
  /// **'Remove poll'**
  String get niosgramRemovePoll;

  /// No description provided for @niosgramSendToChat.
  ///
  /// In en, this message translates to:
  /// **'Send to a chat'**
  String get niosgramSendToChat;

  /// No description provided for @niosgramCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get niosgramCopyLink;

  /// No description provided for @niosgramShareExternal.
  ///
  /// In en, this message translates to:
  /// **'Share in another app'**
  String get niosgramShareExternal;

  /// No description provided for @niosgramNoChats.
  ///
  /// In en, this message translates to:
  /// **'There are no available chats'**
  String get niosgramNoChats;

  /// No description provided for @niosgramLinkAddedToChat.
  ///
  /// In en, this message translates to:
  /// **'Added to the chat. Check its delivery status there.'**
  String get niosgramLinkAddedToChat;

  /// No description provided for @niosgramSendLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the link to the chat. Try again.'**
  String get niosgramSendLinkFailed;

  /// No description provided for @niosgramUnsupportedMedia.
  ///
  /// In en, this message translates to:
  /// **'Use a JPG, PNG, WebP or GIF photo, or an MP4, MOV or WebM video.'**
  String get niosgramUnsupportedMedia;

  /// No description provided for @niosgramMediaTooLarge.
  ///
  /// In en, this message translates to:
  /// **'A file must be no larger than 25 MB.'**
  String get niosgramMediaTooLarge;

  /// No description provided for @niosgramPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'A photo must be no larger than 5 MB after compression.'**
  String get niosgramPhotoTooLarge;

  /// No description provided for @niosgramVideoAlone.
  ///
  /// In en, this message translates to:
  /// **'A video must be posted on its own, without other media.'**
  String get niosgramVideoAlone;

  /// No description provided for @niosgramVideoDurationLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose a video up to 10 seconds long.'**
  String get niosgramVideoDurationLimit;

  /// No description provided for @niosgramVideoDurationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check video duration. Try another file or device.'**
  String get niosgramVideoDurationFailed;

  /// No description provided for @niosgramOpenVideoExternal.
  ///
  /// In en, this message translates to:
  /// **'Open video in another app'**
  String get niosgramOpenVideoExternal;

  /// No description provided for @niosgramTextTooShort.
  ///
  /// In en, this message translates to:
  /// **'A text-only post needs at least 10 characters.'**
  String get niosgramTextTooShort;

  /// No description provided for @niosgramReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get niosgramReadMore;

  /// No description provided for @niosgramReadLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get niosgramReadLess;

  /// No description provided for @niosgramPostStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'The server didn\'t confirm publication. Check the feed before retrying; your draft is still here.'**
  String get niosgramPostStatusUnknown;

  /// No description provided for @niosgramPublishedCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'The post was published, but its draft couldn\'t be removed.'**
  String get niosgramPublishedCleanupFailed;

  /// No description provided for @mediaSendRecording.
  ///
  /// In en, this message translates to:
  /// **'Send recording'**
  String get mediaSendRecording;

  /// No description provided for @mediaRecordStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get mediaRecordStart;

  /// No description provided for @mediaRecordStop.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get mediaRecordStop;

  /// No description provided for @mediaFrontCamera.
  ///
  /// In en, this message translates to:
  /// **'Front camera'**
  String get mediaFrontCamera;

  /// No description provided for @mediaRearCamera.
  ///
  /// In en, this message translates to:
  /// **'Rear camera'**
  String get mediaRearCamera;

  /// No description provided for @mediaPlaybackPosition.
  ///
  /// In en, this message translates to:
  /// **'Playback position'**
  String get mediaPlaybackPosition;

  /// No description provided for @mediaPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get mediaPlaybackSpeed;

  /// No description provided for @mediaEnterFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get mediaEnterFullscreen;

  /// No description provided for @mediaExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get mediaExitFullscreen;

  /// No description provided for @mediaShowControls.
  ///
  /// In en, this message translates to:
  /// **'Show video controls'**
  String get mediaShowControls;

  /// No description provided for @mediaHideControls.
  ///
  /// In en, this message translates to:
  /// **'Hide video controls'**
  String get mediaHideControls;

  /// No description provided for @mediaMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mediaMute;

  /// No description provided for @mediaUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get mediaUnmute;

  /// No description provided for @inboxScheduledMessages.
  ///
  /// In en, this message translates to:
  /// **'Scheduled messages'**
  String get inboxScheduledMessages;

  /// No description provided for @inboxFolders.
  ///
  /// In en, this message translates to:
  /// **'Chat folders'**
  String get inboxFolders;
}

class _SecretChatLocalizationsDelegate
    extends LocalizationsDelegate<SecretChatLocalizations> {
  const _SecretChatLocalizationsDelegate();

  @override
  Future<SecretChatLocalizations> load(Locale locale) {
    return SynchronousFuture<SecretChatLocalizations>(
      lookupSecretChatLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_SecretChatLocalizationsDelegate old) => false;
}

SecretChatLocalizations lookupSecretChatLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SecretChatLocalizationsEn();
    case 'ru':
      return SecretChatLocalizationsRu();
  }

  throw FlutterError(
    'SecretChatLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
