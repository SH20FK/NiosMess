# M3 Expressive Post Card & Action Controls Implementation Plan

## Executive Summary
This document defines the architectural specification and line-by-line implementation blueprint for updating `lib/widgets/post_card.dart` in accordance with Material 3 Expressive standards, the `PROJECT.md` interface contracts, and the NiosGram visual redesign.

---

## 1. Scope & Objectives
1. **Surface Styling**:
   - Apply `colorScheme.surfaceContainerLow` surface color.
   - Enforce `BorderRadius.circular(24)` smooth outer corners.
   - Implement `BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.20), width: 1)` outline border.
2. **Author Header Redesign**:
   - Integrate `BadgeChip` from `lib/widgets/badge_chip.dart` for verified/status badges (`BadgeDisplayMode.statusIcon` and `BadgeDisplayMode.avatarBadge`).
   - Format author display name in bold (`FontWeight.w700`, `fontSize: 15`), followed by status badges.
   - Separate handle (`@username`) and relative time into a distinct subtitle row with dot separator and a dedicated relative time badge container (`formatRelativeTime(post.createdAt)`).
3. **Action Controls Overhaul**:
   - **Like / Heart**: Spring animation (`TweenSequence`), count display, reactive active color (`colorScheme.error`), double-tap overlay animation.
   - **Dislike**: Dislike counter and toggle.
   - **Comment**: Comment trigger with counter (`post.commentsCount`), navigating to comments screen or invoking `onComment`.
   - **Share**: System share trigger or invoking `onShare`.
   - **Bookmark (New)**: Toggleable bookmark control (`Icons.bookmark_outline_rounded` / `Icons.bookmark_rounded`), active state `_isBookmarked`, reactive haptic feedback, invoking `onBookmark` callback.
4. **Interface Contract Compliance**:
   - Expose constructor parameters: `isBookmarked`, `onLike`, `onDislike`, `onComment`, `onShare`, `onBookmark`, `onAuthorTap`, `onMediaTap`.
5. **Code Style & Lint Strictness**:
   - Zero `Colors.white` / `Colors.black` — replace legacy `Colors.black45` shadow with `scheme.scrim.withValues(alpha: 0.45)`.
   - Strict `withValues(alpha:)` syntax.

---

## 2. Component Blueprint & Exact Changes in `lib/widgets/post_card.dart`

### A. Imports & Constructor Interface
**File**: `pulse_flutter/lib/widgets/post_card.dart`  
**Target Lines**: 1–32

#### Additions / Modifications:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}
```

---

### B. State Management & Bookmark Support
**Target Lines**: 33–86

#### Implementation:
```dart
class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;
  bool _showHeart = false;
  late bool _isBookmarked;

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.isBookmarked;
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
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _handleLike();
    if (!mounted) return;
    setState(() => _showHeart = true);
    _heartController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _handleLike() {
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    if (settings.haptics) HapticService.reaction();
    if (widget.onLike != null) {
      widget.onLike!();
    } else {
      ref.read(niosgramProvider.notifier).reactPost(widget.post.id, true);
    }
  }

  void _handleDislike() {
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    if (settings.haptics) HapticService.reaction();
    if (widget.onDislike != null) {
      widget.onDislike!();
    } else {
      ref.read(niosgramProvider.notifier).reactPost(widget.post.id, false);
    }
  }

  void _handleComment() {
    if (widget.onComment != null) {
      widget.onComment!();
    } else {
      context.push('/niosgram/post/${widget.post.id}/comments');
    }
  }

  void _handleShare() {
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    if (settings.haptics) HapticService.tap();
    if (widget.onShare != null) {
      widget.onShare!();
    } else {
      SharePlus.instance.share(ShareParams(text: widget.post.content));
    }
  }

  void _handleBookmark() {
    final UiSettingsState settings = ref.read(uiSettingsProvider);
    if (settings.haptics) HapticService.selection();
    setState(() {
      _isBookmarked = !_isBookmarked;
    });
    widget.onBookmark?.call(_isBookmarked);
  }

  void _handleAuthorTap() {
    if (widget.onAuthorTap != null) {
      widget.onAuthorTap!();
    } else {
      context.push('/profile/${widget.post.author.username}');
    }
  }
```

---

### C. Surface Container & Shape Styling
**Target Lines**: 94–105

#### Implementation:
```dart
    return GestureDetector(
      onDoubleTap: _onDoubleTapLike,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
```

---

### D. Author Header with Badges & Relative Time
**Target Lines**: 106–177

#### Implementation:
```dart
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
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
                          post.author.badges.any((b) => !BadgeResolver.isStatusBadge(b)))
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
                        // Display Name + Status Badges (Verified, Founder, etc.)
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                            if (post.author.badges.where(BadgeResolver.isStatusBadge).isNotEmpty) ...[
                              const SizedBox(width: 4),
                              ...post.author.badges
                                  .where(BadgeResolver.isStatusBadge)
                                  .take(2)
                                  .map(
                                    (ApiBadge b) => Padding(
                                      padding: const EdgeInsets.only(left: 2),
                                      child: BadgeChip(
                                        id: b.id,
                                        name: b.name,
                                        icon: b.icon,
                                        color: b.color,
                                        mode: BadgeDisplayMode.statusIcon,
                                        interactive: false,
                                      ),
                                    ),
                                  ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Handle + Dot + Relative Time Badge
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                '@${post.author.username}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.outlineVariant,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                formatRelativeTime(post.createdAt),
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
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
```

---

### E. Action Controls Bar & Double-Tap Heart Overlay
**Target Lines**: 263–356

#### Implementation:
```dart
          // ── Action bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  _ActionChip(
                    icon: Icons.favorite_border_rounded,
                    activeIcon: Icons.favorite_rounded,
                    count: post.likesCount,
                    active: post.myReaction == true,
                    activeColor: scheme.error,
                    onTap: _handleLike,
                    scheme: scheme,
                  ),
                  const SizedBox(width: 2),
                  _ActionChip(
                    icon: Icons.sentiment_dissatisfied_outlined,
                    activeIcon: Icons.sentiment_dissatisfied_rounded,
                    count: post.dislikesCount,
                    active: post.myReaction == false,
                    activeColor: scheme.error,
                    onTap: _handleDislike,
                    scheme: scheme,
                  ),
                  const SizedBox(width: 2),
                  _ActionChip(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    count: post.commentsCount,
                    active: false,
                    activeColor: scheme.primary,
                    onTap: _handleComment,
                    scheme: scheme,
                  ),
                  const Spacer(),
                  _ActionChip(
                    icon: Icons.share_outlined,
                    activeIcon: Icons.share_rounded,
                    count: 0,
                    active: false,
                    activeColor: scheme.onSurfaceVariant,
                    onTap: _handleShare,
                    scheme: scheme,
                  ),
                  const SizedBox(width: 2),
                  _ActionChip(
                    icon: Icons.bookmark_outline_rounded,
                    activeIcon: Icons.bookmark_rounded,
                    count: 0,
                    active: _isBookmarked,
                    activeColor: scheme.primary,
                    onTap: _handleBookmark,
                    scheme: scheme,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      if (_showHeart)
        Positioned.fill(
          child: Center(
            child: AnimatedBuilder(
              animation: _heartController,
              builder: (_, anim) => Transform.scale(
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
```

---

## 3. Verification & Validation Strategy
1. **Static Analysis**:
   - `flutter analyze` must produce 0 errors, 0 warnings, and 0 infos.
   - Verify absence of hardcoded `Colors.white` or `Colors.black`.
   - Verify that all opacity calls use `.withValues(alpha: ...)`.
2. **Widget Tests**:
   - Verify `PostCard` renders with `post.author.badges` showing `BadgeChip` in `BadgeDisplayMode.statusIcon`.
   - Verify `onBookmark` fires with toggled boolean value upon tapping bookmark button.
   - Verify `onLike`, `onDislike`, `onComment`, `onShare`, and `onAuthorTap` callbacks execute when provided.
   - Verify default fallback behavior when callbacks are null.
