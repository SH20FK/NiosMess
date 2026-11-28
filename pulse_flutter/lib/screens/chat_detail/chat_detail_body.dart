import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/services/desktop_pasteboard_service.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/screens/calls/outgoing_call_screen.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_attachment_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_composer_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_composer_scope.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_draft_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_header_scope.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_media_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_action_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_presenter.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_messages_scope.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_screen_lifecycle.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_send_controller.dart';
import 'package:pulse_flutter/widgets/calls/active_group_call_banner.dart';
import 'package:pulse_flutter/widgets/chat/browser_image_paste_target.dart';
import 'package:pulse_flutter/widgets/chat/chat_file_drop_target.dart';
import 'package:pulse_flutter/widgets/chat/chat_overlay_layer.dart';
import 'package:pulse_flutter/widgets/chat/chat_scroll_coordinator.dart';
import 'package:pulse_flutter/widgets/chat/chat_viewport.dart';
import 'package:pulse_flutter/widgets/chat/desktop_drag_drop_area.dart';
import 'package:pulse_flutter/widgets/chat/encrypted_draft_conflict_notice.dart';

/// The screen's `build` body, split out of the `State`.
///
/// It owns exactly what the old inline tree owned — the file drop / image
/// paste wrappers, the shortcut bindings (Esc: edit → reply → back, desktop
/// paste, secret-chat screenshot), the [PopScope], the app bar, the
/// [ChatViewport] with its banners, FAB and composer — plus the three pieces
/// that only this tree calls: the date separator, the header's call buttons
/// and the media open/long-press guards.
///
/// Performance contract kept from the screen: `ChatViewport` gets `composer`
/// and `messagesBuilder` as two separate subtrees, so typing rebuilds the
/// composer and the reply/edit notifier only, never the message list.
class ChatDetailBody extends ConsumerWidget {
  const ChatDetailBody({
    super.key,
    required this.chatId,
    required this.isSecret,
    required this.isDesktopSplit,
    required this.canRoutePop,
    required this.highlightMessageId,
    required this.interactionEnabled,
    required this.scheme,
    required this.inputController,
    required this.inputFocusNode,
    required this.composer,
    required this.send,
    required this.attachments,
    required this.draft,
    required this.actions,
    required this.media,
    required this.scrollCoordinator,
    required this.lifecycle,
    required this.presenter,
    required this.replyPreviewBuilder,
    required this.onBack,
    required this.onHeaderBack,
    required this.onSecurityTap,
    required this.onShowAi,
    required this.onCancelAi,
  });

  final int chatId;
  final bool isSecret;
  final bool isDesktopSplit;

  /// Whether the route can pop right now (read by Esc and [PopScope]).
  final bool canRoutePop;
  final int? highlightMessageId;

  /// False while editing or while an AI rewrite runs: drops and pastes off.
  final bool interactionEnabled;
  final ColorScheme scheme;

  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final ChatComposerController composer;
  final ChatSendController send;
  final ChatAttachmentController attachments;
  final ChatDraftController draft;
  final ChatMessageActionController actions;
  final ChatMediaController media;
  final ChatScrollCoordinator scrollCoordinator;
  final ChatScreenLifecycle lifecycle;
  final ChatMessagePresenter presenter;
  final String? Function(ApiMessage message, Map<int, ApiMessage> byId)
  replyPreviewBuilder;

  final VoidCallback onBack;

  /// Header back: haptics, then [onBack].
  final VoidCallback onHeaderBack;
  final VoidCallback onSecurityTap;
  final void Function(BuildContext context) onShowAi;
  final VoidCallback onCancelAi;

  /// Date chip between message groups; a message-list concern, kept beside
  /// the tree that hands it to [ChatMessagesScope].
  Widget _dateSeparator(
    BuildContext context,
    DateTime resolvedDate,
    DateTime now,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            presenter.dateSeparatorLabel(resolvedDate, now),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  void _handleOpenMediaFor(BuildContext context, ApiMessage message) {
    if (message.hasMedia) {
      media.openMedia(context, message);
    }
  }

  void _handleLongPressMediaFor(
    BuildContext context,
    ApiMessage message,
    bool isMine,
    bool amAdminOrOwner,
  ) {
    if (message.hasMedia) {
      media.showMediaActions(
        context,
        message,
        isMine: isMine,
        amAdminOrOwner: amAdminOrOwner,
      );
    }
  }

  void _handleLongPressFor(
    BuildContext context,
    ApiMessage message,
    bool isMine,
    bool isChannel,
    bool amAdminOrOwner,
  ) {
    // The menu needs the screen's context; every outcome is the controller's.
    actions.showMessageActions(
      context,
      message,
      isMine: isMine,
      isChannel: isChannel,
      amAdminOrOwner: amAdminOrOwner,
    );
  }

  void _startCall(
    BuildContext context,
    WidgetRef ref, {
    required bool isVideo,
  }) {
    final ApiChatSummary? currentChat = ref.read(chatByIdProvider(chatId));
    if (currentChat != null && currentChat.chatType == 'direct') {
      final int? partnerId = currentChat.partnerUserId;
      final bool isBlockedByMe =
          (partnerId != null &&
              ref.read(privacyProvider).isUserBlocked(partnerId)) ||
          currentChat.isBlockedByMe;
      final bool isBlockedByUser = currentChat.isBlockedByUser;
      if (isBlockedByMe) {
        AppToast.showError(context, context.l10n.chatUnblockToCall);
        return;
      }
      if (isBlockedByUser) {
        AppToast.showError(context, context.l10n.chatCallsRestrictedByUser);
        return;
      }
    }

    final String partnerName = currentChat?.name ?? '';
    final String partnerUsername = currentChat?.username ?? '';
    final String? avatarUrl = currentChat?.avatarUrl;

    context.push(
      '/call/outgoing',
      extra: OutgoingCallArgs(
        username: partnerUsername.isNotEmpty ? partnerUsername : partnerName,
        displayName: partnerName,
        avatarUrl: avatarUrl,
        chatId: chatId,
        isVideo: isVideo,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool showGroupCall = ref.watch(
      chatByIdProvider(chatId).select((c) => c?.chatType == 'group'),
    );

    return ChatFileDropTarget(
      conversationId: chatId,
      enabled: interactionEnabled,
      onFiles: (files) => unawaited(attachments.previewPastedImages(files)),
      child: BrowserImagePasteTarget(
        focusNode: inputFocusNode,
        enabled: interactionEnabled,
        onImages: (images) =>
            unawaited(attachments.previewPastedImages(images)),
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): () {
              final composerState = composer.notifier.value;
              if (composerState.editingMessageId != null) {
                composer.cancelEdit();
              } else if (composerState.replyToMessageId != null) {
                composer.clearReply();
              } else if (!isDesktopSplit && canRoutePop) {
                onBack();
              }
            },
            if (DesktopPasteboardService.isDesktop)
              const SingleActivator(
                LogicalKeyboardKey.keyV,
                control: true,
              ): () {
                // Focused TextField handles Ctrl+V via ChatInputBar.onDesktopPaste;
                // ignore here so both listeners never double-send the same paste.
                if (inputFocusNode.hasFocus) return;
                unawaited(attachments.handleDesktopPaste());
              },
            if (DesktopPasteboardService.isDesktop)
              const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () {
                if (inputFocusNode.hasFocus) return;
                unawaited(attachments.handleDesktopPaste());
              },
            if (isSecret) ...<ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.printScreen):
                  lifecycle.handleScreenshotAction,
              const SingleActivator(
                LogicalKeyboardKey.keyS,
                shift: true,
                meta: true,
              ): lifecycle.handleScreenshotAction,
              const SingleActivator(
                LogicalKeyboardKey.keyS,
                shift: true,
                control: true,
              ): lifecycle.handleScreenshotAction,
              const SingleActivator(
                LogicalKeyboardKey.digit3,
                shift: true,
                meta: true,
              ): lifecycle.handleScreenshotAction,
              const SingleActivator(
                LogicalKeyboardKey.digit4,
                shift: true,
                meta: true,
              ): lifecycle.handleScreenshotAction,
            },
          },
          child: PopScope(
            canPop: !isDesktopSplit && canRoutePop,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop) return;
              // Native two-pane layout: the shell's PopScope on the same route
              // closes this pane. Handling it here as well made one back press
              // do two things.
              if (isDesktopSplit && !kIsWeb) return;
              onBack();
            },
            child: Scaffold(
              appBar: ChatHeaderScope(
                chatId: chatId,
                isDesktopSplit: isDesktopSplit,
                isSecret: isSecret,
                onBack: onHeaderBack,
                onVoiceCall: () => _startCall(context, ref, isVideo: false),
                onVideoCall: () => _startCall(context, ref, isVideo: true),
                onSecurityTap: onSecurityTap,
              ),
              body: DesktopDragDropArea(
                onFilesDropped: attachments.uploadDesktopFiles,
                child: ChatViewport(
                  topBanner: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (showGroupCall) ActiveGroupCallBanner(chatId: chatId),
                      ChatTopBannerLayer(
                        chatId: chatId,
                        isSecret: isSecret,
                        loadingOlderNotifier: lifecycle.loadingOlderNotifier,
                        onE2eeTap: onSecurityTap,
                      ),
                      if (!isSecret)
                        EncryptedDraftConflictNotice(
                          chatId: chatId,
                          onSelected: (text) {
                            inputController.text = text;
                            draft.saveNow();
                          },
                        ),
                    ],
                  ),
                  messagesBuilder:
                      (
                        BuildContext context,
                        ValueListenable<double> bottomInset,
                      ) {
                        return ChatMessagesScope(
                          chatId: chatId,
                          highlightMessageId: highlightMessageId,
                          scrollCoordinator: scrollCoordinator,
                          inputFocusNode: inputFocusNode,
                          bottomInset: bottomInset,
                          onOpenComments: (ApiMessage msg) {
                            context.push(
                              '/channel/$chatId/post/${msg.id}/comments',
                            );
                          },
                          onReactionTap: (ApiMessage msg, String emoji) =>
                              actions.react(msg, emoji),
                          onOpenMedia: (ApiMessage msg) =>
                              _handleOpenMediaFor(context, msg),
                          onLongPressMedia:
                              (
                                ApiMessage msg,
                                bool isMine,
                                bool amAdminOrOwner,
                              ) => _handleLongPressMediaFor(
                                context,
                                msg,
                                isMine,
                                amAdminOrOwner,
                              ),
                          onLongPress:
                              (
                                ApiMessage msg,
                                bool isMine,
                                bool isChannel,
                                bool amAdminOrOwner,
                              ) => _handleLongPressFor(
                                context,
                                msg,
                                isMine,
                                isChannel,
                                amAdminOrOwner,
                              ),
                          onSwipeToReply: composer.setReply,
                          displayTextBuilder: presenter.displayText,
                          mediaUrlBuilder: presenter.mediaUrlFor,
                          isImageMediaBuilder: presenter.isImageMedia,
                          mediaLabelBuilder: presenter.mediaLabel,
                          replyPreviewBuilder: replyPreviewBuilder,
                          dateSeparatorBuilder: (date, now) =>
                              _dateSeparator(context, date, now),
                        );
                      },
                  floatingActionButton: scrollCoordinator.buildFab(
                    chatId: chatId,
                  ),
                  composer: ChatComposerScope(
                    chatId: chatId,
                    composerNotifier: composer.notifier,
                    inputController: inputController,
                    inputFocusNode: inputFocusNode,
                    showDraftRestoredBanner: draft.showRestoredBanner,
                    onClearDraft: draft.clear,
                    onSend: send.send,
                    onCommitEdit: composer.commitEdit,
                    onCancelEdit: composer.cancelEdit,
                    onClearReply: composer.clearReply,
                    onAttachMedia: attachments.pickAndUploadMedia,
                    onAiPressed: (ctx, _) => onShowAi(ctx),
                    onVoiceSend: (p) =>
                        unawaited(attachments.sendVoiceMessage(p)),
                    onCircleSend: (p) =>
                        unawaited(attachments.sendCircleVideo(p)),
                    onCancelAi: onCancelAi,
                    onSendSticker: (s) => unawaited(attachments.sendSticker(s)),
                    onEditLastMessage: composer.editLastMessage,
                    onAttachFiles: attachments.uploadDesktopFiles,
                    onDesktopPaste: attachments.handleDesktopPaste,
                    scheme: scheme,
                  ),
                ),
              ),
              backgroundColor: scheme.surface,
            ),
          ),
        ),
      ),
    );
  }
}
