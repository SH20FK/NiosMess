import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/post_card.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';
import 'package:pulse_flutter/widgets/empty_feed_widget.dart';
import 'package:pulse_flutter/widgets/app_error_banner.dart';
import 'package:pulse_flutter/models/api/post_model.dart';

class NiosgramScreen extends ConsumerStatefulWidget {
  const NiosgramScreen({super.key});

  @override
  ConsumerState<NiosgramScreen> createState() => _NiosgramScreenState();
}

class _NiosgramScreenState extends ConsumerState<NiosgramScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final bool shouldShow = _scrollController.offset > 200;
    if (shouldShow != _showFab) {
      setState(() => _showFab = shouldShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<NiosgramState> feedAsync = ref.watch(niosgramProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          context.l10n.niosgramTitle,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: context.l10n.niosgramCreatePost,
            onPressed: () {
              if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
              context.push('/niosgram/create');
            },
          ),
          const SizedBox(width: 4),
          _NotificationsBell(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton.small(
              heroTag: 'niosgram_scroll_top',
              onPressed: () {
                if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            )
          : null,
      body: feedAsync.when(
        loading: () => ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (_, int i) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(children: <Widget>[
                  const PulseSkeleton(width: 40, height: 40, borderRadius: 20),
                  const SizedBox(width: 10),
                  PulseSkeleton(width: 120 + (i % 3) * 30.0, height: 14),
                ]),
                const SizedBox(height: 12),
                PulseSkeleton(width: double.infinity, height: 200, borderRadius: 16),
                const SizedBox(height: 8),
                PulseSkeleton(width: 180, height: 12),
              ],
            ),
          ),
        ),
        error: (Object e, _) => AppErrorBanner(
          message: context.l10n.niosgramFailedLoad,
          variant: AppErrorBannerVariant.centered,
          onRetry: () => ref.invalidate(niosgramProvider),
        ),
        data: (NiosgramState feedState) {
          if (feedState.posts.isEmpty) {
            return EmptyFeedWidget(
              title: context.l10n.niosgramEmptyFeed,
              description: context.l10n.niosgramEmptyFeedDesc,
              actionLabel: context.l10n.niosgramCreatePost,
              onAction: () => context.push('/niosgram/create'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(niosgramProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 4, bottom: 80),
              itemCount: feedState.posts.length +
                  (feedState.isLoadingMore ? 1 : 0) +
                  (feedState.hasMore && !feedState.isLoadingMore ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (index == feedState.posts.length) {
                  if (feedState.isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: PulseLoadingIndicator(size: 32),
                    );
                  }
                  return _LoadMoreTrigger(
                    onVisible: () =>
                        ref.read(niosgramProvider.notifier).loadMore(),
                  );
                }
                final NgPost post = feedState.posts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Animate(
                    key: ValueKey<String>('post_${post.id}'),
                    effects: <Effect<dynamic>>[
                      FadeEffect(
                        begin: 0,
                        end: 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                      SlideEffect(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      ),
                    ],
                    delay: Duration(milliseconds: (index % 10) * 50),
                    child: PostCard(key: ValueKey<int>(post.id), post: post),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Load more trigger ─────────────────────────────────────────────────
class _LoadMoreTrigger extends StatefulWidget {
  const _LoadMoreTrigger({required this.onVisible});
  final VoidCallback onVisible;

  @override
  State<_LoadMoreTrigger> createState() => _LoadMoreTriggerState();
}

class _LoadMoreTriggerState extends State<_LoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Notification bell with bounce ─────────────────────────────────────
class _NotificationsBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(notificationsProvider).unreadCount;

    return Animate(
      effects: <Effect<dynamic>>[
        if (count > 0)
          ScaleEffect(
            begin: const Offset(1, 1),
            end: const Offset(1.15, 1.15),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
          ),
      ],
      onInit: (controller) {
        if (count > 0) {
          controller.repeat(reverse: true, period: const Duration(seconds: 2));
        }
      },
      child: Stack(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: context.l10n.settingsPushNotifications,
            onPressed: null,
          ),
          if (count > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
