import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';

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
  final FocusNode _inputFocus = FocusNode();
  int? _replyToMessageId;
  String? _replyPreview;
  bool _busy = false;

  PostCommentsArgs get _args =>
      PostCommentsArgs(channelId: widget.channelId, postId: widget.postId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.channelId > 0) {
        final List<ApiMessage>? msgs =
            ref.read(chatMessagesProvider(widget.channelId)).value;
        if (msgs == null || msgs.isEmpty) {
          ref.read(chatMessagesProvider(widget.channelId).notifier).refresh();
        }
      } else {
        final NiosgramState? ngState = ref.read(niosgramProvider).value;
        if (ngState == null || ngState.posts.isEmpty) {
          ref.read(niosgramProvider.notifier).refresh();
        }
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty || _busy) {
      return;
    }

    if (ref.read(uiSettingsProvider).haptics) {
      HapticService.confirm();
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
      AppToast.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteComment(ApiMessage comment) async {
    final bool? confirm = await showAppConfirmDialog(
      context: context,
      title: 'Удалить комментарий?',
      subtitle: 'Этот комментарий будет удален навсегда.',
      confirmLabel: 'Удалить',
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirm != true || !mounted) return;

    if (ref.read(uiSettingsProvider).haptics) {
      HapticService.reaction();
    }

    try {
      await ref
          .read(postCommentsProvider(_args).notifier)
          .deleteComment(comment.id);
      if (mounted) {
        AppToast.showSuccess(context, 'Комментарий удален');
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
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

    // Resolve parent post data (either from channel or NiosGram feed)
    _PinnedPostData? postData;
    int? postAuthorId;
    if (widget.channelId > 0) {
      final List<ApiMessage>? channelMessages =
          ref.watch(chatMessagesProvider(widget.channelId)).value;
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
          hasMedia: parentPost.hasMedia &&
              parentPost.mediaUrl != null &&
              parentPost.mediaUrl!.isNotEmpty,
        );
      }
    } else {
      final NiosgramState? ngState = ref.watch(niosgramProvider).value;
      final NgPost? niosgramPost = ngState?.posts
          .where((NgPost p) => p.id == widget.postId)
          .firstOrNull;
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
          mediaUrl: mediaUrl,
          hasMedia: mediaUrl != null && mediaUrl.isNotEmpty,
        );
      }
    }

    return ListenableBuilder(
      listenable: _inputController,
      builder: (BuildContext context, Widget? child) {
        final bool canRoutePop = ModalRoute.of(context)?.canPop ?? false;
        final bool hasDraft = _inputController.text.trim().isNotEmpty;
        return PopScope(
          canPop: canRoutePop && !hasDraft,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop) return;
            if (!hasDraft) {
              if (canRoutePop) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              } else {
                try {
                  context.go('/main/niosgram');
                } catch (_) {
                  Navigator.maybePop(context);
                }
              }
              return;
            }
            final bool? confirm = await showAppConfirmDialog(
              context: context,
              title: context.l10n.dialogCancelCommentTitle,
              subtitle: context.l10n.dialogCancelCommentBody,
              confirmLabel: context.l10n.commonYes,
              cancelLabel: context.l10n.commonNo,
              icon: Icons.close_rounded,
            );
            if (confirm == true && context.mounted) {
              if (canRoutePop) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              } else {
                try {
                  context.go('/main/niosgram');
                } catch (_) {
                  Navigator.maybePop(context);
                }
              }
            }
          },
          child: child!,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.commentsTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/main/niosgram');
              }
            },
          ),
          bottom: commentsAsync.when(
            data: (List<ApiMessage> comments) => PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  context.l10n.commentsCount(comments.length),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            loading: () => null,
            error: (_, _) => null,
          ),
        ),
        body: Column(
          children: <Widget>[
            if (postData != null) _PinnedPostHeader(data: postData),
            Expanded(
              child: commentsAsync.when(
                data: (List<ApiMessage> comments) {
                  if (comments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 48,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.forum_outlined,
                                size: 32,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.l10n.commentsEmpty,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Станьте первым, кто оставит комментарий к этой записи',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final Map<int, ApiMessage> byId = <int, ApiMessage>{
                    for (final ApiMessage message in comments)
                      message.id: message,
                  };

                  return RefreshIndicator(
                    onRefresh: () => ref
                        .read(postCommentsProvider(_args).notifier)
                        .refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
                      itemCount: comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (BuildContext context, int index) {
                        final ApiMessage comment = comments[index];
                        final bool isMine =
                            comment.senderId == (auth.session?.userId ?? -1);
                        final bool isPostAuthor = postAuthorId != null &&
                            comment.senderId != 0 &&
                            comment.senderId == postAuthorId;
                        final ApiMessage? replyTarget = comment.replyToId != null
                            ? byId[comment.replyToId!]
                            : null;

                        return CommentItemTile(
                          comment: comment,
                          isMine: isMine,
                          isPostAuthor: isPostAuthor,
                          replyTarget: replyTarget,
                          onReply: () {
                            if (ref.read(uiSettingsProvider).haptics) {
                              HapticService.tap();
                            }
                            setState(() {
                              _replyToMessageId = comment.id;
                              _replyPreview =
                                  '${comment.senderDisplayName}: ${_displayText(comment)}';
                            });
                            _inputFocus.requestFocus();
                          },
                          onDelete: isMine ? () => _deleteComment(comment) : null,
                          onAuthorTap: () {
                            if (comment.senderUsername.trim().isNotEmpty) {
                              context.push('/profile/${comment.senderUsername.trim()}');
                            }
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: 5,
                  itemBuilder: (_, int i) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const PulseSkeleton(width: 36, height: 36, borderRadius: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              PulseSkeleton(width: 110 + (i % 3) * 25.0, height: 12),
                              const SizedBox(height: 6),
                              PulseSkeleton(width: double.infinity, height: 14, borderRadius: 6),
                              const SizedBox(height: 4),
                              PulseSkeleton(width: 160, height: 12, borderRadius: 6),
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
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_replyToMessageId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            left: BorderSide(
                              color: scheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.reply_rounded, size: 16, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _replyPreview ?? context.l10n.chatReply,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _replyToMessageId = null;
                                  _replyPreview = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        PulseAvatar(
                          name: auth.profile?.displayName ?? 'Me',
                          avatarUrl: auth.profile?.avatarUrl,
                          radius: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: TextField(
                              controller: _inputController,
                              focusNode: _inputFocus,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              maxLines: 4,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: context.l10n.commentsHint,
                                hintStyle: textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _inputController,
                          builder: (context, value, _) {
                            final bool hasText = value.text.trim().isNotEmpty;
                            return SizedBox(
                              width: 40,
                              height: 40,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                  backgroundColor: hasText
                                      ? scheme.primary
                                      : scheme.surfaceContainerHighest,
                                  foregroundColor: hasText
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                onPressed: (_busy || !hasText) ? null : _send,
                                child: _busy
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: scheme.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_upward_rounded, size: 20),
                              ),
                            );
                          },
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

class _PinnedPostData {
  const _PinnedPostData({
    required this.authorName,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.createdAt,
    required this.content,
    this.mediaUrl,
    this.hasMedia = false,
  });

  final String authorName;
  final String authorUsername;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final String content;
  final String? mediaUrl;
  final bool hasMedia;
}

class _PinnedPostHeader extends StatelessWidget {
  const _PinnedPostHeader({required this.data});

  final _PinnedPostData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final String text = data.content.trim();

    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 3.5,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            PulseAvatar(
              name: data.authorName,
              avatarUrl: data.authorAvatarUrl,
              radius: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          data.authorName,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (data.authorUsername.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '@${data.authorUsername.trim()}',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        formatMessageTime(data.createdAt),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text.isNotEmpty ? text : (data.hasMedia ? 'Медиафайл' : ''),
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (data.hasMedia && data.mediaUrl != null && data.mediaUrl!.isNotEmpty) ...<Widget>[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.network(
                    data.mediaUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) =>
                        Container(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_outlined,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CommentItemTile extends StatelessWidget {
  const CommentItemTile({
    super.key,
    required this.comment,
    required this.isMine,
    required this.isPostAuthor,
    this.replyTarget,
    required this.onReply,
    required this.onDelete,
    required this.onAuthorTap,
  });

  final ApiMessage comment;
  final bool isMine;
  final bool isPostAuthor;
  final ApiMessage? replyTarget;
  final VoidCallback onReply;
  final VoidCallback? onDelete;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final String displayName = comment.senderDisplayName.trim().isNotEmpty
        ? comment.senderDisplayName.trim()
        : (comment.senderUsername.trim().isNotEmpty
            ? comment.senderUsername.trim()
            : 'Пользователь');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Avatar
          GestureDetector(
            onTap: onAuthorTap,
            child: PulseAvatar(
              name: displayName,
              avatarUrl: comment.senderAvatarUrl,
              radius: 18,
            ),
          ),
          const SizedBox(width: 10),
          // Main body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Bubble container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine
                        ? scheme.primaryContainer.withValues(alpha: 0.22)
                        : scheme.surfaceContainerHigh.withValues(alpha: 0.65),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      topLeft: Radius.circular(4),
                    ),
                    border: Border.all(
                      color: isMine
                          ? scheme.primary.withValues(alpha: 0.2)
                          : scheme.outlineVariant.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Header: Name, [Автор], @username, time
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: GestureDetector(
                              onTap: onAuthorTap,
                              child: Text(
                                displayName,
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (isPostAuthor) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Автор',
                                style: textTheme.labelSmall?.copyWith(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                          if (comment.senderUsername.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '@${comment.senderUsername.trim()}',
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Text(
                            formatMessageTime(comment.sentAt),
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      // Reply snippet if in reply to another comment
                      if (replyTarget != null) ...<Widget>[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border(
                              left: BorderSide(
                                color: scheme.primary.withValues(alpha: 0.8),
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.reply_rounded,
                                size: 12,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${replyTarget!.senderDisplayName}: ${replyTarget!.content.trim()}',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      // Content
                      Text(
                        comment.isDeleted
                            ? 'Комментарий удален'
                            : (comment.content.trim().isNotEmpty
                                ? comment.content.trim()
                                : '[${comment.msgType}]'),
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          height: 1.35,
                          color: comment.isDeleted
                              ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                              : scheme.onSurface,
                          fontStyle: comment.isDeleted ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // Footer actions
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Row(
                    children: <Widget>[
                      // Reply button
                      InkWell(
                        onTap: onReply,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.reply_rounded,
                                size: 13,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ответить',
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isMine && onDelete != null) ...<Widget>[
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 13,
                                  color: scheme.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Удалить',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.error,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
