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
