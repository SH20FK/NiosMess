import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/widgets/chat/add_sticker_dialog.dart';
import 'package:pulse_flutter/widgets/chat/create_sticker_set_dialog.dart';
import 'package:pulse_flutter/widgets/chat/sticker_set_modal.dart';

class StickerPickerView extends ConsumerStatefulWidget {
  const StickerPickerView({
    super.key,
    this.chatId,
    this.onStickerSelected,
  });

  final int? chatId;
  final void Function(ApiSticker sticker)? onStickerSelected;

  @override
  ConsumerState<StickerPickerView> createState() => _StickerPickerViewState();
}

class _StickerPickerViewState extends ConsumerState<StickerPickerView> {
  int _selectedSetIndex = 0;

  void _sendSticker(ApiSticker sticker) {
    HapticService.tap();
    if (widget.onStickerSelected != null) {
      widget.onStickerSelected!(sticker);
    } else if (widget.chatId != null) {
      ref
          .read(chatMessagesProvider(widget.chatId!).notifier)
          .sendSticker(sticker.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final AsyncValue<List<ApiStickerSet>> stickerSetsAsync =
        ref.watch(stickerSetsProvider);

    return stickerSetsAsync.when(
      loading: () => Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: scheme.primary,
          ),
        ),
      ),
      error: (Object error, StackTrace? _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded,
                size: 36, color: scheme.error),
            const SizedBox(height: 8),
            Text(
              'Не удалось загрузить стикеры',
              style: textTheme.bodyMedium?.copyWith(color: scheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => ref.refresh(stickerSetsProvider),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
      data: (List<ApiStickerSet> sets) {
        if (sets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.sticky_note_2_rounded,
                      size: 36,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'У вас пока нет стикерпаков',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Создайте свой первый стикерпак и добавьте любимые стикеры',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => CreateStickerSetDialog.show(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Создать стикерпак'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final int activeIndex = _selectedSetIndex.clamp(0, sets.length - 1);
        final ApiStickerSet currentSet = sets[activeIndex];

        return Column(
          children: <Widget>[
            // Google Pixel pack header bar
            _buildPackHeader(context, currentSet, scheme, textTheme),

            // Main stickers area
            Expanded(
              child: currentSet.stickers.isEmpty
                  ? _buildEmptySetState(context, currentSet, scheme, textTheme)
                  : GridView.builder(
                      padding: const EdgeInsets.all(10),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 88,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: currentSet.stickers.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          // Pixel Expressive quick-add tile
                          return InkWell(
                            onTap: () {
                              HapticService.tap();
                              AddStickerDialog.show(
                                context,
                                setId: currentSet.id,
                                setTitle: currentSet.title,
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: scheme.outlineVariant
                                      .withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 24,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Добавить',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final ApiSticker sticker =
                            currentSet.stickers[index - 1];
                        return InkWell(
                          onTap: () => _sendSticker(sticker),
                          onLongPress: () {
                            HapticService.confirm();
                            StickerSetModal.show(
                              context,
                              stickerSet: currentSet,
                              onStickerSelected: _sendSticker,
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh
                                  .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: sticker.resolvedUrl,
                              fit: BoxFit.contain,
                              memCacheWidth: 160,
                              memCacheHeight: 160,
                              placeholder: (_, _) => Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.primary
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              errorWidget: (_, _, _) => Icon(
                                Icons.sticky_note_2_outlined,
                                size: 24,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Google Pixel bottom capsule pack dock
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                itemCount: sets.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) {
                  if (index == sets.length) {
                    // "+" button to add or create pack
                    return IconButton(
                      onPressed: () {
                        HapticService.tap();
                        CreateStickerSetDialog.show(context);
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
                      tooltip: 'Создать стикерпак',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest,
                        foregroundColor: scheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );
                  }

                  final ApiStickerSet s = sets[index];
                  final bool isSelected = index == activeIndex;

                  return InkWell(
                    onTap: () {
                      HapticService.tap();
                      setState(() => _selectedSetIndex = index);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.secondaryContainer
                            : scheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : Colors.transparent,
                          width: 1.8,
                        ),
                      ),
                      child: s.coverSticker != null
                          ? CachedNetworkImage(
                              imageUrl: s.coverSticker!.resolvedUrl,
                              fit: BoxFit.contain,
                              memCacheWidth: 80,
                              memCacheHeight: 80,
                              errorWidget: (_, _, _) => Icon(
                                Icons.sticky_note_2_outlined,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : Icon(
                              Icons.sticky_note_2_outlined,
                              size: 18,
                              color: isSelected
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPackHeader(
    BuildContext context,
    ApiStickerSet currentSet,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: currentSet.coverSticker != null
                ? CachedNetworkImage(
                    imageUrl: currentSet.coverSticker!.resolvedUrl,
                    fit: BoxFit.contain,
                    memCacheWidth: 64,
                    memCacheHeight: 64,
                    errorWidget: (_, _, _) => Icon(
                      Icons.sticky_note_2_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    Icons.sticky_note_2_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    currentSet.title.isNotEmpty
                        ? currentSet.title
                        : currentSet.name,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${currentSet.stickers.length}',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () {
              HapticService.tap();
              AddStickerDialog.show(
                context,
                setId: currentSet.id,
                setTitle: currentSet.title,
              );
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'Добавить',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              HapticService.tap();
              StickerSetModal.show(
                context,
                stickerSet: currentSet,
                onStickerSelected: _sendSticker,
              );
            },
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            tooltip: 'О стикерпаке',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySetState(
    BuildContext context,
    ApiStickerSet currentSet,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                size: 34,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'В этом наборе пока нет стикеров',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Загрузите изображения, мемы или видеоанимации в «${currentSet.title.isNotEmpty ? currentSet.title : currentSet.name}»',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                HapticService.confirm();
                AddStickerDialog.show(
                  context,
                  setId: currentSet.id,
                  setTitle: currentSet.title,
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Добавить стикеры'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
