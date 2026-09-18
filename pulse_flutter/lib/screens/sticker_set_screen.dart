import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/widgets/chat/add_sticker_dialog.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';

class StickerSetScreen extends ConsumerStatefulWidget {
  const StickerSetScreen({required this.setId, super.key});

  final int setId;

  @override
  ConsumerState<StickerSetScreen> createState() => _StickerSetScreenState();
}

class _StickerSetScreenState extends ConsumerState<StickerSetScreen> {
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _error;
  ApiStickerSet? _stickerSet;

  @override
  void initState() {
    super.initState();
    _loadStickerSet();
  }

  Future<void> _loadStickerSet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ApiStickerSet? set = await ref
          .read(stickerRepositoryProvider)
          .getStickerSet(widget.setId);
      if (!mounted) return;
      if (set == null) {
        setState(() {
          _error = 'Стикерпак не найден или недоступен';
          _isLoading = false;
        });
      } else {
        setState(() {
          _stickerSet = set;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить стикерпак: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSave(bool isInstalled) async {
    if (_stickerSet == null || _isActionLoading) return;
    final int setId = _stickerSet!.id;

    setState(() => _isActionLoading = true);
    HapticService.confirm();

    try {
      if (isInstalled) {
        await ref.read(stickerSetsProvider.notifier).removeStickerSet(setId);
        if (mounted) {
          setState(() {
            _stickerSet = _stickerSet?.copyWith(isSaved: false);
          });
          AppToast.showSuccess(context, 'Стикерпак удален из коллекции');
        }
      } else {
        await ref.read(stickerSetsProvider.notifier).saveStickerSet(setId);
        if (mounted) {
          setState(() {
            _stickerSet = _stickerSet?.copyWith(isSaved: true);
          });
          AppToast.showSuccess(context, 'Стикерпак добавлен в коллекцию');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _shareLink() async {
    final String url = _stickerSet?.shareUrl ??
        'https://ni-os.ru/stickers/${widget.setId}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    AppToast.showInfo(context, 'Ссылка на стикерпак скопирована');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<ApiStickerSet> installedSets =
        ref.watch(stickerSetsProvider).value ?? const <ApiStickerSet>[];

    final bool isInstalled = (_stickerSet?.isSaved ?? false) ||
        installedSets.any((ApiStickerSet s) => s.id == widget.setId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _stickerSet?.title.isNotEmpty == true
              ? _stickerSet!.title
              : 'Стикерпак',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/main/chats');
            }
          },
        ),
        actions: <Widget>[
          if (_stickerSet != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Поделиться',
              onPressed: _shareLink,
            ),
        ],
      ),
      body: PulseScaffoldBody(
        maxWidth: 720,
        child: _isLoading
            ? const Center(child: AppLoadingIndicator(size: 48))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.sentiment_dissatisfied_outlined,
                            size: 56,
                            color: scheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _loadStickerSet,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildContent(context, scheme, textTheme, isInstalled),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isInstalled,
  ) {
    final ApiStickerSet set = _stickerSet!;

    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.screenHorizontalPadding,
            16,
            AppConstants.screenHorizontalPadding,
            18,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      // Cover
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: set.coverSticker != null
                            ? CachedNetworkImage(
                                imageUrl: set.coverSticker!.resolvedUrl,
                                fit: BoxFit.contain,
                                memCacheWidth: 200,
                                memCacheHeight: 200,
                                errorWidget: (_, _, _) => Icon(
                                  Icons.sticky_note_2_outlined,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            : Icon(
                                Icons.sticky_note_2_outlined,
                                color: scheme.onSurfaceVariant,
                              ),
                      ),
                      const SizedBox(width: 16),
                      // Titles
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              set.title.isNotEmpty ? set.title : set.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${set.stickers.length} стикеров • @${set.name}',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons: Add/Remove + (if owner) Add stickers
                Row(
                  children: <Widget>[
                    if (set.isOwner == true) ...<Widget>[
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            HapticService.tap();
                            AddStickerDialog.show(
                              context,
                              setId: set.id,
                              setTitle: set.title,
                            );
                          },
                          icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                          label: const Text('Добавить'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size(0, 46),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: isInstalled
                          ? OutlinedButton.icon(
                              onPressed: _isActionLoading ? null : () => _toggleSave(true),
                              icon: _isActionLoading
                                  ? const AppLoadingIndicator(size: 16)
                                  : const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('Удалить из коллекции'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.error,
                                side: BorderSide(
                                  color: scheme.error.withValues(alpha: 0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                minimumSize: const Size(0, 46),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: _isActionLoading ? null : () => _toggleSave(false),
                              icon: _isActionLoading
                                  ? AppLoadingIndicator(
                                      size: 16,
                                      color: scheme.onPrimary,
                                    )
                                  : const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Добавить в коллекцию'),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                minimumSize: const Size(0, 46),
                              ),
                            ),
                    ),
                  ],
                ),

                // Stickers Grid Empty State
                if (set.stickers.isEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Text(
                      'В этом наборе пока нет стикеров',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (set.stickers.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              0,
              AppConstants.screenHorizontalPadding,
              16,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final ApiSticker sticker = set.stickers[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: sticker.resolvedUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: 200,
                      memCacheHeight: 200,
                      placeholder: (_, _) => AppLoadingIndicator(
                        size: 20,
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                      errorWidget: (_, _, _) => Center(
                        child: Text(
                          sticker.emoji.isNotEmpty ? sticker.emoji : '🖼️',
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  );
                },
                childCount: set.stickers.length,
              ),
            ),
          ),
      ],
    );
  }
}
