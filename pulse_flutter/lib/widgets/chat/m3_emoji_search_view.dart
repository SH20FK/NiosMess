import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// Russian keyword dictionary to map common Russian queries to English emoji search terms
const Map<String, List<String>> _ruEmojiKeywords = {
  // Эмоции и лица
  'огонь': ['fire', 'flame', 'lit'],
  'пламя': ['fire', 'flame'],
  'костер': ['fire'],
  'сердце': ['heart', 'love', 'red heart', 'sparkling heart'],
  'любовь': ['heart', 'love', 'kiss', 'couple', 'sparkling heart'],
  'смех': ['joy', 'rofl', 'laughing', 'laugh', 'lol', 'smile'],
  'ржу': ['rofl', 'joy', 'laughing'],
  'лол': ['rofl', 'joy', 'laughing'],
  'хаха': ['joy', 'laughing', 'rofl'],
  'улыбка': ['smile', 'smiling', 'grinning', 'blush'],
  'радость': ['smile', 'joy', 'blush', 'grinning'],
  'грусть': ['sad', 'pensive', 'disappointed', 'crying'],
  'печаль': ['sad', 'crying', 'pensive'],
  'слезы': ['sob', 'cry', 'crying', 'tear', 'joy'],
  'плач': ['sob', 'cry', 'crying'],
  'рыдать': ['sob', 'cry'],
  'шок': ['astonished', 'screaming', 'flushed', 'exploding head', 'shocked'],
  'удивление': ['astonished', 'hushed', 'flushed', 'open mouth'],
  'взрыв': ['boom', 'collision', 'exploding head', 'fire'],
  'поцелуй': ['kiss', 'kissing', 'heart', 'kissing heart'],
  'чмок': ['kiss', 'kissing heart'],
  'подмигивание': ['wink', 'winking'],
  'круто': ['sunglasses', 'cool', 'sunglass'],
  'очки': ['sunglasses', 'glasses'],
  'сон': ['sleeping', 'zzz', 'sleep', 'yawn'],
  'спать': ['sleeping', 'zzz', 'bed'],
  'устал': ['tired', 'yawn', 'weary'],
  'злость': ['angry', 'rage', 'pouting'],
  'злой': ['angry', 'rage', 'devil'],
  'черт': ['devil', 'imp'],
  'дьявол': ['devil', 'imp'],
  'ангел': ['angel', 'innocent'],
  'святой': ['angel', 'innocent'],
  'череп': ['skull', 'death', 'dead'],
  'смерть': ['skull', 'coffin', 'cross'],
  'призрак': ['ghost', 'halloween'],
  'привидение': ['ghost'],
  'робот': ['robot', 'bot'],
  'клоун': ['clown'],
  'какашка': ['poop', 'poo'],
  'говно': ['poop'],

  // Жесты и руки
  'рука': ['hand', 'wave', 'raised hand', 'clap'],
  'ладонь': ['hand', 'raised hand', 'palms'],
  'привет': ['wave', 'hand', 'hello'],
  'пока': ['wave', 'hand', 'bye'],
  'палец': ['point', 'finger', 'thumbs up', 'thumbs down'],
  'лайк': ['thumbs up', 'plus1', 'thumb'],
  'класс': ['thumbs up', 'ok hand', 'clap'],
  'дизлайк': ['thumbs down', '-1'],
  'ок': ['ok hand', 'ok', 'check'],
  'хорошо': ['ok hand', 'thumbs up', 'check'],
  'аплодисменты': ['clap', 'applause'],
  'хлопать': ['clap'],
  'кулак': ['punch', 'fist', 'fist bump'],
  'молитва': ['pray', 'folded hands'],
  'спасибо': ['pray', 'folded hands', 'bow'],
  'пять': ['hand', 'raised hand', 'pray'],
  'мышцы': ['muscle', 'flex', 'bicep'],
  'сила': ['muscle', 'strong', 'flex'],
  'победа': ['victory', 'v hand', 'peace'],
  'мир': ['peace', 'victory'],
  'стоп': ['hand', 'raised hand', 'stop'],

  // Животные
  'кот': ['cat', 'kitten', 'pussy'],
  'кошка': ['cat', 'kitten'],
  'котик': ['cat', 'kitten'],
  'собака': ['dog', 'puppy'],
  'пес': ['dog'],
  'щенок': ['dog', 'puppy'],
  'медведь': ['bear'],
  'панда': ['panda'],
  'обезьяна': ['monkey', 'ape'],
  'лев': ['lion'],
  'тигр': ['tiger'],
  'лиса': ['fox'],
  'волк': ['wolf'],
  'заяц': ['rabbit', 'bunny'],
  'кролик': ['rabbit', 'bunny'],
  'мышь': ['mouse'],
  'свинья': ['pig'],
  'лягушка': ['frog'],
  'птица': ['bird'],
  'орел': ['eagle'],
  'рыба': ['fish'],
  'акула': ['shark'],
  'бабочка': ['butterfly'],
  'змея': ['snake'],

  // Еда и напитки
  'еда': ['food', 'plate', 'fork', 'pizza', 'burger'],
  'пицца': ['pizza'],
  'бургер': ['burger', 'hamburger'],
  'кофе': ['coffee', 'hot beverage', 'cafe'],
  'чай': ['tea', 'hot beverage'],
  'пиво': ['beer', 'beers'],
  'вино': ['wine', 'cocktail'],
  'торт': ['cake', 'birthday'],
  'сладкое': ['candy', 'chocolate', 'cake', 'cookie'],
  'мороженое': ['ice cream', 'icecream'],
  'яблоко': ['apple'],
  'банан': ['banana'],
  'арбуз': ['watermelon'],
  'клубника': ['strawberry'],
  'хлеб': ['bread'],
  'мясо': ['meat', 'steak'],

  // Природа и погода
  'солнце': ['sun', 'sunny'],
  'луна': ['moon', 'crescent moon'],
  'звезда': ['star', 'glowing star', 'sparkles'],
  'дождь': ['rain', 'cloud rain', 'umbrella'],
  'снег': ['snow', 'snowflake', 'snowman'],
  'зима': ['snowflake', 'snowman', 'cold'],
  'лето': ['sun', 'beach', 'sunny'],
  'цветы': ['flower', 'rose', 'blossom', 'tulip'],
  'роза': ['rose'],
  'дерево': ['tree', 'deciduous tree'],

  // Праздники и развлечения
  'праздник': ['party', 'tada', 'confetti', 'balloon'],
  'др': ['birthday', 'cake', 'tada', 'balloon'],
  'день рождения': ['birthday', 'cake', 'tada', 'balloon'],
  'подарок': ['gift', 'present'],
  'салют': ['fireworks', 'sparkler', 'tada'],
  'конфетти': ['confetti', 'tada'],
  'шарик': ['balloon'],
  'музыка': ['musical note', 'notes', 'guitar', 'music'],
  'нота': ['musical note', 'notes'],
  'гитара': ['guitar'],
  'игра': ['game', 'video game', 'joystick', 'dice'],
  'спорт': ['sport', 'soccer', 'football', 'basketball'],
  'мяч': ['soccer', 'football', 'basketball', 'ball'],
  'футбол': ['soccer', 'football'],
  'баскетбол': ['basketball'],

  // Предметы и транспорт
  'деньги': ['money', 'dollar', 'moneybag', 'cash'],
  'доллар': ['dollar', 'money'],
  'рубль': ['money', 'currency exchange'],
  'богатство': ['moneybag', 'money', 'gem', 'diamond'],
  'алмаз': ['gem', 'diamond'],
  'машина': ['car', 'automobile', 'taxi'],
  'авто': ['car', 'automobile'],
  'самолет': ['airplane', 'plane'],
  'поезд': ['train', 'metro'],
  'дом': ['house', 'building'],
  'телефон': ['phone', 'mobile phone', 'iphone'],
  'компьютер': ['computer', 'laptop', 'desktop'],
  'часы': ['clock', 'watch', 'hourglass'],
  'время': ['clock', 'hourglass', 'alarm clock'],
  'замок': ['lock', 'locked', 'key'],
  'ключ': ['key'],
  'бомба': ['bomb', 'explosion'],
  'флаг': ['flag', 'triangular flag'],
  'россия': ['russia', 'ru', 'flag: Russia', 'flag for Russia'],
  '100': ['100', 'hundred points'],
  'сто': ['100', 'hundred points'],
  'галочка': ['check', 'heavy check mark'],
  'крест': ['cross', 'x'],
};

/// Custom Material 3 Russian & English Emoji Search View
class M3EmojiSearchView extends SearchView {
  const M3EmojiSearchView(
    super.config,
    super.state,
    super.showEmojiView, {
    super.key,
  });

  @override
  M3EmojiSearchViewState createState() => M3EmojiSearchViewState();
}

class M3EmojiSearchViewState extends SearchViewState<M3EmojiSearchView> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void onTextInputChanged(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) {
      links.clear();
      results.clear();
      utils.getRecentEmojis().then((value) {
        if (mounted) {
          setState(() {
            _updateResults(value.map((e) => e.emoji).toList());
          });
        }
      });
      return;
    }

    // 1. Check direct Russian dictionary matches
    final List<String> searchTerms = <String>[clean];
    for (final entry in _ruEmojiKeywords.entries) {
      if (entry.key.startsWith(clean) ||
          clean.startsWith(entry.key) ||
          entry.key.contains(clean)) {
        searchTerms.addAll(entry.value);
      }
    }

    final Set<String> seenEmojis = <String>{};
    final List<Emoji> matchedList = <Emoji>[];

    void processTerms(int index) {
      if (index >= searchTerms.length) {
        if (mounted) {
          setState(() {
            _updateResults(matchedList);
          });
        }
        return;
      }

      final term = searchTerms[index];
      utils.searchEmoji(term, widget.state.categoryEmoji).then((found) {
        for (final e in found) {
          if (seenEmojis.add(e.emoji)) {
            matchedList.add(e);
          }
        }
        processTerms(index + 1);
      });
    }

    processTerms(0);
  }

  void _updateResults(List<Emoji> emojis) {
    results
      ..clear()
      ..addAll(emojis);
    results.asMap().entries.forEach((e) {
      links[e.value.emoji] = LayerLink();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final emojiSize =
            widget.config.emojiViewConfig.getEmojiSize(constraints.maxWidth);
        final emojiBoxSize =
            widget.config.emojiViewConfig.getEmojiBoxSize(constraints.maxWidth);

        return Container(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.showEmojiView,
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        color: scheme.onSurfaceVariant,
                        tooltip: 'Назад',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: focusNode,
                          onChanged: onTextInputChanged,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'Поиск эмодзи (огонь, кот, сердце...)',
                            hintStyle: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            filled: false,
                            fillColor: Colors.transparent,
                          ),
                        ),
                      ),
                      if (_textController.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _textController.clear();
                            onTextInputChanged('');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: scheme.onSurfaceVariant,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),

              // Emoji Search Results Grid / Horizontal Scroll
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          _textController.text.isEmpty
                              ? 'Введите текст для поиска'
                              : 'Эмодзи не найдены',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: widget.config.emojiViewConfig.columns,
                          mainAxisSpacing:
                              widget.config.emojiViewConfig.verticalSpacing,
                          crossAxisSpacing:
                              widget.config.emojiViewConfig.horizontalSpacing,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          return buildEmoji(
                            results[index],
                            emojiSize,
                            emojiBoxSize,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
