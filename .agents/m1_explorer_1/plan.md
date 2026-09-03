# Milestone 1: NiosGram Responsive Canvas & Expressive Quick-Creation Bar — Implementation Plan

## 1. Overview & Objectives
This plan details the exact architectural and UI modifications required for **Milestone 1** of NiosMess (NiosGram Social Feed):
1. **Responsive Feed Canvas**: Expand NiosGram from the restrictive `maxWidth: 680` to an adaptive, centered `780dp` canvas (`720–800dp` standard) to eliminate awkward empty side margins on wide/desktop/web viewports while maintaining optimal reading line lengths.
2. **Adaptive Horizontal Gutters**: Implement responsive padding (`16dp` on mobile viewports `< 760dp`, `24dp` on desktop/tablet viewports `≥ 760dp`).
3. **Expressive Quick-Creation FAB / Dock**: Introduce a dedicated Material 3 Expressive quick-creation action button styled with `flutter_m3shapes` (`Shapes.c9_sided_cookie` / `M3Clipper`), tactile elevation glow, clipped ripple effects, tooltip, haptic feedback, and composite stacking with the scroll-to-top button.

---

## 2. Code Analysis & Problem Diagnosis

### 2.1. `lib/screens/main_shell_screen.dart` (Lines 185–195)
```dart
// Current implementation in main_shell_screen.dart
184: final List<Widget> pages = <Widget>[
...
185:   isWide
186:       ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: const ContactsScreen()))
187:       : const ContactsScreen(),
188:   isWide
189:       ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: const NiosgramScreen()))
190:       : const NiosgramScreen(),
191:   isWide
192:       ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: const ProfileScreen()))
193:       : const ProfileScreen(),
194: ];
```
- **Deficiency**: `NiosgramScreen` is restricted to `maxWidth: 680` on `isWide` (`width >= 760`), while `ContactsScreen` and `ProfileScreen` use `maxWidth: 780`. On desktop and web displays (1080p, 1440p, 4K), 680dp leaves excessive dead space on either side and constrains rich media post cards (images/videos) excessively.
- **Resolution**: Expand line 188 to `maxWidth: 780`, harmonizing NiosGram with the rest of the application and providing ample width for expressive media viewports and comments.

### 2.2. `lib/screens/niosgram_screen.dart`
- **Deficiencies**:
  1. **Fixed Item Gutters**: Feed cards use hardcoded `EdgeInsets.symmetric(horizontal: 12, vertical: 6)`. On mobile (360–420dp) 12dp is slightly too narrow for edge breathing room, and on desktop (760dp+) 12dp feels cramped inside the wider container.
  2. **Missing Quick-Creation FAB**: Currently, the only way to create a post is via the top `AppBar` icon button (line 62) or when the feed is empty. The `floatingActionButton` slot (lines 75–88) is only used for a mini scroll-to-top button when `_scrollController.offset > 200`.
  3. **Ergonomic Inefficiency on Mobile**: On modern tall devices, reaching the top-right `AppBar` button requires two hands or awkward thumb reach. A floating M3 cookie FAB in the bottom right enables effortless one-handed creation.

---

## 3. Architecture & Technical Design

### 3.1. Responsive Canvas & Gutters Architecture
- **Breakpoint Rule**:
  - `isWide = MediaQuery.sizeOf(context).width >= 760` (or within `LayoutBuilder`).
- **Gutter Hierarchy**:
  - **Mobile (`< 760dp`)**: `horizontal: 16.0`, `vertical: 6.0`. Bottom padding: `96.0` (to clear bottom navigation bar and floating creation FAB).
  - **Desktop (`≥ 760dp`)**: `horizontal: 24.0`, `vertical: 8.0`. Bottom padding: `84.0`.
  - **Skeleton Loaders**: Adapted to match the responsive horizontal gutter (`16dp` mobile / `24dp` desktop).
  - **Feed Container**: Centered with `maxWidth: 780` both in `main_shell_screen.dart` and self-contained within `NiosgramScreen`.

### 3.2. Expressive Quick-Creation FAB (`Shapes.c9_sided_cookie`)
- **Shape Geometry**: 9-sided cookie (`Shapes.c9_sided_cookie` from `flutter_m3shapes`).
- **Clipping & Ripple**:
  - `ClipPath(clipper: M3Clipper(Shapes.c9_sided_cookie), child: Material(... InkWell(...)))` ensures ink ripples and highlights strictly follow the scalloped 9-fluted cookie contours.
- **Color Palette & Contrast**:
  - Background: `colorScheme.primaryContainer`
  - Icon: `colorScheme.onPrimaryContainer`
  - Splash: `colorScheme.primary.withValues(alpha: 0.18)`
  - Shadow glow: `BoxShadow(color: colorScheme.primary.withValues(alpha: 0.28), blurRadius: 14, spreadRadius: 1, offset: Offset(0, 5))`
- **Composite Action Layout**:
  - When `_showFab == false` (scroll offset ≤ 200dp): Displays `_NiosgramQuickCreateFab`.
  - When `_showFab == true` (scroll offset > 200dp): Displays a clean vertical `Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end)` containing:
    1. `FloatingActionButton.small` (Scroll-to-top, `Icons.keyboard_arrow_up_rounded`)
    2. `SizedBox(height: 12)`
    3. `_NiosgramQuickCreateFab` (9-sided cookie quick-create button)
- **Haptic & Accessibility Support**:
  - Triggers `HapticService.tap()` when `uiSettings.haptics` is true.
  - Wrapped in `Tooltip(message: context.l10n.niosgramCreatePost)` and semantic button labels.

---

## 4. Code Modification Blueprint

### 4.1. File: `pulse_flutter/lib/screens/main_shell_screen.dart`
**Line 188 Modification**:
```dart
<<<<
          isWide
              ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: const NiosgramScreen()))
              : const NiosgramScreen(),
====
          isWide
              ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: const NiosgramScreen()))
              : const NiosgramScreen(),
>>>>
```

---

### 4.2. File: `pulse_flutter/lib/screens/niosgram_screen.dart`
**Imports Addition (top of file)**:
```dart
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
```

**Responsive Layout & FAB Integration**:
```dart
  @override
  Widget build(BuildContext context) {
    final AsyncValue<NiosgramState> feedAsync = ref.watch(niosgramProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWide = screenWidth >= 760;
    final double horizontalGutter = isWide ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          context.l10n.niosgramTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: context.l10n.niosgramCreatePost,
            onPressed: () {
              if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
              context.push('/niosgram/create');
            },
          ),
          const SizedBox(width: 4),
          _NotificationsBell(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _buildFloatingActions(context, scheme),
      body: feedAsync.when(
        loading: () => ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalGutter, vertical: 16),
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
        error: (Object e, _) => AppErrorBanner(
          message: context.l10n.niosgramFailedLoad,
          variant: AppErrorBannerVariant.centered,
          onRetry: () => ref.invalidate(niosgramProvider),
        ),
        data: (NiosgramState feedState) {
          if (feedState.posts.isEmpty) {
            return EmptyFeedWidget(
              title: context.l10n.niosgramEmptyFeed,
              description: context.l10n.niosgramEmptyFeedDesc,
              actionLabel: context.l10n.niosgramCreatePost,
              onAction: () => context.push('/niosgram/create'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(niosgramProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                top: 4,
                bottom: isWide ? 84 : 96,
              ),
              itemCount: feedState.posts.length +
                  (feedState.isLoadingMore ? 1 : 0) +
                  (feedState.hasMore && !feedState.isLoadingMore ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (index == feedState.posts.length) {
                  if (feedState.isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: AppLoadingIndicator(size: 32),
                    );
                  }
                  return _LoadMoreTrigger(
                    onVisible: () =>
                        ref.read(niosgramProvider.notifier).loadMore(),
                  );
                }
                final NgPost post = feedState.posts[index];
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalGutter,
                    vertical: isWide ? 8 : 6,
                  ),
                  child: Animate(
                    key: ValueKey<String>('post_${post.id}'),
                    effects: <Effect<dynamic>>[
                      FadeEffect(
                        begin: 0,
                        end: 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                      SlideEffect(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      ),
                    ],
                    delay: Duration(milliseconds: (index % 10) * 50),
                    child: PostCard(key: ValueKey<int>(post.id), post: post),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
```

**Floating Action Button Helper & Quick-Creation Widget**:
```dart
  Widget _buildFloatingActions(BuildContext context, ColorScheme scheme) {
    final Widget createFab = _NiosgramQuickCreateFab(
      onPressed: () {
        if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
        context.push('/niosgram/create');
      },
      tooltip: context.l10n.niosgramCreatePost,
    );

    if (!_showFab) {
      return createFab;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        FloatingActionButton.small(
          heroTag: 'niosgram_scroll_top',
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurfaceVariant,
          elevation: 2,
          onPressed: () {
            if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          },
          child: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        const SizedBox(height: 12),
        createFab,
      ],
    );
  }

// ── Expressive 9-sided cookie Quick Creation FAB ──────────────────────
class _NiosgramQuickCreateFab extends StatelessWidget {
  const _NiosgramQuickCreateFab({
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.30),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipPath(
            clipper: M3Clipper(Shapes.c9_sided_cookie),
            child: Material(
              color: scheme.primaryContainer,
              child: InkWell(
                onTap: onPressed,
                splashColor: scheme.primary.withValues(alpha: 0.20),
                highlightColor: scheme.primary.withValues(alpha: 0.10),
                child: Center(
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 28,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 5. Verification & Test Plan

1. **Responsive Canvas Constraints Test**:
   - Verify `main_shell_screen.dart` applies `BoxConstraints(maxWidth: 780)` when viewport width ≥ 760dp.
   - Verify layout does not overflow horizontally across screen sizes (360dp, 760dp, 1024dp, 1440dp, 1920dp).
2. **Gutters & Margin Test**:
   - Verify mobile gutter evaluates to `16.0` and desktop gutter evaluates to `24.0`.
3. **M3 Quick-Creation FAB Widget Test**:
   - Verify presence of `_NiosgramQuickCreateFab` in `NiosgramScreen`.
   - Verify tapping the FAB invokes `context.push('/niosgram/create')`.
   - Verify tooltip is present with localized text `context.l10n.niosgramCreatePost`.
   - Verify scroll-to-top button appears above the creation FAB when scroll offset > 200.
4. **Static Analysis**:
   - `flutter analyze` passes with 0 issues.
