import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/widgets/chat/add_sticker_dialog.dart';
import 'package:pulse_flutter/widgets/chat/create_sticker_set_dialog.dart';
import 'package:pulse_flutter/widgets/chat/sticker_set_modal.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Material 3 Expressive Sticker Picker View with fluid spring physics,
/// bouncy press feedback, compact header, and animated squircle pack dock.
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
  final ScrollController _dockScrollController = ScrollController();

  @override
  void dispose() {
    _dockScrollController.dispose();
    super.dispose();
  }

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

  void _selectSet(int index) {
    HapticService.tap();
    setState(() => _selectedSetIndex = index);
    if (_dockScrollController.hasClients) {
      _dockScrollController.animateTo(
        (index * 48.0).clamp(0.0, _dockScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: M3SpringCurves.snappy,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final AsyncValue<List<ApiStickerSet>> stickerSetsAsync =
        ref.watch(stickerSetsProvider);

    return stickerSetsAsync.when(
      loading: () => AppLoadingIndicator(
        size: 32,
        color: scheme.primary,
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
            // Expressive compact pack header bar
            _buildPackHeader(context, currentSet, scheme, textTheme),

            // Main stickers area
            Expanded(
              child: currentSet.stickers.isEmpty
                  ? _buildEmptySetState(context, currentSet, scheme, textTheme)
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 88,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      // Stickers + inline quick-add tile at the end
                      itemCount: currentSet.stickers.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == currentSet.stickers.length) {
                          // Quick-add sticker tile at end of pack
                          return _buildAddStickerTile(context, scheme, currentSet);
                        }

                        final ApiSticker sticker = currentSet.stickers[index];
                        return _ExpressiveStickerTile(
                          sticker: sticker,
                          onTap: () => _sendSticker(sticker),
                          onLongPress: () {
                            HapticService.confirm();
                            StickerSetModal.show(
                              context,
                              stickerSet: currentSet,
                              onStickerSelected: _sendSticker,
                            );
                          },
                        );
                      },
                    ),
            ),

            // Material 3 Expressive squircle pack dock
            _buildPackDock(context, sets, activeIndex, scheme),
          ],
        );
      },
    );
  }

  Widget _buildAddStickerTile(
    BuildContext context,
    ColorScheme scheme,
    ApiStickerSet currentSet,
  ) {
    return TouchContainer(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticService.tap();
        AddStickerDialog.show(
          context,
          setId: currentSet.id,
          setTitle: currentSet.title,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
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

  Widget _buildPackHeader(
    BuildContext context,
    ApiStickerSet currentSet,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.65),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
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
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    Icons.sticky_note_2_outlined,
                    size: 15,
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
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
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
                    color: scheme.secondaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${currentSet.stickers.length}',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                      fontSize: 10,
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
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text(
              'Добавить',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: () {
              HapticService.tap();
              StickerSetModal.show(
                context,
                stickerSet: currentSet,
                onStickerSelected: _sendSticker,
              );
            },
            icon: const Icon(Icons.info_outline_rounded, size: 17),
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
              'Загрузите изображения или видеоанимации в этот набор',
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

  Widget _buildPackDock(
    BuildContext context,
    List<ApiStickerSet> sets,
    int activeIndex,
    ColorScheme scheme,
  ) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.separated(
        controller: _dockScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: sets.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          if (index == sets.length) {
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

          return GestureDetector(
            onTap: () => _selectSet(index),
            child: AnimatedScale(
              scale: isSelected ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: M3SpringCurves.bouncy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: M3SpringCurves.snappy,
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? scheme.primary : Colors.transparent,
                    width: 1.8,
                  ),
                  boxShadow: isSelected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
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
            ),
          );
        },
      ),
    );
  }
}

/// Bouncy animated sticker tile with Material 3 Expressive spring physics
class _ExpressiveStickerTile extends StatefulWidget {
  const _ExpressiveStickerTile({
    required this.sticker,
    required this.onTap,
    required this.onLongPress,
  });

  final ApiSticker sticker;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_ExpressiveStickerTile> createState() => _ExpressiveStickerTileState();
}

class _ExpressiveStickerTileState extends State<_ExpressiveStickerTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: M3SpringCurves.bouncy,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isPressed
                ? scheme.primaryContainer.withValues(alpha: 0.25)
                : scheme.surfaceContainerHigh.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isPressed
                  ? scheme.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: CachedNetworkImage(
            imageUrl: widget.sticker.resolvedUrl,
            fit: BoxFit.contain,
            memCacheWidth: 200,
            memCacheHeight: 200,
            placeholder: (_, _) => AppLoadingIndicator(
              size: 18,
              color: scheme.primary.withValues(alpha: 0.4),
            ),
            errorWidget: (_, _, _) => Icon(
              Icons.sticky_note_2_outlined,
              size: 26,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
