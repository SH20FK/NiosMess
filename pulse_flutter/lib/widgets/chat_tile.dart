import 'dart:math' as math;

import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/status_emoji_model.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/status_emoji_badge.dart';

/// Maximum width reserved for the inline draft marker before it is ellipsized.
/// The marker is a short localized label ("Draft:"), so it must never push the
/// message preview out of the row.
const double _kDraftLabelMaxWidth = 110;

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
    this.onLongPress,
    this.onSecondaryTapDown,
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
  final VoidCallback? onLongPress;

  /// Desktop context-menu request with the pointer position in global
  /// coordinates. Wired instead of the legacy "secondary tap == long press"
  /// fallback so a right click opens exactly one menu.
  final ValueChanged<Offset>? onSecondaryTapDown;

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
  final String? draftLabel;
  final int? chatId;
  final bool isSelected;

  @override
  State<ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<ChatTile> {
  final ValueNotifier<bool> _isHoveredNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isHoveredNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ApiBadge? statusBadge = _resolveStatusBadge(widget.partnerBadges);

    final double vertical = widget.compact ? 10 : 14;
    const double titleGap = 4;
    final bool hasUnread = widget.unreadCount > 0;

    // The draft marker is a fixed localized word, but the API accepts any
    // string: clamp it so a long label can never overflow the preview row.
    final double timeMaxWidth = MediaQuery.sizeOf(context).width * 0.32;

    final String semanticsLabel =
        '${widget.title}${widget.draftLabel != null ? ', ${context.l10n.inboxDraftSemantics}: ${widget.draftLabel}' : ''}'
        '${hasUnread ? ', ${context.l10n.chatListUnreadCount(widget.unreadCount)}' : ''}'
        '${widget.deliveryLabel == null ? '' : ', ${widget.deliveryLabel}'}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _isHoveredNotifier.value = true,
      onExit: (_) => _isHoveredNotifier.value = false,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        // The tile paints its own title, preview, badge and icons: without
        // excludeSemantics TalkBack reads the label plus every child twice.
        excludeSemantics: true,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: TouchContainer(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          borderRadius: AppRadii.lgRadius,
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
                        ? scheme.surfaceContainerHigh.withValues(alpha: 0.65)
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
                  borderRadius: AppRadii.lgRadius,
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
                                  child: ProductivityIcon('bookmark', size: 28),
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
                        if (widget.isOnline && !widget.isSaved)
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
                                        style: textTheme.titleMedium?.copyWith(
                                          fontSize: 15,
                                          fontWeight: hasUnread
                                              ? FontWeight.w700
                                              : FontWeight.w500,
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
                                    if (statusBadge != null)
                                      _ChatBadgeStrip(badge: statusBadge),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: timeMaxWidth,
                                ),
                                child: Text(
                                  widget.formattedTime,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: hasUnread
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.deliveryLabel != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              widget.deliveryLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color:
                                    widget.deliveryIcon ==
                                        Icons.error_outline_rounded
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: titleGap),
                          LayoutBuilder(
                            builder:
                                (
                                  BuildContext context,
                                  BoxConstraints constraints,
                                ) {
                                  // Cap the draft marker against the real row
                                  // width: a 10k-character label must fail
                                  // with an ellipsis, not with an overflow.
                                  final double draftMaxWidth = math.min(
                                    MediaQuery.textScalerOf(
                                      context,
                                    ).scale(_kDraftLabelMaxWidth),
                                    constraints.maxWidth * 0.5,
                                  );
                                  return Row(
                                    children: <Widget>[
                                      if (widget.subtitleIcon !=
                                          null) ...<Widget>[
                                        Icon(
                                          widget.subtitleIcon,
                                          size: 16,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      if (widget.draftLabel !=
                                          null) ...<Widget>[
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: draftMaxWidth,
                                          ),
                                          child: Text(
                                            widget.draftLabel!,
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: scheme.tertiary,
                                                  fontWeight: FontWeight.w700,
                                                ),
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
                                        _AnimatedBadge(
                                          count: widget.unreadCount,
                                          isMuted: widget.isMuted,
                                        ),
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
                                  );
                                },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedBadge extends StatelessWidget {
  const _AnimatedBadge({required this.count, required this.isMuted});

  final int count;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // M3: muted chats keep their counter, but it must not compete with the
    // accent-colored counters of chats that actually notify the user.
    final Color background = isMuted
        ? scheme.surfaceContainerHighest
        : scheme.primary;
    final Color foreground = isMuted
        ? scheme.onSurfaceVariant
        : scheme.onPrimary;

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
        key: ValueKey<String>('${count}_$isMuted'),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ChatBadgeStrip extends StatelessWidget {
  const _ChatBadgeStrip({required this.badge});

  final ApiBadge badge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Tooltip(
      message: badge.name,
      child: Icon(
        _badgeIcon(badge),
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

bool _isBotBadge(ApiBadge badge) {
  final String source = '${badge.name} ${badge.icon}'.toLowerCase();
  return source.contains('bot') ||
      source.contains('ai') ||
      source.contains('system');
}

/// Returns the single most representative status badge for the title row:
/// verified/admin/premium badges win, bot badges fall back to their own icon.
ApiBadge? _resolveStatusBadge(List<ApiBadge> badges) {
  for (final ApiBadge badge in badges) {
    if (BadgeResolver.isStatusBadge(badge) || _isBotBadge(badge)) {
      return badge;
    }
  }
  return null;
}

IconData _badgeIcon(ApiBadge badge) {
  final String source = '${badge.name} ${badge.icon}'.toLowerCase();
  if (source.contains('admin') ||
      source.contains('mod') ||
      source.contains('shield')) {
    return Icons.shield_rounded;
  }
  if (_isBotBadge(badge)) return Icons.smart_toy_rounded;
  if (source.contains('partner') || source.contains('official')) {
    return Icons.handshake_rounded;
  }
  if (source.contains('support') || source.contains('help')) {
    return Icons.headset_mic_rounded;
  }
  if (source.contains('premium') ||
      source.contains('crown') ||
      source.contains('vip')) {
    return Icons.workspace_premium_rounded;
  }
  if (source.contains('dev') ||
      source.contains('code') ||
      source.contains('build')) {
    return Icons.build_rounded;
  }
  return Icons.verified_rounded;
}
