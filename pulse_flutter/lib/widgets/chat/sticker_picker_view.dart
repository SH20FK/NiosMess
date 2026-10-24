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
  const StickerPickerView({this.chatId, this.onStickerSelected, super.key});
  final int? chatId;
  final void Function(ApiSticker)? onStickerSelected;
  @override
  ConsumerState<StickerPickerView> createState() => _StickerPickerViewState();
}

class _StickerPickerViewState extends ConsumerState<StickerPickerView>
    with AutomaticKeepAliveClientMixin {
  int? _selectedSetId; // Null is Recent, not a disappearing first pack.
  final _search = TextEditingController();
  String _query = '';
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l.stickerHubSearch,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
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
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: active == null,
                  avatar: const Icon(Icons.history_rounded, size: 18),
                  label: Text(l.stickerHubRecent),
                  onSelected: (_) => setState(() => _selectedSetId = null),
                ),
              ),
              for (final set in sets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: set.id == active?.id,
                    label: Text(set.title.isEmpty ? set.name : set.title),
                    onSelected: (_) => setState(() => _selectedSetId = set.id),
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
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
      excludeSemantics: true, onTap: widget.onTap, onLongPress: widget.onLongPress,
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
