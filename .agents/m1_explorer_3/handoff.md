# Handoff Report: NiosGram Media Viewports, Shimmer Loaders & Skeletons (M1 Explorer 3)

## 1. Observation

1. **Media Viewport in `lib/widgets/post_card.dart` (lines 210–261)**:
   - Media container is wrapped in `ConstrainedBox(constraints: const BoxConstraints(maxHeight: 480, minHeight: 200))` without aspect ratio locking.
   - Placeholder is a hardcoded `SizedBox(height: 260, child: Center(child: AppLoadingIndicator(size: 28, color: scheme.onSurfaceVariant)))` which causes abrupt layout jump (CLS) when network images resolve to different heights.
   - Cache resolution is hardcoded to `memCacheWidth: 800`, which leads to pixelation on retina high-DPI desktop screens (780dp feed width requires ~1560px).
   - Error widget is `SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image_rounded, color: scheme.outline, size: 32)))` without descriptive error typography.

2. **Skeleton Architecture in `lib/widgets/pulse_skeleton.dart` (lines 1–164)**:
   - Contains `PulseSkeleton` (atomic rectangle with standalone shimmer), `ChatListSkeleton`, and `MessageListSkeleton`.
   - **No** `PostCardSkeleton` or `PostFeedSkeleton` exists.

3. **Loading State in `lib/screens/niosgram_screen.dart` (lines 89–111)**:
   - When `feedAsync` is in `loading` state, it renders an unstyled column of 4 raw `PulseSkeleton` widgets:
     ```dart
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
   - Lacks 24dp card background (`surfaceContainerLow`), outline border (`outlineVariant`), author subtitle/handle bar, verified tick, action bar container, and action chip placeholders.
   - List padding (`all(16)`) mismatches real data list padding (`top: 4, bottom: 80` with item padding `horizontal: 12, vertical: 6`), causing layout shifting upon completion.

---

## 2. Logic Chain

1. **Eliminating Cumulative Layout Shift (CLS)**:
   - By locking the media viewport in `AspectRatio(aspectRatio: 16 / 9)` with `ClipRRect(borderRadius: BorderRadius.circular(16))` and matching the shimmer placeholder to the exact same aspect ratio, the container maintains its exact geometry before, during, and after image loading.
2. **Retina & Wide Screen Crispness**:
   - As the feed canvas expands to 780dp (Explorer 1 specification), increasing `memCacheWidth` to `1600` ensures 2x retina display sharpness without consuming unneeded memory.
3. **Synchronized Feed Shimmer vs Scattered Timers**:
   - Wrapping multiple standalone `PulseSkeleton` widgets in separate shimmer widgets causes visual phase jitter. Creating `PostFeedSkeleton` that wraps a `ListView.builder` inside a single top-level `Shimmer.fromColors` achieves a synchronized sweeping light effect.
4. **Structural Parity between Skeleton and Real PostCard**:
   - `PostCardSkeleton` mirrors the updated M3 Expressive `PostCard` (Explorer 2 specification) token-for-token:
     - Surface: `colorScheme.surfaceContainerLow`
     - Corner radius: `BorderRadius.circular(24)`
     - Border: `Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.20))`
     - Header: 40dp avatar circle, 130x14dp title bar, 85x11dp handle/time bar, 24x24dp trailing menu circle.
     - Body: 2–3 text line bars with varied widths (100%, 220dp, 140dp).
     - Media: 16dp rounded box with `16:9` / `4:3` aspect ratio.
     - Action bar: 16dp rounded strip with 5 action chip placeholders.
5. **Seamless Data Transition in `NiosgramScreen`**:
   - Replacing lines 89–111 in `niosgram_screen.dart` with `PostFeedSkeleton(count: 4)` using identical padding guarantees zero visual popping or layout shift when post data loads from Riverpod.

---

## 3. Caveats

- **Media Aspect Ratio Flexibility**: If backend posts later include native media metadata (`aspect_ratio`, `width`, `height`), `PostMediaViewport` is designed to accept an optional `aspectRatio` parameter while cleanly defaulting to `16:9`.
- **Local Dart SDK Constraints**: Local Dart SDK is 3.10.7; all code strictly uses valid Dart 3.10 syntax (e.g., `withValues(alpha:)` per AGENTS.md, no `dart:io`).

---

## 4. Conclusion

The technical plan is complete, verified, and ready for worker implementation. All widget modifications, line numbers, and architectural specifications are documented in `plan.md`.

Target files for implementation:
1. `pulse_flutter/lib/widgets/pulse_skeleton.dart`: Add `PostCardSkeleton` and `PostFeedSkeleton`.
2. `pulse_flutter/lib/widgets/post_card.dart`: Modernize media viewport (lines 210–261) with `AspectRatio(16/9)`, `ClipRRect(16dp)`, `_MediaPlaceholderShimmer`, `_MediaErrorPlaceholder`, and `memCacheWidth: 1600`.
3. `pulse_flutter/lib/screens/niosgram_screen.dart`: Replace lines 89–111 with `PostFeedSkeleton(count: 4)`.

---

## 5. Verification Method

1. **Static Analysis**:
   ```bash
   cd pulse_flutter
   flutter analyze
   ```
   Ensure 0 warnings and 0 errors across `pulse_skeleton.dart`, `post_card.dart`, and `niosgram_screen.dart`.

2. **Widget & Unit Tests**:
   - Run widget test verifying `PostCardSkeleton` renders all placeholder components (avatar, header, media, action bar) without layout overflow.
   - Run widget test verifying `PostFeedSkeleton` pumps 4 synchronized cards.
   - Run widget test verifying `PostCard` media viewport renders with `AspectRatio(aspectRatio: 16 / 9)` and `_MediaPlaceholderShimmer`.
   ```bash
   flutter test test/widgets/pulse_skeleton_test.dart
   ```
