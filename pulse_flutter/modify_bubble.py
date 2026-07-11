import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

# 1. Add static const fields and method for radius
radius_code = """  static const BorderRadius _mineRadiusNoneSame = BorderRadius.all(Radius.circular(16));
  static const BorderRadius _mineRadiusPrevSame = BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16), topRight: Radius.circular(4), bottomRight: Radius.circular(16));
  static const BorderRadius _mineRadiusNextSame = BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(4));
  static const BorderRadius _mineRadiusPrevSameNextSame = BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16), topRight: Radius.circular(4), bottomRight: Radius.circular(4));

  static const BorderRadius _theirsRadiusNoneSame = BorderRadius.all(Radius.circular(16));
  static const BorderRadius _theirsRadiusPrevSame = BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16), topLeft: Radius.circular(4), bottomLeft: Radius.circular(16));
  static const BorderRadius _theirsRadiusNextSame = BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16), topLeft: Radius.circular(16), bottomLeft: Radius.circular(4));
  static const BorderRadius _theirsRadiusPrevSameNextSame = BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16), topLeft: Radius.circular(4), bottomLeft: Radius.circular(4));

  static BorderRadius _getBubbleRadius(bool isMine, bool isPrevSame, bool isNextSame) {
    if (isMine) {
      if (isPrevSame && isNextSame) return _mineRadiusPrevSameNextSame;
      if (isPrevSame) return _mineRadiusPrevSame;
      if (isNextSame) return _mineRadiusNextSame;
      return _mineRadiusNoneSame;
    } else {
      if (isPrevSame && isNextSame) return _theirsRadiusPrevSameNextSame;
      if (isPrevSame) return _theirsRadiusPrevSame;
      if (isNextSame) return _theirsRadiusNextSame;
      return _theirsRadiusNoneSame;
    }
  }

"""

# Insert radius code before _fwdRegExp
content = content.replace("  static final RegExp _fwdRegExp", radius_code + "  static final RegExp _fwdRegExp")

# 2. Replace the inline radius logic with _getBubbleRadius
old_radius_logic = """    final BorderRadius bubbleRadius = isMine
        ? BorderRadius.only(
            topLeft: const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            topRight: Radius.circular(isPrevSame ? 4 : 16),
            bottomRight: Radius.circular(isNextSame ? 16 : 4),
          )
        : BorderRadius.only(
            topRight: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
            topLeft: Radius.circular(isPrevSame ? 4 : 16),
            bottomLeft: Radius.circular(isNextSame ? 16 : 4),
          );"""

new_radius_logic = """    final BorderRadius bubbleRadius = _getBubbleRadius(isMine, isPrevSame, isNextSame);"""
content = content.replace(old_radius_logic, new_radius_logic)

with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write(content)

