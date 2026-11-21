import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

/// Geometry shared by the inbox placeholder and `ChatTile` itself. Keeping the
/// numbers in one place is what stops the list from jumping when data lands.
abstract final class _ChatRowMetrics {
  /// Outer list padding around real rows (`SliverPadding` in the inbox).
  static const double externalInset = 10.0;

  /// Inner horizontal padding painted by `ChatTile`.
  static const double innerInset = AppSpacing.md;

  /// Total horizontal inset of a real row: 10 + 12 = 22 dp.
  static const double rowInset = externalInset + innerInset;

  /// `ChatTile` vertical padding (14dp) around the 48dp avatar.
  static const double verticalInset = 14.0;

  /// Avatar diameter (48dp).
  static const double avatar = 48.0;

  /// Gap between consecutive rows (Dismissible rows sit flush, 2dp reads better).
  static const double rowGap = 2.0;

  /// Timestamp placeholder — the 28×12 chip of the real trailing label.
  static const double timeWidth = 28.0;
  static const double timeHeight = 12.0;

  static const double titleHeight = 16.0;
  static const double subtitleHeight = 12.0;
  static const double titleGap = AppSpacing.sm;
}

class ChatListSkeleton extends StatefulWidget {
  const ChatListSkeleton({
    this.count = 6,
    this.outerInset = AppSpacing.lg,
    super.key,
  });

  final int count;

  /// Horizontal padding the caller already wraps around this widget. Real rows
  /// sit at 22dp (10dp list padding + 12dp tile padding), so the skeleton
  /// subtracts [outerInset] from that and paints exactly the same inset — the
  /// placeholder lines up with the loaded list instead of sitting 6dp deeper.
  final double outerInset;

  @override
  State<ChatListSkeleton> createState() => _ChatListSkeletonState();
}

/// Breathing pulse shared by the skeletons. One controller drives every block
/// of a skeleton so they fade together. The ping-pong is explicit (not
/// `.repeat`) so the loop is unmistakably owned by the widget and stops with
/// it.
mixin _SkeletonPulse<T extends StatefulWidget> on State<T>, TickerProvider {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..addStatusListener(_onPulseStatus);

  late final Animation<double> pulseOpacity = Tween<double>(
    begin: 1.0,
    end: 0.55,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  bool _reduceMotion = false;

  void _onPulseStatus(AnimationStatus status) {
    if (_reduceMotion || !mounted) return;
    if (status == AnimationStatus.completed) {
      _pulse.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _pulse.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion wins over decoration: no ticking, fully opaque blocks.
    _reduceMotion = context.reduceMotion;
    if (_reduceMotion) {
      _pulse.stop();
      _pulse.value = 0.0;
    } else if (!_pulse.isAnimating) {
      _pulse.forward();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
}

class _ChatListSkeletonState extends State<ChatListSkeleton>
    with
        SingleTickerProviderStateMixin<ChatListSkeleton>,
        _SkeletonPulse<ChatListSkeleton> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double inset = (_ChatRowMetrics.rowInset - widget.outerInset).clamp(
      0.0,
      _ChatRowMetrics.rowInset,
    );

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.count,
      separatorBuilder: (_, _) =>
          const SizedBox(height: _ChatRowMetrics.rowGap),
      itemBuilder: (BuildContext context, int index) => _ChatRowPlaceholder(
        index: index,
        inset: inset,
        scheme: scheme,
        opacity: pulseOpacity,
      ),
    );
  }
}

/// A single placeholder row painted on the same tonal base as a real tile:
/// `surfaceContainerLow` + a hairline `outlineVariant` frame, content blocks on
/// `surfaceContainerHighest`.
class _ChatRowPlaceholder extends StatelessWidget {
  const _ChatRowPlaceholder({
    required this.index,
    required this.inset,
    required this.scheme,
    required this.opacity,
  });

  final int index;
  final double inset;
  final ColorScheme scheme;
  final Animation<double> opacity;

  @override
  Widget build(BuildContext context) {
    // Deterministic variety so the placeholder does not look like a barcode.
    final double titleFactor = 0.42 + (index % 3) * 0.11;
    final double subtitleFactor = 0.58 + (index % 4) * 0.10;

    return Container(
      key: ValueKey<String>('chat_skeleton_row_$index'),
      padding: EdgeInsets.symmetric(
        horizontal: inset,
        vertical: _ChatRowMetrics.verticalInset,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgRadius,
      ),
      // A layout border would add 1dp on every side (76 → 78 and a shifted
      // avatar); painting it in the foreground keeps ChatTile's exact metrics.
      foregroundDecoration: BoxDecoration(
        borderRadius: AppRadii.lgRadius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: FadeTransition(
        opacity: opacity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SkeletonBlock(
              width: _ChatRowMetrics.avatar,
              height: _ChatRowMetrics.avatar,
              radius: _ChatRowMetrics.avatar / 2,
              color: scheme.surfaceContainerHighest,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: titleFactor,
                            child: _SkeletonBlock(
                              height: _ChatRowMetrics.titleHeight,
                              radius: AppRadii.sm,
                              color: scheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Timestamp sits in the top-right corner of a real tile.
                      _SkeletonBlock(
                        width: _ChatRowMetrics.timeWidth,
                        height: _ChatRowMetrics.timeHeight,
                        radius: 6,
                        color: scheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                  const SizedBox(height: _ChatRowMetrics.titleGap),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: subtitleFactor,
                      child: _SkeletonBlock(
                        height: _ChatRowMetrics.subtitleHeight,
                        radius: 6,
                        color: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bare tonal block; width may be unbounded (fractional width inside a row).
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.height,
    required this.radius,
    required this.color,
    this.width,
  });

  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class MessageListSkeleton extends StatefulWidget {
  const MessageListSkeleton({this.count = 8, super.key});

  final int count;

  @override
  State<MessageListSkeleton> createState() => _MessageListSkeletonState();
}

class _MessageListSkeletonState extends State<MessageListSkeleton>
    with
        SingleTickerProviderStateMixin<MessageListSkeleton>,
        _SkeletonPulse<MessageListSkeleton> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.count,
      itemBuilder: (BuildContext context, int index) {
        final bool isMine = index % 3 == 0;
        final double bubbleWidth = 120 + (index % 5) * 40.0;

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: isMine
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 6),
                bottomRight: Radius.circular(isMine ? 6 : 18),
              ),
            ),
            child: FadeTransition(
              opacity: pulseOpacity,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: bubbleWidth,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isMine
                        ? scheme.onPrimaryContainer.withValues(alpha: 0.20)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: bubbleWidth * 0.5,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isMine
                        ? scheme.onPrimaryContainer.withValues(alpha: 0.15)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }
}

// ── PostCard & PostFeed Skeletons for NiosGram ─────────────────────────

/// Skeleton representation of an M3 Expressive NiosGram PostCard.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({
    this.hasMedia = true,
    this.aspectRatio = 16 / 9,
    this.linesCount = 2,
    super.key,
  });

  final bool hasMedia;
  final double aspectRatio;
  final int linesCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header: Avatar + Title/Subtitle + Trailing menu placeholder
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 130,
                        height: 14,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 85,
                        height: 11,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(5.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),

          // Content body text lines
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  height: 13,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6.5),
                  ),
                ),
                if (linesCount > 1) ...<Widget>[
                  const SizedBox(height: 6),
                  Container(
                    width: 220,
                    height: 13,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6.5),
                    ),
                  ),
                ],
                if (linesCount > 2) ...<Widget>[
                  const SizedBox(height: 6),
                  Container(
                    width: 140,
                    height: 13,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6.5),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Media Viewport Box placeholder
          if (hasMedia)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Container(
                    color: scheme.surfaceContainerHighest,
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 36,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Action Bar placeholder strip
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  _ActionChipPlaceholder(scheme: scheme, width: 44),
                  const SizedBox(width: 4),
                  _ActionChipPlaceholder(scheme: scheme, width: 44),
                  const SizedBox(width: 4),
                  _ActionChipPlaceholder(scheme: scheme, width: 44),
                  const Spacer(),
                  _ActionChipPlaceholder(scheme: scheme, width: 32),
                  const SizedBox(width: 4),
                  _ActionChipPlaceholder(scheme: scheme, width: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChipPlaceholder extends StatelessWidget {
  const _ActionChipPlaceholder({required this.scheme, required this.width});
  final ColorScheme scheme;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 24,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// Unified feed loading skeleton with coordinated shimmer sweep.
class PostFeedSkeleton extends StatelessWidget {
  const PostFeedSkeleton({this.count = 4, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: count,
      itemBuilder: (BuildContext context, int index) {
        final bool hasMedia = index % 2 == 0;
        final double aspectRatio = index % 4 == 0 ? (16 / 9) : (4 / 3);
        final int lines = (index % 3) + 1;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: PostCardSkeleton(
            hasMedia: hasMedia,
            aspectRatio: aspectRatio,
            linesCount: lines,
          ),
        );
      },
    );
  }
}
