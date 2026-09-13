import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/inline_query_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/inline_query_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_input_bar.dart';
import 'package:pulse_flutter/widgets/chat/inline_query_overlay.dart';
import 'package:pulse_flutter/widgets/chat/spamblock_banner.dart';

class ChatDetailInputArea extends ConsumerWidget {
  const ChatDetailInputArea({
    super.key,
    required this.canPostInChannel,
    required this.showDraftRestoredBanner,
    required this.onClearDraft,
    required this.uploadingMedia,
    required this.inputController,
    required this.inputFocusNode,
    required this.isAiProcessing,
    this.chatId,
    this.onSendSticker,
    this.onSendInlineResult,
    this.editingMessageId,
    this.editingOriginalText,
    this.replyToMessageId,
    this.replyPreviewText,
    required this.onSend,
    required this.onCommitEdit,
    required this.onCancelEdit,
    required this.onClearReply,
    required this.onAttachMedia,
    required this.onAiPressed,
    required this.onVoiceSend,
    this.onCircleSend,
    required this.hapticsEnabled,
    this.sendOnEnter = true,
    this.isSpamBlocked = false,
    this.spamBlockUntil,
    this.spamBlockReason,
    this.onContactSupport,
    this.isBlockedByMe = false,
    this.isBlockedByUser = false,
    this.onUnblockUser,
  });

  final bool canPostInChannel;
  final bool showDraftRestoredBanner;
  final VoidCallback onClearDraft;
  final bool isSpamBlocked;
  final DateTime? spamBlockUntil;
  final String? spamBlockReason;
  final VoidCallback? onContactSupport;
  final void Function(InlineQueryResult result)? onSendInlineResult;
  final bool isBlockedByMe;
  final bool isBlockedByUser;
  final VoidCallback? onUnblockUser;

  /// True while this chat has uploads in flight — swaps the attach button
  /// for a spinner in [ChatInputBar]. Per-message progress lives in the
  /// message bubble itself.
  final bool uploadingMedia;

  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final bool isAiProcessing;
  final int? editingMessageId;
  final String? editingOriginalText;
  final int? replyToMessageId;
  final String? replyPreviewText;

  final VoidCallback onSend;
  final VoidCallback onCommitEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onClearReply;
  final VoidCallback onAttachMedia;
  final VoidCallback onAiPressed;
  final void Function(String) onVoiceSend;
  final void Function(String)? onCircleSend;
  final int? chatId;
  final void Function(ApiSticker sticker)? onSendSticker;
  final bool hapticsEnabled;
  final bool sendOnEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    if (isBlockedByMe) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.block_rounded, color: scheme.error, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.blockedBannerTitle,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (onUnblockUser != null)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onUnblockUser,
                  child: Text(context.l10n.unblockAction),
                ),
            ],
          ),
        ),
      );
    }

    if (isBlockedByUser) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: scheme.error, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.chatMessagesRestrictedByUser,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.blockedByUserBannerTitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isSpamBlocked) {
      return SafeArea(
        top: false,
        child: RepaintBoundary(
          child: SpamBlockBanner(
            until: spamBlockUntil,
            reason: spamBlockReason,
            onContactSupport: onContactSupport,
          ),
        ),
      );
    }

    final InlineQueryState inlineState = ref.watch(inlineQueryProvider);
    final bool showInlineOverlay = inlineState.isActive &&
        (inlineState.chatId == null || inlineState.chatId == chatId);

    return SafeArea(
      top: false,
      child: RepaintBoundary(
        child: Container(
          color: Colors.transparent,
          child: canPostInChannel
              ? DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (showInlineOverlay)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                          child: InlineQueryOverlay(
                            state: inlineState,
                            onSelectResult: (InlineQueryResult result) {
                              inputController.clear();
                              ref.read(inlineQueryProvider.notifier).clear();
                              if (onSendInlineResult != null) {
                                onSendInlineResult!(result);
                              } else {
                                inputController.text = result.messageText;
                                onSend();
                              }
                            },
                            onClose: () =>
                                ref.read(inlineQueryProvider.notifier).clear(),
                          ),
                        ),
                      if (showDraftRestoredBanner)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer.withValues(alpha: 0.3),
                            border: Border(
                              bottom: BorderSide(
                                color: scheme.tertiaryContainer,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 16,
                                  color: scheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.l10n.chatDraftRestored,
                                    style: textTheme.labelMedium?.copyWith(
                                      color: scheme.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: onClearDraft,
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  iconSize: 18,
                                  color: scheme.onTertiaryContainer,
                                  tooltip: context.l10n.commonDelete,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ChatInputBar(
                        chatId: chatId,
                        onSendSticker: onSendSticker,
                        inputController: inputController,
                        inputFocusNode: inputFocusNode,
                        isAiProcessing: isAiProcessing,
                        uploadingMedia: uploadingMedia,
                        editingMessageId: editingMessageId,
                        editingOriginalText: editingOriginalText,
                        replyToMessageId: replyToMessageId,
                        replyPreviewText: replyPreviewText,
                        onSend: onSend,
                        onCommitEdit: onCommitEdit,
                        onCancelEdit: onCancelEdit,
                        onClearReply: onClearReply,
                        onAttachMedia: onAttachMedia,
                        onAiPressed: onAiPressed,
                        onVoiceSend: onVoiceSend,
                        onCircleSend: onCircleSend,
                        hapticsEnabled: hapticsEnabled,
                        sendOnEnter: sendOnEnter,
                      ),
                    ],
                  ),
                )
              : _ChannelSubscriberBar(
                  chatId: chatId,
                  hapticsEnabled: hapticsEnabled,
                ),
        ),
      ),
    );
  }
}

class _ChannelSubscriberBar extends ConsumerWidget {
  const _ChannelSubscriberBar({
    required this.chatId,
    required this.hapticsEnabled,
  });

  final int? chatId;
  final bool hapticsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final bool isMuted = chatId != null
        ? (ref.watch(chatMutedProvider(chatId!)).value ?? false)
        : false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.chatOnlyAdminsCanPost,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: isMuted
                    ? scheme.surfaceContainerHighest
                    : scheme.primaryContainer.withValues(alpha: 0.6),
                foregroundColor: isMuted
                    ? scheme.onSurfaceVariant
                    : scheme.onPrimaryContainer,
              ),
              icon: Icon(
                isMuted
                    ? Icons.notifications_off_rounded
                    : Icons.notifications_active_rounded,
                size: 20,
              ),
              label: Text(
                isMuted ? 'ВКЛЮЧИТЬ УВЕДОМЛЕНИЯ' : 'ОТКЛЮЧИТЬ УВЕДОМЛЕНИЯ',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  fontSize: 13,
                ),
              ),
              onPressed: () async {
                if (hapticsEnabled) {
                  HapticService.tap();
                }
                if (chatId != null) {
                  await ref.read(chatMutedProvider(chatId!).notifier).toggle();
                  if (context.mounted) {
                    AppToast.showInfo(
                      context,
                      isMuted
                          ? 'Уведомления включены'
                          : 'Уведомления отключены',
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

