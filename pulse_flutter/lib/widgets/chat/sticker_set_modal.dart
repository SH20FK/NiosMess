import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/widgets/chat/add_sticker_dialog.dart';

class StickerSetModal extends ConsumerStatefulWidget {
  const StickerSetModal({
    super.key,
    this.stickerSet,
    this.setId,
    this.onStickerSelected,
  });

  final ApiStickerSet? stickerSet;
  final int? setId;
  final void Function(ApiSticker sticker)? onStickerSelected;

  static Future<void> show(
    BuildContext context, {
    ApiStickerSet? stickerSet,
    int? setId,
    void Function(ApiSticker sticker)? onStickerSelected,
  }) {
    return AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) => StickerSetModal(
        stickerSet: stickerSet,
        setId: setId,
        onStickerSelected: onStickerSelected,
      ),
    );
  }

  @override
  ConsumerState<StickerSetModal> createState() => _StickerSetModalState();
}

class _StickerSetModalState extends ConsumerState<StickerSetModal> {
  bool _isActionLoading = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<ApiStickerSet> installedSets =
        ref.watch(stickerSetsProvider).value ?? const <ApiStickerSet>[];

    // Resolve current sticker set
    ApiStickerSet? currentSet = widget.stickerSet;
    if (currentSet == null && widget.setId != null) {
      for (final ApiStickerSet s in installedSets) {
        if (s.id == widget.setId) {
          currentSet = s;
          break;
        }
      }
    }

    if (currentSet == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.sentiment_dissatisfied_outlined,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Стикерпак не найден',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final ApiStickerSet resolvedSet = currentSet;
    final bool isInstalled =
        installedSets.any((ApiStickerSet s) => s.id == resolvedSet.id);

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
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: resolvedSet.coverSticker != null
                      ? CachedNetworkImage(
                          imageUrl: resolvedSet.coverSticker!.url,
                          fit: BoxFit.contain,
                          memCacheWidth: 160,
                          memCacheHeight: 160,
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
                // Install or Remove button
                isInstalled
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
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
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
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
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
                                  imageUrl: sticker.url,
                                  fit: BoxFit.contain,
                                  memCacheWidth: 200,
                                  memCacheHeight: 200,
                                  placeholder: (_, _) => Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.primary
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => Icon(
                                    Icons.broken_image_outlined,
                                    size: 24,
                                    color: scheme.onSurfaceVariant,
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
