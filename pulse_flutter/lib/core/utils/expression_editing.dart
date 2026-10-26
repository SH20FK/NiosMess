import 'package:characters/characters.dart';
import 'package:pulse_flutter/models/api/custom_emoji_model.dart';

/// Deletes a selection or the grapheme before the cursor, keeping wire tokens
/// and surrogate/ZWJ sequences whole even if a platform supplies an inner offset.
({String text, int cursor}) deleteExpressionBeforeCursor(
  String text,
  int selectionStart,
  int selectionEnd,
) {
  var start = selectionStart.clamp(0, text.length);
  var end = selectionEnd.clamp(start, text.length);
  if (start == end) {
    if (start == 0) return (text: text, cursor: start);
    var offset = 0;
    for (final grapheme in text.characters) {
      final next = offset + grapheme.length;
      if (start > offset && start <= next) {
        start = offset;
        end = next;
        break;
      }
      offset = next;
    }
  } else {
    var offset = 0;
    for (final grapheme in text.characters) {
      final next = offset + grapheme.length;
      if (start > offset && start < next) start = offset;
      if (end > offset && end < next) end = next;
      offset = next;
    }
  }
  for (final token in customEmojiPattern.allMatches(text)) {
    if (start < token.end && end > token.start) {
      if (start > token.start) start = token.start;
      if (end < token.end) end = token.end;
    }
  }
  return (text: text.replaceRange(start, end, ''), cursor: start);
}
