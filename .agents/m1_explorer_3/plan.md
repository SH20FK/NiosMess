# Architecture & Implementation Plan: NiosGram Media Viewports, Shimmer Loaders & Skeletons

## 1. Executive Summary & Objective

This document outlines the detailed technical architecture and exact code implementation plan for the **Media Viewport**, **Shimmer Loaders**, and **Skeletons** of NiosGram social feed in `pulse_flutter` under Milestone 1 (M1).

### Core Goals:
1. **Aspect-Ratio-Aware Media Viewport**:
   - Modern Material 3 Expressive media card container with `16dp` rounded inner corners (`BorderRadius.circular(16)`).
   - Dynamic and adaptive aspect ratio support (`16:9` default landscape, `4:3` photo standard, `1:1` square) preventing Cumulative Layout Shift (CLS).
   - High-fidelity shimmer loading placeholder (`_MediaPlaceholderShimmer`) with soft vector image icon (`Icons.image_outlined`).
   - High-DPI cache optimization (`memCacheWidth: 1600`) to ensure sharp rendering on retina displays and wide canvas (780dp desktop feed).
   - Tonal fallback error widget (`_MediaErrorPlaceholder`) with broken image vector iconography.
2. **Dedicated `PostCardSkeleton` and `PostFeedSkeleton`**:
   - New `PostCardSkeleton` in `lib/widgets/pulse_skeleton.dart` matching the M3 Expressive 24dp post card surface (`colorScheme.surfaceContainerLow`, `BorderRadius.circular(24)`, `outlineVariant.withValues(alpha: 0.20)` border).
   - Complete visual hierarchy skeleton: 40dp circular avatar, author name + handle + relative time bars, trailing icon, multi-line content, 16dp rounded aspect-ratio media box, and 16dp rounded action bar pill container with action chip placeholders (like, dislike, comment, bookmark, share).
   - New `PostFeedSkeleton` wrapping the feed in a single coordinated `Shimmer.fromColors` sweep with alternating media and text-only post variations.
3. **Seamless Replacement in `NiosgramScreen`**:
   - Replace the legacy crude column of `PulseSkeleton` widgets in `lib/screens/niosgram_screen.dart` (lines 90–111) with `PostFeedSkeleton(count: 4)`.
   - Ensure matching padding (`top: 4, bottom: 80`, item padding `horizontal: 12, vertical: 6`) for zero-layout-jump state transitions.

---

## 2. Codebase Observations & Gap Analysis

### 2.1 Media Viewport in `lib/widgets/post_card.dart`
- **Location**: `lib/widgets/post_card.dart` (lines 210–261).
- **Current Code**:
  ```dart
  // ── Media ───────────────────────────────────────────────
  if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
    Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onDoubleTap: _onDoubleTapLike,
        onTap: () => _openFullScreen(context, ApiConstants.resolve(post.mediaUrl), post.id),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 480,
              minHeight: 200,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Hero(
                    tag: 'post_media_${post.id}',
                    child: CachedNetworkImage(
                      imageUrl: ApiConstants.resolve(post.mediaUrl),
                      httpHeaders: cachedAuthHeaders(),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      memCacheWidth: 800,
                      placeholder: (_, _) => SizedBox(
                        height: 260,
                        child: Center(
                          child: AppLoadingIndicator(size: 28, color: scheme.onSurfaceVariant),
                        ),
                      ),
                      errorWidget: (_, _, _) => SizedBox(
                        height: 200,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: scheme.outline,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ```
- **Deficiencies**:
  1. **Layout Jitter / CLS**: `placeholder` is hardcoded to `height: 260`, while the loaded image is constrained only by `maxHeight: 480, minHeight: 200`. When the image arrives, the container height snaps from 260 to the loaded image height, causing jarring feed jumps.
  2. **Crude Spinner Placeholder**: Uses `AppLoadingIndicator(size: 28)` inside a plain grey box, lacking modern shimmer gradients and branded vector iconography.
  3. **Low Cache Resolution**: `memCacheWidth: 800` is blurry on desktop and high-DPI retina screens when the canvas expands to 780dp (device pixel ratio 2.0+ requires 1560px+).
  4. **Missing Container Boundaries**: Lacks inner horizontal gutters (`padding: const EdgeInsets.fromLTRB(14, 10, 14, 0)`) and subtle border (`outlineVariant.withValues(alpha: 0.15)`), causing the media container to clash with outer card padding.

### 2.2 Skeletons in `lib/widgets/pulse_skeleton.dart`
- **Location**: `lib/widgets/pulse_skeleton.dart` (lines 1–164).
- **Current Contents**:
  - `PulseSkeleton` (atomic rectangle).
  - `ChatListSkeleton` (chat conversation item list).
  - `MessageListSkeleton` (chat bubble list).
- **Deficiencies**:
  - **Zero PostCard or Feed Skeleton**: No `PostCardSkeleton` or `PostFeedSkeleton` exists.
  - Skeletons are assembled ad-hoc in screens with mismatched dimensions.

### 2.3 Loading State in `lib/screens/niosgram_screen.dart`
- **Location**: `lib/screens/niosgram_screen.dart` (lines 89–111).
- **Current Code**:
  ```dart
  body: feedAsync.when(
    loading: () => ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, int i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              const PulseSkeleton(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 10),
              PulseSkeleton(width: 120 + (i % 3) * 30.0, height: 14),
            ]),
            const SizedBox(height: 12),
            PulseSkeleton(width: double.infinity, height: 200, borderRadius: 16),
            const SizedBox(height: 8),
            PulseSkeleton(width: 180, height: 12),
          ],
        ),
      ),
    ),
  ```
- **Deficiencies**:
  - Raw un-contained skeleton column without `Card` or `surfaceContainerLow` container.
  - Missing author handle and relative time bars.
  - Missing action bar container and chip placeholders.
  - Padding (`padding: const EdgeInsets.all(16)`) differs from loaded feed padding (`const EdgeInsets.only(top: 4, bottom: 80)` with item padding `horizontal: 12, vertical: 6`), causing noticeable layout shifts on data arrival.

---

## 3. Technical Design & Architecture

### 3.1 Aspect-Ratio-Aware Media Viewport Specification

```
┌────────────────────────────────────────────────────────┐
│ Card Container (24dp radius, surfaceContainerLow)     │
│ ┌────────────────────────────────────────────────────┐ │
│ │ Author Header (Avatar + Name + Time + Menu)        │ │
│ └────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────┐ │
│ │ Post Content Markdown/Text                         │ │
│ └────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────┐ │
│ │ Media Viewport (ClipRRect 16dp, AspectRatio 16:9)  │ │
│ │ ┌────────────────────────────────────────────────┐ │ │
│ │ │ Shimmer Placeholder / CachedNetworkImage       │ │ │
│ │ │ (memCacheWidth: 1600, fadeIn: 250ms)           │ │ │
│ │ └────────────────────────────────────────────────┘ │ │
│ └────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────┐ │
│ │ Action Bar (16dp radius pill container)            │ │
│ └────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘
```

#### Key Implementation Details:
1. **Container Geometry**:
   - `ClipRRect(borderRadius: BorderRadius.circular(16))`
   - Inner margin inside card: `EdgeInsets.fromLTRB(14, 10, 14, 0)`
   - Border: `Border.all(color: scheme.outlineVariant.withValues(alpha: 0.15))`
2. **Aspect Ratio Support**:
   - Wrapped in `AspectRatio(aspectRatio: 16 / 9)` (or configurable aspect ratio `aspectRatio: 16 / 9` / `4 / 3`).
   - `fit: BoxFit.cover` with `alignment: Alignment.center`.
3. **Shimmer Placeholder (`_MediaPlaceholderShimmer`)**:
   - Base color: `scheme.surfaceContainerHighest.withValues(alpha: 0.6)`
   - Highlight color: `scheme.surfaceContainerLow.withValues(alpha: 0.8)`
   - Soft center vector icon: `Icon(Icons.image_outlined, size: 40, color: scheme.onSurfaceVariant.withValues(alpha: 0.35))`
   - Loading indicator line pill: 64x6dp with 3dp radius.
4. **Error Placeholder (`_MediaErrorPlaceholder`)**:
   - Subtle tinted background: `scheme.surfaceContainerHighest.withValues(alpha: 0.35)`
   - Broken image icon: `Icon(Icons.broken_image_rounded, size: 40, color: scheme.outlineVariant)`
   - Explanatory caption: `Text(context.l10n.niosgramFailedLoad, style: textTheme.bodySmall)`
5. **High-DPI Performance**:
   - `memCacheWidth: 1600`
   - `fadeInDuration: const Duration(milliseconds: 250)`
   - `fadeOutDuration: const Duration(milliseconds: 150)`

---

### 3.2 `PostCardSkeleton` and `PostFeedSkeleton` Specification

#### Geometry & Visual Mapping Table:

| UI Section | Real PostCard Component | `PostCardSkeleton` Component |
| :--- | :--- | :--- |
| **Card Frame** | `Card` with `surfaceContainerLow`, `24dp` radius, `outlineVariant` border | `Container` with `surfaceContainerLow`, `24dp` radius, `outlineVariant.withValues(alpha: 0.20)` border |
| **Avatar** | `PulseAvatar(radius: 20)` (40x40dp) | `Container(width: 40, height: 40, shape: BoxShape.circle)` |
| **Author Title** | Bold displayName (15sp) | `Container(width: 130, height: 14, radius: 7)` |
| **Author Subtitle** | `@handle · 2m` (12.5sp) | `Container(width: 85, height: 11, radius: 5.5)` |
| **Trailing Menu** | `PopupMenuButton` (24x24dp) | `Container(width: 24, height: 24, radius: 12)` |
| **Content Lines** | Multi-line text (15sp) | `Container(width: double.infinity, height: 13, radius: 6.5)` + `Container(width: 220, height: 13, radius: 6.5)` |
| **Media Viewport** | 16dp rounded inner image (16:9 / 4:3) | `ClipRRect(16dp, child: AspectRatio(16/9, child: Container(...)))` |
| **Action Bar** | 16dp rounded pill strip with 5 chips | `Container(16dp radius, padding: horizontal 6, vertical 4)` with 5 `_ActionChipPlaceholder` chips |

#### Feed Variation Strategy in `PostFeedSkeleton`:
- Item 0: Post with 16:9 media, 2 content lines.
- Item 1: Post with 4:3 media, 1 content line.
- Item 2: Text-only post, 3 content lines.
- Item 3: Post with 16:9 media, 2 content lines.
- Wrap all items in a top-level `Shimmer.fromColors` for synchronized gradient animation across the viewport.

---

## 4. Code Modifications & Target File Snippets

### File 1: `pulse_flutter/lib/widgets/pulse_skeleton.dart`

**Additions to `pulse_skeleton.dart`**:

```dart
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
```

---

### File 2: `pulse_flutter/lib/widgets/post_card.dart`

**Modifications in `post_card.dart` (Media Viewport Section, lines 210–261)**:

```dart
          // ── Media Viewport ──────────────────────────────────────
          if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: GestureDetector(
                onDoubleTap: _onDoubleTapLike,
                onTap: () => _openFullScreen(
                  context,
                  ApiConstants.resolve(post.mediaUrl),
                  post.id,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.15),
                      ),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Hero(
                        tag: 'post_media_${post.id}',
                        child: CachedNetworkImage(
                          imageUrl: ApiConstants.resolve(post.mediaUrl),
                          httpHeaders: cachedAuthHeaders(),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          memCacheWidth: 1600,
                          fadeInDuration: const Duration(milliseconds: 250),
                          fadeOutDuration: const Duration(milliseconds: 150),
                          placeholder: (BuildContext context, String url) =>
                              _MediaPlaceholderShimmer(scheme: scheme),
                          errorWidget: (BuildContext context, String url, Object error) =>
                              _MediaErrorPlaceholder(scheme: scheme),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
```

**Add Media Helpers to `post_card.dart`**:

```dart
// ── Media Shimmer & Error Placeholders ───────────────────────────────
class _MediaPlaceholderShimmer extends StatelessWidget {
  const _MediaPlaceholderShimmer({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      highlightColor: scheme.surfaceContainerLow.withValues(alpha: 0.8),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.image_outlined,
                size: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 8),
              Container(
                width: 64,
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaErrorPlaceholder extends StatelessWidget {
  const _MediaErrorPlaceholder({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.broken_image_rounded,
              color: scheme.outlineVariant,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.niosgramFailedLoad,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### File 3: `pulse_flutter/lib/screens/niosgram_screen.dart`

**Modifications in `niosgram_screen.dart` (lines 89–111)**:

```dart
      body: feedAsync.when(
        loading: () => const PostFeedSkeleton(count: 4),
        error: (Object e, _) => AppErrorBanner(
          message: context.l10n.niosgramFailedLoad,
          variant: AppErrorBannerVariant.centered,
          onRetry: () => ref.invalidate(niosgramProvider),
        ),
```

---

## 5. Verification & Testing Matrix

| Component | Target Verification Method | Expected Result |
| :--- | :--- | :--- |
| **Media Aspect Ratio** | Render `PostCard` with media url in widget test | `AspectRatio(aspectRatio: 16 / 9)` is present with `ClipRRect(borderRadius: BorderRadius.circular(16))` |
| **Media Shimmer** | Inspect `CachedNetworkImage.placeholder` during network delay | `_MediaPlaceholderShimmer` displays synchronized shimmer with `Icons.image_outlined` |
| **High-DPI Cache** | Verify `memCacheWidth` argument | Value is `1600` |
| **PostCardSkeleton** | Pump `PostCardSkeleton(hasMedia: true)` | All elements (avatar, title, subtitle, content, media, action bar) render with 0 overflow errors |
| **PostFeedSkeleton** | Pump `PostFeedSkeleton(count: 4)` | 4 skeleton cards render in `ListView` with synchronized `Shimmer.fromColors` |
| **Zero CLS on Feed Load** | Measure layout bounds before and after `feedAsync` transitions from `loading` to `data` | List margins (`top: 4, bottom: 80`) and item gutters (`horizontal: 12, vertical: 6`) are identical; zero layout shift |
| **Static Analysis** | Run `flutter analyze` | 0 errors, 0 warnings |

---

## 6. Synergy with Explorer 1 and Explorer 2

- **Explorer 1 (Responsive Canvas & FAB)**: Sets the feed constraint to `maxWidth: 780` in `main_shell_screen.dart`. The media viewport's `memCacheWidth: 1600` and `PostFeedSkeleton` scale seamlessly to this 780dp wide canvas.
- **Explorer 2 (Card Surface & Action Controls)**: Upgrades `PostCard` to `surfaceContainerLow`, `BorderRadius.circular(24)`, `outlineVariant.withValues(alpha: 0.20)`, verified badges, and bookmark action chip. `PostCardSkeleton` is 100% matched to these dimensions and tokens.
