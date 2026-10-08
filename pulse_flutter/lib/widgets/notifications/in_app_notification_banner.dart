import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleItemChange(InAppNotificationItem? next) {
    if (next != null) {
      setState(() {
        _currentItem = next;
      });
      _controller.forward(from: 0.0);
    } else {
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

  void _onMarkRead(InAppNotificationItem item) {
    final int? chatId = item.chatId;
    if (chatId == null) return;
    HapticService.confirm();
    unawaited(ref.read(chatRepositoryProvider).markRead(chatId));
    ref.read(chatsProvider.notifier).markChatAsRead(chatId);
    ref.read(inAppNotificationProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<InAppNotificationItem?>(
      inAppNotificationProvider,
      (previous, next) {
        if (previous?.id != next?.id || next == null) {
          _handleItemChange(next);
        }
      },
    );

    final InAppNotificationItem? item = _currentItem;
    if (item == null) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: RepaintBoundary(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Dismissible(
                  key: ValueKey<String>(item.id),
                  direction: DismissDirection.up,
                  onDismissed: (_) {
                    ref.read(inAppNotificationProvider.notifier).dismiss();
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onTapBanner(item),
                      borderRadius: BorderRadius.circular(22),
                      splashColor: colorScheme.primary.withValues(alpha: 0.1),
                      highlightColor: colorScheme.primary.withValues(alpha: 0.05),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                if (item.icon != null)
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      color: colorScheme.primary,
                                      size: 24,
                                    ),
                                  )
                                else
                                  PulseAvatar(
                                    name: item.title,
                                    avatarUrl: item.avatarUrl,
                                    radius: 22,
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: colorScheme.onSurface,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'сейчас',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: colorScheme.outline,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.body,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 13,
                                          height: 1.25,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: colorScheme.outline,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  tooltip: 'Закрыть',
                                  onPressed: () {
                                    ref
                                        .read(inAppNotificationProvider.notifier)
                                        .dismiss();
                                  },
                                ),
                              ],
                            ),
                            if (item.chatId != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () => _onMarkRead(item),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.done_all_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Прочитано',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _onTapBanner(item),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.reply_rounded, size: 14, color: colorScheme.onPrimary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Ответить',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
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
    );
  }
}
