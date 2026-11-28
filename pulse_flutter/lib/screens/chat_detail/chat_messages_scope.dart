import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_empty_state.dart';
import 'package:pulse_flutter/widgets/chat/chat_message_list.dart';
import 'package:pulse_flutter/widgets/chat/chat_scroll_coordinator.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';

/// Isolated message-list scope: watches the history, auth and chat metadata,
/// and receives every callback as a parameter (the screen owns the controllers).
class ChatMessagesScope extends ConsumerWidget {
  const ChatMessagesScope({
    super.key,
    required this.chatId,
    this.highlightMessageId,
    required this.scrollCoordinator,
    required this.inputFocusNode,
    required this.bottomInset,
    required this.onOpenComments,
    required this.onReactionTap,
    required this.onOpenMedia,
    required this.onLongPressMedia,
    required this.onLongPress,
    required this.onSwipeToReply,
    required this.displayTextBuilder,
    required this.mediaUrlBuilder,
    required this.isImageMediaBuilder,
    required this.mediaLabelBuilder,
    required this.replyPreviewBuilder,
    required this.dateSeparatorBuilder,
  });

  final int chatId;
  final int? highlightMessageId;
  final ChatScrollCoordinator scrollCoordinator;
  final FocusNode inputFocusNode;
  final ValueListenable<double> bottomInset;
  final void Function(ApiMessage) onOpenComments;
  final void Function(ApiMessage, String) onReactionTap;
  final void Function(ApiMessage) onOpenMedia;
  final void Function(ApiMessage, bool isMine, bool amAdminOrOwner)
  onLongPressMedia;
  final void Function(
    ApiMessage,
    bool isMine,
    bool isChannel,
    bool amAdminOrOwner,
  )
  onLongPress;
  final void Function(ApiMessage) onSwipeToReply;
  final String Function(ApiMessage) displayTextBuilder;
  final String? Function(ApiMessage) mediaUrlBuilder;
  final bool Function(ApiMessage, String url) isImageMediaBuilder;
  final String? Function(ApiMessage, String url) mediaLabelBuilder;
  final String? Function(ApiMessage, Map<int, ApiMessage> byId)
  replyPreviewBuilder;
  final Widget Function(DateTime date, DateTime now) dateSeparatorBuilder;

  /// Resends a failed row: secret engine first, then an upload task, then a
  /// plain text send that keeps the local id until the replacement lands.
  Future<void> _retrySend(WidgetRef ref, ApiMessage message) async {
    if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();

    final secret = ref.read(secretChatCoordinatorProvider).value;
    if (secret?.engine.findChat(chatId) != null) {
      await secret!.engine.retry(chatId, message.id);
      return;
    }
    final String localId = message.id.toString();
    final Map<String, UploadTask> uploadTasks = ref.read(uploadQueueProvider);
    if (uploadTasks.containsKey(localId)) {
      // It was an upload task (media/voice/circle/document).
      // Mark local message as sending again and trigger upload retry.
      ref
          .read(chatMessagesProvider(chatId).notifier)
          .markLocalMessageSending(message.id);
      ref.read(uploadQueueProvider.notifier).retry(localId);
      return;
    }

    // Keep the only durable original until its replacement is acknowledged.
    await ref
        .read(chatMessagesProvider(chatId).notifier)
        .send(message.content, replyToId: message.replyToId, localId: localId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ChatHistoryWindowState>(chatHistoryWindowProvider(chatId), (
      previous,
      next,
    ) {
      scrollCoordinator.setHasNewerHistory(next.hasNewer);
      final incoming =
          next.incomingRevision -
          (previous?.incomingRevision ?? next.incomingRevision);
      if (incoming > 0) scrollCoordinator.onIncomingMessages(incoming);
    });
    final window = ref.watch(chatHistoryWindowProvider(chatId));

    final AsyncValue<List<ApiMessage>> messagesAsync = ref.watch(
      chatMessagesProvider(chatId),
    );
    final int myUserId = ref.watch(
      authProvider.select((a) => a.session?.userId ?? -1),
    );
    final (bool isChannel, bool isGroup, bool isSecret) = ref.watch(
      chatByIdProvider(chatId).select(
        (c) => (
          c?.chatType == 'channel',
          c?.chatType == 'group',
          c?.isSecret == true,
        ),
      ),
    );
    final String myRole = ref.watch(myChatRoleProvider(chatId));
    final bool amAdminOrOwner = myRole == 'admin' || myRole == 'owner';

    return messagesAsync.when(
      data: (List<ApiMessage> messages) {
        if (messages.isEmpty) {
          if (isSecret) {
            return ChatEmptyState.secret(
              title: context.l10n.secretChatTitle,
              description: context.l10n.secretChatDesc,
              actionLabel: context.l10n.chatSendFirst,
              onAction: () => inputFocusNode.requestFocus(),
            );
          }

          return ChatEmptyState.empty(
            title: context.l10n.chatNoMessages,
            description: context.l10n.chatSendFirst,
            actionLabel: context.l10n.chatSendFirst,
            onAction: () => inputFocusNode.requestFocus(),
          );
        }

        return ChatMessageList(
          messages: messages,
          scrollController: scrollCoordinator.scrollController,
          followingLatest: window.followingLatest,
          highlightMessageId: highlightMessageId,
          initialScrollAnchor: ref
              .read(chatMessagesProvider(chatId).notifier)
              .scrollAnchor,
          canSaveScrollAnchor: () => !scrollCoordinator.isJumping,
          onScrollAnchorChanged: ref
              .read(chatMessagesProvider(chatId).notifier)
              .saveScrollAnchor,
          onRequestMessage: (id) =>
              ref.read(chatMessagesProvider(chatId).notifier).loadAround(id),
          authUserId: myUserId,
          amAdminOrOwner: amAdminOrOwner,
          isChannel: isChannel,
          isGroup: isGroup,
          bottomPadding: bottomInset,
          topPadding: 48.0,
          onOpenComments: onOpenComments,
          onReactionTap: onReactionTap,
          onOpenMedia: onOpenMedia,
          onLongPressMedia: onLongPressMedia,
          onLongPress: onLongPress,
          onSwipeToReply: onSwipeToReply,
          onCallbackQuery: (ApiMessage message, String data) {
            return ref
                .read(chatMessagesProvider(chatId).notifier)
                .sendCallbackQuery(message.id, data);
          },
          onRetrySend: (ApiMessage message) => _retrySend(ref, message),
          displayTextBuilder: displayTextBuilder,
          mediaUrlBuilder: mediaUrlBuilder,
          isImageMediaBuilder: isImageMediaBuilder,
          mediaLabelBuilder: mediaLabelBuilder,
          replyPreviewBuilder: replyPreviewBuilder,
          dateSeparatorBuilder: dateSeparatorBuilder,
          animatedMessageBuilder:
              ({
                required int messageId,
                required bool animate,
                required int staggerIndex,
                required bool isMine,
                required Widget child,
              }) {
                return _AnimatedMessage(
                  key: ValueKey<int>(messageId),
                  animate: animate,
                  staggerIndex: staggerIndex,
                  isMine: isMine,
                  child: child,
                );
              },
        );
      },
      loading: () => const MessageListSkeleton(),
      error: (Object error, StackTrace trace) {
        return ChatEmptyState.error(
          title: context.l10n.chatConnecting,
          description: context.l10n.chatReconnecting,
          actionLabel: context.l10n.refreshAction,
          onAction: () => ref.invalidate(chatMessagesProvider(chatId)),
        );
      },
    );
  }
}

// ── Animated message entrance widget ────────────────────────────────────────
class _AnimatedMessage extends StatefulWidget {
  const _AnimatedMessage({
    super.key,
    required this.animate,
    required this.isMine,
    required this.child,
    this.staggerIndex = 0,
  });

  final bool animate;
  final bool isMine;
  final Widget child;

  /// Place in a batch of messages that arrived together; delays the entrance.
  final int staggerIndex;

  @override
  State<_AnimatedMessage> createState() => _AnimatedMessageState();
}

class _AnimatedMessageState extends State<_AnimatedMessage>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fade;
  Animation<double>? _scale;
  Animation<double>? _slideY;
  Timer? _staggerTimer;

  static const Duration _staggerStep = Duration(milliseconds: 40);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      final ctrl = AnimationController(
        vsync: this,
        duration: M3Durations.spatialFast,
      );
      _controller = ctrl;
      // Position and scale ride the spatial spring; opacity stays on an
      // effects curve so it never overshoots.
      _fade = ctrl.drive(
        CurveTween(
          curve: const Interval(0.0, 0.5, curve: M3SpringCurves.effectsDefault),
        ),
      );
      _scale = ctrl.drive(
        Tween<double>(
          begin: 0.94,
          end: 1.0,
        ).chain(CurveTween(curve: M3SpringCurves.spatialFast)),
      );
      _slideY = ctrl.drive(
        Tween<double>(
          begin: 16.0,
          end: 0.0,
        ).chain(CurveTween(curve: M3SpringCurves.spatialFast)),
      );
      final int stagger = widget.staggerIndex;
      if (stagger > 0) {
        // Until its turn the row stays at the start of the entrance.
        _staggerTimer = Timer(_staggerStep * stagger, () {
          if (mounted) ctrl.forward();
        });
      } else {
        ctrl.forward();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) _controller?.value = 1.0;
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keyed on the controller, not on `animate`: the list stops asking for
    // the entrance one frame after it starts, and it must still play out.
    if (_controller == null) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fade!,
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (BuildContext context, Widget? child) {
          return Transform.translate(
            offset: Offset(0, _slideY!.value),
            child: Transform.scale(
              scale: _scale!.value,
              alignment: widget.isMine
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
