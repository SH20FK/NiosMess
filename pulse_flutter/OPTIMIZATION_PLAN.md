# NiosMess Performance Optimization Plan

> Generated: 2026-07-04 | Based on codebase audit

---

## 1. CRITICAL (fix first)

### 1.1 God-Classes Decomposition

**Files:** `chat_list_screen.dart` (1338 lines), `chat_detail_screen.dart` (1816 lines)

- [ ] **1.1.1** Extract `ChatListFilterBar` as `ConsumerWidget` with const constructor — watches only `chatFilterProvider`
- [ ] **1.1.2** Extract `ChatSearchField` as `ConsumerStatefulWidget` with const constructor — manages own local state for text input
- [ ] **1.1.3** Extract `ChatListHeader` — avatar row + title + action buttons
- [ ] **1.1.4** Add `const` to `ChatTile` constructors at all call sites in `chat_list_screen.dart`
- [ ] **1.1.5** Extract `ChatDetailAppBar` — title bar, typing indicator, online status
- [ ] **1.1.6** Extract `ChatDetailInputArea` — input bar + voice UI + attachment buttons
- [ ] **1.1.7** Extract `ChatDetailScrollToBottomFAB` as independent widget (used with ValueNotifier)

**Checkpoint:** Both files < 600 lines each, no single widget has > 10 methods

---

### 1.2 AnimationController Visibility Constraints

**Files:** `animated_mesh_background.dart`, `animated_background_blobs.dart`, `active_color_orb.dart`

- [ ] **1.2.1** Add `TickerMode.of(context)` check in `didChangeDependencies()` for `AnimatedMeshBackground` — stop when not active
- [ ] **1.2.2** Add same `TickerMode.of(context)` check for `AnimatedBackgroundBlobs`
- [ ] **1.2.3** Add same check for `ActiveColorOrb`
- [ ] **1.2.4** Ensure controllers are disposed properly when widget unmounts

**Checkpoint:** No animation runs when screen is off/backgrounded. GPU usage drops to 0 when app is backgrounded.

---

### 1.3 MessageBubble Allocation Reduction

**File:** `message_bubble.dart`

- [ ] **1.3.1** Declare 4 BorderRadius variants as `static const` fields:
  - `_mineRadiusPrevSame` (topLeft: 16, bottomLeft: 16, topRight: 4, bottomRight: 4)
  - `_mineRadiusNextSame` (topLeft: 16, bottomLeft: 4, topRight: 4, bottomRight: 4)
  - `_theirsRadiusPrevSame` (topRight: 16, bottomRight: 16, topLeft: 4, bottomLeft: 4)
  - `_theirsRadiusNextSame` (topRight: 16, bottomRight: 4, topLeft: 4, bottomLeft: 4)
- [ ] **1.3.2** Verify `RegExp` is `static final` (audit says already done — confirm)
- [ ] **1.3.3** Add `ValueKey('msg_${message.id}_${message.isRead}')` to `MessageBubble` call site in `chat_message_list.dart`
- [ ] **1.3.4** Extract `_MessageBubbleHeader` widget (name, avatar, badges)
- [ ] **1.3.5** Extract `_MessageBubbleContent` widget (text, media, forwarded label)
- [ ] **1.3.6** Extract `_MessageBubbleFooter` widget (time, double-tick)

**Checkpoint:** MessageBubble.build() has no inline BorderRadius, no inline RegExp, key enables skip-rebuild

---

### 1.4 ChatDetailScreen Scroll setState → ValueNotifier

**File:** `chat_detail_screen.dart`

- [ ] **1.4.1** Declare `final ValueNotifier<bool> _showScrollToBottomNotifier = ValueNotifier<bool>(false);`
- [ ] **1.4.2** Replace `setState(() => _showScrollToBottom = shouldShow)` in `_onScroll()` with `_showScrollToBottomNotifier.value = shouldShow`
- [ ] **1.4.3** Wrap FAB section in `ValueListenableBuilder<bool>(valueListenable: _showScrollToBottomNotifier, builder: ...)`
- [ ] **1.4.4** Remove `_showScrollToBottom` bool field entirely

**Checkpoint:** Scrolling past 300px only rebuilds the FAB widget, not the entire 1816-line screen

---

### 1.5 EncryptedMessageCache — AES in Isolate

**File:** `encrypted_message_cache.dart`

- [ ] **1.5.1** Move `saveMessages()` encrypt logic into `Isolate.run()` (or `compute()`)
- [ ] **1.5.2** Move `getMessages()` decrypt logic into `Isolate.run()`
- [ ] **1.5.3** Pass only serializable data (chatId, json string, key bytes) to isolate — not SecretKey objects directly

**Checkpoint:** Main isolate thread time for encrypt/decrypt < 1ms; AES runs in separate isolate

---

### 1.6 WebSocket Dispatcher — Single Listener

**File:** `backend_chat_provider.dart`

- [ ] **1.6.1** Create `webSocketDispatcherProvider` — single `ref.read(webSocketClientProvider).pushStream.listen()` that routes by `chat_id`
- [ ] **1.6.2** Remove individual `pushStream.listen()` from `ChatMessagesNotifier.build()`
- [ ] **1.6.3** Add `handlePush(Map<String, dynamic> event)` method to `ChatMessagesNotifier` that the dispatcher calls
- [ ] **1.6.4** Ensure auto-dispose: when no one watches `chatMessagesProvider(chatId)`, listener is removed

**Checkpoint:** Only 1 subscription to pushStream regardless of open chats. O(1) per incoming message.

---

### 1.7 ChatMessageList — O(n) Layout Precomputation

**File:** `chat_message_list.dart`

- [ ] **1.7.1** Create `_MessageLayoutData` class with `showDateSep`, `isPrevSame`, `isNextSame`
- [ ] **1.7.2** Create `_precomputeLayout(List<ApiMessage> messages)` — single-pass O(n) algorithm
- [ ] **1.7.3** Cache result in state, invalidate only when message list changes (not on scroll)
- [ ] **1.7.4** Use precomputed data in `itemBuilder` instead of inline checks

**Checkpoint:** Layout computation is O(n) total, not O(n) per visible item. Scroll performance improves with 500+ messages.

---

## 2. MEDIUM (fix second)

### 2.1 RepaintBoundary Coverage

- [ ] **2.1.1** Wrap `ChatTile` in `RepaintBoundary` at all call sites in `chat_list_screen.dart`
- [ ] **2.1.2** Wrap `FloatingActionButton` (scroll-to-bottom) in `RepaintBoundary` in `chat_detail_screen.dart`
- [ ] **2.1.3** Wrap `ChatInputBar` in `RepaintBoundary` in `chat_detail_screen.dart`
- [ ] **2.1.4** Wrap `BottomNavigationBar` / `AppBottomNav` in `RepaintBoundary` in `main_shell_screen.dart`

**Checkpoint:** Each list item and static bar repaints independently

---

### 2.2 flutter_animate — Limit Animated Tiles

**File:** `chat_list_screen.dart`

- [ ] **2.2.1** After `_isInitialLoaded` is true, skip `.animate()` chain entirely (return bare `RepaintBoundary(child: item)`)
- [ ] **2.2.2** During initial load, limit animated items to first 6 only (already has delay guard — extend to skip `.animate()` for index >= 6)

**Checkpoint:** No new AnimationControllers created after initial load animation completes

---

### 2.3 MediaQuery.sizeOf → LayoutBuilder

**Files:** `chat_list_screen.dart`, `chat_detail_screen.dart`, `message_bubble.dart`

- [ ] **2.3.1** Replace `MediaQuery.sizeOf(context).width >= 760` in `chat_list_screen.dart` (lines 321, 416) with `LayoutBuilder`
- [ ] **2.3.2** Replace same pattern in `chat_detail_screen.dart`
- [ ] **2.3.3** Replace `MediaQuery.sizeOf` in `message_bubble.dart` for maxWidth calculation

**Checkpoint:** No implicit MediaQuery dependency for layout decisions — rebuilds only on actual constraint changes

---

### 2.4 ActiveColorOrb — Precompute in initState

**File:** `active_color_orb.dart`

- [ ] **2.4.1** Move `ColorScheme.fromSeed()` call into `initState()` — compute once, store in `_seedPrimary` field
- [ ] **2.4.2** Remove runtime cache logic (`_cachedSeedPrimary`, `_cachedSeedColor`, `_cachedBrightness`)

**Checkpoint:** `ColorScheme.fromSeed` called 0 times during build; only at widget creation

---

### 2.5 AsyncNotifier — Clean build() Pattern

**File:** `backend_chat_provider.dart`

- [ ] **2.5.1** Refactor `ChatListNotifier.build()` to not mutate `state` before returning — use `AsyncValue.guard(_fetch)`
- [ ] **2.5.2** Load cached data inside the async flow, not as side-effect

**Checkpoint:** `build()` returns a Future without synchronous state mutation

---

### 2.6 Blob — Replace StatelessWidget with CustomPainter

**File:** `animated_mesh_background.dart`

- [ ] **2.6.1** Replace `_Blob` StatelessWidget with `_BlobPainter extends CustomPainter`
- [ ] **2.6.2** Use `RepaintBoundary` + single `CustomPaint` with list of painters (one per blob)
- [ ] **2.6.3** Remove `MediaQuery.sizeOf` from blob rendering — use canvas size

**Checkpoint:** 60fps animation uses 1 widget rebuild + canvas draw calls, not N widget rebuilds

---

### 2.7 PulseApp — Selective watch on UiSettingsState

**File:** `main.dart`

- [ ] **2.7.1** Replace `ref.watch(uiSettingsProvider)` with individual `.select()` calls:
  - `ref.watch(uiSettingsProvider.select((s) => s.themeMode))`
  - `ref.watch(uiSettingsProvider.select((s) => s.seedColor))`
  - `ref.watch(uiSettingsProvider.select((s) => s.locale))`
  - etc. — only the 3-4 fields actually used in `PulseApp.build()`
- [ ] **2.7.2** Verify sound/background fields do NOT trigger `PulseApp` rebuild

**Checkpoint:** Changing soundVolume does not rebuild MaterialApp.router

---

### 2.8 CachedNetworkImage for Avatars

**File:** `chat_message_list.dart`

- [ ] **2.8.1** Add `cached_network_image` to `pubspec.yaml` (if not already present)
- [ ] **2.8.2** Replace `NetworkImage(message.senderAvatarUrl!)` with `CachedNetworkImage` in avatar rendering
- [ ] **2.8.3** Add placeholder `CircleAvatar` with person icon
- [ ] **2.8.4** Set `memCacheWidth: 56` for memory efficiency

**Checkpoint:** Avatars are cached in memory/disk; scrolling does not re-fetch

---

### 2.9 AppTheme — LRU Cache

**File:** `app_theme.dart`

- [ ] **2.9.1** Replace `_themeCache` (Map) with `LinkedHashMap<int, ThemeData>` in LRU mode
- [ ] **2.9.2** On insert: `_themeCache[cacheKey] = theme`
- [ ] **2.9.3** On overflow (> 20): `_themeCache.remove(_themeCache.keys.first)` — evict oldest

**Checkpoint:** No full cache clear; smooth cache rotation without memory spike

---

### 2.10 GoRouter — Simplify Transition

**File:** `app_router.dart`

- [ ] **2.10.1** Remove secondary `SlideTransition` + `FadeTransition` layers — keep only primary animation
- [ ] **2.10.2** Result: single `SlideTransition` wrapping `FadeTransition` wrapping `child`

**Checkpoint:** Page transitions use 2 animated layers instead of 4

---

## 3. ENHANCEMENTS (improve further)

### 3.1 PerformanceOverlay in Debug

- [ ] **3.1.1** Add `showPerformanceOverlay: kDebugMode` to `MaterialApp.router` in `main.dart`

---

### 3.2 const-Constructors Pass

- [ ] **3.2.1** Run `dart fix --apply` across the codebase to add missing `const`
- [ ] **3.2.2** Manually add `const` to: `SizedBox.shrink()`, `EdgeInsets.*`, `BorderRadius.*`, `Duration(...)`, `Icon(...)` with constant data, `Text(...)` with constant strings
- [ ] **3.2.3** Verify no const regressions (tests or analyze pass)

---

### 3.3 ListView.builder Optimization

- [ ] **3.3.1** Add `addAutomaticKeepAlives: false` to `ListView.builder` in `chat_message_list.dart`
- [ ] **3.3.2** Add `addSemanticIndexes: false` if screen reader not needed for chat messages
- [ ] **3.3.3** Same for `chat_list_screen.dart` ListView.builder

---

### 3.4 MessageBubble Key

- [ ] **3.4.1** Add `ValueKey('msg_${message.id}_${message.isRead}')` to `MessageBubble` in `chat_message_list.dart`

---

### 3.5 BackdropFilter Blur Optimization

- [ ] **3.5.1** In `chat_list_screen.dart`, reduce `ImageFilter.blur` sigma from 10 to 4 when `optimizeForWeakDevices` is true
- [ ] **3.5.2** Apply same optimization to any other `BackdropFilter` usage in the codebase

---

## Execution Order

```
Phase 1: CRITICAL (1.1–1.7)     ~2-3 hours
Phase 2: MEDIUM   (2.1–2.10)    ~1-2 hours
Phase 3: ENHANCE  (3.1–3.5)     ~30 minutes
```

## Verification Checklist

After each phase:
- [ ] `flutter analyze` — no new warnings
- [ ] `flutter build apk --debug` — builds successfully
- [ ] Manual test on device — no visual regressions
- [ ] Check DevTools Performance tab — frame time < 16ms consistently
