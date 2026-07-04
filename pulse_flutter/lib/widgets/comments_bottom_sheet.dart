import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';

class CommentsBottomSheet extends ConsumerStatefulWidget {
  const CommentsBottomSheet({required this.postId, super.key});

  final int postId;

  @override
  ConsumerState<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _replyToMessageId;
  String? _replyPreviewText;

  PostCommentsArgs get _args => PostCommentsArgs(channelId: 0, postId: widget.postId);

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    final int? replyId = _replyToMessageId;
    setState(() {
      _replyToMessageId = null;
      _replyPreviewText = null;
    });
    await ref.read(postCommentsProvider(_args).notifier).send(text, replyToId: replyId);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _setReply(ApiMessage message) {
    setState(() {
      _replyToMessageId = message.id;
      _replyPreviewText = message.content.isNotEmpty ? message.content : null;
    });
  }

  void _clearReply() {
    setState(() {
      _replyToMessageId = null;
      _replyPreviewText = null;
    });
  }

  String _displayText(ApiMessage message) {
    if (message.isDeleted) return context.l10n.commentsDeleted;
    if (message.content.isEmpty) return '';
    return message.content;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ApiMessage>> commentsAsync = ref.watch(postCommentsProvider(_args));
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Text(
                      context.l10n.niosgramComments,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: commentsAsync.when(
                  data: (List<ApiMessage> comments) {
                    if (comments.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.l10n.commentsEmpty,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: comments.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ApiMessage comment = comments[index];
                        return GestureDetector(
                          onLongPress: () => _setReply(comment),
                          child: MessageBubble(
                            text: _displayText(comment),
                            formattedTime: formatMessageTime(comment.sentAt),
                            isMine: comment.senderId ==
                                ref.read(authProvider).session?.userId,
                            isDeleted: comment.isDeleted,
                            senderDisplayName: comment.senderDisplayName,
                            senderAvatarUrl: comment.senderAvatarUrl,
                            senderBadges: comment.senderBadges,
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (Object e, _) => Center(
                    child: Text(context.l10n.commentsFailedLoad(e.toString())),
                  ),
                ),
              ),
              if (_replyPreviewText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: scheme.surfaceContainerHighest,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.reply_rounded, size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _replyPreviewText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: _clearReply,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: context.l10n.niosgramWriteComment,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
