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
  }) : scrollController = controller ?? ScrollController() {
    scrollController.addListener(_handleScroll);
  }

  final ScrollController scrollController;
  final VoidCallback? onNearTop;
  final VoidCallback? onReachedBottom;

  final ValueNotifier<bool> showScrollToBottomNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> unreadWhileScrolledNotifier = ValueNotifier<int>(0);

  void _handleScroll() {
    if (!scrollController.hasClients) return;
    final double offset = scrollController.offset;
    final double maxExtent = scrollController.position.maxScrollExtent;

    final bool shouldShow = offset > 300;
    if (shouldShow != showScrollToBottomNotifier.value) {
      showScrollToBottomNotifier.value = shouldShow;
    }

    if (offset <= 60 && unreadWhileScrolledNotifier.value != 0) {
      unreadWhileScrolledNotifier.value = 0;
      onReachedBottom?.call();
    }

    // Auto-load older messages when near the end of the reversed scrollable
    if (offset > maxExtent - 400) {
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
  void scrollToBottom({bool animate = true}) {
    if (!scrollController.hasClients) return;
    unreadWhileScrolledNotifier.value = 0;

    if (!animate) {
      scrollController.jumpTo(0.0);
      return;
    }

    scrollController.animateTo(
      0.0,
      duration: M3Durations.medium2,
      curve: M3SpringCurves.expressiveDecel,
    );
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
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    showScrollToBottomNotifier.dispose();
    unreadWhileScrolledNotifier.dispose();
  }
}
