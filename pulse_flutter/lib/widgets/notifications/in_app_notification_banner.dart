import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/providers/in_app_notification_provider.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh
                                .withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.55),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow
                                    .withValues(alpha: 0.16),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              if (item.icon != null)
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
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
                                              fontFamily: 'Onest',
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
                                            fontFamily: 'GolosText',
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
                                        fontFamily: 'GolosText',
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
