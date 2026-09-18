import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/utils/app_curves.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/status_emoji_model.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/status_emoji_badge.dart';

/// Google Messages / M3 Expressive Chat List Tile with unread pills,
/// dynamic online indicator cutout, and refined typography.
class ChatTile extends StatefulWidget {
  const ChatTile({
    required this.title,
    required this.subtitle,
    required this.formattedTime,
    required this.unreadCount,
    required this.avatarText,
    required this.avatarColor,
    this.avatarUrl,
    required this.onTap,
    this.onTapWithRect,
    this.onLongPress,
    this.subtitleIcon,
    this.isPinned = false,
    this.compact = false,
    this.isOnline = false,
    this.isSecret = false,
    this.partnerBadges = const <ApiBadge>[],
    this.statusEmoji,
    this.animateEntrance = false,
    this.actions = const <Widget>[],
    this.draftLabel,
    this.chatId,
    this.isSelected = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final String formattedTime;
  final int unreadCount;
  final String avatarText;
  final Color avatarColor;
  final String? avatarUrl;
  final VoidCallback onTap;
  final void Function(Rect? rect)? onTapWithRect;
  final VoidCallback? onLongPress;
  final IconData? subtitleIcon;
  final bool isPinned;
  final bool compact;
  final bool isOnline;
  final bool isSecret;
  final List<ApiBadge> partnerBadges;
  final ApiStatusEmoji? statusEmoji;
  final bool animateEntrance;
  final List<Widget> actions;
  final String? draftLabel;
  final int? chatId;
  final bool isSelected;

  @override
  State<ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<ChatTile>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fadeAnim;
  Animation<Offset>? _slideAnim;
  final ValueNotifier<bool> _isHoveredNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    if (widget.animateEntrance) {
      final AnimationController controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
      _controller = controller;
      _fadeAnim = CurvedAnimation(
        parent: controller,
        curve: AppCurves.easeOutSmooth,
      );
      _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: controller, curve: AppCurves.springGentle),
          );
      controller.forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _isHoveredNotifier.dispose();
    super.dispose();
  }

  void _handleLongPress() {
    widget.onLongPress?.call();
  }

  Rect? _globalRect() {
    final RenderObject? ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  void _handleTap() {
    if (widget.onTapWithRect != null) {
      widget.onTapWithRect!(_globalRect());
    } else {
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int totalBadges = widget.partnerBadges.length;
    final List<ApiBadge> visibleBadges = totalBadges > 3
        ? widget.partnerBadges.take(2).toList(growable: false)
        : widget.partnerBadges.take(3).toList(growable: false);
    final int hiddenBadgeCount = totalBadges > 3 ? totalBadges - 2 : 0;

    final double vertical = widget.compact ? 8 : 11;
    final double titleGap = widget.compact ? 3 : 5;
    final bool hasUnread = widget.unreadCount > 0;

    final String semanticsLabel =
        '${widget.title}${widget.draftLabel != null ? ', draft: ${widget.draftLabel}' : ''}'
        '${hasUnread ? ', ${widget.unreadCount} unread' : ''}';

    final Widget content = RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _isHoveredNotifier.value = true,
        onExit: (_) => _isHoveredNotifier.value = false,
        child: Semantics(
          button: true,
          label: semanticsLabel,
          child: TouchContainer(
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            borderRadius: BorderRadius.circular(24),
            scaleDown: 0.98,
            releaseCurve: M3SpringCurves.spatial,
            enableHaptics: true,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isHoveredNotifier,
              builder: (BuildContext context, bool isHovered, Widget? child) {
                final Color tileBg = widget.isSelected
                    ? scheme.primaryContainer.withValues(alpha: 0.55)
                    : (isHovered
                        ? scheme.primaryContainer.withValues(alpha: 0.28)
                        : scheme.surfaceContainerLow.withValues(alpha: 0.82));
                final Color borderColor = widget.isSelected
                    ? scheme.primary.withValues(alpha: 0.65)
                    : (isHovered
                        ? scheme.primary.withValues(alpha: 0.24)
                        : scheme.outlineVariant.withValues(alpha: 0.18));

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: vertical),
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: borderColor,
                      width: widget.isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Hero(
                            tag: widget.chatId != null
                                ? 'chat_avatar_${widget.chatId}'
                                : Object(),
                            child: PulseAvatar(
                              key: ValueKey<String>(
                                '${widget.avatarText}_${widget.avatarUrl ?? ''}',
                              ),
                              radius: 25,
                              name: widget.avatarText,
                              avatarUrl: widget.avatarUrl,
                              fallbackColor: widget.avatarColor,
                              textColor: AppColors.avatarTextColorFor(
                                widget.avatarColor,
                                scheme,
                              ),
                            ),
                          ),
                          if (widget.isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: AppColors.statusOnline,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.surfaceContainerLow,
                                    width: 2.2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Row(
                                    children: <Widget>[
                                      Flexible(
                                        child: Text(
                                          widget.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.titleMedium?.copyWith(
                                            fontWeight: hasUnread
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (widget.statusEmoji != null) ...<Widget>[
                                        StatusEmojiBadge(
                                          emoji: widget.statusEmoji!,
                                          size: 16,
                                        ),
                                      ],
                                      if (widget.isSecret) ...<Widget>[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.lock_rounded,
                                          size: 14,
                                          color: scheme.tertiary,
                                        ),
                                      ],
                                      if (widget.isPinned) ...<Widget>[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.push_pin_rounded,
                                          size: 14,
                                          color: scheme.primary,
                                        ),
                                      ],
                                      if (visibleBadges.isNotEmpty)
                                        _ChatBadgeStrip(
                                          badges: visibleBadges,
                                          hiddenCount: hiddenBadgeCount,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.formattedTime,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: hasUnread
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: titleGap),
                            Row(
                              children: <Widget>[
                                if (widget.subtitleIcon != null) ...<Widget>[
                                  Icon(
                                    widget.subtitleIcon,
                                    size: 16,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                if (widget.draftLabel != null) ...<Widget>[
                                  Text(
                                    widget.draftLabel!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: scheme.tertiary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    widget.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: hasUnread
                                          ? scheme.onSurface
                                          : scheme.onSurfaceVariant,
                                      fontWeight: hasUnread
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (hasUnread) ...<Widget>[
                                  const SizedBox(width: 8),
                                  _AnimatedBadge(count: widget.unreadCount),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: widget.actions,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.animateEntrance || _fadeAnim == null || _slideAnim == null) {
      return content;
    }

    return FadeTransition(
      opacity: _fadeAnim!,
      child: SlideTransition(position: _slideAnim!, child: content),
    );
  }
}

class _AnimatedBadge extends StatelessWidget {
  const _AnimatedBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: M3SpringCurves.snappy,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Container(
        key: ValueKey<int>(count),
        height: 22,
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ChatBadgeStrip extends StatelessWidget {
  const _ChatBadgeStrip({required this.badges, required this.hiddenCount});

  final List<ApiBadge> badges;
  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 82),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final ApiBadge badge in badges)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: BadgeChip(
                  id: badge.id,
                  name: badge.name,
                  icon: badge.icon,
                  color: badge.color,
                  interactive: false,
                  mode: BadgeResolver.isStatusBadge(badge)
                      ? BadgeDisplayMode.statusIcon
                      : BadgeDisplayMode.infoLabel,
                ),
              ),
            if (hiddenCount > 0) BadgeOverflowChip(count: hiddenCount),
          ],
        ),
      ),
    );
  }
}
