import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/widgets/feed_poll_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/comment_thread.dart';
import 'package:pulse_flutter/repositories/post_comments_repository.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/comment_item.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_picker.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

final feedPostByIdProvider = FutureProvider.family<NgPost, int>((
  ref,
  id,
) async {
  ref.watch(authProvider.select((a) => a.session?.userId));
  final data = await ref
      .read(postCommentsRepositoryProvider)
      .request('get_feed_post', 0, id, {});
  final posts = data['posts'] as List? ?? [];
  if (posts.isEmpty) throw StateError('Публикация не найдена');
  return NgPost.fromJson(Map<String, dynamic>.from(posts.first as Map));
});

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
  final _inputController = CustomEmojiTextController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final _collapsed = <int>{};
  final _qualityReported = <int>{};
  final _qualityPending = <int>{};
  ApiMessage? _reply;
  ApiMessage? _editing;
  bool _busy = false;
  bool _allowPop = false;
  PostCommentsArgs get _args =>
      PostCommentsArgs(channelId: widget.channelId, postId: widget.postId);
  PostCommentsNotifier get _notifier =>
      ref.read(postCommentsProvider(_args).notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        _perform(() => _notifier.loadMore());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.channelId > 0) {
        if (ref.read(chatMessagesProvider(widget.channelId)).value?.isEmpty ??
            true) {
          ref.read(chatMessagesProvider(widget.channelId).notifier).refresh();
        }
      } else if (ref.read(niosgramProvider).value?.posts.isEmpty ?? true) {
        ref.read(niosgramProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) AppToast.showError(context, error);
    }
  }

  Future<void> _reportQuality(ApiMessage comment) async {
    if (!_qualityPending.add(comment.id)) return;
    try {
      await ref.read(postCommentsRepositoryProvider).request(
        'report_ai_comment_quality',
        widget.channelId,
        widget.postId,
        {'comment_id': comment.id},
      );
      if (mounted) {
        setState(() => _qualityReported.add(comment.id));
        AppToast.showSuccess(context, 'Жалоба на качество отправлена');
      }
    } catch (error) {
      if (mounted) AppToast.showError(context, error);
    } finally {
      _qualityPending.remove(comment.id);
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (_busy || text.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (_editing != null) {
        await _notifier.editComment(_editing!.id, text);
      } else {
        await _notifier.send(text, replyToId: _reply?.id);
      }
      if (!mounted) return;
      if (_reply != null) _collapsed.remove(_reply!.id);
      _inputController.clear();
      setState(() {
        _reply = null;
        _editing = null;
      });
    } catch (error) {
      if (mounted) AppToast.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(ApiMessage comment) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Удалить комментарий?',
      subtitle: 'Ответы останутся в обсуждении.',
      confirmLabel: 'Удалить',
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirm == true && mounted) {
      await _perform(() => _notifier.deleteComment(comment.id));
    }
  }

  Future<void> _leave() async {
    if (_inputController.text.trim().isNotEmpty) {
      final confirm = await showAppConfirmDialog(
        context: context,
        title: context.l10n.dialogCancelCommentTitle,
        subtitle: context.l10n.dialogCancelCommentBody,
        confirmLabel: context.l10n.commonYes,
        cancelLabel: context.l10n.commonNo,
        icon: Icons.close,
      );
      if (confirm != true || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/main/niosgram');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final commentsAsync = ref.watch(postCommentsProvider(_args));
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Resolve parent post data (either from channel or NiosGram feed)
    _PinnedPostData? postData;
    int? postAuthorId;
    if (widget.channelId > 0) {
      final List<ApiMessage>? channelMessages = ref
          .watch(chatMessagesProvider(widget.channelId))
          .value;
      final ApiMessage? parentPost = channelMessages
          ?.where((ApiMessage m) => m.id == widget.postId)
          .firstOrNull;
      if (parentPost != null) {
        postAuthorId = parentPost.senderId;
        postData = _PinnedPostData(
          authorName: parentPost.senderDisplayName.isNotEmpty
              ? parentPost.senderDisplayName
              : 'Канал',
          authorUsername: parentPost.senderUsername,
          authorAvatarUrl: parentPost.senderAvatarUrl,
          createdAt: parentPost.sentAt,
          content: parentPost.content,
          mediaUrl: parentPost.mediaUrl,
          hasMedia:
              parentPost.hasMedia &&
              parentPost.mediaUrl != null &&
              parentPost.mediaUrl!.isNotEmpty,
        );
      }
    } else {
      final NiosgramState? ngState = ref.watch(niosgramProvider).value;
      final NgPost? cachedPost = ngState?.posts
          .where((NgPost p) => p.id == widget.postId)
          .firstOrNull;
      final niosgramPost =
          cachedPost ?? ref.watch(feedPostByIdProvider(widget.postId)).value;
      if (niosgramPost != null) {
        postAuthorId = niosgramPost.author.id;
        final String? mediaUrl = niosgramPost.mediaUrls.isNotEmpty
            ? niosgramPost.mediaUrls.first
            : niosgramPost.mediaUrl;
        postData = _PinnedPostData(
          authorName: niosgramPost.author.displayName.isNotEmpty
              ? niosgramPost.author.displayName
              : (niosgramPost.author.username.isNotEmpty
                    ? niosgramPost.author.username
                    : 'Автор'),
          authorUsername: niosgramPost.author.username,
          authorAvatarUrl: niosgramPost.author.avatarUrl,
          createdAt: niosgramPost.createdAt,
          content: niosgramPost.content,
          poll: niosgramPost.poll,
          postId: widget.postId,
          mediaUrl: mediaUrl,
          hasMedia: mediaUrl != null && mediaUrl.isNotEmpty,
        );
      }
    }

    return ListenableBuilder(
      listenable: _inputController,
      builder: (context, _) => PopScope(
        canPop: _allowPop || _inputController.text.trim().isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Назад',
              icon: const CommentIcon('back'),
              onPressed: _leave,
            ),
            title: Text(context.l10n.commentsTitle),
            actions: [
              if (commentsAsync.value != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      '${_notifier.totalCount ?? commentsAsync.value!.where((c) => !c.isDeleted).length}',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              if (postData != null) _PinnedPostHeader(data: postData),
              Expanded(
                child: commentsAsync.when(
                  loading: () => const Center(child: AppLoadingIndicator()),
                  error: (error, _) => Center(
                    child: TextButton(
                      onPressed: () => _notifier.refresh(),
                      child: const Text('Повторить загрузку'),
                    ),
                  ),
                  data: (comments) {
                    final rows = buildCommentThread(
                      comments,
                      collapsed: _collapsed,
                    );
                    final byId = {
                      for (final comment in comments) comment.id: comment,
                    };
                    return RefreshIndicator(
                      onRefresh: () => _notifier.refresh(),
                      child: ListView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 8, bottom: 24),
                        itemCount: rows.length + 1,
                        itemBuilder: (context, index) {
                          if (index == rows.length) {
                            if (_notifier.hasMore) {
                              return Center(
                                child: TextButton(
                                  onPressed: () =>
                                      _perform(() => _notifier.loadMore()),
                                  child: const Text(
                                    'Загрузить ещё комментарии',
                                  ),
                                ),
                              );
                            }
                            if (rows.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  context.l10n.commentsEmpty,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }
                          final row = rows[index];
                          final comment = row.message;
                          return CommentItem(
                            key: ValueKey(comment.id),
                            comment: comment,
                            depth: row.depth,
                            continueParentLine:
                                index + 1 < rows.length &&
                                rows[index + 1].depth >= row.depth,
                            parent: byId[comment.replyToId],
                            isMine: comment.senderId == auth.session?.userId,
                            isPostAuthor: comment.senderId == postAuthorId,
                            replyCount: row.descendants,
                            collapsed: _collapsed.contains(comment.id),
                            onToggleReplies: () => setState(() {
                              if (!_collapsed.remove(comment.id)) {
                                _collapsed.add(comment.id);
                              }
                            }),
                            onReply: () {
                              setState(() {
                                _reply = comment;
                                _editing = null;
                              });
                              _inputFocus.requestFocus();
                            },
                            onEdit: () {
                              setState(() {
                                _editing = comment;
                                _reply = null;
                              });
                              _inputController.text = comment.content;
                              _inputFocus.requestFocus();
                            },
                            onDelete: () => _delete(comment),
                            qualityReported: _qualityReported.contains(
                              comment.id,
                            ),
                            onQualityReport:
                                comment.systemEvent?['is_niosai_reply'] ==
                                        true ||
                                    comment.senderUsername == 'nios_ai'
                                ? () => _reportQuality(comment)
                                : null,
                            onReact: (reaction) => _perform(
                              () => _notifier.react(comment.id, reaction),
                            ),
                            onAuthorTap: () {
                              if (comment.senderUsername.isNotEmpty) {
                                context.push(
                                  '/profile/${comment.senderUsername}',
                                );
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Material(
                  color: scheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_reply != null || _editing != null)
                          Row(
                            children: [
                              const CommentIcon('reply', size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _editing != null
                                      ? 'Редактирование комментария'
                                      : 'Ответ ${_reply!.senderDisplayName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelLarge,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Отменить',
                                icon: const CommentIcon('close', size: 18),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        if (_editing != null) {
                                          _inputController.clear();
                                        }
                                        _editing = null;
                                        _reply = null;
                                      }),
                              ),
                            ],
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inputController,
                                focusNode: _inputFocus,
                                enabled: !_busy,
                                minLines: 1,
                                maxLines: 6,
                                inputFormatters: [
                                  CustomEmojiLengthFormatter(10000),
                                ],
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Комментарий или вопрос @ai',
                                  counterText: '',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            CustomEmojiComposerButton(
                              controller: _inputController,
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: _editing == null
                                  ? 'Отправить'
                                  : 'Сохранить',
                              onPressed:
                                  _busy || _inputController.text.trim().isEmpty
                                  ? null
                                  : _send,
                              icon: _busy
                                  ? const AppLoadingIndicator(size: 20)
                                  : CommentIcon(
                                      'send',
                                      color: scheme.onPrimary,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedPostData {
  const _PinnedPostData({
    required this.authorName,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.createdAt,
    required this.content,
    this.mediaUrl,
    this.hasMedia = false,
    this.poll,
    this.postId = 0,
  });

  final String authorName;
  final String authorUsername;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final String content;
  final String? mediaUrl;
  final bool hasMedia;
  final Map<String, dynamic>? poll;
  final int postId;
}

class _PinnedPostHeader extends StatelessWidget {
  const _PinnedPostHeader({required this.data});
  final _PinnedPostData data;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PulseAvatar(
              name: data.authorName,
              avatarUrl: data.authorAvatarUrl,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(data.authorName, style: theme.textTheme.labelLarge),
                      if (data.authorUsername.isNotEmpty)
                        Text(
                          '@${data.authorUsername}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        formatMessageTime(data.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  CustomEmojiText(
                    data.content.isNotEmpty
                        ? data.content
                        : (data.hasMedia ? 'Медиафайл' : ''),
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data.poll != null) ...[
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: CustomEmojiText(
                        data.poll!['title'] as String? ?? '',
                      ),
                      subtitle: Text(
                        data.poll!['kind'] == 'quiz' ? 'Викторина' : 'Опрос',
                      ),
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: SingleChildScrollView(
                            child: FeedPollCard(
                              postId: data.postId,
                              poll: data.poll!,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
