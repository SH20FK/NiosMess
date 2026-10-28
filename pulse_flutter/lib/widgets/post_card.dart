import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/feed_poll_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/niosgram_saved_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/vector_illustrations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/screens/niosgram_video_screen.dart';

class PostCard extends ConsumerStatefulWidget {
  const PostCard({
    required this.post,
    this.isBookmarked = false,
    this.onLike,
    this.onDislike,
    this.onComment,
    this.onShare,
    this.onBookmark,
    this.onAuthorTap,
    this.onMediaTap,
    this.onChanged,
    this.onDeleted,
    super.key,
  });

  final NgPost post;
  final bool isBookmarked;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final ValueChanged<bool>? onBookmark;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onMediaTap;
  final VoidCallback? onChanged, onDeleted;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;
  bool _showHeart = false;
  bool _contentExpanded = false;
  late bool _isBookmarked;

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.isBookmarked;
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heartScale = TweenSequence<double>(
      <TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0.0, end: 1.4),
          weight: 25,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1.4, end: 1.0),
          weight: 25,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1.0, end: 0.0),
          weight: 50,
        ),
      ],
    ).animate(CurvedAnimation(parent: _heartController, curve: Curves.easeOut));
    _heartOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) _contentExpanded = false;
    if (oldWidget.isBookmarked != widget.isBookmarked) {
      _isBookmarked = widget.isBookmarked;
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _onDoubleTapLike() {
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    if (settings.haptics) HapticService.reaction();
    _handleLike(triggerHaptic: false, ensureSelected: true);
    if (!mounted) return;
    setState(() => _showHeart = true);
    _heartController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _handleLike({bool triggerHaptic = true, bool ensureSelected = false}) {
    if (ensureSelected && widget.post.myReaction == true) return;
    if (triggerHaptic) {
      final UiSettingsState settings = ref.read(uiSettingsProvider);
      if (settings.haptics) HapticService.reaction();
    }
    if (widget.onLike != null) {
      widget.onLike!();
    } else {
      ref
          .read(niosgramProvider.notifier)
          .reactPost(widget.post.id, true, ensureSelected: ensureSelected)
          .then((_) {
            if (mounted) widget.onChanged?.call();
          });
    }
  }

  void _handleDislike() {
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    if (settings.haptics) HapticService.reaction();
    if (widget.onDislike != null) {
      widget.onDislike!();
    } else {
      ref.read(niosgramProvider.notifier).reactPost(widget.post.id, false).then(
        (_) {
          if (mounted) widget.onChanged?.call();
        },
      );
    }
  }

  void _handleComment() {
    if (widget.onComment != null) {
      widget.onComment!();
    } else {
      context.push('/niosgram/post/${widget.post.id}/comments');
    }
  }

  Future<void> _handleShare() async {
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    if (settings.haptics) HapticService.tap();
    if (widget.onShare != null) {
      widget.onShare!();
      return;
    }
    final account = ref.read(authProvider).session;
    final choice = await AppBottomSheets.show<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(context.l10n.niosgramSendToChat),
              onTap: () => Navigator.pop(sheetContext, 1),
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(context.l10n.niosgramCopyLink),
              onTap: () => Navigator.pop(sheetContext, 2),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(context.l10n.niosgramShareExternal),
              onTap: () => Navigator.pop(sheetContext, 3),
            ),
          ],
        ),
      ),
    );
    if (!mounted ||
        ref.read(authProvider.notifier).isLoggingOut ||
        ref.read(authProvider).session?.userId != account?.userId ||
        ref.read(authProvider).session?.accessToken != account?.accessToken) {
      return;
    }
    final link = niosgramPostShareUrl(widget.post.id);
    if (choice == 1) {
      await _sendToChat(link);
    } else if (choice == 2) {
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) AppToast.showInfo(context, context.l10n.niosgramCopied);
    } else if (choice == 3) {
      await SharePlus.instance.share(ShareParams(text: link));
    }
  }

  Future<void> _sendToChat(String link) async {
    final session = ref.read(authProvider).session;
    bool active() =>
        mounted &&
        !ref.read(authProvider.notifier).isLoggingOut &&
        ref.read(authProvider).session?.userId == session?.userId &&
        ref.read(authProvider).session?.accessToken == session?.accessToken;
    if (session == null || !active()) return;
    try {
      final chats = (await ref.read(
        chatsProvider.future,
      )).where((chat) => !chat.isBlocked && !chat.topicClosed).toList();
      if (!mounted || !active()) return;
      if (chats.isEmpty) {
        AppToast.showInfo(context, context.l10n.niosgramNoChats);
        return;
      }
      final target = await AppBottomSheets.show<ApiChatSummary>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.chatForwardTo,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (_, index) {
                      final chat = chats[index];
                      return ListTile(
                        leading: PulseAvatar(
                          name: chat.name,
                          avatarUrl: chat.avatarUrl,
                          radius: 20,
                        ),
                        title: Text(
                          chat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(sheetContext, chat),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted || !active() || target == null) return;
      final lease = ref.listenManual(
        chatMessagesProvider(target.id),
        (_, _) {},
      );
      try {
        await ref.read(chatMessagesProvider(target.id).future);
        if (!mounted || !active()) return;
        var saved = false;
        await ref
            .read(chatMessagesProvider(target.id).notifier)
            .send(link, requestAi: false, onLocalSaved: () => saved = true);
        if (!mounted || !active()) return;
        if (!saved) throw StateError('POST_LINK_NOT_SAVED');
        AppToast.showSuccess(context, context.l10n.niosgramLinkAddedToChat);
      } finally {
        lease.close();
      }
    } catch (_) {
      if (mounted && active()) {
        AppToast.showError(context, context.l10n.niosgramSendLinkFailed);
      }
    }
  }

  Future<void> _handleBookmark() async {
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    if (settings.haptics) HapticService.tap();
    if (widget.onBookmark != null) {
      setState(() => _isBookmarked = !_isBookmarked);
      widget.onBookmark!(_isBookmarked);
      return;
    }
    try {
      await ref.read(niosgramSavedProvider.notifier).toggle(widget.post);
    } catch (_) {
      if (mounted) AppToast.showError(context, context.l10n.niosgramSaveFailed);
    }
  }

  void _handleAuthorTap() {
    if (widget.onAuthorTap != null) {
      widget.onAuthorTap!();
    } else {
      context.push('/profile/${widget.post.author.username}');
    }
  }

  void _handleMediaTap() {
    if (widget.onMediaTap != null) {
      widget.onMediaTap!();
    } else {
      final List<String> list = widget.post.mediaUrls.isNotEmpty
          ? widget.post.mediaUrls
          : (widget.post.mediaUrl != null && widget.post.mediaUrl!.isNotEmpty
                ? <String>[widget.post.mediaUrl!]
                : const <String>[]);
      if (list.isNotEmpty) {
        _openFullScreen(
          context,
          ApiConstants.resolve(list.first),
          widget.post.id,
        );
      }
    }
  }

  Widget _buildPostContent(BuildContext context, NgPost post) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final collapsible =
        post.content.length > 400 || '\n'.allMatches(post.content).length > 6;
    final markdown = MarkdownBody(
      data: post.content,
      inlineSyntaxes: [CustomEmojiSyntax()],
      builders: {'nios-emoji': CustomEmojiMarkdownBuilder()},
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
        code: TextStyle(
          backgroundColor: scheme.surfaceContainerHighest,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
      onTapLink: (text, href, title) {
        if (href != null) AppUrlLauncher.openUrl(context, href);
      },
    );
    final body = GestureDetector(
      key: ValueKey('niosgram_post_content_${post.id}'),
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _onDoubleTapLike,
      child: SizedBox(width: double.infinity, child: markdown),
    );
    if (!collapsible) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: M3SpringCurves.expressiveDecel,
          alignment: Alignment.topCenter,
          child: _contentExpanded
              ? body
              : SizedBox(
                  height: 210,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: body,
                    ),
                  ),
                ),
        ),
        TextButton(
          onPressed: () => setState(() => _contentExpanded = !_contentExpanded),
          child: Text(
            _contentExpanded
                ? context.l10n.niosgramReadLess
                : context.l10n.niosgramReadMore,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(
      niosgramSavedProvider.select(
        (value) =>
            value.value?.any((post) => post.id == widget.post.id) ?? false,
      ),
    );
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isOwn = ref.watch(
      authProvider.select(
        (a) => (a.profile?.id ?? a.session?.userId) == widget.post.author.id,
      ),
    );
    final NgPost post = widget.post;
    final List<String> effectiveMediaUrls = post.mediaUrls.isNotEmpty
        ? post.mediaUrls
        : (post.mediaUrl != null && post.mediaUrl!.isNotEmpty
              ? <String>[post.mediaUrl!]
              : const <String>[]);

    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.lgRadius),
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── Header ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      GestureDetector(
                        onTap: _handleAuthorTap,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            PulseAvatar(
                              name: post.author.displayName,
                              avatarUrl: post.author.avatarUrl,
                              radius: 20,
                            ),
                            if (post.author.badges.isNotEmpty &&
                                post.author.badges.any(
                                  (ApiBadge b) =>
                                      !BadgeResolver.isStatusBadge(b),
                                ))
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: BadgeChip(
                                  id: post.author.badges.first.id,
                                  name: post.author.badges.first.name,
                                  icon: post.author.badges.first.icon,
                                  color: post.author.badges.first.color,
                                  mode: BadgeDisplayMode.avatarBadge,
                                  interactive: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _handleAuthorTap,
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Display Name + Status Badges (Verified, Founder, Admin)
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      post.author.displayName.isNotEmpty
                                          ? post.author.displayName
                                          : post.author.username,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: scheme.onSurface,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (post.author.badges
                                      .where(BadgeResolver.isStatusBadge)
                                      .isNotEmpty) ...<Widget>[
                                    const SizedBox(width: 4),
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: post.author.badges
                                              .where(
                                                BadgeResolver.isStatusBadge,
                                              )
                                              .take(2)
                                              .map(
                                                (ApiBadge b) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 2,
                                                      ),
                                                  child: BadgeChip(
                                                    id: b.id,
                                                    name: b.name,
                                                    icon: b.icon,
                                                    color: b.color,
                                                    mode: BadgeDisplayMode
                                                        .statusIcon,
                                                    interactive: false,
                                                  ),
                                                ),
                                              )
                                              .toList(growable: false),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              // Handle + Dot + Relative Time Badge (Overflow-safe inline text)
                              Text.rich(
                                TextSpan(
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: '@${post.author.username}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '  •  ',
                                      style: TextStyle(
                                        color: scheme.outlineVariant,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: formatRelativeTime(post.createdAt),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _PostMenu(
                        post: post,
                        isOwn: isOwn,
                        onChanged: widget.onChanged,
                        onDeleted: widget.onDeleted,
                      ),
                    ],
                  ),
                ),

                // ── Content ─────────────────────────────────────────
                if (post.content.isNotEmpty)
                  Padding(
                    key: ValueKey('niosgram_post_content_frame_${post.id}'),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildPostContent(context, post),
                    ),
                  ),

                if (post.poll != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: FeedPollCard(postId: post.id, poll: post.poll!),
                  ),
                // ── Media Viewport ──────────────────────────────────
                if (effectiveMediaUrls.isNotEmpty)
                  _PostMediaViewport(
                    post: post,
                    mediaUrls: effectiveMediaUrls,
                    onDoubleTapLike: _onDoubleTapLike,
                    onMediaTap: _handleMediaTap,
                  ),

                // ── Action bar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: <Widget>[
                      _ActionChip(
                        label: context.l10n.niosgramLikeAction,
                        icon: Icons.favorite_border_rounded,
                        activeIcon: Icons.favorite_rounded,
                        count: post.likesCount,
                        active: post.myReaction == true,
                        activeColor: scheme.error,
                        onTap: _handleLike,
                        scheme: scheme,
                      ),
                      _ActionChip(
                        label: context.l10n.niosgramDislikeAction,
                        icon: Icons.sentiment_dissatisfied_outlined,
                        activeIcon: Icons.sentiment_dissatisfied_rounded,
                        count: post.dislikesCount,
                        active: post.myReaction == false,
                        activeColor: scheme.error,
                        onTap: _handleDislike,
                        scheme: scheme,
                      ),
                      _ActionChip(
                        label: context.l10n.niosgramCommentAction,
                        icon: Icons.chat_bubble_outline_rounded,
                        activeIcon: Icons.chat_bubble_rounded,
                        count: post.commentsCount,
                        active: false,
                        activeColor: scheme.primary,
                        onTap: _handleComment,
                        scheme: scheme,
                      ),
                      _ActionChip(
                        label: context.l10n.niosgramShareAction,
                        icon: Icons.share_outlined,
                        activeIcon: Icons.share_rounded,
                        count: 0,
                        active: false,
                        activeColor: scheme.onSurfaceVariant,
                        onTap: _handleShare,
                        scheme: scheme,
                      ),
                      _ActionChip(
                        label: context.l10n.niosgramSaveAction,
                        icon: Icons.bookmark_outline_rounded,
                        activeIcon: Icons.bookmark_rounded,
                        count: 0,
                        active: widget.onBookmark == null
                            ? saved
                            : _isBookmarked,
                        activeColor: scheme.primary,
                        onTap: _handleBookmark,
                        scheme: scheme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_showHeart)
              Positioned.fill(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _heartController,
                    builder: (_, Widget? anim) => Transform.scale(
                      scale: _heartScale.value,
                      child: Opacity(
                        opacity: _heartOpacity.value,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: scheme.error,
                          size: 100,
                          shadows: <Shadow>[
                            Shadow(
                              blurRadius: 24,
                              color: scheme.scrim.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _openFullScreen(BuildContext context, String url, int postId) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierLabel: context.l10n.semanticsClose,
      pageBuilder: (_, _, _) => _FullScreenImage(url: url, postId: postId),
      transitionsBuilder: (_, Animation<double> a1, _, Widget child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
          child: child,
        );
      },
    ),
  );
}

String niosgramPostShareUrl(int postId) =>
    '${AppUrlLauncher.webOrigin}/web/#/niosgram/post/$postId';

bool _isFeedVideo(String url, NgPost post, int index) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  return RegExp(r'\.(mp4|webm|mov|mkv|avi|3gp)$').hasMatch(path) ||
      (index == 0 && post.isVideo);
}

Widget _feedVideoTile(BuildContext context, String url) {
  final scheme = Theme.of(context).colorScheme;
  return Material(
    color: scheme.surfaceContainerHighest,
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => NiosgramVideoScreen(url: url)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 52,
              color: scheme.primary,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.niosgramPlayVideo),
          ],
        ),
      ),
    ),
  );
}

Widget _feedImage(BuildContext context, String url) {
  final scheme = Theme.of(context).colorScheme;
  final provider = CachedNetworkImageProvider(ApiConstants.resolve(url));
  return Image(
    image: ResizeImage(
      provider,
      width: 600,
      height: 800,
      policy: ResizeImagePolicy.fit,
    ),
    fit: BoxFit.contain,
    width: double.infinity,
    frameBuilder: (context, child, frame, _) =>
        frame == null ? _MediaPlaceholderShimmer(scheme: scheme) : child,
    errorBuilder: (_, _, _) => _MediaErrorPlaceholder(scheme: scheme),
  );
}

// ── Full-screen image viewer ─────────────────────────────────────────
class _FullScreenImage extends StatefulWidget {
  const _FullScreenImage({required this.url, required this.postId});
  final String url;
  final int postId;

  @override
  State<_FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<_FullScreenImage> {
  bool _visible = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: ColoredBox(
        color: scheme.surface,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Hero(
                tag: 'post_media_${widget.postId}',
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _visible ? 1.0 : 0.0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : M3Durations.medium1,
                      child: CachedNetworkImage(
                        imageUrl: widget.url,
                        fit: BoxFit.contain,
                        memCacheWidth: 1600,
                        placeholder: (_, _) => const Center(
                          child: MediaPlaceholderIllustration(
                            width: 220,
                            height: 180,
                          ),
                        ),
                        errorWidget: (_, _, _) => Center(
                          child: MediaErrorIllustration(
                            width: 260,
                            height: 180,
                            message: context.l10n.niosgramFailedLoad,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    curve: M3SpringCurves.expressiveDecel,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : M3Durations.short3,
                    child: Material(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              context.l10n.mediaViewerTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Media Viewport (Carousel & Video) ────────────────────────────────
class _PostMediaViewport extends StatefulWidget {
  const _PostMediaViewport({
    required this.post,
    required this.mediaUrls,
    required this.onDoubleTapLike,
    required this.onMediaTap,
  });

  final NgPost post;
  final List<String> mediaUrls;
  final VoidCallback onDoubleTapLike;
  final VoidCallback onMediaTap;

  @override
  State<_PostMediaViewport> createState() => _PostMediaViewportState();
}

class _PostMediaViewportState extends State<_PostMediaViewport> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isMultiple = widget.mediaUrls.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTapLike,
        child: ClipRRect(
          borderRadius: AppRadii.mdRadius,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: AppRadii.mdRadius,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
            child: AspectRatio(
              aspectRatio: widget.post.isVideo
                  ? (16 / 9)
                  : (isMultiple ? 1.0 : (4 / 3)),
              child: Stack(
                children: <Widget>[
                  if (isMultiple)
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.mediaUrls.length,
                      onPageChanged: (int index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final String url = widget.mediaUrls[index];
                        if (_isFeedVideo(url, widget.post, index)) {
                          return _feedVideoTile(context, url);
                        }
                        return GestureDetector(
                          onTap: () => _openFullScreen(
                            context,
                            ApiConstants.resolve(url),
                            widget.post.id,
                          ),
                          child: _feedImage(context, url),
                        );
                      },
                    )
                  else if (_isFeedVideo(widget.mediaUrls.first, widget.post, 0))
                    _feedVideoTile(context, widget.mediaUrls.first)
                  else
                    GestureDetector(
                      key: ValueKey('post-media-open-${widget.post.id}'),
                      onTap: widget.onMediaTap,
                      child: Hero(
                        tag: 'post_media_${widget.post.id}',
                        child: _feedImage(context, widget.mediaUrls.first),
                      ),
                    ),

                  // If video, render a subtle video badge
                  if (widget.post.isVideo)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.scrim.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.play_arrow_rounded,
                              color: scheme.onSurface,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'VIDEO',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Carousel dots indicator & counter
                  if (isMultiple) ...<Widget>[
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.scrim.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_currentPage + 1}/${widget.mediaUrls.length}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(
                          widget.mediaUrls.length,
                          (int idx) {
                            final bool active = idx == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              width: active ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: active
                                    ? scheme.primary
                                    : scheme.surface.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Refined action chip (X / Threads style) ──────────────────────────
class _ActionChip extends StatefulWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.active,
    required this.activeColor,
    required this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final IconData activeIcon;
  final int count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.32,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.32,
          end: 1.0,
        ).chain(CurveTween(curve: M3SpringCurves.bouncy)),
        weight: 65,
      ),
    ]).animate(_ctrl);
  }

  @override
  void didUpdateWidget(covariant _ActionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = widget.active
        ? widget.activeColor
        : widget.scheme.onSurfaceVariant;
    return Tooltip(
      message: widget.label,
      child: TouchContainer(
        borderRadius: AppRadii.fullRadius,
        onTap: _handleTap,
        child: Material(
          color: widget.active
              ? widget.activeColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: AppRadii.fullRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AnimatedBuilder(
                  animation: _scale,
                  builder: (_, Widget? child) {
                    return Transform.scale(scale: _scale.value, child: child);
                  },
                  child: Icon(
                    widget.active ? widget.activeIcon : widget.icon,
                    size: 18,
                    color: effectiveColor,
                  ),
                ),
                if (widget.count > 0) ...<Widget>[
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(widget.count),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: effectiveColor,
                      fontWeight: widget.active
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── Post menu ────────────────────────────────────────────────────────
class _PostMenu extends ConsumerWidget {
  final VoidCallback? onChanged, onDeleted;
  const _PostMenu({
    required this.post,
    required this.isOwn,
    this.onChanged,
    this.onDeleted,
  });

  final NgPost post;

  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            return IconButton(
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              icon: Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
            );
          },
      menuChildren: <Widget>[
        if (!isOwn)
          MenuItemButton(
            leadingIcon: Icon(
              post.isFollowing
                  ? Icons.person_remove_outlined
                  : Icons.person_add_outlined,
            ),
            onPressed: () => ref
                .read(niosgramProvider.notifier)
                .toggleFollow(post.author.username),
            child: Text(
              post.isFollowing
                  ? context.l10n.niosgramUnfollow
                  : context.l10n.niosgramFollow,
            ),
          ),
        if (isOwn) ...<Widget>[
          MenuItemButton(
            leadingIcon: const Icon(Icons.edit_rounded),
            onPressed: () => _showEditSheet(context),
            child: Text(context.l10n.niosgramEdit),
          ),
          MenuItemButton(
            leadingIcon: Icon(Icons.delete_rounded, color: scheme.error),
            onPressed: () async {
              final account = ref.read(authProvider).session;
              bool active() =>
                  context.mounted &&
                  !ref.read(authProvider.notifier).isLoggingOut &&
                  ref.read(authProvider).session?.userId == account?.userId &&
                  ref.read(authProvider).session?.accessToken ==
                      account?.accessToken;
              if (!active()) return;
              final bool? confirm = await showAppConfirmDialog(
                context: context,
                title: context.l10n.niosgramDeletePost,
                subtitle: context.l10n.niosgramDeletePostConfirm,
                confirmLabel: context.l10n.commonDelete,
                cancelLabel: context.l10n.commonCancel,
                icon: Icons.delete_rounded,
                destructive: true,
              );
              if (confirm == true && context.mounted && active()) {
                try {
                  await ref.read(niosgramProvider.notifier).deletePost(post.id);
                  if (active()) onDeleted?.call();
                } catch (error) {
                  if (context.mounted && active()) {
                    AppToast.showError(context, error);
                  }
                }
              }
            },
            child: Text(
              context.l10n.commonDelete,
              style: TextStyle(color: scheme.error),
            ),
          ),
        ],
        MenuItemButton(
          leadingIcon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: post.content));
            if (context.mounted) {
              AppToast.showInfo(context, context.l10n.niosgramCopied);
            }
          },
          child: Text(context.l10n.niosgramCopyText),
        ),
      ],
    );
  }

  void _showEditSheet(BuildContext context) {
    AppBottomSheets.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditPostSheet(post: post, onChanged: onChanged),
    );
  }
}

class _EditPostSheet extends ConsumerStatefulWidget {
  const _EditPostSheet({required this.post, this.onChanged});

  final NgPost post;
  final VoidCallback? onChanged;

  @override
  ConsumerState<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<_EditPostSheet> {
  late final CustomEmojiTextController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = CustomEmojiTextController(text: widget.post.content);
  }

  @override
  void dispose() {
    // A modal's result completes before its reverse animation unmounts the
    // TextField. Own its controller for that complete widget lifetime.
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || ref.read(authProvider.notifier).isLoggingOut) return;
    final submitted = _controller.text.trim();
    if (submitted.isEmpty) return;
    final account = ref.read(authProvider).session;
    bool active() =>
        mounted &&
        !ref.read(authProvider.notifier).isLoggingOut &&
        ref.read(authProvider).session?.userId == account?.userId &&
        ref.read(authProvider).session?.accessToken == account?.accessToken;
    setState(() => _saving = true);
    try {
      await ref
          .read(niosgramProvider.notifier)
          .editPost(widget.post.id, submitted);
      if (!mounted || !active()) return;
      if (_controller.text.trim() == submitted) Navigator.pop(context);
      widget.onChanged?.call();
    } catch (error) {
      if (mounted && active()) AppToast.showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: _controller,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: context.l10n.niosgramEditPost,
            border: const OutlineInputBorder(),
          ),
        ),
        CustomEmojiComposerButton(controller: _controller),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Media Shimmer & Error Placeholders ───────────────────────────────
class _MediaPlaceholderShimmer extends StatelessWidget {
  const _MediaPlaceholderShimmer({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return const MediaPlaceholderIllustration(
      width: double.infinity,
      height: double.infinity,
      borderRadius: BorderRadius.zero,
      animate: true,
    );
  }
}

class _MediaErrorPlaceholder extends StatelessWidget {
  const _MediaErrorPlaceholder({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return MediaErrorIllustration(
      width: double.infinity,
      height: double.infinity,
      borderRadius: BorderRadius.zero,
      message: context.l10n.niosgramFailedLoad,
    );
  }
}
