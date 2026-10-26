import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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
    this.deliveryIcon,
    this.deliveryLabel,
    this.isMuted = false,
    this.enableHaptics = true,
    this.isPinned = false,
    this.compact = false,
    this.isOnline = false,
    this.isSecret = false,
    this.isSaved = false,
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
  final IconData? deliveryIcon;
  final String? deliveryLabel;
  final bool isMuted;
  final bool enableHaptics;
  final bool isPinned;
  final bool compact;
  final bool isOnline;
  final bool isSecret;
  final bool isSaved;
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
    final List<ApiBadge> visibleBadges = widget.partnerBadges
        .where(BadgeResolver.isVerificationBadge)
        .take(1)
        .toList(growable: false);

    final double vertical = widget.compact ? 10 : 14;
    final double titleGap = 4;
    final bool hasUnread = widget.unreadCount > 0;

    final String semanticsLabel =
        '${widget.title}${widget.draftLabel != null ? ', ${context.l10n.inboxDraftSemantics}: ${widget.draftLabel}' : ''}'
        '${hasUnread ? ', ${context.l10n.chatListUnreadCount(widget.unreadCount)}' : ''}'
        '${widget.deliveryLabel == null ? '' : ', ${widget.deliveryLabel}'}';

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
            borderRadius: BorderRadius.circular(16),
            scaleDown: 0.98,
            releaseCurve: M3SpringCurves.spatial,
            enableHaptics: widget.enableHaptics,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isHoveredNotifier,
              builder: (BuildContext context, bool isHovered, Widget? child) {
                final Color tileBg = widget.isSelected
                    ? scheme.primaryContainer.withValues(alpha: 0.45)
                    : (isHovered
                          ? scheme.surfaceContainerHigh
                          : hasUnread
                          ? scheme.surfaceContainerLow
                          : Colors.transparent);

                return AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : M3Durations.short3,
                  curve: M3SpringCurves.gentle,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: vertical,
                  ),
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(16),
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
                          widget.isSaved
                              ? SizedBox.square(
                                  dimension: widget.compact ? 44 : 48,
                                  child: const Center(
                                    child: ProductivityIcon(
                                      'bookmark',
                                      size: 28,
                                    ),
                                  ),
                                )
                              : PulseAvatar(
                                  key: ValueKey<String>(
                                    '${widget.avatarText}_${widget.avatarUrl ?? ''}',
                                  ),
                                  radius: widget.compact ? 22 : 24,
                                  name: widget.avatarText,
                                  avatarUrl: widget.avatarUrl,
                                  fallbackColor: widget.avatarColor,
                                  textColor: AppColors.avatarTextColorFor(
                                    widget.avatarColor,
                                    scheme,
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
                                        child: CustomEmojiText(
                                          widget.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontSize: 15,
                                                fontWeight: hasUnread
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: scheme.onSurface,
                                              ),
                                        ),
                                      ),
                                      if (widget.statusEmoji !=
                                          null) ...<Widget>[
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
                                          color: scheme.primary,
                                        ),
                                      ],
                                      if (widget.isMuted) ...<Widget>[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.notifications_off_outlined,
                                          size: 14,
                                          color: scheme.onSurfaceVariant,
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
                                        _ChatBadgeStrip(badges: visibleBadges),
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
                            if (widget.deliveryLabel != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.deliveryLabel!,
                                style: textTheme.labelSmall?.copyWith(
                                  color:
                                      widget.deliveryIcon ==
                                          Icons.error_outline_rounded
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
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
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.tertiary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: CustomEmojiText(
                                    widget.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
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
                                ] else if (widget.deliveryIcon !=
                                    null) ...<Widget>[
                                  const SizedBox(width: 8),
                                  Icon(
                                    widget.deliveryIcon,
                                    size: 16,
                                    color:
                                        widget.deliveryIcon ==
                                            Icons.error_outline_rounded
                                        ? scheme.error
                                        : scheme.primary,
                                  ),
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
                          color: scheme.surfaceContainerHigh.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

    final separatedContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        Padding(
          padding: EdgeInsets.only(left: widget.compact ? 68 : 72, right: 12),
          child: Divider(
            height: 1,
            thickness: .5,
            color: scheme.outlineVariant.withValues(alpha: .35),
          ),
        ),
      ],
    );
    if (!widget.animateEntrance || _fadeAnim == null || _slideAnim == null) {
      return separatedContent;
    }

    return FadeTransition(
      opacity: _fadeAnim!,
      child: SlideTransition(position: _slideAnim!, child: separatedContent),
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
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : M3Durations.short4,
      switchInCurve: M3SpringCurves.expressiveDecel,
      switchOutCurve: M3SpringCurves.expressiveAccel,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Container(
        key: ValueKey<int>(count),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ChatBadgeStrip extends StatelessWidget {
  const _ChatBadgeStrip({required this.badges});
  final List<ApiBadge> badges;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Tooltip(
      message: badges.first.name,
      child: Icon(
        Icons.verified_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
