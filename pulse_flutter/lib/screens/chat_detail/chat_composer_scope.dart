import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/inline_query_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_input_area.dart';
import 'package:pulse_flutter/widgets/chat/spamblock_banner.dart';

/// Isolated composer scope: watches composer-side metadata and the reply/edit
/// state notifier, and never rebuilds the message list.
class ChatComposerScope extends ConsumerWidget {
  const ChatComposerScope({
    super.key,
    required this.chatId,
    required this.composerNotifier,
    required this.inputController,
    required this.inputFocusNode,
    required this.showDraftRestoredBanner,
    required this.onClearDraft,
    required this.onSend,
    required this.onCommitEdit,
    required this.onCancelEdit,
    required this.onClearReply,
    required this.onAttachMedia,
    required this.onAiPressed,
    required this.onVoiceSend,
    required this.onCircleSend,
    required this.onCancelAi,
    required this.onSendSticker,
    required this.onEditLastMessage,
    required this.onAttachFiles,
    required this.onDesktopPaste,
    required this.scheme,
  });

  final int chatId;
  final ValueNotifier<ChatComposerState> composerNotifier;
  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final bool showDraftRestoredBanner;
  final VoidCallback onClearDraft;
  final VoidCallback onSend;
  final VoidCallback onCommitEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onClearReply;
  final VoidCallback onAttachMedia;
  final void Function(BuildContext, ColorScheme) onAiPressed;
  final void Function(String) onVoiceSend;
  final void Function(String)? onCircleSend;
  final VoidCallback onCancelAi;
  final void Function(ApiSticker) onSendSticker;
  final VoidCallback onEditLastMessage;
  final void Function(List<String>, {bool sendAsDocument})? onAttachFiles;
  final Future<void> Function() onDesktopPaste;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (
      bool isChannel,
      bool isDirect,
      int? partnerUserId,
      bool isBlockedByMeChat,
      bool isBlockedByUser,
    ) = ref.watch(
      chatByIdProvider(chatId).select(
        (c) => (
          c?.chatType == 'channel',
          c?.chatType == 'direct',
          c?.partnerUserId,
          c?.isBlockedByMe ?? false,
          c?.isBlockedByUser ?? false,
        ),
      ),
    );

    final String myRole = ref.watch(myChatRoleProvider(chatId));
    final bool canPostInChannel =
        !isChannel || myRole == 'admin' || myRole == 'owner';

    final int? partnerId = partnerUserId;
    final bool isBlockedByMe =
        isDirect &&
        partnerId != null &&
        (ref.watch(privacyProvider).isUserBlocked(partnerId) ||
            isBlockedByMeChat);

    final bool hasActiveUploads = ref.watch(
      hasActiveChatUploadsProvider(chatId),
    );
    final bool hapticsEnabled = ref.watch(
      uiSettingsProvider.select((s) => s.haptics),
    );
    final bool sendOnEnter = ref.watch(
      uiSettingsProvider.select((s) => s.sendOnEnter),
    );

    final (
      bool isAccountSpamBlocked,
      DateTime? spamBlockUntil,
      String? spamBlockReason,
      int? myUserId,
    ) = ref.watch(
      authProvider.select(
        (a) => (
          a.profile?.isRestrictedBySpamBlock ?? false,
          a.profile?.spamBlockUntil,
          a.profile?.spamBlockReason,
          a.profile?.id,
        ),
      ),
    );
    final ApiChatSummary? currentChat = isAccountSpamBlocked
        ? ref.watch(chatByIdProvider(chatId))
        : null;
    final bool hasPartnerReply =
        isAccountSpamBlocked &&
        currentChat?.chatType == 'direct' &&
        myUserId != null &&
        ref.watch(
          chatMessagesProvider(chatId).select(
            (s) => (s.asData?.value ?? const <ApiMessage>[]).any(
              (m) => m.senderId != myUserId,
            ),
          ),
        );
    final bool isSpamBlocked = isChatRestrictedBySpamBlock(
      isAccountSpamBlocked: isAccountSpamBlocked,
      chat: currentChat,
      myUserId: myUserId,
      hasPartnerReply: hasPartnerReply,
    );

    if (ref.watch(
      chatByIdProvider(chatId).select((c) => c?.topicClosed == true),
    )) {
      return const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Тема закрыта. Читать сообщения можно, отправлять — после открытия темы.',
          ),
        ),
      );
    }
    return ValueListenableBuilder<ChatComposerState>(
      valueListenable: composerNotifier,
      builder:
          (BuildContext context, ChatComposerState composerState, Widget? _) {
            return ChatDetailInputArea(
              chatId: chatId,
              isBlockedByMe: isBlockedByMe,
              isBlockedByUser: isDirect && isBlockedByUser,
              onUnblockUser: partnerId != null
                  ? () async {
                      HapticService.confirm();
                      final bool success = await ref
                          .read(privacyProvider.notifier)
                          .unblockUser(partnerId);
                      if (!context.mounted) return;
                      if (success) {
                        AppToast.showSuccess(
                          context,
                          context.l10n.userUnblockedSuccess,
                        );
                      }
                    }
                  : null,
              onCancelAi: onCancelAi,
              onSendSticker: onSendSticker,
              onSendInlineResult: (InlineQueryResult result) {
                inputController.text = result.messageText;
                onSend();
              },
              canPostInChannel: canPostInChannel,
              showDraftRestoredBanner: showDraftRestoredBanner,
              onClearDraft: onClearDraft,
              uploadingMedia: hasActiveUploads,
              inputController: inputController,
              inputFocusNode: inputFocusNode,
              isAiProcessing: composerState.isAiProcessing,
              editingMessageId: composerState.editingMessageId,
              editingOriginalText: composerState.editingOriginalText,
              replyToMessageId: composerState.replyToMessageId,
              replyPreviewText: composerState.replyPreviewText,
              onSend: onSend,
              onCommitEdit: onCommitEdit,
              onCancelEdit: onCancelEdit,
              onClearReply: onClearReply,
              onAttachMedia: onAttachMedia,
              onAiPressed: () => onAiPressed(context, scheme),
              onVoiceSend: onVoiceSend,
              onCircleSend: onCircleSend,
              hapticsEnabled: hapticsEnabled,
              sendOnEnter: sendOnEnter,
              isSpamBlocked: isSpamBlocked,
              spamBlockUntil: spamBlockUntil,
              spamBlockReason: spamBlockReason,
              onContactSupport: () => context.push('/support'),
              onEditLastMessage: onEditLastMessage,
              onAttachFiles: onAttachFiles,
              onDesktopPaste: onDesktopPaste,
            );
          },
    );
  }
}
