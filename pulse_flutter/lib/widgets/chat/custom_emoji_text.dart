import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/models/api/custom_emoji_model.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji.dart';
export 'package:pulse_flutter/models/api/custom_emoji_model.dart'
    show customEmojiLength;

/// The wire text stays unchanged, including clipboard and draft persistence.
/// A shortcode occupies one painted cell; selection and deletion are atomic.
class CustomEmojiTextController extends TextEditingController {
  CustomEmojiTextController({super.text});

  @override
  set value(TextEditingValue next) {
    final previous = super.value;
    if (next.text != previous.text && next.composing.isCollapsed) {
      var start = 0;
      while (start < previous.text.length &&
          start < next.text.length &&
          previous.text.codeUnitAt(start) == next.text.codeUnitAt(start)) {
        start++;
      }
      var end = previous.text.length, newEnd = next.text.length;
      while (end > start &&
          newEnd > start &&
          previous.text.codeUnitAt(end - 1) ==
              next.text.codeUnitAt(newEnd - 1)) {
        end--;
        newEnd--;
      }
      var expandedStart = start, expandedEnd = end;
      for (final match in customEmojiPattern.allMatches(previous.text)) {
        if ((start < match.end && end > match.start) ||
            (start == end && start > match.start && start < match.end)) {
          if (match.start < expandedStart) expandedStart = match.start;
          if (match.end > expandedEnd) expandedEnd = match.end;
        }
      }
      if (expandedStart != start || expandedEnd != end) {
        final inserted = next.text.substring(start, newEnd);
        next = TextEditingValue(
          text: previous.text.replaceRange(
            expandedStart,
            expandedEnd,
            inserted,
          ),
          selection: TextSelection.collapsed(
            offset: expandedStart + inserted.length,
          ),
        );
      }
    }
    if (next.selection.isValid && next.composing.isCollapsed) {
      int snap(int offset, bool trailing) {
        for (final match in customEmojiPattern.allMatches(next.text)) {
          if (offset > match.start && offset < match.end) {
            return trailing ? match.end : match.start;
          }
        }
        return offset;
      }

      final selection = next.selection;
      final forward = selection.baseOffset <= selection.extentOffset;
      next = next.copyWith(
        selection: selection.copyWith(
          baseOffset: snap(
            selection.baseOffset,
            selection.isCollapsed || !forward,
          ),
          extentOffset: snap(
            selection.extentOffset,
            selection.isCollapsed || forward,
          ),
        ),
      );
    }
    super.value = next;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <InlineSpan>[];
    var offset = 0;
    final effective = style ?? DefaultTextStyle.of(context).style;
    final composing = value.composing;
    final showComposing =
        withComposing &&
        composing.isValid &&
        !composing.isCollapsed &&
        composing.end <= text.length;
    void addText(int start, int end) {
      if (start >= end) return;
      if (!showComposing || composing.start >= end || composing.end <= start) {
        spans.add(TextSpan(text: text.substring(start, end)));
        return;
      }
      final a = composing.start.clamp(start, end),
          b = composing.end.clamp(start, end);
      if (a > start) spans.add(TextSpan(text: text.substring(start, a)));
      spans.add(
        TextSpan(
          text: text.substring(a, b),
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
      );
      if (b < end) spans.add(TextSpan(text: text.substring(b, end)));
    }

    for (final match in customEmojiPattern.allMatches(text)) {
      addText(offset, match.start);
      if (showComposing &&
          composing.start < match.end &&
          composing.end > match.start) {
        addText(match.start, match.end);
        offset = match.end;
        continue;
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: CustomEmojiInline(
            shortcode: match[1]!,
            size: MediaQuery.textScalerOf(
              context,
            ).scale((effective.fontSize ?? 14) * 1.2),
            color: effective.color,
          ),
        ),
      );
      // WidgetSpan consumes the first character's offset. Retain the remaining
      // offsets at zero advance so IME/clipboard still operate on the wire text.
      spans.add(
        TextSpan(
          text: text.substring(match.start + 1, match.end),
          style: const TextStyle(fontSize: 0, letterSpacing: 0, height: 0),
        ),
      );
      offset = match.end;
    }
    addText(offset, text.length);
    return TextSpan(style: effective, children: spans);
  }
}

class CustomEmojiLengthFormatter extends TextInputFormatter {
  CustomEmojiLengthFormatter(this.maximum);
  final int maximum;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      !newValue.composing.isCollapsed ||
          customEmojiLength(newValue.text) <= maximum
      ? newValue
      : oldValue;
}

class CustomEmojiText extends StatelessWidget {
  const CustomEmojiText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: customEmojiSpans(
        text,
        style ?? DefaultTextStyle.of(context).style,
      ),
    ),
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    textAlign: textAlign,
  );
}
