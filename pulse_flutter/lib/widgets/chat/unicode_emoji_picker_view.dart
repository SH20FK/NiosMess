import 'dart:async';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/utils/noto_emoji.dart';
import 'package:pulse_flutter/widgets/chat/expression_picker_components.dart';
import 'package:pulse_flutter/widgets/chat/m3_emoji_search_view.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

IconData emojiCategoryIcon(Category category) => switch (category) {
  Category.RECENT => Icons.history_rounded,
  Category.SMILEYS => Icons.sentiment_satisfied_alt_rounded,
  Category.ANIMALS => Icons.pets_rounded,
  Category.FOODS => Icons.restaurant_rounded,
  Category.ACTIVITIES => Icons.sports_basketball_rounded,
  Category.TRAVEL => Icons.flight_rounded,
  Category.OBJECTS => Icons.lightbulb_outline_rounded,
  Category.SYMBOLS => Icons.favorite_border_rounded,
  Category.FLAGS => Icons.flag_outlined,
};
String emojiCategoryLabel(BuildContext context, Category category) =>
    switch (category) {
      Category.RECENT => context.l10n.stickerHubRecent,
      Category.SMILEYS => context.l10n.pickerFaces,
      Category.ANIMALS => context.l10n.pickerAnimals,
      Category.FOODS => context.l10n.pickerFood,
      Category.ACTIVITIES => context.l10n.pickerActivities,
      Category.TRAVEL => context.l10n.pickerTravel,
      Category.OBJECTS => context.l10n.pickerObjects,
      Category.SYMBOLS => context.l10n.pickerSymbols,
      Category.FLAGS => context.l10n.pickerFlags,
    };

class UnicodeEmojiPickerView extends StatefulWidget {
  const UnicodeEmojiPickerView({
    required this.state,
    required this.category,
    required this.onCategoryChanged,
    required this.onSearchFocus,
    super.key,
  });
  final EmojiViewState state;
  final Category category;
  final ValueChanged<Category> onCategoryChanged;
  final VoidCallback onSearchFocus;
  @override
  State<UnicodeEmojiPickerView> createState() => _UnicodeEmojiPickerViewState();
}

class _UnicodeEmojiPickerViewState extends State<UnicodeEmojiPickerView> {
  String _query = '';
  List<Emoji> _results = const [];
  int _generation = 0;
  Timer? _debounce;
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String query) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() => _query = query.trim());
    if (_query.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 100), () async {
      final result = await searchNotoPickerEmoji(query);
      if (mounted && generation == _generation) {
        setState(() => _results = result);
      }
    });
  }

  Future<void> _tones(Emoji emoji) async {
    await AppModal.showSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final value in ['', '🏻', '🏼', '🏽', '🏾', '🏿'])
                TextButton(
                  onPressed: () {
                    widget.state.onEmojiSelected(
                      widget.category,
                      EmojiPickerUtils().applySkinTone(emoji, value),
                    );
                    Navigator.pop(context);
                  },
                  child: Text(
                    EmojiPickerUtils().applySkinTone(emoji, value).emoji,
                    style: const TextStyle(
                      fontFamily: NotoEmoji.fontFamily,
                      fontSize: 30,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.state.categoryEmoji
        .where((c) => c.category == widget.category)
        .firstOrNull;
    final items = _query.isEmpty
        ? category?.emoji ?? const <Emoji>[]
        : _results;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (constraints.maxHeight >= 100)
            ExpressionSearchField(
              initialValue: _query,
              key: const ValueKey('unicode-search'),
              hint: context.l10n.pickerSearchEmoji,
              onChanged: _search,
              onFocus: widget.onSearchFocus,
            ),
          if (constraints.maxHeight >= 160)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final group in widget.state.categoryEmoji)
                    ExpressionPackButton(
                      label: emojiCategoryLabel(context, group.category),
                      selected: group.category == widget.category,
                      onTap: () => widget.onCategoryChanged(group.category),
                      child: Icon(emojiCategoryIcon(group.category)),
                    ),
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? context.l10n.pickerNoRecents
                          : context.l10n.stickerHubNoResults,
                      textAlign: TextAlign.center,
                    ),
                  )
                : GridView.builder(
                    key: PageStorageKey('unicode:${widget.category}:$_query'),
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 60,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final emoji = items[index];
                      return Tooltip(
                        message: emoji.name.split(' | ').first,
                        child: Semantics(
                          label: emoji.name.split(' | ').first,
                          button: true,
                          excludeSemantics: true,
                          onTap: () => widget.state.onEmojiSelected(
                            widget.category,
                            emoji,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => widget.state.onEmojiSelected(
                              widget.category,
                              emoji,
                            ),
                            onLongPress: emoji.hasSkinTone
                                ? () => _tones(emoji)
                                : null,
                            child: Center(
                              child: Text(
                                emoji.emoji,
                                textScaler: TextScaler.noScaling,
                                style: const TextStyle(
                                  fontFamily: NotoEmoji.fontFamily,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class NotoPickerLoading extends StatelessWidget {
  const NotoPickerLoading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: AppLoadingIndicator(size: 28));
}
