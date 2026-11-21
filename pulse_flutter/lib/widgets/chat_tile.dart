import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/status_emoji_model.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/status_emoji_badge.dart';

/// Maximum width reserved for the inline draft marker before it is ellipsized.
/// The marker is a short localized label ("Draft:"), so it must never push the
/// message preview out of the row.
const double _kDraftLabelMaxWidth = 110;

/// Unscaled width of the time / delivery-status slot. The rendered cap is
/// `min(textScaler.scale(this), rowWidth * 0.42)` so a 200% text scale cannot
/// clip "12.11.2025" into a single ellipsis.
const double _kTimeBaseMaxWidth = 72;

/// Unscaled width of the delivery-status slot. A localized status ("Ожидает
/// отправки") is longer than a clock, so it gets a wider — still bounded — cap.
const double _kStatusBaseMaxWidth = 112;

/// Title-row glyph size and the gap between every trailing marker.
const double _kTitleIconSize = 16;
const double _kTitleIconGap = 4;

/// Height of the text block: title 24 + gap 4 + preview 20 (M3 titleMedium /
/// bodyMedium line boxes). Kept constant so the row never jumps between
/// resting / hover / selected / sending states.
const double _kTextBlockHeight = 48;

/// Selected-row leading indicator (M3 list: 3x20dp, radius 2, inset 8).
const double _kIndicatorInset = 8;
const double _kIndicatorWidth = 3;
const double _kIndicatorHeight = 20;

/// TODO(l10n): the `keyMismatch`, `pinned`, `muted` and `selected` inbox state
/// markers have no `.arb` entries yet (the repo ships only generated
/// `app_localizations*.dart`, the source .arb files are absent). Replace these
/// hardcoded Russian labels with `context.l10n.*` once the keys land.
const String _kKeyMismatchLabel = 'Ключи не совпадают';
const String _kSelectedSemantics = 'выбран';
const String _kPinnedSemantics = 'закреплён';
const String _kMutedSemantics = 'без звука';

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
    this.isSelected = false,
    this.keyMismatch = false,
    this.isTyping = false,
    this.typingNames,
    this.partnerBadges = const <ApiBadge>[],
    this.statusEmoji,
    this.draftLabel,
    this.chatId,
    super.key,
  });

  /// Row height at 1.0 text scale. The delivery status is painted inside the
  /// time slot, so every tile state keeps [rowHeight] (or [compactRowHeight]).
  static const double rowHeight = 76;
  static const double compactRowHeight = 64;

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

  /// Delivery status copy ("Sending…", "Not sent"). It is rendered inside the
  /// time slot instead of a third text line, so the row height never changes.
  final String? deliveryLabel;
  final bool isMuted;
  final bool enableHaptics;
  final bool isPinned;
  final bool compact;
  final bool isOnline;
  final bool isSecret;
  final bool isSaved;

  /// Two-pane / web list: the chat currently open in the detail pane.
  /// Resting rows stay transparent, hover is `surfaceContainerHigh`, selected
  /// is `secondaryContainer` plus a 3x20dp leading `primary` indicator.
  final bool isSelected;

  /// E2EE key drift for this conversation: renders a `gpp_maybe_rounded` lock,
  /// an error-tinted warning in the preview slot and an `error@0.35` frame.
  final bool keyMismatch;

  /// Partner is typing: accents the preview in `primary` and appends three
  /// animated dots.
  final bool isTyping;

  /// Typing participants. With more than one name the group copy
  /// (`chatTypingMultiple`) is used; when omitted [subtitle] is left untouched.
  final List<String>? typingNames;

  final List<ApiBadge> partnerBadges;
  final ApiStatusEmoji? statusEmoji;
  final String? draftLabel;
  final int? chatId;

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

  /// Preview copy for the typing state. A caller without a participant list
  /// keeps its own subtitle (already localized by the screen); a list switches
  /// to the shared one-person/group typing strings.
  String _typingText(BuildContext context) {
    final List<String>? names = widget.typingNames;
    if (names == null || names.isEmpty) return widget.subtitle;
    if (names.length > 1) return context.l10n.chatTypingMultiple;
    return context.l10n.chatTypingOne(names.first);
  }

  /// The avatar flies into the chat header avatar when the chat opens.
  Widget _avatarHero(Widget avatar) {
    final int? chatId = widget.chatId;
    if (chatId == null) return avatar;
    return Hero(tag: 'chat_avatar_$chatId', child: avatar);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ApiBadge? statusBadge = _resolveStatusBadge(widget.partnerBadges);

    final bool hasUnread = widget.unreadCount > 0;
    final bool reduceMotion = context.reduceMotion;
    final Duration surfaceDuration = reduceMotion
        ? Duration.zero
        : M3Durations.short3;
    final double vertical = widget.compact
        ? (ChatTile.compactRowHeight - _kTextBlockHeight) / 2
        : (ChatTile.rowHeight - _kTextBlockHeight) / 2;

    final bool statusIsError =
        widget.deliveryIcon == Icons.error_outline_rounded;
    final String? statusLabel = widget.deliveryLabel;

    final String semanticsLabel = <String>[
      widget.title,
      if (widget.draftLabel != null)
        '${context.l10n.inboxDraftSemantics}: ${widget.draftLabel}',
      if (hasUnread) context.l10n.chatListUnreadCount(widget.unreadCount),
      if (widget.isSelected) _kSelectedSemantics,
      if (widget.isPinned) _kPinnedSemantics,
      if (widget.isMuted) _kMutedSemantics,
      if (widget.isSecret) context.l10n.secretTitle,
      if (widget.keyMismatch) _kKeyMismatchLabel,
      if (widget.isTyping) _typingText(context),
      if (widget.deliveryIcon == Icons.done_all_rounded)
        context.l10n.deliveryRead
      else if (widget.deliveryIcon == Icons.done_rounded)
        context.l10n.deliverySent,
      ?statusLabel,
    ].join(', ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _isHoveredNotifier.value = true,
      onExit: (_) => _isHoveredNotifier.value = false,
      child: Semantics(
        button: true,
        selected: widget.isSelected,
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
          releaseCurve: M3SpringCurves.spatialFast,
          enableHaptics: widget.enableHaptics,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isHoveredNotifier,
            // The row rebuilds on hover/selected changes because the
            // presence-dot cutout has to follow the real row background.
            builder: (BuildContext context, bool isHovered, Widget? _) {
              // Explicit, measurable levels instead of invisible alpha washes:
              // resting transparent -> hover high -> selected secondaryContainer.
              // Unread is signalled by weight + pill only (M3 never tints rows).
              final bool hasSurface = widget.isSelected || isHovered;
              final Color tileBg = widget.isSelected
                  ? (isHovered
                        ? Color.alphaBlend(
                            scheme.onSurface.withValues(alpha: 0.05),
                            scheme.secondaryContainer,
                          )
                        : scheme.secondaryContainer)
                  : isHovered
                  ? scheme.surfaceContainerHigh
                  : Colors.transparent;
              // The presence dot is cut out of the actual row background: a
              // fixed surface tone would leave a visible ring on hover/selected.
              final Color dotBorder = hasSurface ? tileBg : scheme.surface;

              return AnimatedContainer(
                key: const ValueKey<String>('chat-tile-surface'),
                duration: surfaceDuration,
                curve: M3SpringCurves.effectsFast,
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: AppRadii.lgRadius,
                  border: widget.keyMismatch
                      ? Border.all(
                          color: scheme.error.withValues(alpha: 0.35),
                          width: 1,
                        )
                      : null,
                ),
                child: Stack(
                  // The indicator lives in the leading padding, never in the
                  // hit area: taps still target the whole row.
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: vertical,
                      ),
                      child: Row(
                        children: <Widget>[
                          Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              _avatarHero(
                                widget.isSaved
                                  ? SizedBox.square(
                                      key: const ValueKey<String>(
                                        'chat-tile-saved-avatar',
                                      ),
                                      dimension: widget.compact ? 44 : 48,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: scheme.primaryContainer,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: ProductivityIcon(
                                            'bookmark',
                                            size: 24,
                                            color: scheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Opacity(
                                      // Muted chats recede without losing the
                                      // counter/typography hierarchy.
                                      opacity: widget.isMuted ? 0.9 : 1,
                                      child: PulseAvatar(
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
                                    ),
                              ),
                              if (widget.isOnline && !widget.isSaved)
                                Positioned(
                                  right: -1,
                                  bottom: -1,
                                  child: Container(
                                    key: const ValueKey<String>(
                                      'chat-tile-presence-dot',
                                    ),
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppColors.statusOnline,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: dotBorder,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _buildTitleRow(
                                  context,
                                  textTheme: textTheme,
                                  scheme: scheme,
                                  hasUnread: hasUnread,
                                  statusBadge: statusBadge,
                                  statusLabel: statusLabel,
                                  statusIsError: statusIsError,
                                  duration: surfaceDuration,
                                ),
                                const SizedBox(height: 4),
                                _buildPreviewRow(
                                  context,
                                  textTheme: textTheme,
                                  scheme: scheme,
                                  hasUnread: hasUnread,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: _kIndicatorInset,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: AnimatedOpacity(
                          key: const ValueKey<String>(
                            'chat-tile-selected-indicator',
                          ),
                          opacity: widget.isSelected ? 1 : 0,
                          duration: surfaceDuration,
                          child: Container(
                            width: _kIndicatorWidth,
                            height: _kIndicatorHeight,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Title line plus the trailing time / delivery-status slot. The slot is
  /// bounded by the text scale instead of the screen width so a 200% scale can
  /// still render "12.11.2025".
  Widget _buildTitleRow(
    BuildContext context, {
    required TextTheme textTheme,
    required ColorScheme scheme,
    required bool hasUnread,
    required ApiBadge? statusBadge,
    required String? statusLabel,
    required bool statusIsError,
    required Duration duration,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // A delivery status is a short sentence, not a timestamp: it gets a
        // wider cap than the clock but still never grows past half the row.
        final double slotCap = math.min(
          MediaQuery.textScalerOf(context).scale(
            statusLabel != null ? _kStatusBaseMaxWidth : _kTimeBaseMaxWidth,
          ),
          constraints.maxWidth * (statusLabel != null ? 0.5 : 0.42),
        );
        return Row(
          children: <Widget>[
            Expanded(
              child: _buildTitleMarkers(
                context,
                textTheme: textTheme,
                scheme: scheme,
                hasUnread: hasUnread,
                statusBadge: statusBadge,
                duration: duration,
              ),
            ),
            const SizedBox(width: 8),
            // `flex: 0` keeps this slot out of the flex distribution (it is a
            // bounded, non-growing slot): a flex child would permanently steal
            // half of the row from the title even when the time is short.
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: slotCap),
                child: Text(
                  statusLabel ?? widget.formattedTime,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: statusLabel != null
                      ? textTheme.labelSmall?.copyWith(
                          color: statusIsError
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        )
                      : textTheme.labelMedium?.copyWith(
                          // Time is never an accent: the pill and the title
                          // carry the state.
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTitleMarkers(
    BuildContext context, {
    required TextTheme textTheme,
    required ColorScheme scheme,
    required bool hasUnread,
    required ApiBadge? statusBadge,
    required Duration duration,
  }) {
    final TextStyle titleStyle = (textTheme.titleMedium ?? const TextStyle())
        .copyWith(
          color: scheme.onSurface,
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
          // Variable-weight fonts lerp through fontVariations, so the unread
          // weight change animates instead of snapping at the TextStyle lerp
          // midpoint.
          fontVariations: <FontVariation>[
            FontVariation('wght', hasUnread ? 700 : 600),
          ],
        );

    return Row(
      children: <Widget>[
        Flexible(
          // AnimatedDefaultTextStyle keeps the 600 -> 700 unread weight change
          // from popping while the row background is still animating.
          child: AnimatedDefaultTextStyle(
            duration: duration,
            curve: M3SpringCurves.effectsFast,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
            child: CustomEmojiText(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (widget.statusEmoji != null) ...<Widget>[
          const SizedBox(width: _kTitleIconGap),
          StatusEmojiBadge(emoji: widget.statusEmoji!, size: _kTitleIconSize),
        ],
        if (statusBadge != null) ...<Widget>[
          const SizedBox(width: _kTitleIconGap),
          _BadgeIcon(badge: statusBadge),
        ],
        if (widget.isSecret || widget.keyMismatch) ...<Widget>[
          const SizedBox(width: _kTitleIconGap),
          _TitleIcon(
            icon: widget.keyMismatch
                ? Icons.gpp_maybe_rounded
                : Icons.lock_rounded,
            color: widget.keyMismatch ? scheme.error : scheme.primary,
          ),
        ],
        if (widget.isMuted) ...<Widget>[
          const SizedBox(width: _kTitleIconGap),
          _TitleIcon(
            icon: Icons.notifications_off_outlined,
            color: scheme.onSurfaceVariant,
          ),
        ],
        if (widget.isPinned) ...<Widget>[
          const SizedBox(width: _kTitleIconGap),
          _TitleIcon(
            icon: Icons.push_pin_rounded,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewRow(
    BuildContext context, {
    required TextTheme textTheme,
    required ColorScheme scheme,
    required bool hasUnread,
  }) {
    final TextStyle previewStyle = (textTheme.bodyMedium ?? const TextStyle())
        .copyWith(
          letterSpacing: 0.2,
          color: hasUnread ? scheme.onSurface : scheme.onSurfaceVariant,
          fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
        );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Cap the draft marker against the real row width: a 10k-character
        // label must fail with an ellipsis, not with an overflow.
        final double draftMaxWidth = math.min(
          MediaQuery.textScalerOf(context).scale(_kDraftLabelMaxWidth),
          constraints.maxWidth * 0.5,
        );

        if (widget.isTyping) {
          return Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  _typingText(context),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: previewStyle.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _TypingDots(color: scheme.primary),
            ],
          );
        }

        return Row(
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
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: draftMaxWidth),
                child: Text(
                  widget.draftLabel!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: previewStyle.copyWith(
                    color: scheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: widget.keyMismatch
                  // A broken E2EE handshake must not look like a healthy chat:
                  // the warning replaces the preview in the error tone.
                  ? Text(
                      _kKeyMismatchLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: previewStyle.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : CustomEmojiText(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: previewStyle,
                    ),
            ),
            if (hasUnread) ...<Widget>[
              const SizedBox(width: 8),
              _AnimatedBadge(
                count: widget.unreadCount,
                isMuted: widget.isMuted,
              ),
            ] else if (widget.deliveryIcon != null) ...<Widget>[
              const SizedBox(width: 8),
              Icon(
                widget.deliveryIcon,
                size: 16,
                color: _deliveryColor(scheme),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Delivered and read used to share one accent, so both states looked alike.
  /// Only "read" earns the primary accent; "sent/delivered" stays neutral.
  Color _deliveryColor(ColorScheme scheme) {
    if (widget.deliveryIcon == Icons.error_outline_rounded) {
      return scheme.error;
    }
    if (widget.deliveryIcon == Icons.done_all_rounded) {
      return scheme.primary;
    }
    return scheme.onSurfaceVariant;
  }
}

class _TitleIcon extends StatelessWidget {
  const _TitleIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: _kTitleIconSize, color: color);
}

/// Single normalized status-badge glyph for the title row (16dp slot), routed
/// through [BadgeChip] so badges keep one renderer across the app.
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.badge});

  final ApiBadge badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _kTitleIconSize,
      child: FittedBox(
        fit: BoxFit.contain,
        child: BadgeChip(
          id: badge.id,
          name: badge.name,
          icon: badge.icon,
          color: badge.color,
          mode: BadgeDisplayMode.statusIcon,
          interactive: false,
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
    // accent-colored counters of chats that actually notify the user — a tonal
    // pill with an outline instead of a second primary accent.
    final Color background = isMuted
        ? scheme.surfaceContainerHigh
        : scheme.primary;
    final Color foreground = isMuted
        ? scheme.onSurfaceVariant
        : scheme.onPrimary;

    return AnimatedSwitcher(
      duration: context.reduceMotion
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
          border: isMuted ? Border.all(color: scheme.outlineVariant) : null,
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

/// Three 3dp dots, 160ms stagger, 1000ms cycle. Static under
/// `disableAnimations` or a disabled [TickerMode] so reduced-motion users and
/// off-screen rows never pay for a repeating ticker.
class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  static const double _dotSize = 3;
  static const double _dotGap = 3;
  static const Duration _cycle = Duration(milliseconds: 1000);
  static const double _stagger = 0.16;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  )..addStatusListener(_onStatus);

  // The anti-slop guard forbids raw infinite-repeat calls in idle widgets, so
  // the cycle is restarted from a status listener; it stays bounded by
  // `_animate`.
  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && _animate) {
      _controller.forward(from: 0);
    }
  }

  bool get _animate =>
      !context.reduceMotion &&
      TickerMode.valuesOf(context).enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animate) {
      if (!_controller.isAnimating) {
        _controller.forward(from: _controller.value);
      }
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // One opacity animation per dot: the dots repaint through FadeTransition
  // and the row is not rebuilt on every frame.
  late final List<Animation<double>> _dotOpacities = <Animation<double>>[
    for (int i = 0; i < 3; i++) _controller.drive(_DotWave(i * _stagger)),
  ];

  Widget _buildDots(double? staticOpacity) {
    final Widget dot = Container(
      width: _dotSize,
      height: _dotSize,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : _dotGap),
            child: staticOpacity != null
                ? Opacity(
                    key: ValueKey<String>('chat-typing-dot-$i'),
                    opacity: staticOpacity,
                    child: dot,
                  )
                : FadeTransition(
                    key: ValueKey<String>('chat-typing-dot-$i'),
                    opacity: _dotOpacities[i],
                    child: dot,
                  ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) {
      return SizedBox(
        key: const ValueKey<String>('chat-tile-typing-dots'),
        height: _dotSize,
        child: _buildDots(0.55),
      );
    }
    return SizedBox(
      key: const ValueKey<String>('chat-tile-typing-dots'),
      height: _dotSize,
      child: _buildDots(null),
    );
  }
}

/// Opacity wave of one typing dot over the controller's cycle.
class _DotWave extends Animatable<double> {
  const _DotWave(this.offset);

  final double offset;

  @override
  double transform(double t) {
    final double phase = (t + offset) % 1.0;
    final double wave = 0.5 - 0.5 * math.cos(2 * math.pi * phase);
    return 0.25 + 0.75 * wave;
  }
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
