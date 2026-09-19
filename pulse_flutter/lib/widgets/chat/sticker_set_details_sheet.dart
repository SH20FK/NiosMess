import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/services/sticker_set_resolver.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/widgets/chat/add_sticker_dialog.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Material 3 Expressive bottom sheet for viewing sticker pack details,
/// installing/removing sticker sets, or adding new stickers.
class StickerSetDetailsSheet extends ConsumerStatefulWidget {
  const StickerSetDetailsSheet({
    this.stickerSet,
    this.setId,
    this.stickerId,
    this.onStickerSelected,
    super.key,
  });

  final ApiStickerSet? stickerSet;
  final int? setId;
  final int? stickerId;
  final void Function(ApiSticker sticker)? onStickerSelected;

  /// Canonical single entry point to display a sticker set for a specific sticker.
  /// Uses [StickerSetResolver] under the hood to ensure consistent caching,
  /// error handling, and to guarantee that empty sheets are never shown.
  static Future<void> showForSticker(
    BuildContext context, {
    required int stickerId,
    int? knownSetId,
    void Function(ApiSticker sticker)? onStickerSelected,
  }) {
    return AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) => StickerSetDetailsSheet(
        setId: knownSetId,
        stickerId: stickerId,
        onStickerSelected: onStickerSelected,
      ),
    );
  }

  static Future<void> show(
    BuildContext context, {
    ApiStickerSet? stickerSet,
    int? setId,
    int? stickerId,
    void Function(ApiSticker sticker)? onStickerSelected,
  }) {
    return AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) => StickerSetDetailsSheet(
        stickerSet: stickerSet,
        setId: setId,
        stickerId: stickerId,
        onStickerSelected: onStickerSelected,
      ),
    );
  }

  @override
  ConsumerState<StickerSetDetailsSheet> createState() =>
      _StickerSetDetailsSheetState();
}

/// Backward compatibility alias for [StickerSetDetailsSheet].
typedef StickerSetModal = StickerSetDetailsSheet;

class _StickerSetDetailsSheetState extends ConsumerState<StickerSetDetailsSheet> {
  bool _isActionLoading = false;
  bool _isFetchingSet = false;
  bool _hasFetchError = false;
  ApiStickerSet? _fetchedSet;

  @override
  void initState() {
    super.initState();
    _fetchSetIfNeeded();
  }

  Future<void> _fetchSetIfNeeded() async {
    final int? targetId = widget.setId ?? widget.stickerSet?.id;
    final int? targetStickerId = widget.stickerId;

    if ((targetId == null || targetId <= 0) &&
        (targetStickerId == null || targetStickerId <= 0)) {
      return;
    }

    // If sticker set with stickers is already provided, check if it has stickers
    if (widget.stickerSet != null && widget.stickerSet!.stickers.isNotEmpty) {
      return;
    }

    final List<ApiStickerSet>? installed = ref.read(stickerSetsProvider).value;
    if (installed != null) {
      final ApiStickerSet? cached = installed.cast<ApiStickerSet?>().firstWhere(
            (ApiStickerSet? s) =>
                ((targetId != null && s?.id == targetId) ||
                 (targetStickerId != null &&
                  s?.stickers.any((ApiSticker st) => st.id == targetStickerId) == true)) &&
                (s?.stickers.isNotEmpty == true),
            orElse: () => null,
          );
      if (cached != null) {
        if (mounted) setState(() => _fetchedSet = cached);
        return;
      }
    }

    setState(() {
      _isFetchingSet = true;
      _hasFetchError = false;
    });

    try {
      final ApiStickerSet? fetched = await ref.read(stickerSetResolverProvider).resolveForSticker(
            stickerId: targetStickerId ?? 0,
            knownSetId: targetId,
          );
      if (mounted) {
        setState(() {
          _fetchedSet = fetched;
          _isFetchingSet = false;
          _hasFetchError = fetched == null || fetched.stickers.isEmpty;
        });
      }
    } catch (e) {
      debugPrint('[StickerSetDetailsSheet] Failed to resolve set: $e');
      if (mounted) {
        setState(() {
          _isFetchingSet = false;
          _hasFetchError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<ApiStickerSet> installedSets =
        ref.watch(stickerSetsProvider).value ?? const <ApiStickerSet>[];

    // Resolve current sticker set with reliable precedence
    final ApiStickerSet? provided = widget.stickerSet;
    ApiStickerSet? currentSet;
    if (provided != null && provided.stickers.isNotEmpty) {
      currentSet = provided;
    } else if (_fetchedSet != null && _fetchedSet!.stickers.isNotEmpty) {
      currentSet = _fetchedSet;
    } else {
      currentSet = _fetchedSet ?? provided;
    }

    final int? targetId =
        widget.setId ?? widget.stickerSet?.id ?? _fetchedSet?.id;
    final int? targetStickerId = widget.stickerId;
    if ((currentSet == null || currentSet.stickers.isEmpty) &&
        (targetId != null || targetStickerId != null)) {
      for (final ApiStickerSet s in installedSets) {
        if ((targetId != null && s.id == targetId) ||
            (targetStickerId != null &&
             s.stickers.any((ApiSticker st) => st.id == targetStickerId))) {
          if (s.stickers.isNotEmpty) {
            currentSet = s;
            break;
          }
        }
      }
    }

    if (_isFetchingSet && (currentSet == null || currentSet.stickers.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Center(
          child: AppLoadingIndicator(
            color: scheme.primary,
          ),
        ),
      );
    }

    if (_hasFetchError && (currentSet == null || currentSet.stickers.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_rounded,
                size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'Не удалось загрузить стикерпак',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _fetchSetIfNeeded,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить попытку'),
            ),
          ],
        ),
      );
    }

    if (currentSet == null || currentSet.stickers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.sentiment_dissatisfied_outlined,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              currentSet == null ? 'Стикерпак не найден' : 'В наборе нет стикеров',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _fetchSetIfNeeded,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить попытку'),
            ),
          ],
        ),
      );
    }

    final ApiStickerSet resolvedSet = currentSet;
    final bool isInstalled = (resolvedSet.isSaved ?? false) ||
        installedSets.any((ApiStickerSet s) => s.id == resolvedSet.id);
    final int myUserId = ref.watch(authProvider).session?.userId ?? -1;
    final bool isOwner = resolvedSet.isOwner == true ||
        (resolvedSet.authorId != null && resolvedSet.authorId == myUserId);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header info
            Row(
              children: <Widget>[
                // Cover preview
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: resolvedSet.coverSticker != null
                      ? CachedNetworkImage(
                          imageUrl: resolvedSet.coverSticker!.resolvedUrl,
                          fit: BoxFit.cover,
                          placeholder: (BuildContext ctx, String url) =>
                              Center(
                            child: AppLoadingIndicator(
                              size: 18,
                              color: scheme.primary,
                            ),
                          ),
                          errorWidget:
                              (BuildContext ctx, String url, Object error) =>
                                  Icon(
                            Icons.sticky_note_2_outlined,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : Icon(
                          Icons.sticky_note_2_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                ),
                const SizedBox(width: 14),

                // Titles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        resolvedSet.title.isNotEmpty
                            ? resolvedSet.title
                            : resolvedSet.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${resolvedSet.stickers.length} стикеров • @${resolvedSet.name}',
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
            const SizedBox(height: 16),

            // Primary actions: Add/Remove + Add Stickers
            Row(
              children: <Widget>[
                if (isOwner) ...<Widget>[
                  // Add Stickers button
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        HapticService.tap();
                        AddStickerDialog.show(
                          context,
                          setId: resolvedSet.id,
                          setTitle: resolvedSet.title,
                        );
                      },
                      icon: const Icon(Icons.add_photo_alternate_rounded,
                          size: 18),
                      label: const Text(
                        'Добавить стикеры',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // Install or Remove button
                Expanded(
                  child: isInstalled
                      ? OutlinedButton.icon(
                          onPressed: _isActionLoading
                              ? null
                              : () async {
                                  setState(() => _isActionLoading = true);
                                  HapticService.tap();
                                  try {
                                    await ref
                                        .read(stickerSetsProvider.notifier)
                                        .removeStickerSet(resolvedSet.id);
                                    if (mounted) {
                                      setState(() {
                                        _fetchedSet = (_fetchedSet ?? resolvedSet)
                                            .copyWith(isSaved: false);
                                      });
                                    }
                                    if (context.mounted) {
                                      AppToast.showSuccess(
                                        context,
                                        'Стикерпак удален из коллекции',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      AppToast.showError(
                                        context,
                                        'Не удалось удалить: $e',
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isActionLoading = false);
                                    }
                                  }
                                },
                          icon: _isActionLoading
                              ? const AppLoadingIndicator(size: 16)
                              : const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                          label: const Text('Удалить'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            side: BorderSide(
                              color: scheme.error.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size(0, 44),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _isActionLoading
                              ? null
                              : () async {
                                  setState(() => _isActionLoading = true);
                                  HapticService.confirm();
                                  try {
                                    await ref
                                        .read(stickerSetsProvider.notifier)
                                        .saveStickerSet(resolvedSet.id);
                                    if (mounted) {
                                      setState(() {
                                        _fetchedSet = (_fetchedSet ?? resolvedSet)
                                            .copyWith(isSaved: true);
                                      });
                                    }
                                    if (context.mounted) {
                                      AppToast.showSuccess(
                                        context,
                                        'Стикерпак добавлен в коллекцию',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      AppToast.showError(
                                        context,
                                        'Не удалось добавить: $e',
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isActionLoading = false);
                                    }
                                  }
                                },
                          icon: _isActionLoading
                              ? AppLoadingIndicator(
                                  size: 16,
                                  color: scheme.onPrimary,
                                )
                              : const Icon(Icons.add_rounded, size: 18),
                          label: const Text('В коллекцию'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grid of stickers
            Expanded(
              child: resolvedSet.stickers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 30,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'В этом наборе пока нет стикеров',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Добавьте стикеры прямо сейчас',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () {
                              HapticService.tap();
                              AddStickerDialog.show(
                                context,
                                setId: resolvedSet.id,
                                setTitle: resolvedSet.title,
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Загрузить стикеры'),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 84,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: resolvedSet.stickers.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ApiSticker sticker = resolvedSet.stickers[index];
                        return InkWell(
                          onTap: () {
                            HapticService.tap();
                            if (widget.onStickerSelected != null) {
                              Navigator.pop(context);
                              widget.onStickerSelected!(sticker);
                            } else if (sticker.emoji.isNotEmpty) {
                              AppToast.showSuccess(
                                context,
                                'Стикер: ${sticker.emoji}',
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                CachedNetworkImage(
                                  imageUrl: sticker.resolvedUrl,
                                  fit: BoxFit.contain,
                                  memCacheWidth: 200,
                                  memCacheHeight: 200,
                                  placeholder: (_, _) => AppLoadingIndicator(
                                    size: 20,
                                    color: scheme.primary
                                        .withValues(alpha: 0.5),
                                  ),
                                  errorWidget: (_, _, _) => Center(
                                    child: Text(
                                      sticker.emoji.isNotEmpty
                                            ? sticker.emoji
                                            : '🖼️',
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                                if (sticker.emoji.isNotEmpty)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest
                                            .withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        sticker.emoji,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
