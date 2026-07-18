import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class PostCommentsScreen extends ConsumerStatefulWidget {
  const PostCommentsScreen({
    required this.channelId,
    required this.postId,
    super.key,
  });

  final int channelId;
  final int postId;

  @override
  ConsumerState<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends ConsumerState<PostCommentsScreen> {
  final TextEditingController _inputController = TextEditingController();
  int? _replyToMessageId;
  String? _replyPreview;
  bool _busy = false;

  PostCommentsArgs get _args =>
      PostCommentsArgs(channelId: widget.channelId, postId: widget.postId);

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty || _busy) {
      return;
    }

    setState(() => _busy = true);

    try {
      await ref
          .read(postCommentsProvider(_args).notifier)
          .send(text, replyToId: _replyToMessageId);
      _inputController.clear();
      if (!mounted) return;
      setState(() {
        _replyToMessageId = null;
        _replyPreview = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error is ApiException
          ? error.message
          : context.l10n.commentsFailedSend('$error');
      AppToast.showError(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _displayText(ApiMessage message) {
    if (message.isDeleted) {
      return context.l10n.commentsDeleted;
    }
    if (message.content.trim().isNotEmpty) {
      return message.content.trim();
    }
    return '[${message.msgType}]';
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final AsyncValue<List<ApiMessage>> commentsAsync = ref.watch(
      postCommentsProvider(_args),
    );

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool? confirm = await showAppConfirmDialog(
          context: context,
          title: context.l10n.dialogCancelCommentTitle,
          subtitle: context.l10n.dialogCancelCommentBody,
          confirmLabel: context.l10n.commonYes,
          cancelLabel: context.l10n.commonNo,
          icon: Icons.close_rounded,
        );
        if (confirm == true && mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.commentsTitle),
          bottom: commentsAsync.when(
            data: (List<ApiMessage> comments) => PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${comments.length}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            loading: () => null,
            error: (_, __) => null,
          ),
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: commentsAsync.when(
                data: (List<ApiMessage> comments) {
                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 56,
                            color: scheme.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.commentsEmpty,
                            style: textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final Map<int, ApiMessage> byId = <int, ApiMessage>{
                    for (final ApiMessage message in comments)
                      message.id: message,
                  };

                  return RefreshIndicator(
                    onRefresh: () => ref.read(postCommentsProvider(_args).notifier).refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      itemCount: comments.length,
                      itemBuilder: (BuildContext context, int index) {
                      final ApiMessage message = comments[index];
                      final bool isMine =
                          message.senderId == (auth.session?.userId ?? -1);

                      String? replyPreview;
                      final int? replyToId = message.replyToId;
                      if (replyToId != null && byId[replyToId] != null) {
                        final ApiMessage target = byId[replyToId]!;
                        replyPreview =
                            '${target.senderDisplayName}: ${_displayText(target)}';
                      }

                      return MessageBubble(
                        text: _displayText(message),
                        chatId: message.chatId,
                        formattedTime: formatMessageTime(message.sentAt),
                        isMine: isMine,
                        isEdited: message.isEdited,
                        isDeleted: message.isDeleted,
                        reactions: message.reactions,
                        replyPreview: replyPreview,
                        senderDisplayName: message.senderDisplayName,
                        senderAvatarUrl: message.senderAvatarUrl,
                        senderBadges: message.senderBadges,
                        hideFooter: true,
                        onLongPress: () {
                          setState(() {
                            _replyToMessageId = message.id;
                            _replyPreview =
                                '${message.senderDisplayName}: ${_displayText(message)}';
                          });
                        },
                      );
                    },
                    ),
                  );
                },
                loading: () => ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: 6,
                  itemBuilder: (_, int i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const PulseSkeleton(width: 36, height: 36, borderRadius: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              PulseSkeleton(width: 100 + (i % 3) * 20.0, height: 12),
                              const SizedBox(height: 8),
                              PulseSkeleton(width: double.infinity, height: 14, borderRadius: 6),
                              const SizedBox(height: 4),
                              PulseSkeleton(width: 180, height: 10, borderRadius: 5),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                error: (Object error, StackTrace trace) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(context.l10n.commentsFailedLoad('$error')),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.screenHorizontalPadding,
                  8,
                  AppConstants.screenHorizontalPadding,
                  12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_replyToMessageId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _replyPreview ?? context.l10n.chatReply,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _replyToMessageId = null;
                                  _replyPreview = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: context.l10n.commentsHint,
                              prefixIcon: const Icon(Icons.mode_comment_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(56, 56),
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: _busy ? null : _send,
                          child: _busy
                              ? AppLoadingIndicator(size: 24, color: Theme.of(context).colorScheme.onPrimary)
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
