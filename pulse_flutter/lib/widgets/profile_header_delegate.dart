import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

class ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  const ProfileHeaderDelegate({
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.onBack,
    this.badges = const <ApiBadge>[],
    this.statusText,
    this.isOnline = false,
    this.onMore,
    this.isMe = false,
    this.topInset = 0.0,
    this.heroTag,
  });

  final String name;
  final String username;
  final String? avatarUrl;
  final List<ApiBadge> badges;
  final String? statusText;
  final bool isOnline;
  final VoidCallback onBack;
  final VoidCallback? onMore;
  final bool isMe;
  final double topInset;
  final String? heroTag;

  @override
  double get minExtent => kToolbarHeight + topInset;

  @override
  double get maxExtent => 230.0 + topInset;

  Widget _buildFadedLayer(double opacity, Widget child) {
    if (opacity <= 0.0) return const SizedBox.shrink();
    if (opacity >= 0.98) return child;
    return Opacity(opacity: opacity, child: child);
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final double maxShrink = (maxExtent - minExtent).clamp(0.1, 1000.0);
    final double progress = (shrinkOffset / maxShrink).clamp(0.0, 1.0);

    // Smooth continuous crossfade without dead animation gap
    final double expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final double collapsedOpacity = ((progress - 0.45) * 1.8).clamp(0.0, 1.0);

    final Color headerBackground = Color.lerp(
      scheme.surface,
      scheme.surfaceContainer,
      progress,
    )!;

    final Widget avatar = PulseAvatar(
      name: name,
      avatarUrl: avatarUrl,
      radius: 48,
      fallbackColor: scheme.primaryContainer,
      textColor: scheme.onPrimaryContainer,
      borderColor: scheme.surface,
      borderWidth: 3,
    );

    return Material(
      color: headerBackground,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // ── Expanded Content (Avatar + Name + Status) ──────────────
          if (expandedOpacity > 0.0)
            Positioned.fill(
              child: _buildFadedLayer(
                expandedOpacity,
                Padding(
                  padding: EdgeInsets.only(top: topInset + 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // Hero Avatar
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomRight,
                        children: <Widget>[
                          if (heroTag != null && heroTag!.isNotEmpty)
                            Hero(tag: heroTag!, child: avatar)
                          else
                            avatar,
                          if (badges.isNotEmpty)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: BadgeChip(
                                id: badges.first.id,
                                name: badges.first.name,
                                icon: badges.first.icon,
                                color: badges.first.color,
                                mode: BadgeDisplayMode.avatarBadge,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Display Name + Badges
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            if (badges.where(BadgeResolver.isStatusBadge).isNotEmpty) ...[
                              const SizedBox(width: 6),
                              ...badges.where(BadgeResolver.isStatusBadge).take(2).map(
                                    (ApiBadge b) => Padding(
                                      padding: const EdgeInsets.only(left: 2),
                                      child: BadgeChip(
                                        id: b.id,
                                        name: b.name,
                                        icon: b.icon,
                                        color: b.color,
                                        mode: BadgeDisplayMode.statusIcon,
                                      ),
                                    ),
                                  ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Username & Online Status Row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          if (username.isNotEmpty)
                            Text(
                              '@$username',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (username.isNotEmpty && statusText != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '•',
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (statusText != null) ...[
                            if (isOnline) ...[
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: const BoxDecoration(
                                  color: AppColors.statusOnline,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Text(
                              statusText!,
                              style: textTheme.bodySmall?.copyWith(
                                color: isOnline
                                    ? AppColors.statusOnline
                                    : scheme.onSurfaceVariant,
                                fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Collapsed Content (AppBar Title + Mini Avatar) ────────
          if (collapsedOpacity > 0.0)
            Positioned(
              left: 56,
              right: isMe || onMore == null ? 16 : 56,
              top: topInset,
              height: kToolbarHeight,
              child: _buildFadedLayer(
                collapsedOpacity,
                Row(
                  children: <Widget>[
                    PulseAvatar(
                      name: name,
                      avatarUrl: avatarUrl,
                      radius: 18,
                      fallbackColor: scheme.primaryContainer,
                      textColor: scheme.onPrimaryContainer,
                      borderColor: scheme.surface,
                      borderWidth: 1.5,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (statusText != null || username.isNotEmpty)
                            Text(
                              statusText ?? '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: isOnline
                                    ? AppColors.statusOnline
                                    : scheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Back Button ───────────────────────────────────────────
          Positioned(
            left: 8,
            top: topInset + (kToolbarHeight - 40) / 2,
            child: Material(
              color: scheme.surfaceContainerHigh,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          // ── More Button ("⋮") ─────────────────────────────────────
          if (!isMe && onMore != null)
            Positioned(
              right: 8,
              top: topInset + (kToolbarHeight - 40) / 2,
              child: Material(
                color: scheme.surfaceContainerHigh,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onMore,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant ProfileHeaderDelegate oldDelegate) {
    return name != oldDelegate.name ||
        username != oldDelegate.username ||
        avatarUrl != oldDelegate.avatarUrl ||
        badges != oldDelegate.badges ||
        statusText != oldDelegate.statusText ||
        isOnline != oldDelegate.isOnline ||
        isMe != oldDelegate.isMe ||
        topInset != oldDelegate.topInset ||
        heroTag != oldDelegate.heroTag;
  }
}
