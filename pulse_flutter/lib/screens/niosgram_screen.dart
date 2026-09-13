import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/core/utils/smooth_scroll.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/app_error_banner.dart';
import 'package:pulse_flutter/widgets/empty_feed_widget.dart';
import 'package:pulse_flutter/widgets/post_card.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';

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
    final bool isWide = screenWidth >= 760;
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
        actions: const <Widget>[
          _NotificationsBell(),
          SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _buildFloatingActions(context, scheme),
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
                  onRefresh: () => ref.read(niosgramProvider.notifier).refresh(),
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      top: 4,
                      bottom: isWide ? 84 : 96,
                    ),
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalGutter),
                        child: const _CompactQuickCreateBar(),
                      ),
                      const SizedBox(height: 24),
                      EmptyFeedWidget(
                        title: context.l10n.niosgramEmptyFeed,
                        description: context.l10n.niosgramEmptyFeedDesc,
                        actionLabel: context.l10n.niosgramCreatePost,
                        onAction: () => context.push('/niosgram/create'),
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
                  padding: EdgeInsets.only(
                    top: 4,
                    bottom: isWide ? 84 : 96,
                  ),
                  itemCount: 1 +
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

  Widget _buildFloatingActions(BuildContext context, ColorScheme scheme) {
    final Widget createFab = _NiosgramQuickCreateFab(
      onPressed: () {
        if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
        context.push('/niosgram/create');
      },
      tooltip: context.l10n.niosgramCreatePost,
    );

    if (!_showFab) {
      return createFab;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        FloatingActionButton.small(
          heroTag: 'niosgram_scroll_top',
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurfaceVariant,
          elevation: 2,
          onPressed: () {
            if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          },
          child: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        const SizedBox(height: 12),
        createFab,
      ],
    );
  }
}

// ── Expressive 9-sided cookie Quick Creation FAB ──────────────────────
class _NiosgramQuickCreateFab extends StatelessWidget {
  const _NiosgramQuickCreateFab({
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.30),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipPath(
            clipper: M3Clipper(Shapes.c9_sided_cookie),
            child: Material(
              color: scheme.primaryContainer,
              child: InkWell(
                onTap: onPressed,
                splashColor: scheme.primary.withValues(alpha: 0.20),
                highlightColor: scheme.primary.withValues(alpha: 0.10),
                child: Center(
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 28,
                    color: scheme.onPrimaryContainer,
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
          tooltip: 'Уведомления',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 9.5,
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
    ref.read(notificationsProvider.notifier).markAllRead();
    AppBottomSheets.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final notificationsState = ref.watch(notificationsProvider);
        final scheme = Theme.of(ctx).colorScheme;
        final isRu = context.l10n.localeName.startsWith('ru');

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            final list = notificationsState.notifications;
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_rounded,
                          size: 20,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isRu ? 'Уведомления' : 'Notifications',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const Spacer(),
                      if (list.isNotEmpty)
                        TextButton(
                          onPressed: () => ref
                              .read(notificationsProvider.notifier)
                              .markAllRead(),
                          child: Text(isRu ? 'Прочитано' : 'Mark read'),
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.notifications_none_rounded,
                                    size: 32,
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  isRu
                                      ? 'Нет новых уведомлений'
                                      : 'No notifications yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isRu
                                      ? 'Здесь будут появляться реакции на ваши посты и важные обновления'
                                      : 'Reactions to your posts and key updates will appear here',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: list.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            indent: 68,
                            color: scheme.outlineVariant.withValues(alpha: 0.15),
                          ),
                          itemBuilder: (BuildContext context, int index) {
                            final n = list[index];
                            final IconData icon = switch (n.type) {
                              AppNotificationType.message =>
                                Icons.chat_bubble_outline_rounded,
                              AppNotificationType.postLike =>
                                Icons.favorite_rounded,
                              AppNotificationType.postComment =>
                                Icons.comment_rounded,
                              _ => Icons.notifications_none_rounded,
                            };
                            final Color iconColor = switch (n.type) {
                              AppNotificationType.postLike => scheme.error,
                              AppNotificationType.postComment => scheme.primary,
                              AppNotificationType.message => scheme.tertiary,
                              _ => scheme.secondary,
                            };

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 2),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(icon, color: iconColor, size: 20),
                              ),
                              title: Text(
                                n.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                final route = n.payload?['route'] as String?;
                                if (route != null && route.isNotEmpty) {
                                  context.push(route);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}



// ── Inline Quick Create Composer (Threads / X style) ───────────────────
class _CompactQuickCreateBar extends ConsumerStatefulWidget {
  const _CompactQuickCreateBar();

  @override
  ConsumerState<_CompactQuickCreateBar> createState() =>
      _CompactQuickCreateBarState();
}

class _CompactQuickCreateBarState extends ConsumerState<_CompactQuickCreateBar> {
  bool _isExpanded = false;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PlatformFile> _selectedFiles = <PlatformFile>[];
  List<Uint8List> _previewBytesList = <Uint8List>[];
  bool _isLoading = false;
  String? _error;

  static const int _maxFileBytes = 10 * 1024 * 1024; // 10 MB

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _expand() {
    if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
    setState(() => _isExpanded = true);
    _focusNode.requestFocus();
  }

  void _collapse() {
    if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
    setState(() {
      _isExpanded = false;
      _textController.clear();
      _selectedFiles = <PlatformFile>[];
      _previewBytesList = <Uint8List>[];
      _error = null;
    });
    _focusNode.unfocus();
  }

  Future<void> _pickMedia() async {
    final int availableSlots = 5 - _selectedFiles.length;
    if (availableSlots <= 0) {
      if (mounted) AppToast.showInfo(context, 'Максимум 5 фотографий');
      return;
    }

    final List<PlatformFile> result = await FilePicker.pickFiles(
      type: FileType.media,
    );
    if (result.isEmpty) return;

    final List<PlatformFile> picked = result.take(availableSlots).toList();
    final List<PlatformFile> validFiles = List<PlatformFile>.from(_selectedFiles);
    final List<Uint8List> previews = List<Uint8List>.from(_previewBytesList);

    for (final PlatformFile file in picked) {
      if ((await file.length()) > _maxFileBytes) {
        setState(() {
          _isExpanded = true;
          _error = context.l10n.postFileTooLarge;
        });
        continue;
      }

      Uint8List previewBytes = await file.readAsBytes();
      final Uint8List? compressed = await ImageCompressor.compressImageBytes(
        bytes: previewBytes,
        fileName: file.name,
      );
      if (compressed != null) previewBytes = compressed;
      validFiles.add(file);
      previews.add(previewBytes);
    }

    if (validFiles.length != _selectedFiles.length) {
      setState(() {
        _isExpanded = true;
        _selectedFiles = validFiles;
        _previewBytesList = previews;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final String text = _textController.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty) {
      setState(() => _error = context.l10n.postEmptyContent);
      return;
    }

    if (ref.read(uiSettingsProvider).haptics) HapticService.tap();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<String>? uploadIds;
      if (_selectedFiles.isNotEmpty) {
        uploadIds = <String>[];
        for (int i = 0; i < _selectedFiles.length; i++) {
          final PlatformFile file = _selectedFiles[i];
          final Uint8List fileBytes = (i < _previewBytesList.length)
              ? _previewBytesList[i]
              : await file.readAsBytes();
          String filename = file.name;
          if (!filename.contains('.')) {
            filename = '$filename.jpg';
          }
          final String uploadIdStr = await ref
              .read(chatRepositoryProvider)
              .uploadStreamInChunks(
                bytes: fileBytes,
                filename: filename,
                mediaSubtype: 'media',
                fileSize: fileBytes.length,
                onProgress: (_, _) {},
              );
          if (uploadIdStr.isNotEmpty) {
            uploadIds.add(uploadIdStr);
          }
        }
      }

      await ref.read(niosgramProvider.notifier).createPost(
            text,
            uploadIds: uploadIds,
            uploadId: uploadIds?.firstOrNull,
          );

      if (mounted) {
        if (ref.read(uiSettingsProvider).haptics) HapticService.confirm();
        AppToast.showSuccess(context, 'Публикация добавлена');
        _collapse();
      }
    } catch (e) {
      if (ref.read(uiSettingsProvider).haptics) HapticService.destructive();
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AuthState auth = ref.watch(authProvider);
    final String displayName = auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: isDark ? 0.20 : 0.35,
          ),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      padding: EdgeInsets.all(_isExpanded ? 16 : 10),
      child: !_isExpanded
          // Collapsed single-line bar
          ? Row(
              children: <Widget>[
                PulseAvatar(
                  name: displayName,
                  avatarUrl: auth.profile?.avatarUrl,
                  radius: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _expand,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: isDark ? 0.35 : 0.45,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Что у вас нового?',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  child: Tooltip(
                    message: 'Добавить фото',
                    child: InkWell(
                      onTap: _pickMedia,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          // Expanded inline composer
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Header
                Row(
                  children: <Widget>[
                    PulseAvatar(
                      name: displayName,
                      avatarUrl: auth.profile?.avatarUrl,
                      radius: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            displayName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Новая публикация',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Свернуть',
                      onPressed: _isLoading ? null : _collapse,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Text field
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: isDark ? 0.30 : 0.40,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: 6,
                    minLines: 3,
                    style: textTheme.bodyLarge?.copyWith(fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: 'Что у вас нового?',
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                // Selected media preview (compact horizontal strip)
                if (_previewBytesList.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _previewBytesList.length +
                          (_previewBytesList.length < 5 ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == _previewBytesList.length) {
                          // [+] Slot to add more photos
                          return Material(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _isLoading ? null : _pickMedia,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: scheme.outlineVariant
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Icons.add_photo_alternate_rounded,
                                      size: 22,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Ещё',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return Stack(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _previewBytesList[index],
                                width: 76,
                                height: 76,
                                cacheWidth: 200,
                                cacheHeight: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 3,
                              right: 3,
                              child: Material(
                                color: scheme.scrim.withValues(alpha: 0.65),
                                shape: const CircleBorder(),
                                child: Tooltip(
                                  message: 'Удалить фото',
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => setState(() {
                                      _selectedFiles.removeAt(index);
                                      _previewBytesList.removeAt(index);
                                    }),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 13,
                                        color: scheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],

                // Error message
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: scheme.onErrorContainer,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: scheme.onErrorContainer,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Bottom toolbar
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool isVeryNarrow = constraints.maxWidth < 310;
                    return Row(
                      children: <Widget>[
                        Tooltip(
                          message: _selectedFiles.isEmpty
                              ? 'Прикрепить фото'
                              : 'Прикреплено фото: ${_selectedFiles.length}/5',
                          child: IconButton.filledTonal(
                            onPressed: _isLoading || _selectedFiles.length >= 5
                                ? null
                                : _pickMedia,
                            icon: Badge(
                              isLabelVisible: _selectedFiles.isNotEmpty,
                              label: Text('${_selectedFiles.length}'),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 20,
                              ),
                            ),
                            style: IconButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_textController.text.isNotEmpty && !isVeryNarrow)
                          Text(
                            '${_textController.text.length} симв.',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isLoading ? null : _collapse,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Отмена', style: TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 4),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          icon: _isLoading
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 14),
                          label: Text(
                            isVeryNarrow ? 'Пост' : 'Опубликовать',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.symmetric(
                              horizontal: isVeryNarrow ? 10 : 14,
                              vertical: 0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

