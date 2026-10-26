import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/core/utils/app_error_formatter.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/widgets/notifications/notification_center.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/core/utils/smooth_scroll.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
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
import 'package:pulse_flutter/widgets/post_media_strip.dart';

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
        actions: const <Widget>[_NotificationsBell(), SizedBox(width: 8)],
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

// ── Inline Quick Create Composer (Threads / X style) ───────────────────
class _CompactQuickCreateBar extends ConsumerStatefulWidget {
  const _CompactQuickCreateBar();

  @override
  ConsumerState<_CompactQuickCreateBar> createState() =>
      _CompactQuickCreateBarState();
}

class _CompactQuickCreateBarState
    extends ConsumerState<_CompactQuickCreateBar> {
  bool _isExpanded = false;
  final TextEditingController _textController = CustomEmojiTextController();
  final FocusNode _focusNode = FocusNode();
  List<PlatformFile> _selectedFiles = <PlatformFile>[];
  List<Uint8List> _previewBytesList = <Uint8List>[];
  bool _isLoading = false, _isPickingMedia = false;
  int _draftGeneration = 0;
  CancellationToken? _uploadCancellation;
  String? _error;

  static const int _maxPostLength = 2000;
  static const int _maxFileBytes = 10 * 1024 * 1024; // 10 MB

  @override
  void dispose() {
    _draftGeneration++;
    _uploadCancellation?.cancel();
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
    _draftGeneration++;
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

  Future<Uint8List> _readMediaBytes(
    PlatformFile file,
    String sizeError, {
    CancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final length = await file.length();
    if (length <= 0 || length > _maxFileBytes) throw FormatException(sizeError);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      cancellation?.throwIfCancelled();
      if (bytes.length + chunk.length > _maxFileBytes) {
        throw FormatException(sizeError);
      }
      bytes.add(chunk);
    }
    if (bytes.isEmpty) throw FormatException(sizeError);
    return bytes.takeBytes();
  }

  Future<void> _pickMedia() async {
    if (_isLoading ||
        _isPickingMedia ||
        ref.read(authProvider.notifier).isLoggingOut) {
      return;
    }
    final slots = 5 - _selectedFiles.length;
    if (slots <= 0) return;
    _isPickingMedia = true;
    final generation = _draftGeneration;
    final account = ref.read(authProvider).session;
    bool active() =>
        mounted &&
        generation == _draftGeneration &&
        !ref.read(authProvider.notifier).isLoggingOut &&
        ref.read(authProvider).session?.userId == account?.userId &&
        ref.read(authProvider).session?.accessToken == account?.accessToken;
    final sizeError = context.l10n.postFileTooLarge;
    try {
      final picked = await FilePicker.pickFiles(type: FileType.media);
      if (!active() || picked.isEmpty) return;
      final files = List<PlatformFile>.of(_selectedFiles);
      final previews = List<Uint8List>.of(_previewBytesList);
      for (final file in picked.take(slots)) {
        final bytes = await _readMediaBytes(file, sizeError);
        if (!active()) return;
        final compressed = await ImageCompressor.compressImageBytes(
          bytes: bytes,
          fileName: file.name,
        );
        if (!active()) return;
        files.add(file);
        previews.add(compressed ?? bytes);
      }
      if (!active()) return;
      setState(() {
        _isExpanded = true;
        _selectedFiles = files;
        _previewBytesList = previews;
        _error = null;
      });
    } catch (error) {
      if (active()) {
        setState(
          () => _error = AppErrorFormatter.format(
            error,
            l10n: context.l10n,
          ).toString(),
        );
      }
    } finally {
      _isPickingMedia = false;
    }
  }

  Future<void> _submit() async {
    if (_isLoading ||
        _isPickingMedia ||
        ref.read(authProvider.notifier).isLoggingOut) {
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty) {
      setState(() => _error = context.l10n.postEmptyContent);
      return;
    }
    final files = List<PlatformFile>.of(_selectedFiles);
    final previews = List<Uint8List>.of(_previewBytesList);
    final generation = _draftGeneration;
    final account = ref.read(authProvider).session;
    final repository = ref.read(chatRepositoryProvider),
        feed = ref.read(niosgramProvider.notifier);
    final sizeError = context.l10n.postFileTooLarge;
    final cancellation = CancellationToken();
    _uploadCancellation = cancellation;
    bool active() =>
        mounted &&
        generation == _draftGeneration &&
        !ref.read(authProvider.notifier).isLoggingOut &&
        ref.read(authProvider).session?.userId == account?.userId &&
        ref.read(authProvider).session?.accessToken == account?.accessToken;
    if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uploadIds = <String>[];
      for (var i = 0; i < files.length; i++) {
        cancellation.throwIfCancelled();
        if (!active()) return;
        final file = files[i];
        final bytes = i < previews.length && previews[i].isNotEmpty
            ? previews[i]
            : await _readMediaBytes(
                file,
                sizeError,
                cancellation: cancellation,
              );
        if (!active()) return;
        final id = await repository.uploadStreamInChunks(
          bytes: bytes,
          filename: file.name.contains('.') ? file.name : '${file.name}.jpg',
          mediaSubtype: 'media',
          fileSize: bytes.length,
          onProgress: (_, _) {},
          cancellationToken: cancellation,
        );
        if (!active()) return;
        if (id.isEmpty) throw StateError('empty_upload_id');
        uploadIds.add(id);
      }
      if (!active()) return;
      await feed.createPost(
        text,
        uploadIds: uploadIds,
        uploadId: uploadIds.firstOrNull,
      );
      if (!mounted || !active()) return;
      if (ref.read(uiSettingsProvider).haptics) HapticService.confirm();
      AppToast.showSuccess(context, context.l10n.auditPostPublished);
      // Preserve edits typed or inserted while this particular draft was pending.
      if (_textController.text.trim() == text) _collapse();
    } catch (error) {
      if (active() && !cancellation.isCancelled) {
        if (ref.read(uiSettingsProvider).haptics) HapticService.destructive();
        setState(
          () => _error = AppErrorFormatter.format(
            error,
            l10n: context.l10n,
          ).toString(),
        );
      }
    } finally {
      if (identical(_uploadCancellation, cancellation)) {
        _uploadCancellation = null;
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AuthState auth = ref.watch(authProvider);
    final String displayName =
        auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: M3SpringCurves.spatial,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.35),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: M3SpringCurves.spatial,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: !_isExpanded
                // Collapsed single-line bar
                ? KeyedSubtree(
                    key: const ValueKey<String>('collapsed_quick_bar'),
                    child: Row(
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
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: isDark ? 0.35 : 0.45),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  context.l10n.postHint,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.8,
                                    ),
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
                            message: context.l10n.postAttachMedia,
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
                    ),
                  )
                // Expanded inline composer
                : KeyedSubtree(
                    key: const ValueKey<String>('expanded_quick_composer'),
                    child: Column(
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
                                    context.l10n.postNewPost,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              tooltip: context.l10n.commonCancel,
                              onPressed: _isLoading ? null : _collapse,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Text field with M3 Expressive padding & geometry
                        Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: isDark ? 0.30 : 0.40,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLines: 6,
                            minLines: 1,
                            inputFormatters: [
                              CustomEmojiLengthFormatter(_maxPostLength),
                            ],
                            buildCounter:
                                (
                                  _, {
                                  required int currentLength,
                                  required bool isFocused,
                                  int? maxLength,
                                }) => null,
                            style: textTheme.bodyLarge?.copyWith(fontSize: 15),
                            decoration: InputDecoration(
                              hintText: context.l10n.postHint,
                              hintStyle: TextStyle(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),

                        // Selected media preview (reusable PostMediaStrip)
                        if (_previewBytesList.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          PostMediaStrip(
                            selectedFiles: _selectedFiles,
                            previewBytesList: _previewBytesList,
                            tileSize: 76,
                            isLoading: _isLoading,
                            onAdd: _pickMedia,
                            onRemove: (int index) {
                              setState(() {
                                _selectedFiles.removeAt(index);
                                _previewBytesList.removeAt(index);
                              });
                            },
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
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final bool isVeryNarrow =
                                    constraints.maxWidth < 310;
                                final int textLength = customEmojiLength(
                                  _textController.text,
                                );
                                final bool isNearLimit =
                                    textLength > (_maxPostLength - 200);

                                return Row(
                                  children: <Widget>[
                                    Tooltip(
                                      message: _selectedFiles.isEmpty
                                          ? context.l10n.postAttachMedia
                                          : '${context.l10n.postAttachMedia}: ${_selectedFiles.length}/5',
                                      child: IconButton.filledTonal(
                                        onPressed:
                                            _isLoading ||
                                                _selectedFiles.length >= 5
                                            ? null
                                            : _pickMedia,
                                        icon: Badge(
                                          isLabelVisible:
                                              _selectedFiles.isNotEmpty,
                                          label: Text(
                                            '${_selectedFiles.length}',
                                          ),
                                          child: const Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 20,
                                          ),
                                        ),
                                        style: IconButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (textLength > 0 && !isVeryNarrow)
                                      Text(
                                        '$textLength / $_maxPostLength',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: isNearLimit
                                              ? scheme.error
                                              : scheme.onSurfaceVariant
                                                    .withValues(alpha: 0.6),
                                          fontSize: 11,
                                          fontWeight: isNearLimit
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _isLoading ? null : _collapse,
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        context.l10n.commonCancel,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    FilledButton.icon(
                                      onPressed: _isLoading ? null : _submit,
                                      icon: _isLoading
                                          ? AppLoadingIndicator(
                                              size: 14,
                                              color: scheme.onPrimary,
                                            )
                                          : const Icon(
                                              Icons.send_rounded,
                                              size: 14,
                                            ),
                                      label: Text(
                                        isVeryNarrow
                                            ? 'Пост'
                                            : context.l10n.postPublish,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isVeryNarrow ? 10 : 14,
                                          vertical: 0,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
