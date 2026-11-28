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
      'You will be signed out on this device. Regular chats stay on the server. Secret history and unsent messages on this device will be deleted. Your contact keeps their copy.';

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
  String get inboxEmptyTitle => 'Your chats will appear here';

  @override
  String get inboxEmptyHint =>
      'Message a friend, create a group or join with a link';

  @override
  String get inboxResetFilters => 'All chats';

  @override
  String inboxDeleteSelectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count chats?',
      one: 'Delete $count chat?',
    );
    return '$_temp0';
  }

  @override
  String get inboxDeleteSelectedBody =>
      'Direct chats will be deleted, and you will leave groups and channels.';

  @override
  String inboxDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats removed',
      one: '$count chat removed',
    );
    return '$_temp0';
  }

  @override
  String get inboxSwipeMute => 'Mute';

  @override
  String get inboxSwipeUnmute => 'Unmute';

  @override
  String get inboxMutedToast => 'Notifications are off';

  @override
  String get inboxUnmutedToast => 'Notifications are on';

  @override
  String get inboxSelect => 'Select';

  @override
  String inboxSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get inboxAddToFolder => 'Add to folder';

  @override
  String inboxFolderAdded(String name) {
    return 'Added to “$name”';
  }

  @override
  String inboxFolderRemoved(String name) {
    return 'Removed from “$name”';
  }

  @override
  String get inboxSearchEmpty => 'Nothing found';

  @override
  String get inboxSearchEmptyHint => 'Try another search';

  @override
  String get inboxSearchPeople => 'People';

  @override
  String get inboxSearchDirectChat => 'Direct chat';

  @override
  String get inboxSearchMessage => 'Message';

  @override
  String get inboxSearchFailed =>
      'Search failed. Check your connection and try again.';

  @override
  String get inboxWaitingToSend => 'Waiting to send';

  @override
  String get inboxSendFailed => 'Not sent — retry in the chat';

  @override
  String get inboxDraftSemantics => 'Draft';

  @override
  String get inboxKeyMismatch => 'Keys do not match';

  @override
  String get inboxSelectedSemantics => 'selected';

  @override
  String get inboxMutedSemantics => 'muted';

  @override
  String get inboxPin => 'Pin';

  @override
  String get inboxUnpin => 'Unpin';

  @override
  String get inboxArchive => 'Archive';

  @override
  String get inboxUnarchive => 'Unarchive';

  @override
  String get inboxMarkUnread => 'Mark as unread';

  @override
  String get inboxSwipeUnread => 'Unread';

  @override
  String get inboxSwipeUnarchive => 'Unarchive';

  @override
  String get inboxArchiveTitle => 'Archive';

  @override
  String inboxArchiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '$count chat',
    );
    return '$_temp0';
  }

  @override
  String get inboxArchivedToast => 'Chat archived';

  @override
  String get inboxUnarchivedToast => 'Chat returned from the archive';

  @override
  String inboxPinLimit(int count) {
    return 'You can pin up to $count chats';
  }

  @override
  String get inboxPinnedSemantics => 'pinned';

  @override
  String get inboxMarkedUnreadSemantics => 'marked as unread';

  @override
  String get composeOpenDialogFailed => 'Could not open the conversation';

  @override
  String get composeSecretTitle => 'New secret chat';

  @override
  String get composeMessageTitle => 'New message';

  @override
  String get composeSecretSubtitle => 'End-to-end Double Ratchet encryption';

  @override
  String get composeSearchHint => 'Name or @username';

  @override
  String get composeRecentPeople => 'Recent people';

  @override
  String get composeSecretEmptyTitle => 'Secret conversation';

  @override
  String get composeSecretEmptyHint =>
      'Enter a person\'s @username to start an encrypted conversation that leaves no trace on the server';

  @override
  String composeFindHandle(String handle) {
    return 'Find @$handle';
  }

  @override
  String get composeFindHandleHint => 'Check the exact username on the server';

  @override
  String composeUserNotFound(String handle) {
    return 'User @$handle not found';
  }

  @override
  String composeQueryNotFound(String query) {
    return 'No user found for “$query”';
  }

  @override
  String get composeAddMembers => 'Add members';

  @override
  String composeNextCount(int count) {
    return 'Next ($count)';
  }

  @override
  String get composeNoContacts => 'No contacts';

  @override
  String get composeNoContactsHint => 'Find people with the search field above';

  @override
  String get composeGroupPartialMembers =>
      'The group was created, but some members could not be added because of their privacy settings';

  @override
  String get composeGroupFailed => 'Could not create the group';

  @override
  String get composeGroupNameTooShort =>
      'The group name must be at least 2 characters long';

  @override
  String get composeGroupNameLabel => 'Group name *';

  @override
  String get composeNameHint => 'Enter a name';

  @override
  String composeMinChars(int count) {
    return 'At least $count characters';
  }

  @override
  String get composeGroupType => 'Group type';

  @override
  String get composeGroupPublic => 'Public';

  @override
  String get composeGroupPrivate => 'Private';

  @override
  String get composeGroupPrivateHint =>
      'People can join the group only with an invite link.';

  @override
  String get composeGroupPublicHint =>
      'The group will appear in NiosMess global search.';

  @override
  String composeMembersCount(int count) {
    return 'Members ($count)';
  }

  @override
  String get composeNoMembersHint =>
      'No members selected. You can invite them later with a link.';

  @override
  String get composeCreateGroup => 'Create group';

  @override
  String get composeGroupDetailsTitle => 'Group details';

  @override
  String get composeChannelFailed => 'Could not create the channel';

  @override
  String get composeChannelFailedUsername =>
      'Could not create the channel. The username may already be taken.';

  @override
  String get composeChannelNameLabel => 'Channel name *';

  @override
  String get composeChannelUsernameLabel => 'Channel username *';

  @override
  String get composeUsernameRules => 'Use Latin letters, digits, _ and -';

  @override
  String get composeChannelType => 'Channel type';

  @override
  String get composeChannelPrivateHint =>
      'People can join the channel only with an invite link.';

  @override
  String get composeChannelPublicHint =>
      'Public channels appear in search and have a permanent link.';

  @override
  String get composeChannelComments => 'Allow comments on posts';

  @override
  String get composeChannelCommentsOn =>
      'Every post automatically gets a discussion thread.';

  @override
  String get composeChannelCommentsOff =>
      'Subscribers will not be able to comment on posts.';

  @override
  String get composeCreateChannel => 'Create channel';

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
  String get noticeMessagesPrivate => 'Private chats';

  @override
  String get noticeMessagesGroups => 'Groups';

  @override
  String get noticeMessagesChannels => 'Channels';

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

  @override
  String get settingsV2Appearance => 'Appearance';

  @override
  String get settingsV2AppearanceHint =>
      'Theme, palette, text and interface density';

  @override
  String get settingsV2Chats => 'Chats';

  @override
  String get settingsV2ChatsHint => 'Typing, reactions, microphone and camera';

  @override
  String get settingsV2Notifications => 'Notifications';

  @override
  String get settingsV2NotificationsHint =>
      'Push, message previews, sound and vibration';

  @override
  String get settingsV2Privacy => 'Privacy and security';

  @override
  String get settingsV2PrivacyHint =>
      'Visibility, account access and encryption';

  @override
  String get settingsV2Storage => 'Data and storage';

  @override
  String get settingsV2StorageHint => 'Cache, media downloads and device data';

  @override
  String get settingsV2Language => 'Language';

  @override
  String get settingsV2LanguageHint => 'Interface language and time zone';

  @override
  String get settingsV2About => 'Help';

  @override
  String get settingsV2AboutHint => 'Version, updates, help and documents';

  @override
  String get settingsV2GroupCommunication => 'Communication and appearance';

  @override
  String get settingsV2GroupPrivacy => 'Privacy and data';

  @override
  String get settingsV2GroupApplication => 'Application';

  @override
  String get settingsV2Search => 'Search settings';

  @override
  String get settingsV2SearchEmpty => 'Find a setting by its name or action';

  @override
  String get settingsV2SearchNone => 'No results. Try a different word.';

  @override
  String get settingsV2AccountHint => 'Profile and account management';

  @override
  String get settingsV2NiosId => 'Manage Nios ID';

  @override
  String get settingsV2Qr => 'My QR code';

  @override
  String get settingsV2Share => 'Share profile';

  @override
  String get settingsV2More => 'Profile actions';

  @override
  String get settingsV2Advanced => 'Advanced';

  @override
  String get settingsV2GeometryHint => 'Corners of cards and system panels';

  @override
  String get settingsV2Density => 'Interface density';

  @override
  String get settingsV2TextShape => 'Text and shape';

  @override
  String get settingsV2ResetSection => 'Reset';

  @override
  String get settingsV2Graphics => 'Performance';

  @override
  String get settingsV2OptimizeHint =>
      'Simplify visual effects for smoother performance';

  @override
  String get settingsV2ChatAnimations => 'Chat animations';

  @override
  String get settingsV2ChatAnimationsHint =>
      'Choose which effects play automatically';

  @override
  String get settingsV2Stickers => 'Animated stickers';

  @override
  String get settingsV2StickersHint => 'Play sticker animations in messages';

  @override
  String get settingsV2Emoji => 'Animated emoji';

  @override
  String get settingsV2EmojiHint => 'Play emoji animations in messages';

  @override
  String get settingsV2Off => 'Off';

  @override
  String get settingsV2Reset => 'Reset local preferences';

  @override
  String get settingsV2ResetHint =>
      'Restore default appearance and behavior. Message history is kept.';

  @override
  String get settingsV2LockTimeout => 'Auto-lock';

  @override
  String get settingsV2LockTimeoutHint =>
      'When to lock the app after it goes to the background';

  @override
  String get settingsV2BiometricFailure => 'Could not verify your identity';

  @override
  String get settingsV2ReadReceipts => 'Read receipts';

  @override
  String get settingsV2ReadReceiptsHint => 'Show when you have read a message';

  @override
  String get settingsV2Typing => 'Typing indicator';

  @override
  String get settingsV2TypingHint => 'Let others see when you are typing';

  @override
  String get settingsV2ReadSaveFailed => 'Could not save read receipt settings';

  @override
  String get settingsV2TypingSaveFailed => 'Could not save typing settings';

  @override
  String get settingsV2StorageDetails => 'Storage usage';

  @override
  String get settingsV2StorageDetailsHint =>
      'Downloaded media and temporary files';

  @override
  String get settingsV2Wifi => 'On Wi-Fi';

  @override
  String get settingsV2MobileData => 'On mobile data';

  @override
  String get settingsV2MobileDataHint => 'May use your mobile data allowance';

  @override
  String get autoDownloadPhotos => 'Auto-download photos';

  @override
  String get autoDownloadVideos => 'Auto-download videos';

  @override
  String get autoDownloadAutomatic => 'Download automatically';

  @override
  String get settingsV2SecretCache => 'Secret chat cache';

  @override
  String get settingsV2SecretCacheHint => 'Decrypted messages on this device';

  @override
  String get settingsV2ClearSecretCache => 'Clear secret chat cache';

  @override
  String get settingsV2Diagnostics => 'Device diagnostics';

  @override
  String get settingsV2DiagnosticsHint => 'System and hardware information';

  @override
  String get settingsV2StorageImages => 'Photos';

  @override
  String get settingsV2StorageVideos => 'Videos';

  @override
  String get settingsV2StorageAudio => 'Audio';

  @override
  String get settingsV2StorageFiles => 'Files';

  @override
  String get settingsV2StorageStickers => 'Stickers';

  @override
  String get settingsV2StorageAvatars => 'Avatars';

  @override
  String get settingsV2StorageDrafts => 'Drafts';

  @override
  String get settingsV2StorageOther => 'Other';

  @override
  String get settingsV2ProfileCopied => 'Profile link copied';

  @override
  String get settingsV2Economy => 'Economy';

  @override
  String get settingsV2Reliable => 'Reliable';

  @override
  String get settingsV2BackgroundOff =>
      'The background connection is off. Notifications still arrive through the system.';

  @override
  String get settingsV2Preview => 'Show message text';

  @override
  String get settingsV2StorageError => 'Could not load storage data';

  @override
  String get settingsV2ClearCategory => 'Clear files in this category?';

  @override
  String get settingsV2ClearCategoryHint =>
      'Files in this category will be removed from the local cache.';

  @override
  String get settingsV2SecretCacheConfirm =>
      'All decrypted secret-chat messages on this device will be deleted. This cannot be undone.';

  @override
  String get settingsV2ResetConfirm => 'Reset local preferences?';

  @override
  String get settingsV2ResetBody =>
      'Appearance, language, sounds, notifications and other app preferences will reset. Chats, files, keys and server privacy settings will remain.';

  @override
  String get settingsV2ResetDone => 'Local preferences reset';

  @override
  String get settingsV2ResetFailed => 'Could not reset preferences';

  @override
  String get pickerClearSearch => 'Clear search';

  @override
  String get pickerFaces => 'Smileys';

  @override
  String get pickerAnimals => 'Nature';

  @override
  String get pickerFood => 'Food';

  @override
  String get pickerActivities => 'Activities';

  @override
  String get pickerTravel => 'Travel';

  @override
  String get pickerObjects => 'Objects';

  @override
  String get pickerSymbols => 'Symbols';

  @override
  String get pickerFlags => 'Flags';

  @override
  String get pickerSearchEmoji => 'Search emoji';

  @override
  String get pickerNoRecents => 'Your recent emoji will appear here';

  @override
  String get pickerCustom => 'Custom';

  @override
  String get pickerCompact => 'Collapse';

  @override
  String get pickerLibrary => 'Library';

  @override
  String get pickerSearchPacks => 'Search packs';

  @override
  String get pickerManage => 'Manage packs';

  @override
  String get customEmojiTitle => 'Custom emoji';

  @override
  String get customContinue => 'Continue';

  @override
  String get customCreateSet => 'Create emoji pack';

  @override
  String get customSetTitle => 'Title';

  @override
  String get customSetName => 'Pack name in Latin letters';

  @override
  String get customAddSet => 'Add emoji pack';

  @override
  String get customAddEmoji => 'Add emoji';

  @override
  String get customRemoveSet => 'Remove from my packs';

  @override
  String get customShortcode => 'Shortcode: letters, numbers, _';

  @override
  String get customFileTooLarge => 'Choose an image up to 512 KB';

  @override
  String get customTooManyFrames => 'Too many frames in this emoji';

  @override
  String get customEmptySet => 'This pack has no emoji yet';

  @override
  String get auditSystemLanguage => 'System';

  @override
  String get auditPostPublished => 'Post published';

  @override
  String get auditCommentSend => 'Send comment';

  @override
  String get auditCommentDeleteTitle => 'Delete comment?';

  @override
  String get auditCommentDeleteBody => 'Replies will remain in the discussion.';

  @override
  String get auditCommentLoadMore => 'Load more comments';

  @override
  String get auditCommentHint => 'Comment or ask @ai';

  @override
  String get auditCommentEditing => 'Editing comment';

  @override
  String auditCommentReply(String name) {
    return 'Reply to $name';
  }

  @override
  String get auditCommentReported => 'Quality report sent';

  @override
  String get auditCommentAuthor => 'Author';

  @override
  String get auditCommentChannel => 'Channel';

  @override
  String get auditPostMedia => 'Media file';

  @override
  String get auditPostQuiz => 'Quiz';

  @override
  String get auditPostPoll => 'Poll';

  @override
  String get auditPlusSignIn => 'Sign in with NiosID';

  @override
  String get auditPlusCatalogUnavailable => 'Plans are unavailable';

  @override
  String get auditPlusCatalogLoadFailed =>
      'Could not load plans. You can still activate a purchased link below.';

  @override
  String get auditPlusActivationLinkInvalid =>
      'Paste the full activation link from your order';

  @override
  String get auditPlusAccountChanged =>
      'Account changed. Refresh plans before purchasing.';

  @override
  String get auditPlusProductUnavailable =>
      'The product address is unavailable. Try refreshing plans.';

  @override
  String get auditPlusOpenFailed => 'Could not open FunPay';

  @override
  String get auditPlusNativeOnly =>
      'Purchase and activation are available in the mobile and desktop NiosMess app.';

  @override
  String get auditPlusSupportedPlatforms =>
      'Purchase and activation are currently available on Android, Windows and Linux.';

  @override
  String get auditPlusPurchaseTitle => 'Purchase and renewal';

  @override
  String get auditPlusPromoLimit => 'Once per account, IP address and device';

  @override
  String get auditPlusBuy => 'Buy';

  @override
  String get auditPlusSalesPending =>
      'Sales have not opened yet. You can activate a purchased link below.';

  @override
  String get auditPlusRefreshPlans => 'Refresh plans';

  @override
  String get auditPlusAlreadyPurchased => 'Already purchased NiosPlus?';

  @override
  String get auditPlusActivationLink => 'Activation link';

  @override
  String get auditPlusCheckSubscription => 'Check subscription';

  @override
  String get auditPlusContinuePurchase => 'Continue to purchase';

  @override
  String get auditPlusPurchaseInstructions =>
      'FunPay will give you a single-use link. Open it in NiosMess to activate your purchase.';

  @override
  String get auditPlusFeeNotice =>
      'A payment gateway fee is added to the price. FunPay will show the total before payment.';

  @override
  String get auditPlusDeviceHashConsent =>
      'I agree to share the SHA-256 device hash during activation';

  @override
  String get auditPlusDeviceHashPurpose =>
      'This protects your purchase. Promotional plans also check your account and IP address.';

  @override
  String get auditPlusOpenFunPay => 'Open FunPay';

  @override
  String get auditAppLockCheckFailed =>
      'Couldn\'t check the app lock. Try again.';

  @override
  String get auditAppLockTitle => 'NiosMess is locked';

  @override
  String get auditAppLockDescription =>
      'Confirm your identity to access messages and data';

  @override
  String get auditAppLockAuthenticating => 'Checking…';

  @override
  String get auditAppLockUnlock => 'Unlock';

  @override
  String get auditAppLockMinimize => 'Minimize';

  @override
  String get savedMessagesTitle => 'Saved Messages';

  @override
  String get savedMessagesSubtitle => 'Notes and saved messages';

  @override
  String get niosgramPageLoadFailed => 'Couldn\'t load more posts';

  @override
  String get niosgramVideoTitle => 'Video';

  @override
  String get niosgramVideoUnavailable => 'Couldn\'t open this video';

  @override
  String get niosgramPlayVideo => 'Open video';

  @override
  String get niosgramSavedTitle => 'Saved posts';

  @override
  String get niosgramSavedLocalNotice =>
      'Saved on this device for this account. Copies may be out of date and are removed when you sign out.';

  @override
  String get niosgramSavedEmpty => 'No saved posts yet';

  @override
  String get niosgramRemoveSaved => 'Remove from saved';

  @override
  String get niosgramSaveFailed => 'Couldn\'t update saved posts. Try again.';

  @override
  String get niosgramDraftSaveFailed =>
      'Couldn\'t save the draft. Your edits are still here; try again before leaving.';

  @override
  String get niosgramDraftRestoreFailed =>
      'Couldn\'t restore the draft. It hasn\'t been deleted.';

  @override
  String get niosgramScrollTop => 'Back to top';

  @override
  String get niosgramLikeAction => 'Like';

  @override
  String get niosgramDislikeAction => 'Show fewer posts like this';

  @override
  String get niosgramCommentAction => 'Comments';

  @override
  String get niosgramShareAction => 'Share post';

  @override
  String get niosgramSaveAction => 'Save post';

  @override
  String get niosgramPublishToFeed => 'Post in NiosGram';

  @override
  String get niosgramAnonymousPoll => 'Anonymous poll';

  @override
  String get niosgramAnonymousQuiz => 'Anonymous quiz';

  @override
  String get niosgramRemovePoll => 'Remove poll';

  @override
  String get niosgramSendToChat => 'Send to a chat';

  @override
  String get niosgramCopyLink => 'Copy link';

  @override
  String get niosgramShareExternal => 'Share in another app';

  @override
  String get niosgramNoChats => 'There are no available chats';

  @override
  String get niosgramLinkAddedToChat =>
      'Added to the chat. Check its delivery status there.';

  @override
  String get niosgramSendLinkFailed =>
      'Couldn\'t add the link to the chat. Try again.';

  @override
  String get niosgramUnsupportedMedia =>
      'Use a JPG, PNG, WebP or GIF photo, or an MP4, MOV or WebM video.';

  @override
  String get niosgramMediaTooLarge => 'A file must be no larger than 25 MB.';

  @override
  String get niosgramPhotoTooLarge =>
      'A photo must be no larger than 5 MB after compression.';

  @override
  String get niosgramVideoAlone =>
      'A video must be posted on its own, without other media.';

  @override
  String get niosgramVideoDurationLimit =>
      'Choose a video up to 10 seconds long.';

  @override
  String get niosgramVideoDurationFailed =>
      'Couldn\'t check video duration. Try another file or device.';

  @override
  String get niosgramOpenVideoExternal => 'Open video in another app';

  @override
  String get niosgramTextTooShort =>
      'A text-only post needs at least 10 characters.';

  @override
  String get niosgramReadMore => 'Read more';

  @override
  String get niosgramReadLess => 'Show less';

  @override
  String get niosgramPostStatusUnknown =>
      'The server didn\'t confirm publication. Check the feed before retrying; your draft is still here.';

  @override
  String get niosgramPublishedCleanupFailed =>
      'The post was published, but its draft couldn\'t be removed.';

  @override
  String get mediaSendRecording => 'Send recording';

  @override
  String get mediaRecordStart => 'Start recording';

  @override
  String get mediaRecordStop => 'Stop recording';

  @override
  String get mediaFrontCamera => 'Front camera';

  @override
  String get mediaRearCamera => 'Rear camera';

  @override
  String get mediaPlaybackPosition => 'Playback position';

  @override
  String get mediaPlaybackSpeed => 'Playback speed';

  @override
  String get mediaEnterFullscreen => 'Full screen';

  @override
  String get mediaExitFullscreen => 'Exit full screen';

  @override
  String get mediaShowControls => 'Show video controls';

  @override
  String get mediaHideControls => 'Hide video controls';

  @override
  String get mediaMute => 'Mute';

  @override
  String get mediaUnmute => 'Unmute';

  @override
  String get inboxScheduledMessages => 'Scheduled messages';

  @override
  String get inboxFolders => 'Chat folders';

  @override
  String get niosgramNotInterested => 'Not interested';

  @override
  String get niosgramPostHidden => 'Post hidden';

  @override
  String get niosgramReactionFailed =>
      'Could not save the reaction. Try again.';

  @override
  String get niosgramVoteFailed =>
      'Could not confirm your vote. Your selection is kept — try again.';

  @override
  String get niosgramAnonymousNotice => 'Voter names are not published';

  @override
  String get auditCommentActions => 'Comment actions';

  @override
  String get auditCommentQualityReport => 'Report AI response quality';

  @override
  String get auditCommentLike => 'Like';

  @override
  String get auditCommentLove => 'Love';

  @override
  String get auditCommentLaugh => 'Funny';

  @override
  String get auditCommentSurprise => 'Surprised';

  @override
  String get auditCommentSad => 'Sad';

  @override
  String auditCommentShowReplies(int count) {
    return 'Show replies ($count)';
  }

  @override
  String auditCommentHideReplies(int count) {
    return 'Hide replies ($count)';
  }

  @override
  String get auditDeletedAccount => 'Deleted account';

  @override
  String get settingsProfileChangePhoto => 'Change photo';

  @override
  String get settingsProfilePhone => 'Phone number';

  @override
  String get settingsProfilePhoneInvalid =>
      'Enter a phone number with 7 to 15 digits';

  @override
  String get settingsProfileBirthday => 'Birthday';

  @override
  String get settingsProfileClearBirthday => 'Remove birthday';

  @override
  String get settingsProfileNotSet => 'Not set';

  @override
  String get settingsProfileWorkingHours => 'Working hours';

  @override
  String get settingsProfileHoursConfigured => 'Configured';

  @override
  String get settingsProfileSaveFailed =>
      'Could not save your profile. Your changes are still in the form.';

  @override
  String get settingsProfileSaved => 'Profile saved';

  @override
  String get settingsProfileChoosePhoto => 'Choose photo';

  @override
  String get settingsProfilePhotoHint => 'PNG, JPG or WebP · up to 8 MB';

  @override
  String get settingsProfileChooseVideo => 'Choose video avatar';

  @override
  String get settingsProfileVideoHint => 'Video up to 5 seconds · up to 8 MB';

  @override
  String get settingsProfileVideoFormats => 'MP4, MOV and WebM are supported';

  @override
  String get settingsProfilePhotoFormats => 'PNG, JPG and WebP are supported';

  @override
  String get settingsProfileFileTooLarge => 'Choose a file up to 8 MB';

  @override
  String get settingsQrTitle => 'My QR code';

  @override
  String get settingsQrProfileTitle => 'Profile QR code';

  @override
  String get settingsQrHint => 'Scan this code to open the profile';

  @override
  String get settingsQrCopy => 'Copy link';

  @override
  String get settingsQrCopied => 'Link copied';

  @override
  String get settingsDeviceTitle => 'System and device';

  @override
  String get settingsDeviceError => 'Could not load device information';

  @override
  String get settingsDeviceErrorHint =>
      'Try refreshing the information. Your app data will stay unchanged.';

  @override
  String get settingsDeviceMemory => 'Memory and storage';

  @override
  String get settingsDeviceRam => 'Memory';

  @override
  String get settingsDeviceStorage => 'Device storage';

  @override
  String get settingsDeviceSpecs => 'Specifications';

  @override
  String get settingsDeviceCopyHint =>
      'Select a specification to copy its value';

  @override
  String get settingsDeviceProcessor => 'Processor';

  @override
  String get settingsDeviceDisplay => 'Display and graphics';

  @override
  String get settingsDeviceCameras => 'Cameras';

  @override
  String get settingsDeviceOs => 'Operating system';

  @override
  String get settingsDeviceSecurityPatch => 'Security update';

  @override
  String get settingsDeviceBuild => 'Build number';

  @override
  String get settingsDeviceModel => 'Model';

  @override
  String get settingsDeviceArchitecture => 'Architecture';

  @override
  String get settingsDeviceGb => 'GB';

  @override
  String get settingsDeviceMp => 'MP';

  @override
  String get settingsDeviceHz => 'Hz';

  @override
  String get settingsDeviceCores => 'cores';

  @override
  String get settingsDeviceFrontCamera => 'front';

  @override
  String get settingsDeviceAvailable => 'Available';

  @override
  String get settingsDeviceUnknown => 'No data';

  @override
  String get settingsStorageClearAction => 'Clear';

  @override
  String get settingsAboutSupport => 'Help and feedback';

  @override
  String get settingsAboutLinks => 'NiosMess online';

  @override
  String get settingsE2eeOrdinaryTitle => 'Personal chats · E2E preview';

  @override
  String get settingsE2eeEncrypt => 'Encrypt messages';

  @override
  String get settingsE2eeBluetoothRequired =>
      'Bluetooth delivery requires E2E encryption';

  @override
  String get settingsE2eeModeDescription =>
      'New messages and files are encrypted before sending. Unencrypted mode is available only when both participants turn E2E off.';

  @override
  String get settingsE2eeLockedDescription =>
      'This device is not linked yet. Restore your keys or transfer them from another device.';

  @override
  String get settingsE2eeDeviceDescription =>
      'Linked devices receive history independently. Older messages, groups and bots keep their existing mode. Explicit @ai requests send the request text to NiosAI, without history or file keys. A leaked long-term key can expose older encrypted history.';

  @override
  String get settingsE2eeActionFailed =>
      'Could not complete the action. Check your connection, account and code. A reset requires a fresh NiosID sign-in within the last 15 minutes.';

  @override
  String get settingsE2eeReconnect => 'Retry connection';

  @override
  String get settingsE2eeResetTitle => 'Start with new keys?';

  @override
  String get settingsE2eeResetDescription =>
      'Older encrypted history cannot be restored without the original keys. Other devices will be signed out. Your contacts will need to verify the new fingerprint.';

  @override
  String get settingsE2eeResetAction => 'Create new keys';

  @override
  String get settingsE2eeOfflineTitle => 'Without internet';

  @override
  String get settingsE2eeMeshTitle => 'Use Bluetooth when offline';

  @override
  String get settingsE2eeMeshDescription =>
      'Relays encrypted text through nearby NiosMess devices. Bluetooth permission and running apps are required.';

  @override
  String get settingsE2eeBluetoothPermission => 'Allow Bluetooth';

  @override
  String get settingsE2eeRecoveryTitle => 'Recovery key';

  @override
  String get settingsE2eeRecoveryDescription =>
      'Save this key in a password manager. It restores history if you lose every device. We cannot recover it for you.';

  @override
  String get settingsE2eeShowRecovery => 'Show recovery key';

  @override
  String get settingsE2eeHideRecovery => 'Hide recovery key';

  @override
  String get settingsE2eeBackupSaved => 'I saved the key';

  @override
  String get settingsE2eeOwnFingerprint => 'My fingerprint';

  @override
  String get settingsE2eeRestoreTitle => 'Restore on this device';

  @override
  String get settingsE2eeRestoreAction => 'Restore history';

  @override
  String get settingsE2eeLostKeys => 'All keys are lost — start again';

  @override
  String get settingsE2eeLinkTitle => 'Link another device';

  @override
  String get settingsE2eePairNewDescription =>
      'Create a code here and enter it in this section on a linked device. The code lasts 10 minutes. Share it only between your own devices.';

  @override
  String get settingsE2eePairCodeCreate => 'Create linking code';

  @override
  String get settingsE2eePairCodeCopy => 'Copy linking code';

  @override
  String get settingsE2eePairCodeLabel => 'Linking code';

  @override
  String get settingsE2eePairApproveDescription =>
      'Paste the code from your new device. This will transfer your chat keys to it.';

  @override
  String get settingsE2eePairApproveAction => 'Transfer keys';

  @override
  String get settingsE2eePairExpired =>
      'The linking code expired. Create a new one.';

  @override
  String get settingsE2eeContactTitle => 'Verify a contact';

  @override
  String get settingsE2eeContactDescription =>
      'The first contact key is remembered. To protect your first conversation against impersonation, compare fingerprints over another trusted channel.';

  @override
  String get settingsE2eeDirectChat => 'Personal chat';

  @override
  String get settingsE2eeAcceptFingerprint => 'Fingerprints match — trust key';

  @override
  String get settingsE2eeCopyToast => 'Copied';

  @override
  String get settingsSessionsLoadFailed =>
      'Could not load devices. Check your connection and try again.';

  @override
  String get settingsSessionsOthers => 'Other devices';

  @override
  String get settingsSessionsEmptyDescription =>
      'You are signed in only on this device.';

  @override
  String get settingsSessionsEndedOthers => 'All other sessions ended';

  @override
  String get settingsSessionsEndFailed =>
      'Could not end the session. Try again.';

  @override
  String get settingsSessionsApp => 'App';

  @override
  String get settingsSessionsIp => 'IP address';

  @override
  String get settingsSessionsRegion => 'Location';

  @override
  String get settingsSessionsFirstSignIn => 'First sign-in';

  @override
  String get settingsSessionsLastActive => 'Last active';

  @override
  String get settingsSessionsEndThis => 'End this session';

  @override
  String get settingsSessionsCurrentDevice => 'This device';

  @override
  String get settingsSessionsNoOtherDevices => 'No other active sessions';

  @override
  String get settingsE2eeMeshSearching => 'Looking for nearby devices';

  @override
  String get settingsE2eeMeshDevices => 'Nearby devices';

  @override
  String get settingsE2eeMeshPermission => 'Bluetooth permission is required';

  @override
  String get settingsE2eeMeshOff => 'Bluetooth is turned off on this device';

  @override
  String get settingsE2eeMeshUnsupported =>
      'This Bluetooth adapter does not support relaying';

  @override
  String get settingsE2eeMeshScanOnly =>
      'This adapter can only scan for nearby devices';

  @override
  String get settingsE2eeMeshStarting => 'Connecting to Bluetooth';

  @override
  String get settingsE2eeMeshStopped => 'Bluetooth delivery is turned off';

  @override
  String get settingsE2eeMeshUnavailable =>
      'Bluetooth is temporarily unavailable';

  @override
  String get settingsPlusActive => 'Subscription active';

  @override
  String settingsPlusActiveUntil(String date) {
    return 'Active until $date';
  }

  @override
  String get settingsPlusGrace =>
      'Your subscription has ended. Channel, group and emoji settings are temporarily retained.';

  @override
  String settingsPlusGraceUntil(String date) {
    return 'Channel, group and emoji settings are retained until $date';
  }

  @override
  String get settingsPlusSummary =>
      'Higher NiosAI limits, access to Prime and SPrime, files up to 100 MB and higher messenger limits.';

  @override
  String get settingsPlusBenefits => 'Included';

  @override
  String get settingsPlusAiBudget => 'Higher NiosAI limits';

  @override
  String get settingsPlusAiBudgetHint =>
      'Expanded access to NiosAI models across NiosMess, the bot and the website. Usage depends on the model and conversation length.';

  @override
  String get settingsPlusModelsHint =>
      'Models for complex questions, detailed analysis and coding.';

  @override
  String get settingsPlusFiles => 'Files up to 100 MB';

  @override
  String get settingsPlusFilesHint => 'Up from 30 MB on Free.';

  @override
  String get settingsPlusCommunities => '220 public channels and 220 groups';

  @override
  String get settingsPlusCommunitiesHint =>
      'Up from 110 channels and 110 groups on Free.';

  @override
  String get settingsPlusEmoji => '100 emoji packs';

  @override
  String get settingsPlusEmojiHint =>
      'Up from 50 on Free. Set an emoji status next to your name.';

  @override
  String get settingsPlusGracePeriod => '5 days to renew';

  @override
  String get settingsPlusGracePeriodHint =>
      'Channel, group and custom emoji settings are retained for 5 days after expiry. Items above the Free limit then become private. Data is not deleted.';

  @override
  String get settingsPlusTrial => 'Try free for 1 day';

  @override
  String get settingsPlusTrialPending => 'Activating…';

  @override
  String get settingsPlusTrialActivated => 'Your 1-day Nios+ trial is active';

  @override
  String get settingsPlusTrialFailed => 'Could not activate the trial';

  @override
  String get settingsPlusStatusFailed =>
      'Could not check your subscription. Refresh its status before activating the trial.';

  @override
  String get settingsStorageSafeCleanup =>
      'Clearing the cache removes downloaded media copies. Chats, keys and the sending queue are kept. Deleting drafts is a separate action.';

  @override
  String get settingsStorageEstimate =>
      'Usage is calculated from available app folders. Your personal device folders are not scanned.';

  @override
  String get settingsProfileAccountChanged =>
      'Your account has changed. Open the profile again.';

  @override
  String get settingsPrivacyLoadFailed => 'Could not refresh privacy settings';

  @override
  String get settingsPrivacySaveFailed =>
      'Could not save this rule. The previous setting has been restored.';

  @override
  String get settingsProfileAvatarFailed =>
      'Could not update your photo. Try again.';

  @override
  String get settingsAiUsageTitle => 'AI characters';

  @override
  String get settingsAiUsageUnavailable => 'No quota is configured';

  @override
  String settingsAiUsageRemaining(String remaining, String limit) {
    return '$remaining of $limit characters';
  }

  @override
  String settingsAiUsageReset(String date) {
    return 'Quota resets: $date';
  }

  @override
  String settingsAiUsagePercent(String percent) {
    return '$percent% remaining';
  }

  @override
  String get settingsBadgePickerTitle => 'Choose badges';

  @override
  String get settingsBadgePickerHint =>
      'Choose up to two badges for your profile.';

  @override
  String get settingsBadgePickerLimit => 'You can select up to two badges';

  @override
  String get settingsBadgePickerEmpty =>
      'You do not have any available badges yet';

  @override
  String get settingsBadgePickerLoadFailed => 'Could not load badges';

  @override
  String get settingsBadgePickerSaveFailed => 'Could not save badges';

  @override
  String get settingsBadgePickerSelected => 'Selected';

  @override
  String get settingsHoursAddInterval => 'Add interval';

  @override
  String get settingsHoursDeleteInterval => 'Delete interval';

  @override
  String get settingsHoursStart => 'Start time';

  @override
  String get settingsHoursEnd => 'End time';

  @override
  String get settingsHoursEndAfterStart =>
      'End time must be later than start time';

  @override
  String get settingsHoursOverlap => 'Time intervals must not overlap';

  @override
  String get settingsHoursLimit => 'Up to four intervals per day';

  @override
  String get settingsHoursDayOff => 'Day off';

  @override
  String get settingsHoursDayOffHint =>
      'Add a time interval or choose a preset.';

  @override
  String get settingsHoursPresets => 'Time presets';

  @override
  String get settingsHoursRepeat => 'Repeat schedule';

  @override
  String get settingsHoursCopyWeekdays => 'Copy to weekdays';

  @override
  String get settingsHoursCopyAll => 'Copy to all days';

  @override
  String get settingsHoursCopied => 'Schedule copied';

  @override
  String get settingsHoursTimezone => 'Time zone';

  @override
  String get settingsProfileExtraDetails => 'Additional details';

  @override
  String get settingsProfileLinksActions => 'Links and account';

  @override
  String get inboxAllFolders => 'All folders';

  @override
  String get inboxFolderCreate => 'Create folder';

  @override
  String get inboxFolderNew => 'New folder';

  @override
  String get inboxFolderEdit => 'Edit folder';

  @override
  String get inboxFolderDelete => 'Delete folder';

  @override
  String get inboxFolderActions => 'Folder actions';

  @override
  String inboxFolderChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '$count chat',
      zero: 'No chats',
    );
    return '$_temp0';
  }

  @override
  String get inboxFolderHasRules => 'Has rules';

  @override
  String get inboxFolderAutoAdd => 'Add automatically';

  @override
  String get inboxFolderUnreadOnly => 'Unread only';

  @override
  String get inboxFolderAddChats => 'Add individual chats';

  @override
  String get inboxFolderNameInvalid => 'Enter a name of up to 40 characters';

  @override
  String get inboxFolderEmptyRules => 'Select chats or a rule';

  @override
  String get inboxFolderConflict =>
      'Folder changed on another device. The list was updated';

  @override
  String get inboxFoldersUnavailable => 'Folders unavailable';

  @override
  String get inboxChatsLoadFailed => 'Could not load chats';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get inboxScheduleTitle => 'Scheduled message';

  @override
  String get inboxReminderTitle => 'Remind about message';

  @override
  String get inboxScheduleCreated => 'Message scheduled';

  @override
  String get inboxReminderSaved => 'Reminder saved';

  @override
  String get inboxReminderText => 'Reminder text';

  @override
  String get inboxScheduleInHour => 'In an hour';

  @override
  String get inboxScheduleTomorrow => 'Tomorrow morning';

  @override
  String get inboxScheduleServerHint =>
      'It will be sent from the server even if this device is turned off.';

  @override
  String get inboxMessageRequired => 'Enter a message';

  @override
  String get inboxScheduleFutureTime => 'Choose a time in the future';

  @override
  String get inboxReminderSave => 'Save reminder';

  @override
  String get inboxScheduleAction => 'Schedule';

  @override
  String get inboxScheduledTitle => 'Scheduled and reminders';

  @override
  String get inboxScheduleEmpty => 'Nothing scheduled yet';

  @override
  String get inboxScheduleEmptyHint =>
      'Hold the send button to pick a time. Any message can also be turned into a reminder.';

  @override
  String get inboxScheduleActions => 'Scheduled message actions';

  @override
  String get inboxScheduleReschedule => 'Change time';

  @override
  String get inboxScheduleCancel => 'Cancel sending';

  @override
  String get inboxTopicsTitle => 'Group topics';

  @override
  String get inboxTopicClosed => 'Topic closed';

  @override
  String get inboxTopicActions => 'Topic actions';

  @override
  String get inboxTopicRename => 'Rename';

  @override
  String get inboxTopicOpen => 'Open topic';

  @override
  String get inboxTopicClose => 'Close topic';

  @override
  String get inboxTopicName => 'Topic name';

  @override
  String get inboxTopicCreate => 'Create topic';

  @override
  String get inboxE2eeWaitingActiveDevice =>
      'Waiting for keys from your active device';

  @override
  String get inboxE2eeWaitingKeys => 'Waiting for encrypted chat keys';

  @override
  String get inboxSavedOpening => 'Opening Saved Messages…';

  @override
  String get inboxScheduleLockedPreview =>
      'Connect a device with encryption keys to read this message';

  @override
  String get settingsIssuePushTitle =>
      'Notifications are off in system settings';

  @override
  String get settingsIssuePushBody =>
      'Until the system allows them, you will not see new messages and calls while the app is closed.';

  @override
  String get settingsIssuePushAction => 'Open notifications';

  @override
  String settingsIssueCacheTitle(String size) {
    return 'Cache takes up $size';
  }

  @override
  String get settingsIssueCacheBody =>
      'Temporary files can be deleted. Your chats stay in place.';

  @override
  String get settingsIssueCacheAction => 'Open storage';

  @override
  String get settingsIssueUpdateTitle => 'The update was not installed';

  @override
  String get settingsIssueUpdateBody =>
      'Checking or downloading the update ended with an error.';

  @override
  String get settingsIssueUpdateAction => 'Open update';

  @override
  String get noticeOpenSystemSettings => 'Open system settings';

  @override
  String get noticeOpenSystemSettingsHint =>
      'Allow notifications for NiosMess, then come back here.';

  @override
  String get noticePermissionDenied => 'The system did not allow notifications';

  @override
  String get settingsAccountUsername => 'Username';

  @override
  String get settingsDangerZone => 'Danger zone';

  @override
  String get settingsLockTimeoutImmediately => 'Immediately';

  @override
  String get settingsLockTimeout30Seconds => 'After 30 seconds';

  @override
  String get settingsLockTimeout1Minute => 'After 1 minute';

  @override
  String get settingsLockTimeout5Minutes => 'After 5 minutes';

  @override
  String get settingsLockTimeout30Minutes => 'After 30 minutes';

  @override
  String get settingsSpamBlockServerHint =>
      'This limit is set by the server and cannot be lifted from the app.';

  @override
  String get accountDeleteTitle => 'Delete account';

  @override
  String get accountDeleteEntry => 'Delete account';

  @override
  String get accountDeleteEntryHint =>
      'You will need a code from your email. There is time to change your mind before anything is erased.';

  @override
  String accountDeleteDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return '$_temp0';
  }

  @override
  String get accountDeleteWhatTitle => 'What will be deleted';

  @override
  String get accountDeleteWhatBody =>
      'Your messages and files, your direct chats in full (including the other person\'s messages), posts, comments and subscriptions. Groups and channels you created will stay, but without an owner.';

  @override
  String get accountDeleteHowTitle => 'How it works';

  @override
  String accountDeleteHowBody(String period) {
    return 'After you confirm, you are signed out on every device. The account is erased in $period. Until then you can sign in again and cancel the deletion. Signing in alone does not cancel it.';
  }

  @override
  String get accountDeleteSendCode => 'Email me a code';

  @override
  String get accountDeleteCodeSent =>
      'The code was sent to the email of your Nios ID. It is valid for 15 minutes.';

  @override
  String get accountDeleteCodeLabel => 'Code from the email';

  @override
  String get accountDeleteConfirmTitle => 'Delete account?';

  @override
  String accountDeleteConfirmBody(String period) {
    return 'You will be signed out on every device. In $period the account and its data are erased and cannot be restored.';
  }

  @override
  String accountDeleteScheduledToast(String date) {
    return 'Deletion is scheduled for $date. Until then you can sign in and cancel it.';
  }

  @override
  String accountDeletePendingTitle(String date) {
    return 'The account will be deleted on $date';
  }

  @override
  String get accountDeletePendingNoDate =>
      'The account is scheduled for deletion';

  @override
  String get accountDeletePendingBody =>
      'Until that day the account works as usual, then it is erased with all its data. Signing in does not cancel the deletion.';

  @override
  String get accountDeleteCancel => 'Cancel deletion';

  @override
  String get accountDeleteKeep => 'Leave as is';

  @override
  String get accountDeleteCancelled =>
      'Deletion cancelled. The account stays with you.';

  @override
  String get accountDeletePlusActive =>
      'Cancel your Nios+ subscription first: an account with an active subscription cannot be deleted.';

  @override
  String get accountDeleteInvalidCode =>
      'The code is wrong or has expired. Request a new one.';

  @override
  String get accountDeleteFailed => 'That did not work. Try again.';

  @override
  String get accountDeleteLoadFailed =>
      'Could not find out whether a deletion is scheduled';

  @override
  String get settingsIssueDeletionAction => 'Open account';

  @override
  String get settingsNiosIdSecurity => 'Nios ID security';

  @override
  String get settingsNiosIdSecurityHint =>
      'Password, sessions and connected apps on ni-os.ru';

  @override
  String get settingsSaveFailed =>
      'Could not save this setting. The previous value is back.';

  @override
  String get settingsNotificationsOffReason => 'Turn on notifications first';

  @override
  String get settingsNotificationsLoadFailed =>
      'Could not load notification settings';

  @override
  String settingsChatsQuickReactionEmoji(String emoji) {
    return 'Quick reaction $emoji';
  }

  @override
  String get settingsStorageNothingToClear => 'Nothing to clear';

  @override
  String get settingsDevicesTitle => 'Devices';

  @override
  String get settingsPasswordEntry => 'Password';

  @override
  String get settingsPasswordEntryHint => 'Reset with a code from your email';

  @override
  String get settingsPasswordTitle => 'Password reset';

  @override
  String settingsPasswordCodeIntro(String email) {
    return 'We will send a six-digit code to the email of your Nios ID — $email. The code is valid for 15 minutes, and a new request retires the previous one.';
  }

  @override
  String get settingsPasswordRequest => 'Email me a code';

  @override
  String get settingsPasswordResend => 'Send the code again';

  @override
  String get settingsPasswordRequested =>
      'If your Nios ID has an email, the code is on its way. It is valid for 15 minutes; sending again replaces the previous code. No letter after a couple of minutes? Send it again.';

  @override
  String get settingsPasswordCodeLabel => 'Code from the letter';

  @override
  String get settingsPasswordNewPasswordLabel => 'New password';

  @override
  String get settingsPasswordRepeatLabel => 'Repeat the password';

  @override
  String get settingsPasswordRuleHint =>
      'At least 10 characters, one uppercase Latin letter and one digit.';

  @override
  String get settingsPasswordShow => 'Show password';

  @override
  String get settingsPasswordHide => 'Hide password';

  @override
  String get settingsPasswordSubmit => 'Change password';

  @override
  String get settingsPasswordErrorWeak =>
      'This password will not do: at least 10 characters, an uppercase letter and a digit.';

  @override
  String get settingsPasswordErrorCode =>
      'The code is wrong or has expired. Check the letter or request a new code.';

  @override
  String get settingsPasswordErrorRate =>
      'Too many attempts. Wait a minute and try again.';

  @override
  String get settingsPasswordErrorNetwork =>
      'No connection. Check the network and try again.';

  @override
  String get settingsPasswordErrorUnknown => 'That did not work. Try again.';

  @override
  String get settingsPasswordDoneTitle => 'Password changed';

  @override
  String get settingsPasswordDoneBody =>
      'The password of your Nios ID is updated and its central sessions are signed out. Use the new password the next time you sign in to Nios ID.';

  @override
  String get settingsPasswordDoneAction => 'Done';

  @override
  String get settingsPasswordNoEmailTitle => 'No email on file';

  @override
  String get settingsPasswordNoEmailBody =>
      'The reset code is sent to an email, and your Nios ID does not have one. Add an email in the account settings at ni-os.ru and come back.';

  @override
  String get settingsPasswordOpenNiosId => 'Open Nios ID settings';
}
