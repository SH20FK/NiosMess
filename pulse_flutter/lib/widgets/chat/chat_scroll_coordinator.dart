import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_fab.dart';

/// Coordinator that isolates scroll metrics, jump-to-bottom FAB visibility,
/// pagination triggers, and unread message counter while scrolled up, decoupling
/// scroll listener notifications from the root chat screen build pass.
class ChatScrollCoordinator {
  ChatScrollCoordinator({
    ScrollController? controller,
    this.onNearTop,
    this.onReachedBottom,
    this.onNearBottom,
    this.onJumpToLatest,
    this.onFollowLatestChanged,
  }) : scrollController = controller ?? ScrollController() {
    scrollController.addListener(_handleScroll);
  }

  final ScrollController scrollController;
  final VoidCallback? onNearTop;
  final VoidCallback? onReachedBottom;
  final VoidCallback? onNearBottom;
  final Future<void> Function()? onJumpToLatest;
  final ValueChanged<bool>? onFollowLatestChanged;
  bool _hasNewerHistory = false;
  bool _jumping = false;
  bool _disposed = false;

  void setHasNewerHistory(bool value) {
    _hasNewerHistory = value;
    _handleScroll();
  }

  final ValueNotifier<bool> showScrollToBottomNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<int> unreadWhileScrolledNotifier = ValueNotifier<int>(0);

  void _handleScroll() {
    if (!scrollController.hasClients) return;
    final double offset =
        scrollController.offset - scrollController.position.minScrollExtent;
    final double maxExtent = scrollController.position.maxScrollExtent;

    final bool shouldShow = _hasNewerHistory || offset > 300;
    if (shouldShow != showScrollToBottomNotifier.value) {
      showScrollToBottomNotifier.value = shouldShow;
    }

    onFollowLatestChanged?.call(offset <= 60 && !_hasNewerHistory);
    if (!_jumping && _hasNewerHistory && offset < 400) onNearBottom?.call();
    if (offset <= 60 &&
        !_hasNewerHistory &&
        unreadWhileScrolledNotifier.value != 0) {
      unreadWhileScrolledNotifier.value = 0;
      onReachedBottom?.call();
    }

    // Auto-load older messages when near the end of the reversed scrollable
    if (!_jumping && scrollController.offset > maxExtent - 400) {
      onNearTop?.call();
    }
  }

  /// Increments unread counter when new incoming messages arrive while user is scrolled up.
  void onIncomingMessages(int count) {
    if (showScrollToBottomNotifier.value && count > 0) {
      unreadWhileScrolledNotifier.value += count;
    }
  }

  /// Smoothly scrolls down to the newest message.
  Future<void> scrollToBottom({bool animate = true}) async {
    if (_disposed || _jumping) return;
    _jumping = true;
    try {
      await onJumpToLatest?.call();
      if (_disposed) return;
      WidgetsBinding.instance.ensureVisualUpdate();
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed || !scrollController.hasClients) return;
      unreadWhileScrolledNotifier.value = 0;
      final target = scrollController.position.minScrollExtent;
      if (!animate) {
        scrollController.jumpTo(target);
        return;
      }
      await scrollController.animateTo(
        target,
        duration: M3Durations.medium2,
        curve: M3SpringCurves.expressiveDecel,
      );
    } finally {
      _jumping = false;
    }
  }

  /// Builds the isolated reactive FAB widget.
  Widget buildFab({required int chatId}) {
    return ValueListenableBuilder<bool>(
      valueListenable: showScrollToBottomNotifier,
      builder: (BuildContext context, bool showScroll, Widget? _) {
        return ValueListenableBuilder<int>(
          valueListenable: unreadWhileScrolledNotifier,
          builder: (BuildContext context, int unreadCount, Widget? _) {
            return ChatDetailScrollToBottomFAB(
              show: showScroll,
              chatId: chatId,
              unreadCount: unreadCount,
              onPressed: () => scrollToBottom(animate: true),
            );
          },
        );
      },
    );
  }

  void dispose() {
    _disposed = true;
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    showScrollToBottomNotifier.dispose();
    unreadWhileScrolledNotifier.dispose();
  }
}
