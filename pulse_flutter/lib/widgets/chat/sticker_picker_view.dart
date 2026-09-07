import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
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
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 48,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'У вас пока нет стикерпаков',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Создайте свой первый стикерпак прямо сейчас',
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
            // Main stickers grid
            Expanded(
              child: currentSet.stickers.isEmpty
                  ? Center(
                      child: Text(
                        'В этом наборе нет стикеров',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: currentSet.stickers.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ApiSticker sticker = currentSet.stickers[index];
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
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: sticker.url,
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

            // Horizontal pack selector bar
            Container(
              height: 48,
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
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          borderRadius: BorderRadius.circular(10),
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
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.secondaryContainer
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: s.coverSticker != null
                          ? CachedNetworkImage(
                              imageUrl: s.coverSticker!.url,
                              fit: BoxFit.contain,
                              memCacheWidth: 72,
                              memCacheHeight: 72,
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
}
