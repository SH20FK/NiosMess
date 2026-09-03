import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class PulseSkeleton extends StatelessWidget {
  const PulseSkeleton({
    this.width,
    this.height = 18,
    this.borderRadius = 8,
    super.key,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      highlightColor: scheme.primaryContainer.withValues(alpha: 0.6),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({this.count = 6, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      highlightColor: scheme.primaryContainer.withValues(alpha: 0.6),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 140 + (index % 3) * 40.0,
                        height: 16,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 200 + (index % 4) * 30.0,
                        height: 12,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MessageListSkeleton extends StatelessWidget {
  const MessageListSkeleton({this.count = 8, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      highlightColor: scheme.primaryContainer.withValues(alpha: 0.6),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (BuildContext context, int index) {
          final bool isMine = index % 3 == 0;
          final double bubbleWidth = 120 + (index % 5) * 40.0;

          return Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 6),
                  bottomRight: Radius.circular(isMine ? 6 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: bubbleWidth,
                    height: 14,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: bubbleWidth * 0.5,
                    height: 10,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      highlightColor: scheme.surfaceContainerLow.withValues(alpha: 0.85),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        itemCount: count,
        itemBuilder: (BuildContext context, int index) {
          final bool hasMedia = index % 2 == 0;
          final double aspectRatio = index % 4 == 0 ? (16 / 9) : (4 / 3);
          final int lines = (index % 3) + 1;

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            child: PostCardSkeleton(
              hasMedia: hasMedia,
              aspectRatio: aspectRatio,
              linesCount: lines,
            ),
          );
        },
      ),
    );
  }
}

