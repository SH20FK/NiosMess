import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class _ProfileHeaderFadeTransition extends StatelessWidget {
  const _ProfileHeaderFadeTransition({
    required this.opacity,
    required this.child,
  });

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (opacity >= 1) return child;
    return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
  }
}

class ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  ProfileHeaderDelegate({
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.onEdit,
    required this.onUploadAvatar,
    required this.isUploadingAvatar,
    this.bio,
    this.badges = const <ApiBadge>[],
  });

  final String name;
  final String username;
  final String? avatarUrl;
  final VoidCallback onEdit;
  final VoidCallback onUploadAvatar;
  final bool isUploadingAvatar;
  final String? bio;
  final List<ApiBadge> badges;

  @override
  double get minExtent => 68;

  @override
  double get maxExtent => 220;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double topInset = MediaQuery.viewPaddingOf(context).top;
    final double progress =
        (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final double screenWidth = MediaQuery.sizeOf(context).width;

    final double expandedOpacity = ((0.65 - progress) / 0.35).clamp(0.0, 1.0);
    final double collapsedOpacity = ((progress - 0.4) / 0.35).clamp(0.0, 1.0);

    const double expandedAvatarSize = 76;
    const double collapsedAvatarSize = 36;

    final double collapsedAvatarTop =
        topInset + (minExtent - topInset - collapsedAvatarSize) / 2;
    final double gearTop = topInset + 8;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            scheme.primaryContainer.withValues(
              alpha: ui.lerpDouble(isDark ? 0.30 : 0.40, 0.08, progress)!,
            ),
            scheme.surface,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(
              alpha: progress > 0.85 ? (isDark ? 0.20 : 0.35) : 0.0,
            ),
          ),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 1. Expanded view: compact avatar, name, username, badges, bio
          Positioned.fill(
            child: _ProfileHeaderFadeTransition(
              opacity: expandedOpacity,
              child: Padding(
                padding: EdgeInsets.only(top: topInset + 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Avatar with camera badge
                    GestureDetector(
                      onTap: isUploadingAvatar ? null : onUploadAvatar,
                      child: SizedBox(
                        width: expandedAvatarSize,
                        height: expandedAvatarSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            PulseAvatar(
                              radius: expandedAvatarSize / 2,
                              name: name,
                              avatarUrl: avatarUrl,
                              fallbackColor: scheme.primaryContainer,
                              textColor: scheme.onPrimaryContainer,
                              borderColor: scheme.surface,
                              borderWidth: 2,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: scheme.shadow
                                          .withValues(alpha: 0.12),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: isUploadingAvatar
                                      ? AppLoadingIndicator(
                                          size: 10,
                                          color: scheme.onPrimary,
                                        )
                                      : Icon(
                                          Icons.camera_alt_rounded,
                                          size: 11,
                                          color: scheme.onPrimary,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Name + username
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            username.isEmpty ? '' : '@',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Badges or bio
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: badges.take(2).map((ApiBadge b) {
                          return BadgeChip(
                            id: b.id,
                            name: b.name,
                            icon: b.icon,
                            color: b.color,
                            mode: BadgeDisplayMode.infoLabel,
                          );
                        }).toList(),
                      ),
                    ] else if (bio != null && bio!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          bio!.trim(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 2. Collapsed view: compact horizontal bar
          Positioned(
            left: 16,
            top: collapsedAvatarTop,
            child: _ProfileHeaderFadeTransition(
              opacity: collapsedOpacity,
              child: GestureDetector(
                onTap: isUploadingAvatar ? null : onUploadAvatar,
                child: SizedBox(
                  width: collapsedAvatarSize,
                  height: collapsedAvatarSize,
                  child: PulseAvatar(
                    radius: collapsedAvatarSize / 2,
                    name: name,
                    avatarUrl: avatarUrl,
                    fallbackColor: scheme.primaryContainer,
                    textColor: scheme.onPrimaryContainer,
                    borderColor: scheme.surface,
                    borderWidth: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 62,
            top: topInset + (minExtent - topInset - 24) / 2,
            child: _ProfileHeaderFadeTransition(
              opacity: collapsedOpacity,
              child: SizedBox(
                width: (screenWidth - 120).clamp(100.0, 600.0),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),

          // 3. Edit gear button (always top-right)
          Positioned(
            right: 14,
            top: gearTop,
            child: Material(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
              shape: const CircleBorder(),
              child: Tooltip(
                message: 'Редактировать',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onEdit,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.tune_rounded, size: 20),
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
  bool shouldRebuild(ProfileHeaderDelegate oldDelegate) {
    return name != oldDelegate.name ||
        username != oldDelegate.username ||
        avatarUrl != oldDelegate.avatarUrl ||
        isUploadingAvatar != oldDelegate.isUploadingAvatar ||
        onEdit != oldDelegate.onEdit ||
        onUploadAvatar != oldDelegate.onUploadAvatar ||
        bio != oldDelegate.bio ||
        badges != oldDelegate.badges;
  }
}
