import 'package:characters/characters.dart';
import 'package:pulse_flutter/core/utils/noto_emoji_catalog.dart';

/// A single supported Unicode emoji, retaining the sender's exact sequence.
/// Asset normalization never changes the message or drops tone/ZWJ components.
final class NotoEmoji {
  const NotoEmoji._(this.unicode, this.assetId);

  final String unicode;
  final String assetId;

  static const fontFamily = 'NotoColorEmoji';

  bool get hasAnimation => animatedNotoEmojiIds.contains(assetId);

  String? get animationAsset =>
      hasAnimation ? 'assets/emoji/animated/$assetId.json.gz' : null;

  static NotoEmoji? fromMessage(String message) {
    // Emoji graphemes are short. Avoid scanning arbitrary chat bodies here.
    if (message.isEmpty || message.length > 128) return null;
    final unicode = message.trim();
    final graphemes = unicode.characters.iterator;
    if (!graphemes.moveNext() || graphemes.moveNext()) return null;
    final points = unicode.runes.toList(growable: false);
    // VS15 explicitly requests text presentation, rather than a large emoji.
    if (points.contains(0xfe0e)) return null;
    final normalized = points.where((point) => point != 0xfe0f).toList();
    if (normalized.isEmpty) return null;
    if (normalized.length == 1) {
      final point = normalized.single;
      if (point <= 0x7f ||
          (point >= 0x1f3fb && point <= 0x1f3ff) ||
          (point >= 0x1f1e6 && point <= 0x1f1ff)) {
        return null;
      }
    }
    for (var index = 0; index < points.length; index++) {
      if (points[index] == 0xfe0f &&
          (index == 0 ||
              points[index - 1] == 0xfe0f ||
              points[index - 1] == 0x200d ||
              points[index - 1] == 0x20e3)) {
        return null;
      }
    }
    final id = normalized.map((point) => point.toRadixString(16)).join('_');
    if (!notoEmojiIds.contains(id)) return null;
    return NotoEmoji._(unicode, id);
  }
}
