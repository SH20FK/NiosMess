import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

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

// Search both keyword sets even when the app uses Russian. The short Russian
// aliases above also expand to English names (e.g. "кот" -> "cat").
final List<CategoryEmoji> _notoSearchIndex = <CategoryEmoji>[
  ...emojiSetEnglish,
  ...emojiSetRussian,
];

Future<List<Emoji>> searchNotoPickerEmoji(String query) async {
  final clean = query.trim().toLowerCase();
  if (clean.isEmpty) return const [];
  final terms = <String>{clean};
  for (final entry in _ruEmojiKeywords.entries) {
    if (entry.key.startsWith(clean) ||
        clean.startsWith(entry.key) ||
        entry.key.contains(clean)) {
      terms.addAll(entry.value);
    }
  }
  final results = await Future.wait([
    for (final term in terms)
      EmojiPickerUtils().searchEmoji(
        term,
        _notoSearchIndex,
        checkPlatformCompatibility: false,
      ),
  ]);
  return {
    for (final result in results)
      for (final emoji in result) emoji.emoji: emoji,
  }.values.toList();
}
