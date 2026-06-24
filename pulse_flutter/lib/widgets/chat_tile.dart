import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/app_curves.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

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
    this.onLongPress,
    this.subtitleIcon,
    this.isPinned = false,
    this.compact = false,
    this.isOnline = false,
    this.partnerBadges = const <ApiBadge>[],
    this.animateEntrance = false,
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
  final VoidCallback? onLongPress;
  final IconData? subtitleIcon;
  final bool isPinned;
  final bool compact;
  final bool isOnline;
  final List<ApiBadge> partnerBadges;
  final bool animateEntrance;

  @override
  State<ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<ChatTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: AppCurves.easeOutSmooth,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _controller, curve: AppCurves.springGentle),
        );
    if (widget.animateEntrance) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<ApiBadge> visibleBadges = widget.partnerBadges.length > 2
        ? widget.partnerBadges.take(1).toList(growable: false)
        : widget.partnerBadges.take(2).toList(growable: false);
    final int hiddenBadgeCount =
        widget.partnerBadges.length - visibleBadges.length;

    final double vertical = widget.compact ? 9 : 12;
    final double titleGap = widget.compact ? 4 : 6;

    final Widget content = RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: vertical),
            decoration: BoxDecoration(
              color: _isHovered
                  ? scheme.primaryContainer.withValues(alpha: 0.28)
                  : scheme.surfaceContainerLow.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isHovered
                    ? scheme.primary.withValues(alpha: 0.24)
                    : scheme.outlineVariant.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    PulseAvatar(
                      key: ValueKey<String>(
                        '${widget.avatarText}_${widget.avatarUrl ?? ''}',
                      ),
                      radius: 26,
                      name: widget.avatarText,
                      avatarUrl: widget.avatarUrl,
                      fallbackColor: widget.avatarColor,
                      textColor: scheme.onPrimary,
                    ),
                    if (widget.isOnline)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.surface, width: 2),
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
                                    style: textTheme.titleMedium,
                                  ),
                                ),
                                if (widget.isPinned) ...<Widget>[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.push_pin_rounded,
                                    size: 15,
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
                          Text(widget.formattedTime, style: textTheme.bodySmall),
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
                          Expanded(
                            child: Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (widget.unreadCount > 0) ...<Widget>[
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
          ),
        ),
      ),
    );

    if (!widget.animateEntrance) return content;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: content),
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
      duration: const Duration(milliseconds: 150),
      switchInCurve: Curves.easeOutCubic,
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
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          '$count',
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
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
                ),
              ),
            if (hiddenCount > 0) BadgeOverflowChip(count: hiddenCount),
          ],
        ),
      ),
    );
  }
}
