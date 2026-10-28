import 'package:pulse_flutter/widgets/notifications/notification_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/smooth_scroll.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_error_banner.dart';
import 'package:pulse_flutter/widgets/empty_feed_widget.dart';
import 'package:pulse_flutter/widgets/post_card.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';
import 'package:pulse_flutter/screens/niosgram_saved_screen.dart';
import 'package:pulse_flutter/screens/create_post_screen.dart';

class NiosgramScreen extends ConsumerStatefulWidget {
  const NiosgramScreen({super.key});

  @override
  ConsumerState<NiosgramScreen> createState() => _NiosgramScreenState();
}

class _NiosgramScreenState extends ConsumerState<NiosgramScreen> {
  final ScrollController _scrollController = SmoothScrollController();
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWide = screenWidth >= Breakpoints.medium;
    final double horizontalGutter = isWide ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          context.l10n.niosgramTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: scheme.onSurface,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.niosgramSavedTitle,
            icon: const Icon(Icons.bookmark_outline_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NiosgramSavedScreen(),
              ),
            ),
          ),
          const _NotificationsBell(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton.small(
              heroTag: 'niosgram_scroll_top',
              tooltip: context.l10n.niosgramScrollTop,
              backgroundColor: scheme.surfaceContainerHigh,
              foregroundColor: scheme.onSurfaceVariant,
              elevation: 0,
              onPressed: () => _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: M3SpringCurves.expressiveDecel,
              ),
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            )
          : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: feedAsync.when(
            loading: () => const PostFeedSkeleton(count: 4),
            error: (Object e, _) => AppErrorBanner(
              message: context.l10n.niosgramFailedLoad,
              variant: AppErrorBannerVariant.centered,
              onRetry: () => ref.invalidate(niosgramProvider),
            ),
            data: (NiosgramState feedState) {
              if (feedState.posts.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(niosgramProvider.notifier).refresh(),
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(top: 4, bottom: isWide ? 84 : 96),
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalGutter,
                        ),
                        child: const _CompactQuickCreateBar(),
                      ),
                      const SizedBox(height: 24),
                      EmptyFeedWidget(
                        title: context.l10n.niosgramEmptyFeed,
                        description: context.l10n.niosgramEmptyFeedDesc,
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(niosgramProvider.notifier).refresh(),
                child: ListView.builder(
                  controller: _scrollController,
                  addRepaintBoundaries: false,
                  padding: EdgeInsets.only(top: 4, bottom: isWide ? 84 : 96),
                  itemCount:
                      1 +
                      feedState.posts.length +
                      (feedState.isLoadingMore ? 1 : 0) +
                      (feedState.hasMore && !feedState.isLoadingMore ? 1 : 0),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalGutter,
                          vertical: 6,
                        ),
                        child: const _CompactQuickCreateBar(),
                      );
                    }
                    final int postIndex = index - 1;
                    if (postIndex == feedState.posts.length) {
                      if (feedState.isLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: AppLoadingIndicator(size: 32),
                        );
                      }
                      if (feedState.loadMoreFailed) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              Text(context.l10n.niosgramPageLoadFailed),
                              TextButton(
                                onPressed: () => ref
                                    .read(niosgramProvider.notifier)
                                    .loadMore(retry: true),
                                child: Text(context.l10n.commonRetry),
                              ),
                            ],
                          ),
                        );
                      }
                      return _LoadMoreTrigger(
                        onVisible: () =>
                            ref.read(niosgramProvider.notifier).loadMore(),
                      );
                    }
                    final NgPost post = feedState.posts[postIndex];
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalGutter,
                        vertical: isWide ? 8 : 6,
                      ),
                      child: PostCard(key: ValueKey<int>(post.id), post: post),
                    );
                  },
                ),
              );
            },
          ),
        ),
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

// ── Material 3 Expressive Activity & Notifications Bell ────────────────
class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(notificationsProvider).unreadCount;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        IconButton(
          icon: Icon(
            count > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_outlined,
            color: count > 0 ? scheme.primary : scheme.onSurfaceVariant,
          ),
          tooltip: context.l10n.notificationsTitle,
          onPressed: () {
            if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
            _showNotificationsSheet(context, ref);
          },
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 200),
              curve: M3SpringCurves.bouncy,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.surface, width: 1.5),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: scheme.error.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationsSheet(BuildContext context, WidgetRef ref) {
    showNotificationCenter(context);
  }
}

// One editor handles text, media, and polls, including restored drafts.
class _CompactQuickCreateBar extends ConsumerWidget {
  const _CompactQuickCreateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;
    final name =
        auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;
    return Material(
      key: const ValueKey('collapsed_quick_bar'),
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
          if (GoRouter.maybeOf(context) != null) {
            context.push('/niosgram/create');
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CreatePostScreen()),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              PulseAvatar(
                name: name,
                avatarUrl: auth.profile?.avatarUrl,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.postHint,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_note_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
