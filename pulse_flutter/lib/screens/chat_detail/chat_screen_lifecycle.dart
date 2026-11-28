import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/services/desktop_window_service.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/screen_security_service.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';

/// Quiet time between two screenshot notices in a secret chat.
const Duration chatScreenshotThrottle = Duration(seconds: 5);

/// The screen's `ref` / `BuildContext` side of [ChatScreenLifecycle].
///
/// A small value object, like `ChatDetailPorts`: the lifecycle keeps no
/// `Ref`, no stored `BuildContext` and no widgets, so every branch below is
/// callable from a plain test. The screen builds it in `initState` out of live
/// getters — a chat that turns secret, a destroyed provider or a locale change
/// is picked up at call time, never captured at construction.
class ChatLifecyclePorts {
  const ChatLifecyclePorts({
    required this.chatId,
    required this.isMounted,
    required this.isSecret,
    required this.chatIsSecret,
    required this.onSecretDetected,
    required this.setCanPersistOrdinaryDraft,
    required this.haptics,
    required this.markMessagesRead,
    required this.markChatAsRead,
    required this.refreshMessages,
    required this.followingLatest,
    required this.fetchChat,
    required this.upsertChat,
    required this.loadOlderPage,
    required this.onLoadOlderError,
    required this.clearInlineQuery,
    required this.scrimColor,
    required this.insertOverlay,
    required this.removeOverlay,
    required this.onInfo,
    required this.sendScreenshotNotice,
    required this.onScrollToBottom,
    required this.beforeSecureFlag,
    required this.disposeControllers,
  });

  /// The chat this screen shows; `null` when the route id does not parse.
  final int? chatId;

  /// `State.mounted`, read when a callback could still be queued.
  final bool Function() isMounted;

  /// The screen's live secret flag (it also flips from `build` listeners).
  final bool Function() isSecret;

  /// `chatByIdProvider`'s `isSecret`; `null` while metadata is unknown.
  final bool? Function() chatIsSecret;

  /// Marks the chat secret and binds the draft engine handle.
  final void Function() onSecretDetected;

  /// `_canPersistOrdinaryDraft`, the gate ordinary drafts save behind.
  final void Function(bool value) setCanPersistOrdinaryDraft;

  /// The user's haptics preference, read at call time.
  final bool Function() haptics;

  /// `chatMessagesProvider(chatId).notifier.markRead()`.
  final Future<void> Function() markMessagesRead;

  /// `chatsProvider.notifier.markChatAsRead(chatId)`.
  final void Function() markChatAsRead;

  /// `chatMessagesProvider(chatId).notifier.refresh()`.
  final Future<void> Function() refreshMessages;

  /// The message window's current "following the newest message" state.
  final bool Function() followingLatest;

  /// `chatRepositoryProvider.getChat(chatId)` for the metadata refresh.
  final Future<ApiChatSummary?> Function(int chatId) fetchChat;

  /// `chatsProvider.notifier.upsertChat(chat)`.
  final void Function(ApiChatSummary chat) upsertChat;

  /// `chatMessagesProvider(chatId).notifier.loadOlder(pageSize: 50)`.
  final Future<int> Function() loadOlderPage;

  /// Reports a failed history load (the screen decides whether it can toast).
  final void Function(Object error) onLoadOlderError;

  /// `inlineQueryProvider.notifier.clear()`; may throw once its scope is gone.
  final void Function() clearInlineQuery;

  /// `Theme.of(context).colorScheme.scrim` for the protection overlay.
  final Color Function() scrimColor;

  /// `Overlay.of(context, rootOverlay: true).insert(entry)`.
  final void Function(OverlayEntry entry) insertOverlay;

  /// `entry.remove()`.
  final void Function(OverlayEntry entry) removeOverlay;

  /// A neutral toast ("снимок экрана зафиксирован").
  final void Function(String message) onInfo;

  /// The chat message that records a screenshot in a secret chat.
  final void Function() sendScreenshotNotice;

  /// `_scrollCoordinator.scrollToBottom()`.
  final void Function() onScrollToBottom;

  /// Post-frame work that must happen *before* the secure flag is applied:
  /// newer-history bookkeeping and the draft restore.
  final void Function() beforeSecureFlag;

  /// Disposes the screen's own controllers. Called from the middle of
  /// [ChatScreenLifecycle.dispose], because the secure flag must be the very
  /// last thing the screen does.
  final void Function() disposeControllers;
}

/// Owns the chat screen's mount/teardown and app-lifecycle edges: the secure
/// flag pairing, the push "current chat" pointer, read receipts on foreground,
/// the secret-chat screenshot overlay and its 5 s throttle, the post-frame
/// refresh, and older-history paging.
///
/// A plain class with [WidgetsBindingObserver], like `ChatDraftController`: no
/// `ref`, no `BuildContext`. Behaviour carried over verbatim from
/// `_ChatDetailScreenState` — the parts a device can see but a unit test
/// cannot afford to lose:
/// * `setSecureFlag(true)` on entry, `false` **only** in [dispose] — strict
///   pairing, both calls kept even when they look redundant.
/// * `PushNotificationService.setCurrentChat(chatId)` on entry, `null` in
///   [dispose].
/// * `markRead` / `markChatAsRead` only while
///   [PushNotificationService.isForeground].
/// * `inlineQueryProvider.clear()` inside `try/catch`: the provider may already
///   be gone when the screen outlives its scope.
/// * The screenshot overlay is never created on desktop, and a second overlay
///   is never stacked on the first.
/// * Screenshot notices are throttled to one per [chatScreenshotThrottle].
class ChatScreenLifecycle with WidgetsBindingObserver {
  ChatScreenLifecycle({
    required ChatLifecyclePorts ports,
    bool Function()? isDesktop,
    DateTime Function()? now,
  }) : _ports = ports,
       _isDesktop = isDesktop ?? (() => DesktopWindowService.isDesktop),
       _now = now ?? DateTime.now;

  final ChatLifecyclePorts _ports;
  final bool Function() _isDesktop;
  final DateTime Function() _now;

  final ValueNotifier<bool> _loadingOlderNotifier = ValueNotifier<bool>(false);
  OverlayEntry? _screenshotOverlay;
  DateTime? _lastScreenshotAlertTime;
  bool _isDisposed = false;

  /// Drives the "loading older messages" indicator in the message list.
  ValueNotifier<bool> get loadingOlderNotifier => _loadingOlderNotifier;

  /// True while the secret-chat protection overlay is on screen.
  bool get hasScreenshotOverlay => _screenshotOverlay != null;

  /// Registers for app-lifecycle events and claims the push "current chat".
  ///
  /// Call once from `initState`, before the post-frame work.
  void attach() {
    WidgetsBinding.instance.addObserver(this);
    final int? id = _ports.chatId;
    if (id != null) PushNotificationService.setCurrentChat(id);
  }

  /// Post-frame work: newer-history bookkeeping, the secure flag (draft restore
  /// reads `_isSecret`, so the flag goes first), then a refresh.
  void runAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ports.isMounted()) return;
      if (_ports.chatId != null) {
        _ports.beforeSecureFlag();
        applySecureFlag();
      }
      // Same "not awaited" entry as before: the refresh only needs its own
      // `debugPrint` on failure.
      unawaited(refreshNow());
    });
  }

  /// Turns on the secure flag when the chat's metadata says secret. An
  /// ordinary chat leaves the flag alone: only `dispose()` clears it.
  void applySecureFlag() {
    if (_ports.chatId == null) return;
    final bool? isSecret = _ports.chatIsSecret();
    _ports.setCanPersistOrdinaryDraft(isSecret == false);
    if (isSecret != true) return;
    _ports.onSecretDetected();
    ScreenSecurityService.setSecureFlag(enabled: true);
  }

  /// Reloads the open window and the inbox metadata.
  ///
  /// A secret chat never asks the repository for metadata, and a locally sent
  /// message (negative id) has no server row yet. Every failure is a
  /// `debugPrint`: a background refresh must not surface an error to the user.
  Future<void> refreshNow() async {
    final int? chatId = _ports.chatId;
    if (chatId == null) return;
    try {
      await _ports.refreshMessages();
      final bool followingLatest = _ports.followingLatest();
      if ((_ports.isSecret() || followingLatest) &&
          PushNotificationService.isForeground) {
        await _ports.markMessagesRead();
        _ports.markChatAsRead();
      }
      if (_ports.isSecret() || chatId < 0) return;
      final ApiChatSummary? freshChat = await _ports.fetchChat(chatId);
      if (freshChat != null && _ports.isMounted()) {
        _ports.upsertChat(
          freshChat.copyWith(
            unreadCount: followingLatest ? 0 : freshChat.unreadCount,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to refresh: $e');
    }
  }

  /// One page of older history; the caller owns the re-entry guard.
  Future<bool> loadOlderMessages() async {
    if (_ports.chatId == null) return false;
    try {
      final int added = await _ports.loadOlderPage();
      return added > 0;
    } catch (error) {
      if (!_ports.isMounted()) return false;
      _ports.onLoadOlderError(error);
      return false;
    }
  }

  /// Scroll-triggered older-history load, guarded against overlapping pages.
  Future<void> autoLoadOlderMessages() async {
    if (_loadingOlderNotifier.value) return;
    _loadingOlderNotifier.value = true;
    try {
      await loadOlderMessages();
    } finally {
      _loadingOlderNotifier.value = false;
    }
  }

  /// Haptic tap, a foreground read receipt, then the list jump.
  void scrollToBottom() {
    if (_ports.haptics()) HapticService.tap();
    _markReadIfForeground();
    _ports.onScrollToBottom();
  }

  /// The message list reached its bottom: same read receipt as a manual jump.
  void onReachedBottom() => _markReadIfForeground();

  /// Records a screenshot in a secret chat, at most once per throttle window.
  void handleScreenshotAction() {
    if (!_ports.isMounted()) return;
    final DateTime now = _now();
    final DateTime? last = _lastScreenshotAlertTime;
    if (last != null && now.difference(last) < chatScreenshotThrottle) {
      return;
    }
    _lastScreenshotAlertTime = now;
    HapticService.confirm();
    _ports.onInfo('В секретном чате зафиксирован снимок экрана');
    _ports.sendScreenshotNotice();
  }

  /// Adds the scrim that hides the conversation in the app switcher. A second
  /// call is a no-op — two overlays would leave one behind after `resumed`.
  void showScreenshotOverlay() {
    if (_screenshotOverlay != null) return;
    _screenshotOverlay = OverlayEntry(
      builder: (_) => Container(
        color: _ports.scrimColor(),
        width: double.infinity,
        height: double.infinity,
      ),
    );
    _ports.insertOverlay(_screenshotOverlay!);
  }

  /// Removes the scrim, if one is up.
  void removeScreenshotOverlay() {
    final OverlayEntry? overlay = _screenshotOverlay;
    if (overlay == null) return;
    _ports.removeOverlay(overlay);
    _screenshotOverlay = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ports.isSecret()) {
      if (state == AppLifecycleState.resumed) unawaited(refreshNow());
      return;
    }
    if (_isDesktop()) {
      // Desktop windows are not captured the way the app switcher is; the
      // overlay would only cover the chat the user is still looking at.
      removeScreenshotOverlay();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      showScreenshotOverlay();
    } else {
      removeScreenshotOverlay();
    }
  }

  /// Tears the lifecycle down. Order is load-bearing:
  /// read receipt → push pointer → observer → overlay → controllers →
  /// inline query → secure flag off (the last act).
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    try {
      _markReadIfForeground();
    } catch (_) {
      // Reading `ref` here is not allowed once the scope is gone.
    }
    PushNotificationService.setCurrentChat(null);
    WidgetsBinding.instance.removeObserver(this);
    // Not desktop-gated: a stale overlay must not outlive the screen.
    removeScreenshotOverlay();
    _ports.disposeControllers();
    _loadingOlderNotifier.dispose();
    try {
      _ports.clearInlineQuery();
    } catch (_) {
      // The provider may already be gone when the screen outlives its scope.
    }
    if (_ports.isSecret()) {
      ScreenSecurityService.setSecureFlag(enabled: false);
    }
  }

  void _markReadIfForeground() {
    if (_ports.chatId == null) return;
    if (!PushNotificationService.isForeground) return;
    unawaited(_ports.markMessagesRead());
    _ports.markChatAsRead();
  }
}
