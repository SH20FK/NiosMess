// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'secret_chat_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SecretChatLocalizationsEn extends SecretChatLocalizations {
  SecretChatLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get updateIntegrityFailed =>
      'The update file is incomplete or corrupted. Download it again.';

  @override
  String get callMediaUnavailable =>
      'Could not access the microphone or camera. Check app permissions and try again.';

  @override
  String get callConnectionFailed =>
      'Could not connect the call. Please try again.';

  @override
  String get callConnectionLost => 'The call disconnected. Please call again.';

  @override
  String get callSignalingFailed =>
      'Could not establish a secure call connection. Please try again.';

  @override
  String get callSoloTimeout => 'Call ended: no one else joined.';

  @override
  String get callDurationLimit => 'The call duration limit has been reached.';

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

  @override
  String get modalDeleteChatBody =>
      'Remove this conversation from your chat list?';

  @override
  String get modalSessionTitle => 'End this session?';

  @override
  String modalSessionBody(String device) {
    return 'The device “$device” will be disconnected from your account.';
  }

  @override
  String get modalSessionConfirm => 'End session';

  @override
  String get modalSessionsTitle => 'End all other sessions?';

  @override
  String get modalSessionsBody =>
      'Every device except this one will be disconnected from your account.';

  @override
  String get modalSessionsConfirm => 'End all other sessions';

  @override
  String get inboxActions => 'Actions';

  @override
  String get backgroundsPaused => 'Backgrounds are temporarily disabled';

  @override
  String get inboxChatType => 'Chat type';

  @override
  String get inboxCreateMenu => 'Create…';

  @override
  String get inboxComposeTitle => 'Start a conversation';

  @override
  String get inboxComposePersonHint => 'Choose a person or search by @username';

  @override
  String get inboxComposeGroupHint => 'A conversation with several people';

  @override
  String get inboxComposeChannelHint => 'Posts for your subscribers';

  @override
  String get inboxComposeSecretHint =>
      'A private conversation with end-to-end encryption';

  @override
  String get inboxJoinLink => 'Join with a link';

  @override
  String get inboxJoinLinkHint => 'Open a group or channel invitation';

  @override
  String get inboxEncryptedPreview => 'Encrypted message';

  @override
  String get inboxNoUnread => 'You’re all caught up';

  @override
  String get inboxCategoryEmpty => 'No chats in this category yet';

  @override
  String get inboxFilterResetHint => 'Select All to return to every chat';

  @override
  String get inboxSearchEmpty => 'Nothing found';

  @override
  String get inboxSearchEmptyHint => 'Try another search';

  @override
  String get inboxWaitingToSend => 'Waiting to send';

  @override
  String get inboxSendFailed => 'Not sent — retry in the chat';

  @override
  String get inboxDraftSemantics => 'Draft';

  @override
  String get inboxDraftLabel => 'Draft:';

  @override
  String get inboxDeleted => 'Conversation deleted';

  @override
  String inboxDeleteNamed(String name) {
    return 'Delete chat “$name”?';
  }

  @override
  String inboxLeaveNamed(String name) {
    return 'Leave “$name”?';
  }

  @override
  String get inboxRefreshFailed => 'Could not refresh your chats. Try again.';

  @override
  String get interactiveTitle => 'Create';

  @override
  String get interactivePoll => 'Poll';

  @override
  String get interactiveQuiz => 'Quiz';

  @override
  String get interactiveList => 'Shared list';

  @override
  String get interactiveTitleField => 'Title';

  @override
  String get interactiveQuestion => 'Question';

  @override
  String get interactiveTitleRequired => 'Enter a title';

  @override
  String get interactiveQuestionRequired => 'Enter a question';

  @override
  String get interactiveOptions => 'Answer options';

  @override
  String get interactiveQuizOptions => 'Answer options. Choose the correct one';

  @override
  String get interactiveFieldRequired => 'Complete this field';

  @override
  String get interactiveDuplicateOptions => 'Options must be different';

  @override
  String interactiveItemNumber(int number) {
    return 'Item $number';
  }

  @override
  String interactiveOptionNumber(int number) {
    return 'Option $number';
  }

  @override
  String get interactiveRemoveItem => 'Remove item';

  @override
  String get interactiveRemoveOption => 'Remove option';

  @override
  String get interactiveAddItem => 'Add item';

  @override
  String get interactiveAddOption => 'Add option';

  @override
  String get interactiveCorrectAnswer => 'Correct answer';

  @override
  String get interactiveMultiple => 'Multiple answers';

  @override
  String get interactiveExplanation => 'Explanation (optional)';

  @override
  String get interactiveExplanationHint => 'Shown after answering';

  @override
  String get interactiveVotesVisible =>
      'Participants can see who voted for each option.';

  @override
  String get interactiveSend => 'Send';

  @override
  String get interactiveSendFailed => 'Could not send. Retry in the chat.';

  @override
  String get interactiveSaveFailed => 'Could not save. Try again.';

  @override
  String get interactiveVoters => 'Votes';

  @override
  String get interactiveParticipant => 'Participant';

  @override
  String get interactiveClosed => 'Closed';

  @override
  String get interactiveOpenPoll => 'Public poll';

  @override
  String get interactiveQuizClosed => 'Quiz closed';

  @override
  String get interactivePollClosed => 'Poll closed';

  @override
  String get interactiveQuizSingle => 'Quiz, one answer';

  @override
  String get interactivePollMultiple => 'Public poll, multiple answers';

  @override
  String get interactivePollSingle => 'Public poll, one answer';

  @override
  String get interactiveCorrectAnswerLabel => 'Correct answer';

  @override
  String get interactiveItemReopened => 'Item reopened';

  @override
  String get interactiveItemCompleted => 'Item completed';

  @override
  String get interactiveQuizAnswer => 'Quiz answer';

  @override
  String get interactiveCorrect => 'Correct';

  @override
  String get interactiveIncorrect => 'Incorrect';

  @override
  String get interactiveVoteEvent => 'Poll vote';

  @override
  String get interactiveVote => 'Vote';

  @override
  String get interactiveChangeVote => 'Change vote';

  @override
  String get interactiveVoteRevoked => 'Vote withdrawn';

  @override
  String get interactiveRevoke => 'Withdraw';

  @override
  String get interactiveLoadRetry => 'Could not load. Retry';

  @override
  String get interactiveLoading => 'Loading updates…';

  @override
  String get interactiveAfterSend => 'Available after sending';

  @override
  String get interactiveFinishList => 'Close this list?';

  @override
  String get interactiveFinishPoll => 'Close voting?';

  @override
  String get interactiveFinishBody =>
      'Participants will no longer be able to change their answers.';

  @override
  String get interactiveFinish => 'Close';

  @override
  String get interactiveFinishedEvent => 'Closed';

  @override
  String get interactiveYourWrongAnswer => 'Your answer, incorrect';

  @override
  String get interactiveYourAnswer => 'Your answer';

  @override
  String get interactiveSaving => 'Saving…';

  @override
  String interactiveParticipantNumber(int id) {
    return 'Participant $id';
  }

  @override
  String interactiveCompletedCount(int count, int total) {
    return 'Completed $count of $total';
  }

  @override
  String interactiveVoterCount(int count) {
    return 'Voters: $count';
  }

  @override
  String get attachmentPhotoVideo => 'Photo or video';

  @override
  String get attachmentDocument => 'File or document';

  @override
  String get attachmentAudio => 'Audio file';

  @override
  String get attachmentRecordCircle => 'Record a video message';

  @override
  String get recordCircleDesktopHint =>
      'Video message: click to record, right-click for microphone';

  @override
  String get recordVoiceDesktopHint =>
      'Voice message: click to record, right-click for video';

  @override
  String get recordSwitchVoice => 'Switch to microphone';

  @override
  String get recordSwitchCircle => 'Switch to video message';

  @override
  String get deliverySent => 'Sent';

  @override
  String get deliveryRead => 'Read';

  @override
  String get webWorkspaceHint =>
      'Select a chat on the left. Ctrl + Alt + N starts a conversation.';

  @override
  String get videoPreview => 'Play video';

  @override
  String get webAutoDownload => 'Download media automatically';

  @override
  String get webMotionTitle => 'Motion and performance';

  @override
  String get webDownloadStarted => 'Download started';

  @override
  String get pasteImageTitle => 'Send image?';

  @override
  String get pasteImageCaption => 'Caption';

  @override
  String get pasteImageFailed => 'Could not read the clipboard image';

  @override
  String get pasteImageLimit => 'Paste up to 8 images, totaling up to 40 MB';

  @override
  String get pasteImageSendFailed =>
      'Could not save the attachment. The image is still here; try sending again.';

  @override
  String pasteImageCount(int count) {
    return 'Images remaining: $count';
  }

  @override
  String get webStorageTitle => 'Browser data';

  @override
  String get webStorageDescription =>
      'Your browser manages this site’s storage. Disk usage and system temporary files are unavailable here. Clearing site data in your browser also deletes local secret chats and the outgoing queue.';

  @override
  String get webStorageDrafts => 'Regular chat drafts';

  @override
  String get webStorageDraftsDescription =>
      'Saved in this browser. Secret drafts are stored separately.';

  @override
  String get callDevicesTitle => 'Audio and camera';

  @override
  String get callDevicesLocalHint =>
      'Tests stay on this device: audio and video are not sent anywhere.';

  @override
  String get callDevicesUnavailable => 'Could not list devices';

  @override
  String get callDevicesPermission =>
      'Could not open the microphone or camera. Check permissions or select another device.';

  @override
  String get callDevicesApplyFailed =>
      'Could not switch devices. Select an available device and try again.';

  @override
  String get callDeviceDefault => 'System default';

  @override
  String get callDeviceMicrophone => 'Microphone';

  @override
  String get callDeviceCamera => 'Camera';

  @override
  String get callDeviceOutput => 'Headphones and speakers';

  @override
  String get callDeviceSpeak =>
      'Say something: the meter shows your microphone level';

  @override
  String get callDeviceLevelUnavailable =>
      'Microphone is open. This device does not report its input level.';

  @override
  String get callDeviceTest => 'Test microphone and camera';

  @override
  String get callDeviceTestSound => 'Test speakers';

  @override
  String get callDeviceTestSystemSound => 'Test system audio';

  @override
  String get callDeviceOutputUnavailable =>
      'This output cannot be selected. Check your devices and browser or system sound settings.';

  @override
  String get callDeviceStart => 'Start call';

  @override
  String get callQualityReconnecting => 'Reconnecting…';

  @override
  String get callQualityMeasuring => 'Measuring connection…';

  @override
  String get callQualityGood => 'Good connection';

  @override
  String get callQualityFair => 'Unstable connection';

  @override
  String get callQualityPoor => 'Poor connection';

  @override
  String get callQualityLatency => 'high latency';

  @override
  String get callQualityLoss => 'packet loss';

  @override
  String get callQualityJitter => 'uneven packet timing';

  @override
  String get callQualityBandwidth => 'limited bandwidth';

  @override
  String get callQualityCpu => 'device is struggling to encode video';

  @override
  String get stickerHubSearch => 'Search emoji and pack names';

  @override
  String get stickerHubRecent => 'Recent';

  @override
  String get stickerHubEmpty => 'No stickers here yet';

  @override
  String get stickerHubEmptyHint =>
      'Choose a pack or create your own. Sent stickers appear in Recent.';

  @override
  String get stickerHubLoadError => 'Could not load stickers';

  @override
  String get stickerHubCreate => 'Create pack';

  @override
  String get stickerHubAdd => 'Add stickers';

  @override
  String get stickerHubDetails => 'Pack details';

  @override
  String get stickerHubEmoji => 'Emoji';

  @override
  String get stickerHubStickers => 'Stickers';

  @override
  String get stickerHubNoResults => 'No results';

  @override
  String get chatDropFiles => 'Drop files to preview';

  @override
  String get chatDropError =>
      'Could not read these files. Try the attachment button.';

  @override
  String get chatBatchTitle => 'Send attachments?';

  @override
  String get chatBatchAlbum => 'Group photos into an album';

  @override
  String get chatBatchSeparate => 'Send as separate files';

  @override
  String get chatBatchRemove => 'Remove attachment';

  @override
  String get chatBatchLimit => 'Add up to 10 files, totaling up to 100 MB';

  @override
  String get chatAlbumOpen => 'Open album';

  @override
  String get chatAlbumPrevious => 'Previous photo';

  @override
  String get chatAlbumNext => 'Next photo';

  @override
  String get callDeviceMissing => 'device unavailable';

  @override
  String get noticeOpenChat => 'Open chat';

  @override
  String get noticeOpen => 'Open';

  @override
  String get noticeReadChat => 'Read entire chat';

  @override
  String get noticeMarkAllRead => 'Mark all read';

  @override
  String get noticeTitle => 'Notifications';

  @override
  String get noticeEmpty => 'All caught up';

  @override
  String get noticeEmptyHint =>
      'Messages and activity for this account are saved here.';

  @override
  String get noticeClose => 'Close';

  @override
  String get noticeClear => 'Clear history';

  @override
  String get noticePermissionGranted => 'System notifications are allowed';

  @override
  String get noticePermissionMissing => 'Push requires system permission';

  @override
  String get noticePermissionHint =>
      'Allow notifications for NiosMess in your browser or device settings.';

  @override
  String get noticeDeviceHint =>
      'These preferences apply to this device. The open chat does not show duplicate alerts.';

  @override
  String get noticeMessages => 'Messages';

  @override
  String get noticeCalls => 'Incoming calls';

  @override
  String get noticeActivity => 'NiosGram activity';

  @override
  String get noticePreview => 'Show message preview';

  @override
  String get noticePreviewHint =>
      'Secret message contents are always hidden in system push.';

  @override
  String get noticeSound => 'Notification sound';

  @override
  String get noticeSoundHint =>
      'System channel sounds can also be changed in OS settings.';

  @override
  String get noticeMessagesChannel => 'NiosMess messages';

  @override
  String get noticeCallsChannel => 'NiosMess calls';

  @override
  String get noticeUpdatesChannel => 'NiosMess updates';

  @override
  String get noticeIncomingCall => 'Incoming call';

  @override
  String get noticeIncomingVideo => 'Incoming video call';

  @override
  String get noticeAccept => 'Accept';

  @override
  String get noticeDecline => 'Decline';

  @override
  String get noticeNewMessage => 'New message';

  @override
  String get noticeEncrypted => 'Encrypted message';

  @override
  String get noticeBackground => 'Background operation is enabled';

  @override
  String get noticeEconomy => 'Save battery';

  @override
  String get noticeSoundTest => 'Test sound';

  @override
  String get noticeSoundTestHint => 'Tap, message, success and error';

  @override
  String get noticeSyncFailed =>
      'Could not update push on the server. Your preference is saved and will retry on connection.';

  @override
  String get noticeCopied => 'Copied';

  @override
  String get noticeUpdateDownloading => 'Downloading NiosMess update';

  @override
  String get noticeUpdateReady => 'NiosMess update is ready';

  @override
  String get noticeUpdateTap => 'Tap to install';

  @override
  String get noticeVersion => 'Version';

  @override
  String get noticeInAppOnly => 'This device supports in-app notifications';

  @override
  String get noticePostLike => 'Reaction to your post';

  @override
  String get noticePostComment => 'Comment on your post';

  @override
  String get noticeAttachment => 'Attachment';

  @override
  String get noticeReply => 'Reply';

  @override
  String get noticeMarkRead => 'Mark as read';

  @override
  String get noticeReplyHint => 'Message';

  @override
  String get noticeSend => 'Send';

  @override
  String get noticeSending => 'Sending…';

  @override
  String get noticeReplyFailed =>
      'Could not send. Your text is still here — try again.';

  @override
  String get noticeReplySaveFailed =>
      'Could not save the draft. Your text is still here.';

  @override
  String get noticeDeviceRegistered => 'This device is registered for push';

  @override
  String get noticeDevicePending =>
      'Push registration is waiting for connection';

  @override
  String get noticeUiSoundsHint =>
      'Tap and action sounds. Notification sounds are configured separately.';

  @override
  String get noticeSilentMessages => 'Silent messages';
}
