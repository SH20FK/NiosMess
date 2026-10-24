import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pulse_flutter/models/api/custom_emoji_model.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_sticker_player.dart';

class CustomEmojiImage extends StatelessWidget {
  const CustomEmojiImage({
    required this.emoji,
    this.size = 24,
    this.color,
    super.key,
  });
  final ApiCustomEmoji emoji;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final tint = emoji.isAdaptive
        ? color ?? Theme.of(context).colorScheme.onSurface
        : null;
    final fallback = Text(
      emoji.token,
      style: TextStyle(fontSize: size * .45, color: color),
    );
    final Widget image = emoji.isSvg
        ? SvgPicture.network(
            emoji.url,
            width: size,
            height: size,
            colorFilter: tint == null
                ? null
                : ColorFilter.mode(tint, BlendMode.srcIn),
            placeholderBuilder: (_) => SizedBox.square(dimension: size),
          )
        : emoji.isVideo
        ? StickerVideoPlayer(url: emoji.url)
        : CachedNetworkImage(
            imageUrl: emoji.url,
            memCacheWidth: 128,
            memCacheHeight: 128,
            width: size,
            height: size,
            fit: BoxFit.contain,
            color: tint,
            colorBlendMode: tint == null ? null : BlendMode.srcIn,
            placeholder: (_, _) => SizedBox.square(dimension: size),
            errorWidget: (_, _, _) => fallback,
          );
    return Semantics(
      label: emoji.token,
      image: true,
      child: SizedBox.square(dimension: size, child: image),
    );
  }
}

class CustomEmojiInline extends ConsumerWidget {
  const CustomEmojiInline({
    required this.shortcode,
    this.size = 24,
    this.color,
    super.key,
  });
  final String shortcode;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emoji = ref.watch(
      customEmojiCatalogProvider.select((m) => m[shortcode]),
    );
    if (emoji == null) {
      ref.read(customEmojiCatalogProvider.notifier).ensure([shortcode]);
      return Text(
        ':$shortcode:',
        style: TextStyle(color: color, fontSize: size / 1.2),
      );
    }
    return CustomEmojiImage(emoji: emoji, size: size, color: color);
  }
}

List<InlineSpan> customEmojiSpans(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  var offset = 0;
  for (final match in customEmojiPattern.allMatches(text)) {
    if (match.start > offset) {
      spans.add(
        TextSpan(text: text.substring(offset, match.start), style: style),
      );
    }
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Builder(
          builder: (context) => CustomEmojiInline(
            shortcode: match[1]!,
            size: MediaQuery.textScalerOf(
              context,
            ).scale((style.fontSize ?? 14) * 1.2),
            color: style.color,
          ),
        ),
      ),
    );
    offset = match.end;
  }
  if (offset < text.length) {
    spans.add(TextSpan(text: text.substring(offset), style: style));
  }
  return spans;
}

class CustomEmojiSyntax extends md.InlineSyntax {
  CustomEmojiSyntax() : super(r':([a-z0-9_]{2,64}):');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('nios-emoji', match[1]!));
    return true;
  }
}

class CustomEmojiMarkdownBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => CustomEmojiInline(
    shortcode: element.textContent,
    size: MediaQuery.textScalerOf(
      context,
    ).scale((preferredStyle?.fontSize ?? parentStyle?.fontSize ?? 15) * 1.2),
    color: preferredStyle?.color ?? parentStyle?.color,
  );
}

void insertCustomEmoji(TextEditingController controller, ApiCustomEmoji emoji) {
  final selection = controller.selection;
  final start = selection.isValid ? selection.start : controller.text.length;
  final end = selection.isValid ? selection.end : controller.text.length;
  final text = controller.text.replaceRange(start, end, emoji.token);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: start + emoji.token.length),
  );
}
