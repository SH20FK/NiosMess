import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/core/notifications/notification_reply_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/in_app_notification_provider.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

class InAppNotificationBannerOverlay extends ConsumerStatefulWidget {
  const InAppNotificationBannerOverlay({super.key});

  @override
  ConsumerState<InAppNotificationBannerOverlay> createState() =>
      _InAppNotificationBannerOverlayState();
}

class _InAppNotificationBannerOverlayState
    extends ConsumerState<InAppNotificationBannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  InAppNotificationItem? _currentItem;
  final _replyController = CustomEmojiTextController();
  final _replyFocus = FocusNode();
  Timer? _draftTimer;
  bool _replying = false, _sending = false, _hovered = false, _focused = false;
  int? _replyAccount;
  String? _replyError, _replyLocalId;

  void _updatePause() => ref
      .read(inAppNotificationProvider.notifier)
      .pause(_replying || _sending || _hovered || _focused);

  Future<void> _startReply(InAppNotificationItem item) async {
    if (_sending || item.chatId == null) return;
    final account = ref.read(authProvider).session?.userId;
    if (account == null) return;
    setState(() {
      _replying = true;
      _replyError = null;
      _replyAccount = account;
      _replyLocalId ??= '-${DateTime.now().microsecondsSinceEpoch}';
    });
    _updatePause();
    final replyId = _replyLocalId;
    final service = ref.read(notificationReplyServiceProvider);
    try {
      final draft = await service.loadDraft(item.chatId!);
      if (!mounted ||
          !_replying ||
          _currentItem?.chatId != item.chatId ||
          ref.read(authProvider).session?.userId != account) {
        return;
      }
      if (_replyController.text.isEmpty) _replyController.text = draft;
    } catch (_) {
      if (mounted &&
          _replyLocalId == replyId &&
          ref.read(authProvider).session?.userId == account) {
        setState(() => _replyError = context.l10n.noticeReplySaveFailed);
      }
    }
    if (mounted &&
        _replying &&
        _replyLocalId == replyId &&
        ref.read(authProvider).session?.userId == account) {
      setState(() {});
      _replyFocus.requestFocus();
    }
  }

  Future<bool> _saveReplyDraft() async {
    _draftTimer?.cancel();
    final chat = _currentItem?.chatId;
    if (chat == null ||
        _replyAccount == null ||
        ref.read(authProvider).session?.userId != _replyAccount) {
      return false;
    }
    final account = _replyAccount;
    final replyId = _replyLocalId;
    final service = ref.read(notificationReplyServiceProvider);
    try {
      await service.saveDraft(chat, _replyController.text);
      return mounted &&
          _replyLocalId == replyId &&
          ref.read(authProvider).session?.userId == account;
    } catch (_) {
      if (mounted &&
          _replyLocalId == replyId &&
          ref.read(authProvider).session?.userId == account) {
        setState(() => _replyError = context.l10n.noticeReplySaveFailed);
      }
      return false;
    }
  }

  void _replyChanged(String text) {
    setState(() {
      _replyError = null;
    });
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 300), _saveReplyDraft);
  }

  Future<void> _closeBanner() async {
    if (_sending) return;
    if (_replying && !await _saveReplyDraft()) return;
    if (mounted) ref.read(inAppNotificationProvider.notifier).dismiss();
  }

  Future<void> _cancelReply() async {
    if (_sending || !await _saveReplyDraft() || !mounted) return;
    setState(() => _replying = false);
    _replyFocus.unfocus();
    _updatePause();
  }

  Future<void> _sendReply(InAppNotificationItem item) async {
    if (_sending ||
        item.chatId == null ||
        _replyController.text.trim().isEmpty) {
      return;
    }
    if (ref.read(authProvider).session?.userId != _replyAccount) return;
    final text = _replyController.text;
    final account = _replyAccount;
    final token = ref.read(authProvider).session?.accessToken;
    final replyId = _replyLocalId!;
    final service = ref.read(notificationReplyServiceProvider);
    bool isCurrentReply() =>
        mounted &&
        _replyLocalId == replyId &&
        _currentItem?.chatId == item.chatId &&
        ref.read(authProvider).session?.userId == account &&
        ref.read(authProvider).session?.accessToken == token;
    setState(() {
      _sending = true;
      _replyError = null;
    });
    _updatePause();
    try {
      if (!await _saveReplyDraft() || !isCurrentReply()) return;
      await service.send(item.chatId!, text, localId: replyId);
      if (!isCurrentReply()) return;
      // Clear only after the chat pipeline has saved/acknowledged the outgoing
      // message. Secret messages may be durably queued while their peer is offline.
      try {
        await service.saveDraft(item.chatId!, '');
      } catch (_) {
        debugPrint('[Notifications] REPLY_DRAFT_CLEAR_PENDING');
      }
      if (!isCurrentReply()) return;
      _replyController.clear();
      _replyFocus.unfocus();
      ref.read(notificationsProvider.notifier).markRead(item.id);
      ref.read(inAppNotificationProvider.notifier).dismiss();
    } catch (_) {
      if (isCurrentReply()) {
        setState(() => _replyError = context.l10n.noticeReplyFailed);
      }
    } finally {
      if (mounted && _replyLocalId == replyId) {
        setState(() => _sending = false);
        _updatePause();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: M3SpringCurves.spatial,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    ref.listenManual(
      inAppNotificationProvider,
      (_, next) => _handleItemChange(next),
      fireImmediately: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    _controller.duration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 380);
    _controller.reverseDuration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 250);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _replyController.dispose();
    _replyFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleItemChange(InAppNotificationItem? next) {
    if (next != null) {
      final sameConversation =
          _currentItem?.id == next.id ||
          (next.chatId != null && _currentItem?.chatId == next.chatId);
      if (!sameConversation) {
        _draftTimer?.cancel();
        _replyController.clear();
        _replying = false;
        _sending = false;
        _replyError = null;
        _replyLocalId = null;
        _replyAccount = null;
      }
      setState(() {
        _currentItem = next;
      });
      if (!sameConversation) {
        _controller.forward(from: 0.0);
        _updatePause();
      }
    } else {
      _draftTimer?.cancel();
      _replyController.clear();
      _replyFocus.unfocus();
      _replying = false;
      _sending = false;
      _replyAccount = null;
      _replyError = null;
      _replyLocalId = null;
      _controller.reverse().then((_) {
        if (mounted && ref.read(inAppNotificationProvider) == null) {
          setState(() {
            _currentItem = null;
          });
        }
      });
    }
  }

  void _onTapBanner(InAppNotificationItem item) {
    if (_replying || _sending) return;
    ref.read(notificationsProvider.notifier).markRead(item.id);
    ref.read(inAppNotificationProvider.notifier).dismiss();
    final BuildContext? ctx = AppRouter.navigatorKey.currentContext;
    if (ctx == null) return;

    if (item.id.startsWith('ota_ready')) {
      ref.read(otaUpdateProvider.notifier).installApk(context: ctx);
      return;
    }

    if (item.route != null && item.route!.isNotEmpty) {
      ctx.push(item.route!);
    } else if (item.chatId != null) {
      ctx.push('/chat/${item.chatId}');
    }
  }

  Future<void> _onMarkRead(InAppNotificationItem item) async {
    final chatId = item.chatId;
    if (chatId == null) return;
    final account = ref.read(authProvider).session?.userId;
    try {
      await ref.read(chatRepositoryProvider).markRead(chatId);
      if (!mounted || ref.read(authProvider).session?.userId != account) return;
      ref.read(chatsProvider.notifier).markChatAsRead(chatId);
      ref.read(notificationsProvider.notifier).markChatRead(chatId);
      if (ref.read(inAppNotificationProvider)?.chatId == chatId) {
        ref.read(inAppNotificationProvider.notifier).dismiss();
      }
    } catch (error) {
      if (mounted) AppToast.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _currentItem;
    if (item == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final notifier = ref.read(inAppNotificationProvider.notifier);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight:
                    (MediaQuery.sizeOf(context).height -
                            MediaQuery.viewInsetsOf(context).bottom -
                            MediaQuery.paddingOf(context).vertical -
                            24)
                        .clamp(0, double.infinity),
              ),
              child: RepaintBoundary(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: MouseRegion(
                      onEnter: (_) {
                        _hovered = true;
                        _updatePause();
                      },
                      onExit: (_) {
                        _hovered = false;
                        _updatePause();
                      },
                      child: Focus(
                        onFocusChange: (focused) {
                          _focused = focused;
                          _updatePause();
                        },
                        child: Semantics(
                          liveRegion: !_replying,
                          container: true,
                          child: Dismissible(
                            key: ValueKey(
                              item.chatId == null
                                  ? item.id
                                  : 'chat:${item.chatId}',
                            ),
                            direction: DismissDirection.up,
                            confirmDismiss: (_) async =>
                                !_replying && !_sending,
                            onDismissed: (_) => notifier.dismiss(),
                            child: Material(
                              color: scheme.surfaceContainerHigh,
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(28),
                                side: BorderSide(color: scheme.outlineVariant),
                              ),
                              child: InkWell(
                                onTap: () => _onTapBanner(item),
                                customBorder: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: AnimatedSize(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : M3Durations.medium1,
                                  curve: M3SpringCurves.expressiveStandard,
                                  alignment: Alignment.topCenter,
                                  child: SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (item.icon != null)
                                                DecoratedBox(
                                                  decoration: ShapeDecoration(
                                                    color:
                                                        scheme.primaryContainer,
                                                    shape: RoundedSuperellipseBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                  ),
                                                  child: SizedBox(
                                                    width: 48,
                                                    height: 48,
                                                    child: Icon(
                                                      item.icon,
                                                      color: scheme
                                                          .onPrimaryContainer,
                                                    ),
                                                  ),
                                                )
                                              else
                                                PulseAvatar(
                                                  name: item.title,
                                                  avatarUrl: item.avatarUrl,
                                                  radius: 24,
                                                ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.title,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    Text(
                                                      DateFormat.Hm(
                                                        Localizations.localeOf(
                                                          context,
                                                        ).languageCode,
                                                      ).format(
                                                        item.timestamp
                                                            .toLocal(),
                                                      ),
                                                      style: theme
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: l10n.noticeClose,
                                                onPressed: _sending
                                                    ? null
                                                    : _closeBanner,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 48,
                                                      minHeight: 48,
                                                    ),
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          CustomEmojiText(
                                            item.body,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                          if (!_replying &&
                                              (item.chatId != null ||
                                                  item.route != null)) ...[
                                            const SizedBox(height: 12),
                                            Wrap(
                                              alignment: WrapAlignment.end,
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                if (item.chatId != null)
                                                  TextButton(
                                                    style: TextButton.styleFrom(
                                                      minimumSize: const Size(
                                                        48,
                                                        48,
                                                      ),
                                                    ),
                                                    onPressed: () =>
                                                        _onMarkRead(item),
                                                    child: Text(
                                                      l10n.noticeMarkRead,
                                                    ),
                                                  ),
                                                FilledButton.tonal(
                                                  style: FilledButton.styleFrom(
                                                    minimumSize: const Size(
                                                      48,
                                                      48,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      item.chatId != null
                                                      ? _startReply(item)
                                                      : _onTapBanner(item),
                                                  child: Text(
                                                    item.chatId != null
                                                        ? l10n.noticeReply
                                                        : l10n.noticeOpen,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (_replying) ...[
                                            const SizedBox(height: 12),
                                            RepaintBoundary(
                                              child: TextField(
                                                controller: _replyController,
                                                focusNode: _replyFocus,
                                                enabled: !_sending,
                                                minLines: 1,
                                                maxLines: 4,
                                                textCapitalization:
                                                    TextCapitalization
                                                        .sentences,
                                                textInputAction:
                                                    TextInputAction.newline,
                                                onChanged: _replyChanged,
                                                decoration: InputDecoration(
                                                  labelText:
                                                      l10n.noticeReplyHint,
                                                  filled: true,
                                                  fillColor: scheme
                                                      .surfaceContainerHighest,
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_replyError != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Semantics(
                                                  liveRegion: true,
                                                  child: Text(
                                                    _replyError!,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: scheme.error,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              alignment: WrapAlignment.end,
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                TextButton(
                                                  onPressed: _sending
                                                      ? null
                                                      : _cancelReply,
                                                  style: TextButton.styleFrom(
                                                    minimumSize: const Size(
                                                      48,
                                                      48,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    l10n.commonCancel,
                                                  ),
                                                ),
                                                FilledButton.icon(
                                                  onPressed:
                                                      _sending ||
                                                          _replyController.text
                                                              .trim()
                                                              .isEmpty
                                                      ? null
                                                      : () => _sendReply(item),
                                                  style: FilledButton.styleFrom(
                                                    minimumSize: const Size(
                                                      48,
                                                      48,
                                                    ),
                                                  ),
                                                  icon: _sending
                                                      ? const SizedBox.square(
                                                          dimension: 20,
                                                          child:
                                                              AppLoadingIndicator(),
                                                        )
                                                      : const Icon(
                                                          Icons.send_rounded,
                                                        ),
                                                  label: Text(
                                                    _sending
                                                        ? l10n.noticeSending
                                                        : l10n.noticeSend,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
