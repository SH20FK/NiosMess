# NiosGram Codebase Survey & Material 3 Expressive Gap Analysis

**Date:** 2026-09-02  
**Project:** NiosMess (`pulse_flutter`)  
**Investigator:** Explorer 1 (`explorer_survey_1`)  
**Scope:** NiosGram Social Feed Subsystem (`lib/screens/`, `lib/widgets/`, `lib/providers/`, `lib/models/`, `lib/router/`, `lib/l10n/`)

---

## 1. Executive Summary

NiosGram is the native social feed component of NiosMess. It enables users to browse a dynamic timeline of posts containing rich Markdown text, images, and attachments, interact with posts (likes, comments, sharing, editing, deleting), and follow/unfollow authors. Real-time post delivery is handled over WebSockets with optimistic UI updates powered by Riverpod 3.x (`NotifierProvider` / `AsyncNotifierProvider`).

While NiosGram has complete functional logic and WebSocket RPC integration, its visual presentation and responsive layout have significant gaps when compared to **Material 3 Expressive** design guidelines and modern web/desktop adaptivity standards. Currently:
- On wide displays (desktop/web), the feed is either constrained to an awkward **680dp** in `main_shell_screen.dart` (leaving large side voids) or expands without constraints to full monitor width (e.g. 1920dp+) when rendered standalone.
- Post cards use standard `Card` containers lacking subtle tonal borders (`outlineVariant`), smooth 20–24dp corners, and verified author badges.
- Media viewports rely on fixed height constraints (`minHeight: 200, maxHeight: 480`) with basic spinners instead of aspect-ratio-aware containers with smooth blur/shimmer loaders and soft tinted vector graphics.
- The action bar lacks a **Bookmark** button, still includes legacy dislike buttons, and lacks expressive animated reaction controls.
- The feed lacks an expressive quick-creation FAB/bar utilizing `flutter_m3shapes` tokens.

This report provides a complete catalog of all relevant files, analyzes component implementations, maps responsive behaviors, and defines an actionable blueprint for the upcoming M3 Expressive overhaul.

---

## 2. File & Component Catalog

### 2.1 Screens (`lib/screens/`)
| File | Lines | Purpose & Key Components |
|---|---|---|
| `lib/screens/niosgram_screen.dart` | 259 | Main feed view. Contains `NiosgramScreen`, `_NotificationsBell`, `_LoadMoreTrigger`. Renders `feedAsync.when` (loading skeleton, error banner, empty feed, posts list) and scroll-to-top mini FAB. |
| `lib/screens/create_post_screen.dart` | 230 | Post composer screen. Multi-line input, media picker (`FileType.media`), image compression via `ImageCompressor`, chunked file upload via `chatRepositoryProvider.uploadStreamInChunks`, discard confirmation dialog. |
| `lib/screens/post_comments_screen.dart` | 335 | Standalone comments page for a post. Shows comment count header, list of `MessageBubble` widgets, reply-to preview banner, input bar with circular send button, and delete/report triggers. |
| `lib/screens/main_shell_screen.dart` | 401 | Main app shell hosting bottom navigation on mobile (<760dp) and `NavigationRail` on desktop (>=760dp). Tab index 2 hosts `NiosgramScreen`. |

### 2.2 Widgets (`lib/widgets/`)
| File | Lines | Purpose & Key Components |
|---|---|---|
| `lib/widgets/post_card.dart` | 711 | Core feed item widget (`PostCard`). Displays author avatar (`PulseAvatar`), display name, `@username`, relative timestamp, follow/unfollow toggle, popup options menu (`_PostMenu`), markdown body (`MarkdownBody`), media viewport (`CachedNetworkImage` + `_FullScreenImage`), action chips bar, double-tap heart animation (`_heartController`). |
| `lib/widgets/comments_bottom_sheet.dart` | 226 | Modal bottom sheet alternative for post comments (`DraggableScrollableSheet`) with reply preview and text input. |
| `lib/widgets/empty_feed_widget.dart` | 169 | Empty state widget featuring `M3Container(Shapes.c9_sided_cookie)`, title, description, and tonal action button. |
| `lib/widgets/badge_chip.dart` | 395 | Author badge display (`BadgeChip`, `BadgeResolver`, `BadgeDisplayMode.statusIcon/infoLabel/avatarBadge`). Maps emojis and keywords (verified, developer, admin, premium) to M3 icons. |
| `lib/widgets/pulse_avatar.dart` | 202 | Avatar component with network image caching (Web `Image.network` vs mobile `CachedNetworkImage`), initials generator, and animated shimmer placeholder. |
| `lib/widgets/pulse_skeleton.dart` | 164 | Shimmer loading skeleton primitives (`PulseSkeleton`, `ChatListSkeleton`, `MessageListSkeleton`). |

### 2.3 Providers & State Management (`lib/providers/`)
| File | Lines | Purpose & Key Components |
|---|---|---|
| `lib/providers/niosgram_provider.dart` | 284 | `NiosgramNotifier` extending `AsyncNotifier<NiosgramState>`. Manages `posts`, `isLoadingMore`, `hasMore`, and `page`. Implements `build()`, `_fetchPage()`, `_handlePush()`, `refresh()`, `loadMore()`, `reactPost()`, `createPost()`, `deletePost()`, `editPost()`, and `toggleFollow()`. Subscribes to WS push action `new_ng_post`. |
| `lib/providers/backend_chat_provider.dart` | ~450 | Defines `postCommentsProvider(PostCommentsArgs)` family provider for fetching comments and sending new comments over WebSocket. |
| `lib/providers/ui_settings_provider.dart` | 180 | Provides UI settings (theme mode, seed color, dynamic color, haptics toggle, animations/weak device optimization). |

### 2.4 Models (`lib/models/api/`)
| File | Lines | Fields & Contract |
|---|---|---|
| `lib/models/api/post_model.dart` | 108 | `NgPost`: `id` (int), `content` (String), `mediaUrl` (String?), `likesCount` (int), `dislikesCount` (int), `commentsCount` (int), `myReaction` (bool?), `isFollowing` (bool), `author` (`ApiProfile`), `createdAt` (`DateTime`). Includes `fromJson`, `toJson`, and immutable `copyWith`. |
| `lib/models/api/profile_model.dart` | 116 | `ApiProfile`: `id`, `username`, `displayName`, `bio`, `avatarUrl`, `badges` (`List<ApiBadge>`), `twoFaEnabled`, `spamBlock`, `createdAt`. |
| `lib/models/api/badge_model.dart` | 32 | `ApiBadge`: `id`, `name`, `icon`, `color`. |

### 2.5 Router Configuration (`lib/router/app_router.dart`)
- `/main/niosgram` (via `/main/:tab` in `MainShellScreen`)
- `/niosgram/create` -> `CreatePostScreen`
- `/niosgram/post/:postId/comments` -> `PostCommentsScreen(channelId: 0, postId: postId)`
- `/profile/:username` -> `PublicProfileScreen(username: username)`

---

## 3. Architecture & Data Flow Analysis

```
┌────────────────────────────────────────────────────────┐
│                   WebSocket Server                     │
│                     (wss://...)                        │
└───────────────▲────────────────────────┬───────────────┘
                │                        │ Push: "new_ng_post"
   Action Requests:                      │
   - "get_feed"                          ▼
   - "react_post"            ┌───────────────────────────┐
   - "create_post"           │   WebSocketClientProvider │
   - "delete_post"           └─────────────┬─────────────┘
   - "edit_post"                           │ pushStream
   - "follow_user"                         ▼
                             ┌───────────────────────────┐
                             │     NiosgramNotifier      │
                             │ (AsyncNotifier<NiosgramState>)
                             └─────────────┬─────────────┘
                                           │ ref.watch
                                           ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        NiosgramScreen (UI)                             │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Adaptive Centered Canvas (720-800dp on Web/Desktop, 100% Mobile) │  │
│  │ ┌──────────────────────────────────────────────────────────────┐ │  │
│  │ │ PostCard (Author Header + Badges + Markdown + Media + Actions)│ │  │
│  │ └──────────────────────────────────────────────────────────────┘ │  │
│  │ ┌──────────────────────────────────────────────────────────────┐ │  │
│  │ │ Expressive FAB / Quick-Creation Bar (flutter_m3shapes)       │ │  │
│  │ └──────────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Key Architectural Patterns:
1. **Riverpod 3.x Notifier Architecture**:
   - Uses `AsyncNotifierProvider<NiosgramNotifier, NiosgramState>` with immutable state models.
   - Clean separation of business logic and UI.
   - Automatic subscription to push stream upon initialization (`build()`) and proper cleanup via `ref.onDispose()`.
2. **Optimistic UI Updates**:
   - `reactPost()` immediately updates `likesCount`, `dislikesCount`, and `myReaction` locally before awaiting WS confirmation.
   - `toggleFollow()` flips `isFollowing` across all posts by that author instantly.
   - `deletePost()` removes the post from the local list immediately.
   - `editPost()` applies the new text optimistically.
3. **Chunked Media Uploading**:
   - `CreatePostScreen` compresses images via `ImageCompressor` and uploads large binaries in streaming chunks via `chatRepositoryProvider.uploadStreamInChunks()`, obtaining an `uploadId` passed to `createPost()`.

---

## 4. Deep Component-by-Component Survey

### 4.1 Post Card (`lib/widgets/post_card.dart`)
- **Container Styling**:
  - Current: `Card(margin: EdgeInsets.zero, elevation: 0, color: scheme.surfaceContainerLow, clipBehavior: Clip.antiAlias)`
  - Gap: Uses generic card radius without distinct M3 Expressive smooth 20–24dp corners (`BorderRadius.circular(24)` or `Shapes.c9_sided_cookie`) and lacks subtle container border (`Border.all(color: scheme.outlineVariant.withValues(alpha: 0.20), width: 1)`).
- **Author Header**:
  - Current: Displays `PulseAvatar`, `displayName`, `@username`, and `formatRelativeTime(post.createdAt)`. Follow button is a plain `TextButton`.
  - Gap: Completely ignores author badges (`post.author.badges`). The verified checkmark and author role badges (e.g. Developer, Admin, Premium) defined in `badge_chip.dart` are missing from the header. Follow button should be an expressive tonal pill button (`FilledButton.tonal` / `OutlinedButton` with 20dp radius).
- **Markdown Body**:
  - Current: `MarkdownBody` with custom `MarkdownStyleSheet` and link tapping support via `url_launcher`.
  - Quality: Well-structured; matches theme typography (`bodyMedium`).
- **Post Menu (`_PostMenu`)**:
  - Current: `PopupMenuButton` with Copy, Edit, and Delete (with `showAppConfirmDialog`).
  - Quality: Conforms to app dialog conventions.

### 4.2 Media Viewport (`lib/widgets/post_card.dart` lines 211–261)
- **Dimensions & Constraints**:
  - Current: `ConstrainedBox(constraints: BoxConstraints(maxHeight: 480, minHeight: 200))` with `BoxFit.cover`.
  - Gap: Forces fixed rectangular bounds without respecting media aspect ratios (e.g., square 1:1, landscape 16:9, or portrait 4:5), causing awkward cropping.
- **Loading & Error Placeholders**:
  - Current: `SizedBox(height: 260)` with a small `AppLoadingIndicator` and grey `ColoredBox(color: scheme.surfaceContainerHighest)`.
  - Gap: Lacks smooth blur/shimmer skeleton placeholders and soft tinted vector graphics / SVG icons.
- **Video & Rich Media**:
  - Current: Only renders `CachedNetworkImage`. Does not indicate if media is a video or provide video play badges.
- **Inner Corners**:
  - Current: `ClipRRect(borderRadius: BorderRadius.circular(16))` (meets the 16dp requirement, but needs pairing with adaptive aspect ratios).

### 4.3 Action Controls & Reactions
- **Action Bar Container**:
  - Current: Horizontal bar inside `Container(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16))`.
- **Reaction Buttons**:
  - Current: Like chip, Dislike chip, Comment chip, Share chip.
  - Double-tap Heart: Plays a scale + fade heart animation in the center of the post card (`_heartController`).
  - Gap:
    - Requirements specify: **heart/like button with reactive animation, comment trigger with counter, share, and bookmark**.
    - The **Bookmark** button is entirely missing.
    - Dislike button is a legacy element and should be replaced or refined.
    - Like reaction button animation can be enhanced with M3 expressive bounce and micro-haptics (`HapticService.reaction()`).

### 4.4 Feed Loading Skeletons (`lib/screens/niosgram_screen.dart` lines 90–111)
- Current: Basic `ListView.builder` with 5 items containing raw `PulseSkeleton` shapes.
- Gap: Does not mirror the actual M3 Expressive post card structure (rounded card container, avatar circle, author line, subtitle line, full media card rectangle, and bottom action chip row). Needs a dedicated `PostCardSkeleton` widget.

### 4.5 Empty Feed State (`lib/widgets/empty_feed_widget.dart`)
- Current: Displays `M3Container(Shapes.c9_sided_cookie)` with an icon, title, description, and action button.
- Gap: Can be enriched with crisp SVG/vector illustrations and responsive centering on desktop screens.

### 4.6 Quick-Creation Bar / Expressive FAB
- Current:
  - In `niosgram_screen.dart`, there is only an AppBar `+` icon button and a scroll-to-top FAB.
  - In `main_shell_screen.dart`, the bottom navigation FAB is hidden on the NiosGram tab (`currentIndex == 0 ? _composeFab(context) : null`).
- Gap: Requirement R1 calls for a **"Polished quick-creation FAB/bar with expressive shape (`flutter_m3shapes`)"**. On desktop, a floating or anchored expressive creation bar/FAB encourages instant posting. On mobile, an expressive FAB (`M3Container` or `FloatingActionButton.extended` with `Shapes.c9_sided_cookie` styling) provides prominent access.

---

## 5. Responsive Behavior Analysis (Mobile vs Web/Desktop)

### 5.1 Current Responsive Setup
```dart
// lib/screens/main_shell_screen.dart lines 187-189
isWide
    ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: const NiosgramScreen()))
    : const NiosgramScreen(),
```

### 5.2 Critical Responsive Issues:
1. **Narrow Constraint (680dp) on Wide Displays**:
   - On 1080p, 1440p, or 4K monitors, 680dp produces excessive empty side gutters ("side voids") while compressing rich media cards.
   - Requirement R1 explicitly specifies: **"Expand NiosGram layout on wide screens/desktop to an adaptive centered 720-800dp canvas, removing awkward side voids while keeping optimal reading line lengths."**
2. **Unconstrained Standalone Screen**:
   - In `niosgram_screen.dart`, `ListView.builder` has no internal `maxWidth` clamp. If navigated to directly or embedded in a full-width parent, it expands across the entire viewport (1920dp+), resulting in stretched cards and broken typography hierarchy.
3. **Adaptive Margin & Padding Discrepancies**:
   - On mobile, `ListView.builder` uses `horizontal: 12, vertical: 6` padding.
   - On desktop, cards should have generous spacing (16–20dp vertical, 16–24dp horizontal) with centered alignment inside a `760dp` (or 720–800dp) canvas.

---

## 6. Material 3 Expressive Gap Analysis Matrix

| Feature / Area | Current State | M3 Expressive Requirement | Gap Severity |
|---|---|---|---|
| **Canvas Sizing (Desktop/Web)** | MaxWidth: 680dp in shell, unconstrained in screen | Adaptive centered **720–800dp** canvas with responsive side margins | **HIGH** |
| **Post Card Surfaces** | `Card(color: surfaceContainerLow, margin: 0)` | `surfaceContainerLow` / `surfaceContainer`, subtle `outlineVariant` border, **20–24dp smooth corners** | **HIGH** |
| **Author Header & Badges** | Plain text title & subtitle | Expressive typography, `@username` handle, relative time badge, **verified tick & `BadgeChip` integration** | **MEDIUM** |
| **Media Viewport** | Fixed height `minHeight: 200, maxHeight: 480`, `BoxFit.cover` | **Full-width aspect-ratio media viewports**, 16dp inner radius, smooth blur/shimmer skeleton, soft vector placeholder | **HIGH** |
| **Action Controls** | Like, Dislike, Comment, Share | **Heart/Like with reactive animation**, Comment with counter, Share, **Bookmark action button** | **HIGH** |
| **Quick-Creation FAB / Bar** | AppBar `+` button only; no FAB on tab | **Polished quick-creation FAB/bar** with expressive shape (`flutter_m3shapes`) | **HIGH** |
| **Shimmer & Loaders** | Plain 4-line inline skeleton | Dedicated **`PostCardSkeleton`** matching exact M3 Expressive card geometry | **MEDIUM** |
| **Empty State** | Icon in `M3Container` | Crisp **SVG/vector illustration** with expressive M3 tokens | **MEDIUM** |
| **Theme Token Compliance** | Mostly semantic, some raw TextStyles | 100% semantic tokens (`colorScheme`, `textTheme`, zero hardcoded colors) | **LOW** |

---

## 7. Actionable Implementation Blueprint

### Phase 1: Layout & Canvas Adaptation
1. **Adaptive Canvas in `main_shell_screen.dart`**:
   - Update NiosGram tab constraint from `maxWidth: 680` to `maxWidth: 780` (or `BoxConstraints(maxWidth: 780)`).
2. **Adaptive Canvas in `niosgram_screen.dart`**:
   - Wrap the feed list view in a centered `ConstrainedBox(constraints: BoxConstraints(maxWidth: 780))` with responsive padding (`context.isWide ? 20 : 12`).

### Phase 2: Post Card & Media Viewport Overhaul (`post_card.dart`)
1. **Container & Border**:
   - Wrap `PostCard` in a `Container` with `color: scheme.surfaceContainerLow`, `borderRadius: BorderRadius.circular(24)`, and `border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.20), width: 1)`.
2. **Author Header with Badges**:
   - Render `post.author.displayName` in `textTheme.titleMedium` (bold).
   - If `post.author.badges` has status badges (e.g. verified, premium, developer), render `BadgeChip(mode: BadgeDisplayMode.statusIcon)`.
   - Display `@${post.author.username}` and relative time in a subtle capsule badge or tonal label.
   - Refine Follow button as an expressive tonal pill (`FilledButton.tonal` / `OutlinedButton` with 20dp radius).
3. **Aspect-Ratio-Aware Media Viewport**:
   - Wrap media in `AspectRatio(aspectRatio: ...)` or an adaptive constrained viewport with `ClipRRect(borderRadius: BorderRadius.circular(16))`.
   - Implement smooth shimmer skeleton loader with soft tinted vector illustration for placeholder and error states.
   - Add full-screen viewer zoom and swipe-to-dismiss gesture.
4. **Action Controls**:
   - Replace legacy dislike button with **Bookmark** button.
   - Enhance heart/like button with reactive spring/bounce animation (`flutter_animate` / `AnimationController`) and haptic feedback (`HapticService.reaction()`).
   - Add comment trigger with badge counter and share trigger.

### Phase 3: Expressive Quick-Creation FAB / Bar
1. **NiosGram FAB**:
   - Implement an expressive floating action button or quick-creation dock on NiosGram screen using `M3Container(Shapes.c9_sided_cookie)` or `FloatingActionButton.extended` with `primaryContainer` tonal coloring.
2. **Main Shell Integration**:
   - Update `main_shell_screen.dart` FAB builder to present the NiosGram post creation action when tab 2 is active.

### Phase 4: Shimmers, Vector Graphics & Empty States
1. **`PostCardSkeleton`**:
   - Build a reusable `PostCardSkeleton` in `lib/widgets/pulse_skeleton.dart` and use it in `NiosgramScreen`.
2. **Empty State & Vector Graphics**:
   - Enrich `EmptyFeedWidget` with vector/SVG styling and expressive typography.

---

## 8. Verification & Test Plan

- **Static Analysis**: `flutter analyze` must report 0 issues.
- **Unit & Widget Tests**:
  - `test/widgets/post_card_test.dart`: Test post card rendering, double tap heart reaction, bookmark tap, badge display, and author info.
  - `test/screens/niosgram_screen_test.dart`: Test responsive canvas constraints (360dp mobile, 760dp tablet, 1440dp desktop), loading shimmer, empty feed, and feed list scrolling.
- **Web Build**: `flutter build web --profile` verification to ensure zero CanvasKit / Web rendering regressions.
