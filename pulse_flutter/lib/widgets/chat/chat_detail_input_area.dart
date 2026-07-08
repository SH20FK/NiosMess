import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/chat/chat_input_bar.dart';
import 'package:pulse_flutter/widgets/file_upload_progress_widget.dart';

class ChatDetailInputArea extends StatelessWidget {
  const ChatDetailInputArea({
    super.key,
    required this.canPostInChannel,
    required this.showDraftRestoredBanner,
    required this.onClearDraft,
    required this.uploadingMedia,
    this.uploadFileName,
    this.uploadFileSize,
    required this.uploadProgress,
    required this.onCancelUpload,
    required this.inputController,
    required this.inputFocusNode,
    required this.isAiProcessing,
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
    required this.hapticsEnabled,
  });

  final bool canPostInChannel;
  final bool showDraftRestoredBanner;
  final VoidCallback onClearDraft;
  final bool uploadingMedia;
  final String? uploadFileName;
  final int? uploadFileSize;
  final double uploadProgress;
  final VoidCallback onCancelUpload;
  
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
  final bool hapticsEnabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

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
                      if (uploadingMedia && uploadFileName != null)
                        FileUploadProgressWidget(
                          fileName: uploadFileName!,
                          fileSize: uploadFileSize ?? 0,
                          progress: uploadProgress,
                          onCancel: onCancelUpload,
                        ),
                      ChatInputBar(
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
                        hapticsEnabled: hapticsEnabled,
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      context.l10n.chatOnlyAdminsCanPost,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
