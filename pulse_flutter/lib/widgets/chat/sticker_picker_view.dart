import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/widgets/chat/expression_picker_components.dart';
import 'dart:async';
import 'package:pulse_flutter/core/utils/noto_emoji.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/recent_stickers_provider.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/widgets/chat/add_sticker_dialog.dart';
import 'package:pulse_flutter/widgets/chat/create_sticker_set_dialog.dart';
import 'package:pulse_flutter/widgets/chat/sticker_set_details_sheet.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_sticker_player.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class StickerPickerView extends ConsumerStatefulWidget {
  const StickerPickerView({
    this.chatId,
    this.onStickerSelected,
    this.selectedSetId,
    this.onSetSelected,
    this.onSearchFocus,
    this.showManagement = true,
    super.key,
  });
  final int? chatId;
  final int? selectedSetId;
  final ValueChanged<int?>? onSetSelected;
  final VoidCallback? onSearchFocus;
  final bool showManagement;
  final void Function(ApiSticker)? onStickerSelected;
  @override
  ConsumerState<StickerPickerView> createState() => StickerPickerViewState();
}

class StickerPickerViewState extends ConsumerState<StickerPickerView>
    with AutomaticKeepAliveClientMixin {
  late int? _selectedSetId =
      widget.selectedSetId; // Null is Recent, not a disappearing first pack.
  String _query = '';
  @override
  bool get wantKeepAlive => true;
  @override
  void didUpdateWidget(covariant StickerPickerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSetId != widget.selectedSetId) {
      _selectedSetId = widget.selectedSetId;
    }
  }

  void _selectSet(int? id) {
    setState(() => _selectedSetId = id);
    widget.onSetSelected?.call(id);
  }

  Future<void> showManagement() async {
    final sets = ref.read(stickerSetsProvider).value ?? const <ApiStickerSet>[];
    final active = sets.where((pack) => pack.id == _selectedSetId).firstOrNull;
    final action = await AppModal.showSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(context.l10n.pickerManage),
                subtitle: active == null ? null : Text(active.title),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text(context.l10n.stickerHubCreate),
                onTap: () => Navigator.pop(context, 'create'),
              ),
              if (active != null) ...[
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(context.l10n.stickerHubDetails),
                  onTap: () => Navigator.pop(context, 'details'),
                ),
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: Text(context.l10n.stickerHubAdd),
                  onTap: () => Navigator.pop(context, 'add'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'create') {
      await CreateStickerSetDialog.show(context);
      return;
    }
    if (action == 'details' && active != null) {
      await StickerSetDetailsSheet.show(
        context,
        stickerSet: active,
        onStickerSelected: _send,
      );
    }
    if (!mounted) return;
    if (action == 'add' && active != null) {
      await AddStickerDialog.show(
        context,
        setId: active.id,
        setTitle: active.title,
      );
    }
  }

  void _send(ApiSticker sticker) {
    unawaited(ref.read(recentStickersProvider.notifier).record(sticker.id));
    if (widget.onStickerSelected != null) {
      widget.onStickerSelected!(sticker);
    } else if (widget.chatId != null) {
      unawaited(
        ref
            .read(chatMessagesProvider(widget.chatId!).notifier)
            .sendSticker(sticker.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme, l = context.l10n;
    final asyncSets = ref.watch(stickerSetsProvider);
    final sets = asyncSets.value ?? const <ApiStickerSet>[];
    final recent = ref.watch(recentStickersProvider).value ?? const <int>[];
    final byId = <int, ApiSticker>{
      for (final set in sets)
        for (final sticker in set.stickers) sticker.id: sticker,
    };
    final active = sets.where((s) => s.id == _selectedSetId).firstOrNull;
    final query = _query.trim().toLowerCase();
    final items = query.isNotEmpty
        ? <ApiSticker>[
            for (final set in sets)
              for (final sticker in set.stickers)
                if (sticker.emoji.toLowerCase().contains(query) ||
                    set.title.toLowerCase().contains(query) ||
                    set.name.toLowerCase().contains(query))
                  sticker,
          ]
        : active != null
        ? active.stickers
        : [
            for (final id in recent)
              if (byId[id] != null) byId[id]!,
          ];
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (constraints.maxHeight >= 100)
            Row(
              children: [
                Expanded(
                  child: ExpressionSearchField(
                    initialValue: _query,
                    hint: l.stickerHubSearch,
                    onFocus: widget.onSearchFocus,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                if (widget.showManagement)
                  MenuAnchor(
                    builder: (_, controller, _) => IconButton(
                      tooltip: l.stickerHubDetails,
                      onPressed: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                    menuChildren: [
                      if (active != null)
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.info_outline_rounded),
                          onPressed: () => StickerSetDetailsSheet.show(
                            context,
                            stickerSet: active,
                            onStickerSelected: _send,
                          ),
                          child: Text(l.stickerHubDetails),
                        ),
                      if (active != null)
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.add_rounded),
                          onPressed: () => AddStickerDialog.show(
                            context,
                            setId: active.id,
                            setTitle: active.title,
                          ),
                          child: Text(l.stickerHubAdd),
                        ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.playlist_add_rounded),
                        onPressed: () => CreateStickerSetDialog.show(context),
                        child: Text(l.stickerHubCreate),
                      ),
                    ],
                  ),
              ],
            ),
          if (constraints.maxHeight >= 160)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  ExpressionPackButton(
                    label: l.stickerHubRecent,
                    selected: active == null,
                    onTap: () => _selectSet(null),
                    child: const Icon(Icons.history_rounded),
                  ),
                  for (final set in sets)
                    ExpressionPackButton(
                      label: set.title.isEmpty ? set.name : set.title,
                      selected: set.id == active?.id,
                      onTap: () => _selectSet(set.id),
                      child:
                          set.stickers.isEmpty || set.stickers.first.isAnimated
                          ? const Icon(Icons.sticky_note_2_outlined)
                          : CachedNetworkImage(
                              imageUrl: set.stickers.first.resolvedUrl,
                              width: 30,
                              height: 30,
                              memCacheWidth: 72,
                              memCacheHeight: 72,
                              errorWidget: (_, _, _) =>
                                  const Icon(Icons.sticky_note_2_outlined),
                            ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: asyncSets.isLoading && sets.isEmpty
                ? const Center(child: AppLoadingIndicator(size: 32))
                : asyncSets.hasError && sets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.stickerHubLoadError),
                        TextButton(
                          onPressed: () => ref.invalidate(stickerSetsProvider),
                          child: Text(l.commonRetry),
                        ),
                      ],
                    ),
                  )
                : items.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 36,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            query.isEmpty
                                ? l.stickerHubEmpty
                                : l.stickerHubNoResults,
                          ),
                          if (query.isEmpty) ...[
                            Text(
                              l.stickerHubEmptyHint,
                              textAlign: TextAlign.center,
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  CreateStickerSetDialog.show(context),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(l.stickerHubCreate),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    key: PageStorageKey('stickers:${active?.id}:$query'),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    physics: kIsWeb ? const ClampingScrollPhysics() : null,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 112,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final sticker = items[index];
                      return _StickerTile(
                        key: ValueKey(sticker.id),
                        sticker: sticker,
                        onTap: () => _send(sticker),
                        onLongPress: () {
                          final pack = sets
                              .where(
                                (s) =>
                                    s.stickers.any((st) => st.id == sticker.id),
                              )
                              .firstOrNull;
                          if (pack != null) {
                            StickerSetDetailsSheet.show(
                              context,
                              stickerSet: pack,
                              onStickerSelected: _send,
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StickerTile extends StatefulWidget {
  const _StickerTile({
    required this.sticker,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });
  final ApiSticker sticker;
  final VoidCallback onTap, onLongPress;
  @override
  State<_StickerTile> createState() => _StickerTileState();
}

class _StickerTileState extends State<_StickerTile> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Text(
        widget.sticker.emoji.isEmpty ? '▧' : widget.sticker.emoji,
        style: const TextStyle(fontSize: 28, fontFamily: NotoEmoji.fontFamily),
      ),
    );
    return Semantics(
      excludeSemantics: true,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      button: true,
      label: widget.sticker.emoji.isEmpty
          ? context.l10n.stickerHubStickers
          : widget.sticker.emoji,
      child: AnimatedScale(
        scale: _pressed ? .94 : 1,
        duration: M3Durations.short4,
        curve: M3SpringCurves.snappy,
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: RepaintBoundary(
                child: widget.sticker.isAnimated
                    ? StickerVideoPlayer(
                        url: widget.sticker.resolvedUrl,
                        placeholder: fallback,
                      )
                    : CachedNetworkImage(
                        imageUrl: widget.sticker.resolvedUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: 224,
                        memCacheHeight: 224,
                        placeholder: (_, _) => fallback,
                        errorWidget: (_, _, _) => fallback,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
