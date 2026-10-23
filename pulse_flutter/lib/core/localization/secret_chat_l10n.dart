import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/l10n/secret/generated/secret_chat_localizations.dart';

extension SecretChatL10n on AppLocalizations {
  String get interactiveTitle => _secret.interactiveTitle;
  String get interactivePoll => _secret.interactivePoll;
  String get interactiveQuiz => _secret.interactiveQuiz;
  String get interactiveList => _secret.interactiveList;
  String get interactiveTitleField => _secret.interactiveTitleField;
  String get interactiveQuestion => _secret.interactiveQuestion;
  String get interactiveTitleRequired => _secret.interactiveTitleRequired;
  String get interactiveQuestionRequired => _secret.interactiveQuestionRequired;
  String get interactiveOptions => _secret.interactiveOptions;
  String get interactiveQuizOptions => _secret.interactiveQuizOptions;
  String get interactiveFieldRequired => _secret.interactiveFieldRequired;
  String get interactiveDuplicateOptions => _secret.interactiveDuplicateOptions;
  String interactiveItemNumber(int number) =>
      _secret.interactiveItemNumber(number);
  String interactiveOptionNumber(int number) =>
      _secret.interactiveOptionNumber(number);
  String get interactiveRemoveItem => _secret.interactiveRemoveItem;
  String get interactiveRemoveOption => _secret.interactiveRemoveOption;
  String get interactiveAddItem => _secret.interactiveAddItem;
  String get interactiveAddOption => _secret.interactiveAddOption;
  String get interactiveCorrectAnswer => _secret.interactiveCorrectAnswer;
  String get interactiveMultiple => _secret.interactiveMultiple;
  String get interactiveExplanation => _secret.interactiveExplanation;
  String get interactiveExplanationHint => _secret.interactiveExplanationHint;
  String get interactiveVotesVisible => _secret.interactiveVotesVisible;
  String get interactiveSend => _secret.interactiveSend;
  String get interactiveSendFailed => _secret.interactiveSendFailed;

  String get inboxDraftLabel => _secret.inboxDraftLabel;
  String get inboxDeleted => _secret.inboxDeleted;
  String inboxDeleteNamed(String name) => _secret.inboxDeleteNamed(name);
  String inboxLeaveNamed(String name) => _secret.inboxLeaveNamed(name);
  String get inboxRefreshFailed => _secret.inboxRefreshFailed;

  String get inboxChatType => _secret.inboxChatType;
  String get inboxCreateMenu => _secret.inboxCreateMenu;
  String get inboxComposeTitle => _secret.inboxComposeTitle;
  String get inboxComposePersonHint => _secret.inboxComposePersonHint;
  String get inboxComposeGroupHint => _secret.inboxComposeGroupHint;
  String get inboxComposeChannelHint => _secret.inboxComposeChannelHint;
  String get inboxComposeSecretHint => _secret.inboxComposeSecretHint;
  String get inboxJoinLink => _secret.inboxJoinLink;
  String get inboxJoinLinkHint => _secret.inboxJoinLinkHint;
  String get inboxEncryptedPreview => _secret.inboxEncryptedPreview;
  String get inboxNoUnread => _secret.inboxNoUnread;
  String get inboxCategoryEmpty => _secret.inboxCategoryEmpty;
  String get inboxFilterResetHint => _secret.inboxFilterResetHint;
  String get inboxSearchEmpty => _secret.inboxSearchEmpty;
  String get inboxSearchEmptyHint => _secret.inboxSearchEmptyHint;
  String get inboxWaitingToSend => _secret.inboxWaitingToSend;
  String get inboxSendFailed => _secret.inboxSendFailed;
  String get inboxDraftSemantics => _secret.inboxDraftSemantics;

  String get inboxActions => _secret.inboxActions;
  String get backgroundsPaused => _secret.backgroundsPaused;
  String updateFailureMessage(String message) =>
      message == 'UPDATE_INTEGRITY_MISMATCH'
      ? _secret.updateIntegrityFailed
      : message;
  SecretChatLocalizations get _secret =>
      lookupSecretChatLocalizations(Locale(localeName.split('_').first));
  String callFailureMessage(String code) => switch (code) {
    'media_unavailable' => _secret.callMediaUnavailable,
    'connection_failed' => _secret.callConnectionFailed,
    'connection_lost' => _secret.callConnectionLost,
    'signaling_failed' => _secret.callSignalingFailed,
    'solo_timeout' => _secret.callSoloTimeout,
    'duration_limit' => _secret.callDurationLimit,
    _ => callsFailedToStart(code),
  };
  String get modalDeleteChatBody => _secret.modalDeleteChatBody;
  String get modalSessionTitle => _secret.modalSessionTitle;
  String modalSessionBody(String device) => _secret.modalSessionBody(device);
  String get modalSessionConfirm => _secret.modalSessionConfirm;
  String get modalSessionsTitle => _secret.modalSessionsTitle;
  String get modalSessionsBody => _secret.modalSessionsBody;
  String get modalSessionsConfirm => _secret.modalSessionsConfirm;
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
  String get interactiveSaveFailed => _secret.interactiveSaveFailed;
  String get interactiveVoters => _secret.interactiveVoters;
  String get interactiveParticipant => _secret.interactiveParticipant;
  String get interactiveClosed => _secret.interactiveClosed;
  String get interactiveOpenPoll => _secret.interactiveOpenPoll;
  String get interactiveQuizClosed => _secret.interactiveQuizClosed;
  String get interactivePollClosed => _secret.interactivePollClosed;
  String get interactiveQuizSingle => _secret.interactiveQuizSingle;
  String get interactivePollMultiple => _secret.interactivePollMultiple;
  String get interactivePollSingle => _secret.interactivePollSingle;
  String get interactiveCorrectAnswerLabel =>
      _secret.interactiveCorrectAnswerLabel;
  String get interactiveItemReopened => _secret.interactiveItemReopened;
  String get interactiveItemCompleted => _secret.interactiveItemCompleted;
  String get interactiveQuizAnswer => _secret.interactiveQuizAnswer;
  String get interactiveCorrect => _secret.interactiveCorrect;
  String get interactiveIncorrect => _secret.interactiveIncorrect;
  String get interactiveVoteEvent => _secret.interactiveVoteEvent;
  String get interactiveVote => _secret.interactiveVote;
  String get interactiveChangeVote => _secret.interactiveChangeVote;
  String get interactiveVoteRevoked => _secret.interactiveVoteRevoked;
  String get interactiveRevoke => _secret.interactiveRevoke;
  String get interactiveLoadRetry => _secret.interactiveLoadRetry;
  String get interactiveLoading => _secret.interactiveLoading;
  String get interactiveAfterSend => _secret.interactiveAfterSend;
  String get interactiveFinishList => _secret.interactiveFinishList;
  String get interactiveFinishPoll => _secret.interactiveFinishPoll;
  String get interactiveFinishBody => _secret.interactiveFinishBody;
  String get interactiveFinish => _secret.interactiveFinish;
  String get interactiveFinishedEvent => _secret.interactiveFinishedEvent;
  String get interactiveYourWrongAnswer => _secret.interactiveYourWrongAnswer;
  String get interactiveYourAnswer => _secret.interactiveYourAnswer;
  String get interactiveSaving => _secret.interactiveSaving;
  String interactiveParticipantNumber(int id) =>
      _secret.interactiveParticipantNumber(id);
  String interactiveCompletedCount(int count, int total) =>
      _secret.interactiveCompletedCount(count, total);
  String interactiveVoterCount(int count) =>
      _secret.interactiveVoterCount(count);
  String get attachmentPhotoVideo => _secret.attachmentPhotoVideo;
  String get attachmentDocument => _secret.attachmentDocument;
  String get attachmentAudio => _secret.attachmentAudio;
  String get attachmentRecordCircle => _secret.attachmentRecordCircle;
  String get recordCircleDesktopHint => _secret.recordCircleDesktopHint;
  String get recordVoiceDesktopHint => _secret.recordVoiceDesktopHint;
  String get recordSwitchVoice => _secret.recordSwitchVoice;
  String get recordSwitchCircle => _secret.recordSwitchCircle;
  String get deliverySent => _secret.deliverySent;
  String get deliveryRead => _secret.deliveryRead;
  String get webWorkspaceHint => _secret.webWorkspaceHint;
  String get videoPreview => _secret.videoPreview;
  String get webAutoDownload => _secret.webAutoDownload;
  String get webMotionTitle => _secret.webMotionTitle;
  String get webDownloadStarted => _secret.webDownloadStarted;
}
