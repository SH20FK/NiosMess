import 'package:pulse_flutter/models/interactive_message.dart';
import 'dart:async';
import 'package:pulse_flutter/widgets/chat/ordinary_encryption_settings_button.dart';
import 'package:pulse_flutter/core/storage/chat_history_anchor.dart';
import 'package:pulse_flutter/widgets/chat/message_layout_store.dart';
export 'package:pulse_flutter/widgets/chat/message_layout_store.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/widgets/chat/sticker_set_details_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class ChatMessageList extends ConsumerStatefulWidget {
  const ChatMessageList({
    required this.messages,
    required this.scrollController,
    required this.authUserId,
    required this.amAdminOrOwner,
    required this.isChannel,
    this.isGroup = false,
    this.followingLatest = true,
    this.onRequestMessage,
    this.highlightMessageId,
    this.initialScrollAnchor,
    this.onScrollAnchorChanged,
    this.canSaveScrollAnchor,
    this.bottomPadding = 56.0,
    this.topPadding = 48.0,
    this.onOpenComments,
    this.onReactionTap,
    required this.onOpenMedia,
    required this.onLongPressMedia,
    required this.onLongPress,
    required this.onSwipeToReply,
    required this.onCallbackQuery,
    required this.onRetrySend,
    required this.displayTextBuilder,
    required this.mediaUrlBuilder,
    required this.isImageMediaBuilder,
    required this.mediaLabelBuilder,
    required this.replyPreviewBuilder,
    required this.dateSeparatorBuilder,
    required this.animatedMessageBuilder,
    super.key,
  });

  final List<ApiMessage> messages;
  final ScrollController scrollController;
  final int authUserId;
  final bool amAdminOrOwner;
  final bool isChannel;
  final bool isGroup;
  final bool followingLatest;
  final Future<bool> Function(int)? onRequestMessage;
  final int? highlightMessageId;
  final ChatHistoryAnchor? initialScrollAnchor;
  final ValueChanged<ChatHistoryAnchor>? onScrollAnchorChanged;
  final bool Function()? canSaveScrollAnchor;
  final double bottomPadding;
  final double topPadding;
  final void Function(ApiMessage message, String emoji)? onReactionTap;
  final void Function(ApiMessage)? onOpenComments;
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
  final void Function(ApiMessage, String data) onCallbackQuery;
  final void Function(ApiMessage) onRetrySend;
  final String Function(ApiMessage) displayTextBuilder;
  final String? Function(ApiMessage) mediaUrlBuilder;
  final bool Function(ApiMessage, String url) isImageMediaBuilder;
  final String? Function(ApiMessage, String url) mediaLabelBuilder;
  final String? Function(ApiMessage, Map<int, ApiMessage> byId)
  replyPreviewBuilder;
  final Widget Function(DateTime date, DateTime now) dateSeparatorBuilder;
  final Widget Function({
    required int messageId,
    required bool animate,
    required bool isMine,
    required Widget child,
  })
  animatedMessageBuilder;

  @override
  ConsumerState<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends ConsumerState<ChatMessageList>
    with WidgetsBindingObserver {
  late final AdaptivePerformanceNotifier _performance;
  final Map<int, _HistoryAnchorBox> _anchors = {};
  Map<int, int> _rowIds = {};
  Map<(int, String), int> _clientRowIds = {};
  Map<int, int> _rowIndexes = {};
  // Keep fallback keys exact on both native Dart and JavaScript targets.
  int _collisionId = -1;

  void _syncRowIds(List<ApiMessage> messages) {
    final next = <int, int>{};
    final clients = <(int, String), int>{};
    final indexes = <int, int>{};
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final client = message.clientMessageId;
      final operation = client == null || client.isEmpty
          ? null
          : (message.senderId, client);
      var rowId =
          _rowIds[message.id] ??
          (operation == null ? null : _clientRowIds[operation]) ??
          message.id;
      if (indexes.containsKey(rowId)) {
        rowId = message.id;
        while (indexes.containsKey(rowId)) {
          rowId = _collisionId--;
        }
      }
      next[message.id] = rowId;
      indexes[rowId] = i;
      if (operation != null) clients.putIfAbsent(operation, () => rowId);
    }
    _rowIds = next;
    _clientRowIds = clients;
    _rowIndexes = indexes;
  }

  int _rowId(ApiMessage message) => _rowIds[message.id] ?? message.id;
  final Key _centerSliverKey = UniqueKey();
  int? _centerMessageId;
  double? _anchorFraction;

  Timer? _anchorCaptureTimer;
  ChatHistoryAnchor? _lastMeasuredAnchor;
  ChatHistoryAnchor? _lastPublishedAnchor;
  bool _explicitTarget = false;
  bool _restoringAnchor = false;
  double? _measuredViewportHeight;

  ChatHistoryAnchor? _measureScrollAnchor() {
    final scroll = widget.scrollController;
    final viewport = context.findRenderObject();
    if (!scroll.hasClients ||
        viewport is! RenderBox ||
        !viewport.attached ||
        !viewport.hasSize) {
      return null;
    }
    _measuredViewportHeight = viewport.size.height;
    final latest =
        widget.followingLatest &&
        scroll.position.pixels - scroll.position.minScrollExtent <= 60;
    if (latest && _store.messages.isNotEmpty) {
      return ChatHistoryAnchor(
        messageId: _store.messages.last.id,
        fraction: 0,
        followingLatest: true,
      );
    }
    final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    _HistoryAnchorBox? chosen;
    double? closest;
    for (final row in _anchors.values) {
      if (!row.attached || !row.hasSize) continue;
      final rect = row.localToGlobal(Offset.zero) & row.size;
      if (rect.bottom <= bounds.top ||
          rect.top >= bounds.bottom - widget.bottomPadding) {
        continue;
      }
      final distance = (rect.top - bounds.top).abs();
      if (closest == null || distance < closest) {
        closest = distance;
        chosen = row;
      }
    }
    if (chosen == null || bounds.height <= 0) return null;
    final bottom = chosen.localToGlobal(Offset.zero).dy + chosen.size.height;
    return ChatHistoryAnchor(
      messageId: chosen.messageId,
      fraction: (bounds.bottom - bottom) / bounds.height,
    );
  }

  void _captureScrollAnchor({bool explicit = false}) {
    if (widget.onScrollAnchorChanged == null) return;
    if (_restoringAnchor ||
        (!explicit && _explicitTarget) ||
        widget.canSaveScrollAnchor?.call() == false) {
      return;
    }
    final anchor = _measureScrollAnchor();
    if (anchor == null) return;
    _lastMeasuredAnchor = anchor;
    if (anchor == _lastPublishedAnchor) return;
    _lastPublishedAnchor = anchor;
    widget.onScrollAnchorChanged?.call(anchor);
  }

  void _publishLastMeasuredAnchor() {
    final anchor = _lastMeasuredAnchor;
    if (anchor == null ||
        _restoringAnchor ||
        _explicitTarget ||
        widget.canSaveScrollAnchor?.call() == false ||
        anchor == _lastPublishedAnchor) {
      return;
    }
    _lastPublishedAnchor = anchor;
    widget.onScrollAnchorChanged?.call(anchor);
  }

  void _trackScrollGeometry(double? delta) {
    final anchor = _lastMeasuredAnchor;
    final height = _measuredViewportHeight;
    if (anchor == null ||
        delta == null ||
        height == null ||
        height <= 0 ||
        _restoringAnchor ||
        _explicitTarget ||
        widget.canSaveScrollAnchor?.call() == false) {
      return;
    }
    // Reversed scrolling translates every retained row by the exact same delta.
    // Keep close/background snapshots current without measuring rows per frame.
    final fraction = anchor.followingLatest
        ? widget.bottomPadding / height
        : anchor.fraction;
    _lastMeasuredAnchor = ChatHistoryAnchor(
      messageId: anchor.messageId,
      fraction: fraction - delta / height,
    );
  }

  void _scheduleAnchorCapture() {
    if (widget.onScrollAnchorChanged == null) return;
    _anchorCaptureTimer ??= Timer(const Duration(milliseconds: 180), () {
      _anchorCaptureTimer = null;
      if (mounted) _captureScrollAnchor();
    });
  }

  @override
  void deactivate() {
    _captureScrollAnchor();
    _publishLastMeasuredAnchor();
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _captureScrollAnchor();
    }
  }

  void _rebaseAnchor(List<ApiMessage> next) {
    if (next.isEmpty) return;
    final scroll = widget.scrollController;
    if (!scroll.hasClients) {
      _centerMessageId = next.last.id;
      return;
    }
    final position = scroll.position;
    final atBottom = position.pixels - position.minScrollExtent <= 60;
    final viewport = context.findRenderObject();
    if (widget.followingLatest && atBottom) {
      _centerMessageId = next.last.id;
      _anchorFraction = null;
    } else if (viewport is RenderBox && viewport.hasSize) {
      final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
      final ids = next.map((m) => m.id).toSet();
      _HistoryAnchorBox? chosen;
      double? best;
      for (final row in _anchors.values) {
        if (!ids.contains(row.messageId) || !row.attached || !row.hasSize) {
          continue;
        }
        final rect = row.localToGlobal(Offset.zero) & row.size;
        if (rect.bottom <= bounds.top ||
            rect.top >= bounds.bottom - widget.bottomPadding) {
          continue;
        }
        final distance = (rect.top - bounds.top).abs();
        if (best == null || distance < best) {
          best = distance;
          chosen = row;
        }
      }
      if (chosen != null) {
        final bottom =
            chosen.localToGlobal(Offset.zero).dy + chosen.size.height;
        _centerMessageId = chosen.messageId;
        _anchorFraction = ((bounds.bottom - bottom) / bounds.height).clamp(
          0.0,
          1.0,
        );
      } else {
        _centerMessageId = next.last.id;
        _anchorFraction = null;
      }
    }
    // Rebase the coordinate system before layout. Unlike jumpTo, correctBy lets
    // ScrollPosition rebase its current ballistic activity with the new bounds.
    position.correctBy(-position.pixels);
  }

  final MessageLayoutStore _store = MessageLayoutStore();
  GlobalKey? _activeTargetKey;
  int? _activeTargetMessageId;
  final Set<int> _animatedMessageIds = <int>{};
  Timer? _highlightTimer;
  Timer? _scrollIdleTimer;
  final Stopwatch _scrollClock = Stopwatch()..start();
  Duration? _previousScrollTime;
  bool _fastScrolling = false;

  void _setFastScrolling(bool value) {
    if (_fastScrolling == value) return;
    _fastScrolling = value;
    AnimatedMediaControllerPool.instance.setFastScrolling(value, source: this);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollUpdateNotification) {
      _trackScrollGeometry(notification.scrollDelta);
      _scheduleAnchorCapture();
      final now = _scrollClock.elapsed;
      final previous = _previousScrollTime;
      _previousScrollTime = now;
      final delta = notification.scrollDelta;
      if (previous != null && delta != null) {
        final elapsed = (now - previous).inMicroseconds;
        if (elapsed > 0) {
          final speed = delta.abs() * Duration.microsecondsPerSecond / elapsed;
          if (speed > 1800) {
            _scrollIdleTimer?.cancel();
            _scrollIdleTimer = null;
            _setFastScrolling(true);
            _scheduleScrollIdle();
          } else if (speed < 900) {
            _scheduleScrollIdle();
          }
        }
      }
    } else if (notification is ScrollEndNotification) {
      _anchorCaptureTimer?.cancel();
      _anchorCaptureTimer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _captureScrollAnchor();
      });
      _performance.setInteractionActive(this, false);
      _previousScrollTime = null;
      _scheduleScrollIdle();
    } else if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) _explicitTarget = false;
      _performance.setInteractionActive(this, true);
      _previousScrollTime = _scrollClock.elapsed;
    }
    return false;
  }

  void _scheduleScrollIdle() {
    _scrollIdleTimer ??= Timer(const Duration(milliseconds: 160), () {
      _scrollIdleTimer = null;
      _setFastScrolling(false);
    });
  }

  final ValueNotifier<int?> _highlightedIdNotifier = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _performance = ref.read(adaptivePerformanceProvider.notifier);
    _centerMessageId = widget.messages.isEmpty ? null : widget.messages.last.id;
    _store.reset(widget.messages);
    _syncRowIds(widget.messages);
    final saved = widget.highlightMessageId == null
        ? widget.initialScrollAnchor
        : null;
    if (saved != null &&
        !saved.followingLatest &&
        _store.byId.containsKey(saved.messageId)) {
      _centerMessageId = saved.messageId;
      _anchorFraction = saved.fraction.clamp(0.0, 1.0);
      _restoringAnchor = true;
      _lastMeasuredAnchor = saved;
      _lastPublishedAnchor = saved;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.highlightMessageId != null) return;
      if (_restoringAnchor && saved != null) {
        final viewport = context.findRenderObject();
        final row = _anchors[saved.messageId];
        if (viewport is RenderBox &&
            viewport.attached &&
            viewport.hasSize &&
            row != null &&
            row.attached &&
            row.hasSize &&
            widget.scrollController.hasClients) {
          final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
          final actualBottom =
              row.localToGlobal(Offset.zero).dy + row.size.height;
          final desiredBottom = bounds.bottom - saved.fraction * bounds.height;
          final position = widget.scrollController.position;
          final target = (position.pixels + desiredBottom - actualBottom).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
          if ((target - position.pixels).abs() > 0.01) {
            widget.scrollController.jumpTo(target);
          }
        }
        _restoringAnchor = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _captureScrollAnchor();
        });
      } else {
        _captureScrollAnchor();
      }
    });
    _animatedMessageIds.addAll(widget.messages.map(_rowId));
    if (widget.highlightMessageId case final id?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_scrollToMessage(id));
      });
    }
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.highlightMessageId;
    if (id != null && id != oldWidget.highlightMessageId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_scrollToMessage(id));
      });
    }
    if (!identical(widget.messages, oldWidget.messages)) {
      _syncRowIds(widget.messages);
      _rebaseAnchor(widget.messages);
      _store.sync(widget.messages);
      _animatedMessageIds.retainAll(widget.messages.map(_rowId));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _captureScrollAnchor();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anchorCaptureTimer?.cancel();
    _publishLastMeasuredAnchor();
    _highlightTimer?.cancel();
    _scrollIdleTimer?.cancel();
    _scrollClock.stop();
    _performance.setInteractionActive(this, false);
    AnimatedMediaControllerPool.instance.setFastScrolling(false, source: this);
    _highlightedIdNotifier.dispose();
    super.dispose();
  }

  Future<void> _scrollToMessage(int messageId) async {
    _explicitTarget = true;
    if (!_store.byId.containsKey(messageId) &&
        widget.onRequestMessage != null) {
      if (!await widget.onRequestMessage!(messageId) || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_scrollToMessage(messageId));
      });
      return;
    }
    _highlightTimer?.cancel();
    _highlightedIdNotifier.value = messageId;
    _activeTargetMessageId = messageId;
    _activeTargetKey = GlobalKey(debugLabel: 'target_msg_$messageId');
    if (mounted) setState(() {});

    // Center the exact target row, including rows that were outside the current
    // 300-message window. No average-height estimate is needed for mixed media.
    if (widget.scrollController.hasClients) {
      _centerMessageId = messageId;
      _anchorFraction = 0.7;
      widget.scrollController.position.correctBy(
        -widget.scrollController.position.pixels,
      );
      setState(() {});
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _activeTargetKey?.currentContext;
      if (targetContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            targetContext,
            alignment: 0.3,
            duration: M3Durations.medium2,
            curve: M3SpringCurves.expressiveDecel,
          ).then((_) {
            if (mounted) _captureScrollAnchor(explicit: true);
          }),
        );
      } else {
        _captureScrollAnchor(explicit: true);
      }
    });

    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && _highlightedIdNotifier.value == messageId) {
        _highlightedIdNotifier.value = null;
        _activeTargetMessageId = null;
        _activeTargetKey = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ApiMessage> messages = _store.messages;
    final List<MessageLayoutData> layout = _store.layout;
    final Map<int, ApiMessage> byId = _store.byId;

    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((s) => s.tier),
    );
    final bool isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final double cacheExtent = switch (tier) {
      PerformanceTier.tierC => 250.0,
      PerformanceTier.tierB => isWindows ? 350.0 : 500.0,
      PerformanceTier.tierA => isWindows ? 350.0 : 750.0,
    };

    final DateTime now = AppTimeSettings.now();

    Widget buildRow(BuildContext context, int index) {
      final int reversedIndex = messages.length - 1 - index;
      final ApiMessage message = messages[reversedIndex];
      final MessageLayoutData data = layout[reversedIndex];

      final bool isMine = message.senderId == widget.authUserId;

      final String? mediaUrl = widget.mediaUrlBuilder(message);
      final bool hasMedia = mediaUrl != null && mediaUrl.trim().isNotEmpty;
      final bool isImageMedia = hasMedia
          ? widget.isImageMediaBuilder(message, mediaUrl)
          : false;
      final String? mediaLabel = hasMedia
          ? widget.mediaLabelBuilder(message, mediaUrl)
          : null;

      final bool isVoice =
          message.msgType == 'voice' ||
          (message.mediaType ?? '').toLowerCase().startsWith('audio/');
      final bool isCircleVideo =
          message.msgType == 'circle' ||
          message.msgType == 'circle_video' ||
          message.msgType == 'video_note' ||
          message.msgType == 'round_video';
      final bool isSticker = message.isSticker;
      final int? mediaDuration = message.mediaDuration;
      final bool isLocalSending = message.isSending && message.id < 0;

      final String rawText =
          message.isE2ee && !message.isDecrypted && message.content.isEmpty
          ? context.l10n.secretUnavailable
          : widget.displayTextBuilder(message);
      final bool isCallMessage =
          message.isCallEvent ||
          rawText.startsWith('📹') ||
          rawText.startsWith('📞');

      if (isCallMessage) {
        final Widget callPill = _CallEventPill(
          message: message,
          formattedTime: formatMessageTime(message.sentAt),
          isMine: isMine,
        );
        return RepaintBoundary(
          key: ValueKey<int>(_rowId(message)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (data.showDateSep)
                widget.dateSeparatorBuilder(message.resolvedSentAt, now),
              callPill,
            ],
          ),
        );
      }

      final bool isScreenshotMsg =
          message.isSystemEvent && message.systemEventType == 'screenshot';
      if (message.isSystemEvent || isScreenshotMsg) {
        final Widget systemPill = _SystemEventPill(
          message: message,
          formattedTime: formatMessageTime(message.sentAt),
        );
        return RepaintBoundary(
          key: ValueKey<int>(_rowId(message)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (data.showDateSep)
                widget.dateSeparatorBuilder(message.resolvedSentAt, now),
              systemPill,
            ],
          ),
        );
      }

      final bool shouldAnimate =
          index == 0 &&
          !_animatedMessageIds.contains(_rowId(message)) &&
          now.difference(message.resolvedSentAt).inSeconds < 4;
      if (shouldAnimate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animatedMessageIds.add(_rowId(message));
        });
      }

      Widget buildBubble({
        double? progress,
        int? bytesSent,
        int? totalBytes,
        UploadTask? uploadTask,
        int? queuePosition,
        required bool animateHighlight,
      }) {
        return MessageBubble(
          key: ValueKey<int>(_rowId(message)),
          chatId: message.chatId,
          text: InteractiveMessage.parse(rawText)?.preview ?? rawText,
          messageData: message,
          isMine: isMine,
          isE2ee: message.isE2ee,
          showEncryptionSettings: needsOrdinaryEncryptionSettings(message),
          e2eeFileKey: message.e2eeFileKey,
          expiresAt: message.expiresAt,
          isPrevSame: data.isPrevSame,
          isNextSame: data.isNextSame,
          formattedTime: formatMessageTime(message.sentAt),
          isEdited: message.isEdited,
          isDeleted: message.isDeleted,
          isRead: message.isRead,
          replyPreview: widget.replyPreviewBuilder(message, byId),
          replyToId: message.replyToId,
          onReplyTap: message.replyToId != null
              ? () {
                  _scrollToMessage(message.replyToId!);
                }
              : null,
          reactions: message.reactions,
          onReactionTap: widget.onReactionTap != null
              ? (String emoji) => widget.onReactionTap!(message, emoji)
              : null,
          mediaUrl: mediaUrl,
          mediaIsImage: isImageMedia,
          mediaLabel: mediaLabel,
          mediaSize: totalBytes ?? message.mediaSize,
          isVoice: isVoice,
          isCircleVideo: isCircleVideo,
          isSticker: isSticker,
          sticker: message.sticker,
          onStickerTap: () {
            final int? stickerId = message.sticker?.id;
            final int? targetSetId =
                message.resolvedStickerSetId ?? message.sticker?.setId;
            if (targetSetId != null && targetSetId > 0) {
              StickerSetDetailsSheet.show(
                context,
                setId: targetSetId,
                stickerId: stickerId,
              );
            } else if (stickerId != null && stickerId > 0) {
              StickerSetDetailsSheet.showForSticker(
                context,
                stickerId: stickerId,
                knownSetId: targetSetId,
              );
            } else {
              AppToast.showError(context, 'Стикерпак не найден');
            }
          },
          mediaDuration: mediaDuration,
          senderBadges: message.senderBadges,
          senderDisplayName: widget.isGroup ? message.senderDisplayName : null,
          isChannel: widget.isChannel,
          commentsCount: message.commentsCount,
          onOpenComments: widget.onOpenComments != null
              ? () => widget.onOpenComments!(message)
              : null,
          animate: shouldAnimate,
          isSending: isLocalSending,
          isFailed: message.isFailed,
          onRetrySend: () => widget.onRetrySend(message),
          uploadProgress: progress,
          uploadBytesSent: bytesSent,
          uploadTotalBytes: totalBytes,
          uploadTask: uploadTask,
          uploadQueuePosition: queuePosition,
          localId: isLocalSending ? message.id.toString() : null,
          onOpenMedia: hasMedia ? () => widget.onOpenMedia(message) : null,
          onLongPressMedia: hasMedia
              ? () => widget.onLongPressMedia(
                  message,
                  isMine,
                  widget.amAdminOrOwner,
                )
              : null,
          onLongPress: () => widget.onLongPress(
            message,
            isMine,
            widget.isChannel,
            widget.amAdminOrOwner,
          ),
          onSwipeToReply: () => widget.onSwipeToReply(message),
          replyMarkup: message.replyMarkup,
          onCallbackQuery: (String data) =>
              widget.onCallbackQuery(message, data),
          animateHighlight: animateHighlight,
        );
      }

      final Key itemKey = (message.id == _activeTargetMessageId)
          ? (_activeTargetKey ??= GlobalKey(
              debugLabel: 'target_msg_${message.id}',
            ))
          : ValueKey<int>(_rowId(message));

      final Widget bubble = ValueListenableBuilder<int?>(
        valueListenable: _highlightedIdNotifier,
        builder: (BuildContext context, int? highlightedId, Widget? _) {
          final bool isHighlighted = message.id == highlightedId;
          return isLocalSending
              ? Consumer(
                  builder: (context, ref, _) {
                    final String localIdStr = message.id.toString();
                    final uploadTask = ref.watch(
                      uploadTaskProvider(localIdStr),
                    );
                    final int queuePosition = ref.watch(
                      uploadQueuePositionProvider(localIdStr),
                    );
                    return buildBubble(
                      progress: uploadTask?.progress ?? 0.0,
                      bytesSent: uploadTask?.bytesSent,
                      totalBytes: uploadTask != null && uploadTask.fileSize > 0
                          ? uploadTask.fileSize
                          : message.mediaSize,
                      uploadTask: uploadTask,
                      queuePosition: queuePosition,
                      animateHighlight: isHighlighted,
                    );
                  },
                )
              : buildBubble(progress: null, animateHighlight: isHighlighted);
        },
      );

      final Widget animatedBubble = KeyedSubtree(
        key: itemKey,
        child: widget.animatedMessageBuilder(
          messageId: _rowId(message),
          animate: shouldAnimate,
          isMine: isMine,
          child: bubble,
        ),
      );

      if (isMine) {
        return RepaintBoundary(
          key: ValueKey<int>(_rowId(message)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (data.showDateSep)
                widget.dateSeparatorBuilder(message.resolvedSentAt, now),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (message.isSending &&
                      !hasMedia &&
                      !isVoice &&
                      !isCircleVideo &&
                      !isSticker)
                    const Padding(
                      padding: EdgeInsets.only(right: 8, bottom: 12),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: AppLoadingIndicator(size: 14),
                      ),
                    ),
                  if (message.isFailed)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      child: IconButton(
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 22,
                        ),
                        onPressed: () => widget.onRetrySend(message),
                      ),
                    ),
                  Flexible(child: animatedBubble),
                ],
              ),
            ],
          ),
        );
      }

      return RepaintBoundary(
        key: ValueKey<int>(_rowId(message)),
        child: Column(
          children: <Widget>[
            if (data.showDateSep)
              widget.dateSeparatorBuilder(message.resolvedSentAt, now),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (widget.isGroup) ...<Widget>[
                  if (!data.isNextSame) ...[
                    GestureDetector(
                      onTap: () {
                        final String username = message.senderUsername.trim();
                        if (username.isNotEmpty) {
                          context.push('/profile/$username');
                        } else if (message.senderId > 0) {
                          context.push('/profile/${message.senderId}');
                        }
                      },
                      child: message.senderAvatarUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: ApiConstants.resolve(
                                  message.senderAvatarUrl,
                                ),
                                httpHeaders: cachedAuthHeaders(),
                                memCacheWidth: 56,
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.person, size: 16),
                                ),
                                errorWidget: (context, url, error) =>
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.person, size: 16),
                                    ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 14,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: Text(
                                message.senderDisplayName.isNotEmpty
                                    ? message.senderDisplayName[0]
                                    : '?',
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const SizedBox(width: 36),
                ],
                Flexible(child: animatedBubble),
              ],
            ),
          ],
        ),
      );
    }

    final centerReversed = _centerMessageId == null
        ? null
        : _store.idToIndex[_centerMessageId];
    final center = centerReversed == null
        ? messages.length - 1
        : messages.length - 1 - centerReversed;
    Widget anchored(BuildContext context, int ascending) => _HistoryAnchor(
      key: ValueKey<int>(_rowId(messages[ascending])),
      messageId: messages[ascending].id,
      registry: _anchors,
      child: buildRow(context, messages.length - 1 - ascending),
    );
    int? ascendingIndex(Key key) =>
        key is ValueKey<int> ? _rowIndexes[key.value] : null;

    return ScrollNotificationObserver(
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final defaultAnchor = (widget.bottomPadding / constraints.maxHeight)
                .clamp(0.0, 1.0);
            return RepaintBoundary(
              child: CustomScrollView(
                controller: widget.scrollController,
                reverse: true,
                center: _centerSliverKey,
                anchor: _anchorFraction ?? defaultAnchor,
                // ignore: deprecated_member_use
                cacheExtent: cacheExtent,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: widget.bottomPadding),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            anchored(context, center + 1 + index),
                        childCount: (messages.length - center - 1).clamp(
                          0,
                          messages.length,
                        ),
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                        findChildIndexCallback: (key) {
                          final index = ascendingIndex(key);
                          return index != null && index > center
                              ? index - center - 1
                              : null;
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    key: _centerSliverKey,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => anchored(context, center - index),
                        childCount: center + 1,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                        findChildIndexCallback: (key) {
                          final index = ascendingIndex(key);
                          return index != null && index <= center
                              ? center - index
                              : null;
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: widget.topPadding),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryAnchor extends SingleChildRenderObjectWidget {
  const _HistoryAnchor({
    super.key,
    required this.messageId,
    required this.registry,
    required super.child,
  });
  final int messageId;
  final Map<int, _HistoryAnchorBox> registry;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _HistoryAnchorBox(messageId, registry);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _HistoryAnchorBox renderObject,
  ) {
    renderObject.updateMessageId(messageId);
  }
}

class _HistoryAnchorBox extends RenderProxyBox {
  _HistoryAnchorBox(this.messageId, this.registry);
  int messageId;
  final Map<int, _HistoryAnchorBox> registry;
  void updateMessageId(int next) {
    if (messageId == next) return;
    if (identical(registry[messageId], this)) registry.remove(messageId);
    messageId = next;
    if (attached) registry[messageId] = this;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    registry[messageId] = this;
  }

  @override
  void detach() {
    if (identical(registry[messageId], this)) registry.remove(messageId);
    super.detach();
  }
}

class _CallEventPill extends StatelessWidget {
  const _CallEventPill({
    required this.message,
    required this.formattedTime,
    required this.isMine,
  });

  final ApiMessage message;
  final String formattedTime;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isVideo = message.isCallVideo;
    final bool isMissed = message.isCallMissed;

    final IconData icon = isVideo
        ? Icons.videocam_rounded
        : (isMissed ? Icons.phone_missed_rounded : Icons.phone_rounded);
    final Color iconColor = isMissed ? scheme.error : scheme.primary;

    String cleanText = message.content.trim();
    if (cleanText.startsWith('📹') || cleanText.startsWith('📞')) {
      cleanText = cleanText.substring(2).trim();
    }
    if (cleanText.isEmpty) {
      if (isVideo) {
        cleanText = isMissed ? 'Пропущенный видеозвонок' : 'Видеозвонок';
      } else {
        cleanText = isMissed ? 'Пропущенный звонок' : 'Голосовой звонок';
      }
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isMissed
              ? scheme.errorContainer.withValues(alpha: isDark ? 0.40 : 0.60)
              : (isDark
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.60)
                    : scheme.surfaceContainerHigh.withValues(alpha: 0.80)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMissed
                ? scheme.error.withValues(alpha: 0.25)
                : scheme.outlineVariant.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              cleanText,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isMissed ? scheme.onErrorContainer : scheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formattedTime,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: isMissed
                    ? scheme.onErrorContainer.withValues(alpha: 0.70)
                    : scheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemEventPill extends StatelessWidget {
  const _SystemEventPill({required this.message, required this.formattedTime});

  final ApiMessage message;
  final String formattedTime;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final String text = message.content.isNotEmpty
        ? message.content
        : 'Системное уведомление';

    final bool isScreenshot =
        message.isSystemEvent && message.systemEventType == 'screenshot';
    final IconData icon = isScreenshot
        ? Icons.camera_alt_outlined
        : Icons.info_outline_rounded;
    final Color iconColor = isScreenshot ? scheme.error : scheme.primary;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.60)
              : scheme.surfaceContainerHigh.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isScreenshot
                ? scheme.error.withValues(alpha: 0.35)
                : scheme.outlineVariant.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formattedTime,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
