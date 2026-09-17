import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/models/api/status_emoji_model.dart';

class StatusEmojiBadge extends StatelessWidget {
  const StatusEmojiBadge({
    required this.emoji,
    this.size = 18.0,
    super.key,
  });

  final ApiStatusEmoji emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (emoji.url.isEmpty) return const SizedBox.shrink();

    final Widget imageWidget = emoji.isSvg
        ? SvgPicture.network(
            emoji.url,
            width: size,
            height: size,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => SizedBox(width: size, height: size),
          )
        : CachedNetworkImage(
            imageUrl: emoji.url,
            width: size,
            height: size,
            fit: BoxFit.contain,
            placeholder: (BuildContext context, String url) =>
                SizedBox(width: size, height: size),
            errorWidget: (BuildContext context, String url, Object error) =>
                const SizedBox.shrink(),
          );

    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Tooltip(
        message: emoji.shortcode,
        child: SizedBox(
          width: size,
          height: size,
          child: imageWidget,
        ),
      ),
    );
  }
}
