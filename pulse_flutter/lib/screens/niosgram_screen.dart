import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/core/utils/smooth_scroll.dart';
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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: <Widget>[
          _NotificationsBell(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _buildFloatingActions(context, scheme),
      body: feedAsync.when(
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
                    delay: Duration(milliseconds: (postIndex % 10) * 50),
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

// ── Notification bell ─────────────────────────────────────────────────
class _NotificationsBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(notificationsProvider).unreadCount;

    return Stack(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: context.l10n.settingsPushNotifications,
          onPressed: () => context.push('/settings/privacy'),
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
  PlatformFile? _selectedFile;
  Uint8List? _previewBytes;
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
      _selectedFile = null;
      _previewBytes = null;
      _error = null;
    });
    _focusNode.unfocus();
  }

  Future<void> _pickMedia() async {
    final List<PlatformFile> result = await FilePicker.pickFiles(
      type: FileType.media,
    );
    if (result.isEmpty) return;
    final PlatformFile file = result.first;
    if ((await file.length()) > _maxFileBytes) {
      setState(() {
        _isExpanded = true;
        _error = context.l10n.postFileTooLarge;
      });
      return;
    }

    Uint8List previewBytes = await file.readAsBytes();
    final Uint8List? compressed = await ImageCompressor.compressImageBytes(
      bytes: previewBytes,
      fileName: file.name,
    );
    if (compressed != null) previewBytes = compressed;

    setState(() {
      _isExpanded = true;
      _selectedFile = file;
      _previewBytes = previewBytes;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final String text = _textController.text.trim();
    if (text.isEmpty && _selectedFile == null) {
      setState(() => _error = context.l10n.postEmptyContent);
      return;
    }

    if (ref.read(uiSettingsProvider).haptics) HapticService.tap();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      int? uploadId;
      if (_selectedFile != null) {
        final PlatformFile file = _selectedFile!;
        final Uint8List fileBytes = await file.readAsBytes();
        final String uploadIdStr = await ref
            .read(chatRepositoryProvider)
            .uploadStreamInChunks(
              bytes: fileBytes,
              filename: file.name,
              mediaSubtype: 'media',
              fileSize: fileBytes.length,
              onProgress: (_, _) {},
            );
        uploadId = int.tryParse(uploadIdStr);
      }

      await ref.read(niosgramProvider.notifier).createPost(
            text,
            uploadId: uploadId,
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

                // Selected media preview
                if (_previewBytes != null) ...<Widget>[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(
                            maxHeight: 320,
                            minHeight: 120,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Image.memory(
                            _previewBytes!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.60),
                            shape: const CircleBorder(),
                            child: Tooltip(
                              message: 'Удалить фото',
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => setState(() {
                                  _selectedFile = null;
                                  _previewBytes = null;
                                }),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickMedia,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(
                        _selectedFile == null ? 'Фото' : 'Заменить фото',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_textController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '${_textController.text.length} симв.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: _isLoading ? null : _collapse,
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 15),
                      label: const Text('Опубликовать'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

