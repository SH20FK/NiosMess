import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/noto_emoji.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_picker.dart';
import 'package:pulse_flutter/widgets/chat/sticker_picker_view.dart';
import 'package:pulse_flutter/widgets/chat/expression_picker_components.dart';
import 'package:pulse_flutter/widgets/chat/unicode_emoji_picker_view.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

enum ExpressionMode { emoji, custom, stickers }

class ExpressionPickerPanel extends StatefulWidget {
  const ExpressionPickerPanel({
    required this.inputController,
    required this.onStickerSelected,
    required this.onClose,
    required this.onBackspace,
    required this.onExpandedChanged,
    this.onHandleDragUpdate,
    this.onHandleDragEnd,
    this.initialMode = ExpressionMode.emoji,
    super.key,
  });
  final TextEditingController inputController;
  final ValueChanged<ApiSticker> onStickerSelected;
  final VoidCallback onClose, onBackspace;
  final ValueChanged<bool> onExpandedChanged;

  /// Finger movement on the header since the last update; positive is down.
  final ValueChanged<double>? onHandleDragUpdate;

  /// Finger velocity when the header drag ends; positive is down. Called
  /// before the drag decides to expand, collapse or close.
  final ValueChanged<double>? onHandleDragEnd;
  final ExpressionMode initialMode;
  @override
  State<ExpressionPickerPanel> createState() => _ExpressionPickerPanelState();
}

class _ExpressionPickerPanelState extends State<ExpressionPickerPanel> {
  late ExpressionMode _mode = widget.initialMode;
  late final PageController _pages = PageController(initialPage: _mode.index);
  final _customKey = GlobalKey<CustomEmojiPickerState>();
  final _stickerKey = GlobalKey<StickerPickerViewState>();
  final _storage = PageStorageBucket();
  static const double _flingVelocity = 700;
  bool _expanded = false, _library = false;
  double _drag = 0;
  int? _stickerSet, _customSet;
  Category _category = Category.SMILEYS;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _expand({required bool library}) {
    setState(() {
      _expanded = true;
      _library = library;
    });
    widget.onExpandedChanged(true);
  }

  void _collapse() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _expanded = false;
      _library = false;
    });
    widget.onExpandedChanged(false);
  }

  void _select(ExpressionMode mode) {
    if (_mode == mode) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _mode = mode);
    if (_pages.hasClients) {
      if (context.reduceMotion || _library) {
        _pages.jumpToPage(mode.index);
      } else {
        _pages.animateToPage(
          mode.index,
          duration: M3Durations.medium2,
          curve: M3SpringCurves.spatialDefault,
        );
      }
    }
  }

  String _label(BuildContext context, ExpressionMode mode) => switch (mode) {
    ExpressionMode.emoji => context.l10n.stickerHubEmoji,
    ExpressionMode.custom => context.l10n.pickerCustom,
    ExpressionMode.stickers => context.l10n.stickerHubStickers,
  };
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PageStorage(
      bucket: _storage,
      child: Material(
        color: scheme.surfaceContainerLow,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: SizedBox(
              height: math.max(220, constraints.maxHeight),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) => _drag = 0,
                    onVerticalDragCancel: () =>
                        widget.onHandleDragEnd?.call(0),
                    onVerticalDragUpdate: (details) {
                      _drag += details.delta.dy;
                      widget.onHandleDragUpdate?.call(details.delta.dy);
                    },
                    onVerticalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0.0;
                      widget.onHandleDragEnd?.call(velocity);
                      // A fling decides on its own and overrides the distance.
                      final up =
                          velocity < -_flingVelocity ||
                          (velocity <= _flingVelocity && _drag < -24);
                      final down =
                          velocity > _flingVelocity ||
                          (velocity >= -_flingVelocity && _drag > 24);
                      if (up) {
                        _expand(library: true);
                      } else if (down) {
                        _expanded ? _collapse() : widget.onClose();
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const ValueKey('expression-library-toggle'),
                              onPressed: _expanded
                                  ? _collapse
                                  : () => _expand(library: true),
                              icon: Icon(
                                _expanded
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.expand_less_rounded,
                              ),
                              label: Text(
                                _expanded
                                    ? context.l10n.pickerCompact
                                    : context.l10n.pickerLibrary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        if (_expanded && !_library)
                          IconButton(
                            tooltip: context.l10n.pickerLibrary,
                            onPressed: () => _expand(library: true),
                            icon: const Icon(Icons.grid_view_rounded),
                          ),
                        if (_mode != ExpressionMode.stickers)
                          IconButton(
                            key: const ValueKey('expression-backspace'),
                            tooltip: context.l10n.commonDelete,
                            onPressed: widget.onBackspace,
                            icon: const Icon(
                              Icons.backspace_outlined,
                              size: 21,
                            ),
                          ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Offstage(
                          offstage: _library,
                          child: ExcludeFocus(
                            excluding: _library,
                            child: TickerMode(
                              enabled: !_library,
                              child: PageView(
                                key: const ValueKey('expression-pages'),
                                controller: _pages,
                                onPageChanged: (page) {
                                  if (!_library && _mode.index != page) {
                                    setState(
                                      () => _mode = ExpressionMode.values[page],
                                    );
                                  }
                                },
                                children: [
                                  _KeepAlive(
                                    child: EmojiPicker(
                                      textEditingController:
                                          widget.inputController,
                                      config: Config(
                                        height: null,
                                        checkPlatformCompatibility: false,
                                        locale: Localizations.localeOf(context),
                                        emojiTextStyle: const TextStyle(
                                          fontFamily: NotoEmoji.fontFamily,
                                        ),
                                        emojiViewConfig: const EmojiViewConfig(
                                          loadingIndicator: NotoPickerLoading(),
                                        ),
                                      ),
                                      customWidget:
                                          (config, state, showSearch) =>
                                              UnicodeEmojiPickerView(
                                                state: state,
                                                category: _category,
                                                onCategoryChanged: (value) =>
                                                    setState(
                                                      () => _category = value,
                                                    ),
                                                onSearchFocus: () =>
                                                    _expand(library: false),
                                              ),
                                    ),
                                  ),
                                  CustomEmojiPicker(
                                    key: _customKey,
                                    selectedSetId: _customSet,
                                    showManagement: false,
                                    onSetSelected: (id) =>
                                        setState(() => _customSet = id),
                                    onSearchFocus: () =>
                                        _expand(library: false),
                                    onSelected: (emoji) => insertCustomEmoji(
                                      widget.inputController,
                                      emoji,
                                    ),
                                  ),
                                  StickerPickerView(
                                    key: _stickerKey,
                                    selectedSetId: _stickerSet,
                                    onSetSelected: (id) =>
                                        setState(() => _stickerSet = id),
                                    onSearchFocus: () =>
                                        _expand(library: false),
                                    showManagement: false,
                                    onStickerSelected: widget.onStickerSelected,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_library)
                          Positioned.fill(
                            child: _ExpressionLibrary(
                              mode: _mode,
                              category: _category,
                              onManageCustom: () =>
                                  _customKey.currentState?.showManagement(),
                              onManageStickers: () =>
                                  _stickerKey.currentState?.showManagement(),
                              onCategory: (category) {
                                setState(() {
                                  _category = category;
                                  _library = false;
                                });
                              },
                              onPack: (id) {
                                setState(() {
                                  if (_mode == ExpressionMode.custom) {
                                    _customSet = id;
                                  } else {
                                    _stickerSet = id;
                                  }
                                  _library = false;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ExpressionMode>(
                          key: const ValueKey('expression-mode-tabs'),
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            textStyle: Theme.of(context).textTheme.labelMedium,
                          ),
                          segments: [
                            for (final mode in ExpressionMode.values)
                              ButtonSegment(
                                value: mode,
                                label: Text(
                                  _label(context, mode),
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (value) => _select(value.single),
                        ),
                      ),
                    ),
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

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ExpressionLibrary extends ConsumerStatefulWidget {
  const _ExpressionLibrary({
    required this.mode,
    required this.category,
    required this.onCategory,
    required this.onPack,
    required this.onManageCustom,
    required this.onManageStickers,
  });
  final ExpressionMode mode;
  final Category category;
  final ValueChanged<Category> onCategory;
  final ValueChanged<int?> onPack;
  final VoidCallback onManageCustom, onManageStickers;
  @override
  ConsumerState<_ExpressionLibrary> createState() => _ExpressionLibraryState();
}

class _ExpressionLibraryState extends ConsumerState<_ExpressionLibrary> {
  String _query = '';
  @override
  void didUpdateWidget(covariant _ExpressionLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode) _query = '';
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final l = context.l10n;
    final cards = <Widget>[];
    bool loading = false, failed = false;
    VoidCallback? retry;
    if (mode == ExpressionMode.emoji) {
      for (final category in Category.values) {
        final label = emojiCategoryLabel(context, category);
        if (_query.isNotEmpty && !label.toLowerCase().contains(_query)) {
          continue;
        }
        final data = emojiSetEnglish
            .where((group) => group.category == category)
            .firstOrNull;
        cards.add(
          ExpressionPackCard(
            title: label,
            count: category == Category.RECENT ? null : data?.emoji.length,
            previews: [
              if (category == Category.RECENT)
                Icon(emojiCategoryIcon(category))
              else
                for (final emoji in (data?.emoji ?? const <Emoji>[]).take(3))
                  Text(
                    emoji.emoji,
                    style: const TextStyle(
                      fontFamily: NotoEmoji.fontFamily,
                      fontSize: 28,
                    ),
                    textScaler: TextScaler.noScaling,
                  ),
            ],
            onTap: () => widget.onCategory(category),
          ),
        );
      }
    } else if (mode == ExpressionMode.stickers) {
      final result = ref.watch(stickerSetsProvider);
      final sets = result.value ?? const <ApiStickerSet>[];
      loading = result.isLoading && sets.isEmpty;
      failed = result.hasError && sets.isEmpty;
      retry = () => ref.invalidate(stickerSetsProvider);
      if (_query.isEmpty) {
        cards.add(
          ExpressionPackCard(
            title: l.stickerHubRecent,
            count: null,
            previews: const [Icon(Icons.history_rounded)],
            onTap: () => widget.onPack(null),
          ),
        );
      }
      for (final pack in sets) {
        if (_query.isNotEmpty &&
            !'${pack.title} ${pack.name}'.toLowerCase().contains(_query)) {
          continue;
        }
        cards.add(
          ExpressionPackCard(
            title: pack.title.isEmpty ? pack.name : pack.title,
            count: pack.stickers.length,
            previews: [
              for (final sticker in pack.stickers.take(3))
                sticker.isAnimated
                    ? Text(
                        sticker.emoji.isEmpty ? '▧' : sticker.emoji,
                        style: const TextStyle(
                          fontFamily: NotoEmoji.fontFamily,
                          fontSize: 28,
                        ),
                        textScaler: TextScaler.noScaling,
                      )
                    : CachedNetworkImage(
                        imageUrl: sticker.resolvedUrl,
                        width: 40,
                        height: 40,
                        memCacheWidth: 96,
                        memCacheHeight: 96,
                        errorWidget: (_, _, _) =>
                            const Icon(Icons.sticky_note_2_outlined),
                      ),
            ],
            onTap: () => widget.onPack(pack.id),
          ),
        );
      }
    } else {
      final result = ref.watch(customEmojiSetsProvider);
      final sets = result.value ?? const [];
      loading = result.isLoading && sets.isEmpty;
      failed = result.hasError && sets.isEmpty;
      retry = () => ref.invalidate(customEmojiSetsProvider);
      for (final pack in sets) {
        if (_query.isNotEmpty &&
            !'${pack.title} ${pack.name}'.toLowerCase().contains(_query)) {
          continue;
        }
        cards.add(
          ExpressionPackCard(
            title: pack.title,
            count: pack.emojis.length,
            previews: [
              for (final emoji in pack.emojis.take(3))
                CustomEmojiImage(emoji: emoji, size: 36),
            ],
            onTap: () => widget.onPack(pack.id),
          ),
        );
      }
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ExpressionSearchField(
                key: ValueKey(mode),
                hint: l.pickerSearchPacks,
                onChanged: (query) =>
                    setState(() => _query = query.trim().toLowerCase()),
              ),
            ),
            if (mode != ExpressionMode.emoji)
              IconButton(
                key: const ValueKey('expression-manage-packs'),
                tooltip: l.pickerManage,
                onPressed: mode == ExpressionMode.custom
                    ? widget.onManageCustom
                    : widget.onManageStickers,
                icon: const Icon(Icons.add_rounded),
              ),
          ],
        ),
        Expanded(
          child: loading
              ? const Center(child: AppLoadingIndicator(size: 28))
              : failed
              ? Center(
                  child: TextButton.icon(
                    onPressed: retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l.commonRetry),
                  ),
                )
              : cards.isEmpty
              ? Center(child: Text(l.stickerHubNoResults))
              : GridView.builder(
                  key: PageStorageKey('expression-library:$mode'),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent:
                        140 +
                        (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (_, index) => cards[index],
                ),
        ),
      ],
    );
  }
}
