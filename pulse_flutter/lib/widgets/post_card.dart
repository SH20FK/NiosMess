import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/glass_card.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

class PostCard extends ConsumerStatefulWidget {
  const PostCard({required this.post, super.key});

  final NgPost post;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heartScale = TweenSequence<double>(<TweenSequenceItem<double>>[
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
    ]).animate(CurvedAnimation(parent: _heartController, curve: Curves.easeOut));
    _heartOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _onDoubleTapLike() {
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    if (settings.haptics) HapticService.reaction();
    ref.read(niosgramProvider.notifier).reactPost(widget.post.id, true);
    if (!mounted) return;
    setState(() => _showHeart = true);
    _heartController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AuthState auth = ref.watch(authProvider);
    final bool isOwn = auth.profile?.id == widget.post.author.id;
    final NgPost post = widget.post;

    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: <Widget>[
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Row(
              children: <Widget>[
                GestureDetector(
                  onTap: () => context.push('/profile/${post.author.username}'),
                  child: PulseAvatar(
                    name: post.author.displayName,
                    avatarUrl: post.author.avatarUrl,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        context.push('/profile/${post.author.username}'),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            post.author.displayName.isNotEmpty
                                ? post.author.displayName
                                : post.author.username,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '@${post.author.username}  ·  ${formatRelativeTime(post.createdAt)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!isOwn)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: TextButton(
                      onPressed: () {
                        ref.read(niosgramProvider.notifier).toggleFollow(post.author.username);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        post.isFollowing ? context.l10n.niosgramUnfollow : context.l10n.niosgramFollow,
                        style: textTheme.labelMedium?.copyWith(
                          color: post.isFollowing ? scheme.onSurfaceVariant : scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                _PostMenu(post: post, isOwn: isOwn),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: MarkdownBody(
                  data: post.content,
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      height: 1.45,
                    ),
                    code: TextStyle(
                      backgroundColor: scheme.surfaceContainerHighest,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                  onTapLink: (String text, String? href, String title) {
                    if (href != null) {
                      launchUrl(
                        Uri.parse(href),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
            ),

          // ── Media ───────────────────────────────────────────────
          if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GestureDetector(
                onDoubleTap: _onDoubleTapLike,
                onTap: () => _openFullScreen(context, post.mediaUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Hero(
                            tag: 'post_media_${post.id}',
                            child: CachedNetworkImage(
                              imageUrl: post.mediaUrl!,
                              fit: BoxFit.contain,
                              memCacheWidth: 800,
                              placeholder: (_, _) => Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              errorWidget: (_, _, _) => Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: scheme.outline,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_showHeart)
                          AnimatedBuilder(
                            animation: _heartController,
                            builder: (_, anim) => Transform.scale(
                              scale: _heartScale.value,
                              child: Opacity(
                                opacity: _heartOpacity.value,
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: Color(0xFFFF3B5C),
                                  size: 80,
                                  shadows: <Shadow>[
                                    Shadow(blurRadius: 20, color: Colors.black45),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Action bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: <Widget>[
                  _ActionChip(
                    icon: Icons.favorite_border_rounded,
                    activeIcon: Icons.favorite_rounded,
                    count: post.likesCount,
                    active: post.myReaction == true,
                    activeColor: const Color(0xFFFF3B5C),
                    isLike: true,
                    onTap: () {
                      if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
                      ref
                          .read(niosgramProvider.notifier)
                          .reactPost(post.id, true);
                    },
                    scheme: scheme,
                  ),
                  const SizedBox(width: 2),
                  _ActionChip(
                    icon: Icons.sentiment_dissatisfied_outlined,
                    activeIcon: Icons.sentiment_dissatisfied_rounded,
                    count: post.dislikesCount,
                    active: post.myReaction == false,
                    activeColor: scheme.error,
                    isLike: false,
                    onTap: () {
                      if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
                      ref
                          .read(niosgramProvider.notifier)
                          .reactPost(post.id, false);
                    },
                    scheme: scheme,
                  ),
                  const SizedBox(width: 2),
                  _ActionChip(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    count: post.commentsCount,
                    active: false,
                    activeColor: scheme.primary,
                    isLike: false,
                    onTap: () =>
                        context.push('/niosgram/post/${post.id}/comments'),
                    scheme: scheme,
                  ),
                  const Spacer(),
                  _ActionChip(
                    icon: Icons.share_outlined,
                    activeIcon: Icons.share_rounded,
                    count: 0,
                    active: false,
                    activeColor: scheme.onSurfaceVariant,
                    isLike: false,
                    onTap: () {
                      if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
                      Clipboard.setData(
                        ClipboardData(text: post.content),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.niosgramCopied),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    scheme: scheme,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _openFullScreen(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        barrierLabel: 'Close',
        pageBuilder: (_, _, _) => _FullScreenImage(url: url),
        transitionsBuilder: (_, a1, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }
}

// ── Full-screen image viewer ─────────────────────────────────────────
class _FullScreenImage extends StatefulWidget {
  const _FullScreenImage({required this.url});
  final String url;

  @override
  State<_FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<_FullScreenImage> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Hero(
              tag: 'post_media_${widget.url.hashCode}',
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: CachedNetworkImage(
                      imageUrl: widget.url,
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white38,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Refined action chip (X / Threads style) ──────────────────────────
class _ActionChip extends StatefulWidget {
  const _ActionChip({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.active,
    required this.activeColor,
    required this.isLike,
    required this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool active;
  final Color activeColor;
  final bool isLike;
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
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.35),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.35, end: 0.9),
        weight: 20,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.9, end: 1.1),
        weight: 20,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.1, end: 1.0),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
    final Color effectiveColor =
        widget.active ? widget.activeColor : widget.scheme.onSurfaceVariant;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedBuilder(
              animation: _scale,
              builder: (_, Widget? child) {
                return Transform.scale(
                  scale: _scale.value,
                  child: child,
                );
              },
              child: Icon(
                widget.active ? widget.activeIcon : widget.icon,
                size: 20,
                color: effectiveColor,
              ),
            ),
            if (widget.count > 0) ...<Widget>[
              const SizedBox(width: 4),
              Text(
                _formatCount(widget.count),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: effectiveColor,
                      fontWeight:
                          widget.active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
              ),
            ],
          ],
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
  const _PostMenu({required this.post, required this.isOwn});

  final NgPost post;

  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onSelected: (String value) async {
        if (value == 'delete') {
          final bool? confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(context.l10n.niosgramDeletePost),
              content: Text(context.l10n.niosgramDeletePostConfirm),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.commonDelete),
                ),
              ],
            ),
          );
          if (confirm == true) {
            ref.read(niosgramProvider.notifier).deletePost(post.id);
          }
        } else if (value == 'edit') {
          _showEditSheet(context, ref);
        } else if (value == 'copy') {
          await Clipboard.setData(ClipboardData(text: post.content));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.niosgramCopied)),
            );
          }
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        if (isOwn) ...<PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_rounded),
              title: Text(context.l10n.niosgramEdit),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_rounded),
              title: Text(context.l10n.commonDelete),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        PopupMenuItem<String>(
          value: 'copy',
          child: ListTile(
            leading: Icon(Icons.copy_rounded),
            title: Text(context.l10n.niosgramCopyText),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController ctrl =
        TextEditingController(text: post.content);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
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
              controller: ctrl,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: context.l10n.niosgramEditPost,
                border: OutlineInputBorder(),
              ),
            ),
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
                  onPressed: () {
                    if (ctrl.text.trim().isNotEmpty) {
                      ref
                          .read(niosgramProvider.notifier)
                          .editPost(post.id, ctrl.text);
                      Navigator.pop(context);
                    }
                  },
                  child: Text(context.l10n.commonSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
