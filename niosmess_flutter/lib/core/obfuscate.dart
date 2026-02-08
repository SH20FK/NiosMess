class Obfuscator {
  static final Map<String, String> _map = {
    "А": "☢",
    "Б": "⬣",
    "В": "⬟",
    "Г": "⬢",
    "Д": "✥",
    "Е": "✸",
    "Ё": "✦",
    "Ж": "⚡",
    "З": "⬥",
    "И": "◎",
    "Й": "✺",
    "К": "☍",
    "Л": "⬤",
    "М": "☯",
    "Н": "⚑",
    "О": "⚙",
    "П": "⬦",
    "Р": "☁",
    "С": "⬧",
    "Т": "✖",
    "У": "⬨",
    "Ф": "✣",
    "Х": "☊",
    "Ц": "✹",
    "Ч": "✪",
    "Ш": "⬩",
    "Щ": "✶",
    "Ъ": "⍉",
    "Ы": "⌬",
    "Ь": "⌫",
    "Э": "✷",
    "Ю": "✿",
    "Я": "☮",
    "а": "☠",
    "б": "⬞",
    "в": "⬠",
    "г": "⬡",
    "д": "✧",
    "е": "✱",
    "ё": "✫",
    "ж": "⚔",
    "з": "⬪",
    "и": "◉",
    "й": "✻",
    "к": "☌",
    "л": "⬯",
    "м": "☰",
    "н": "⚐",
    "о": "⚗",
    "п": "⬫",
    "р": "☂",
    "с": "⧈",
    "т": "✕",
    "у": "⬭",
    "ф": "✤",
    "х": "☋",
    "ц": "✾",
    "ч": "✯",
    "ш": "⬮",
    "щ": "✵",
    "ъ": "⍊",
    "ы": "⌭",
    "ь": "〉",
    "э": "✼",
    "ю": "❀",
    "я": "☾",
    "A": "∆",
    "B": "∑",
    "C": "⊗",
    "D": "∂",
    "E": "≡",
    "F": "⊥",
    "G": "∇",
    "H": "⊕",
    "I": "∫",
    "J": "⌘",
    "K": "⍟",
    "L": "⌗",
    "M": "⎔",
    "N": "⊘",
    "O": "⊙",
    "P": "⌖",
    "Q": "⌬̸",
    "R": "⎇",
    "S": "⌿",
    "T": "⏚",
    "U": "⎊",
    "V": "⌸",
    "W": "⍥",
    "X": "⨯",
    "Y": "⍠",
    "Z": "⍢",
    "a": "☉",
    "b": "⬖",
    "c": "⬘",
    "d": "✢",
    "e": "✶̇",
    "f": "⬛",
    "g": "⚘",
    "h": "✺̇",
    "i": "⬙",
    "j": "❖",
    "k": "下",
    "l": "⬚",
    "m": "⚐̇",
    "n": "⬢̇",
    "o": "⚙̇",
    "p": "⬣̇",
    "q": "✧̇",
    "r": "凹",
    "s": "⬥̇",
    "t": "✸̇",
    "u": "⬦̇",
    "v": "✷̇",
    "w": "⬧̇",
    "x": "❂",
    "y": "✦̇",
    "z": "⬨̇",
  };

  static final Map<String, String> _reverse = {
    for (final entry in _map.entries) entry.value: entry.key
  };

  static final List<String> _tokens = (() {
    final list = _reverse.keys.toList();
    list.sort((a, b) => b.length.compareTo(a.length));
    return list;
  })();

  static String obfuscate(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_map[ch] ?? ch);
    }
    return buffer.toString();
  }

  static String deobfuscate(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    var i = 0;
    while (i < text.length) {
      var matched = false;
      for (final token in _tokens) {
        if (text.startsWith(token, i)) {
          buffer.write(_reverse[token]);
          i += token.length;
          matched = true;
          break;
        }
      }
      if (!matched) {
        buffer.write(text[i]);
        i += 1;
      }
    }
    return buffer.toString();
  }
}
