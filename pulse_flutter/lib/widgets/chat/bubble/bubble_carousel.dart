import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/chat/ws_cached_image.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class MediaCarousel extends StatefulWidget {
  const MediaCarousel({
    required this.urls,
    required this.scheme,
    required this.textStyle,
    required this.isMine,
    required this.onOpenMedia,
    required this.onLongPressMedia,
    required this.chatId,
    required this.isE2ee,
    this.e2eeFileKey,
    this.radius = 12.0,
    super.key,
  });

  final List<String> urls;
  final ColorScheme scheme;
  final TextStyle textStyle;
  final bool isMine;
  final VoidCallback? onOpenMedia;
  final VoidCallback? onLongPressMedia;
  final int chatId;
  final bool isE2ee;
  final String? e2eeFileKey;
  final double radius;

  @override
  State<MediaCarousel> createState() => MediaCarouselState();
}

class MediaCarouselState extends State<MediaCarousel> {
  final PageController _controller = PageController(viewportFraction: 1.0);
  final ValueNotifier<int> _pageNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _controller.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double rad = widget.radius;
    return InkWell(
      onTap: widget.onOpenMedia,
      onLongPress: widget.onLongPressMedia,
      borderRadius: BorderRadius.circular(rad),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rad),
        child: SizedBox(
          width: 240,
          height: 190,
          child: Stack(
            children: <Widget>[
              PageView.builder(
                controller: _controller,
                itemCount: widget.urls.length,
                onPageChanged: (int index) => _pageNotifier.value = index,
                itemBuilder: (BuildContext context, int index) {
                  return WsCachedImage(
                    e2eeFileKey: widget.e2eeFileKey,
                    mediaUrl: widget.urls[index],
                    chatId: widget.chatId,
                    isE2ee: widget.isE2ee,
                    width: 240,
                    height: 190,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context) => SizedBox(
                      width: 240,
                      height: 190,
                      child: Center(
                        child: AppLoadingIndicator(
                          color: widget.isMine
                              ? widget.scheme.onPrimary
                              : widget.scheme.primary,
                        ),
                      ),
                    ),
                    errorWidget: (BuildContext context, Object error) => Container(
                      width: 240,
                      height: 190,
                      alignment: Alignment.center,
                      color: widget.isMine
                          ? widget.scheme.onPrimary.withValues(alpha: 0.12)
                          : widget.scheme.surfaceContainerHigh,
                      child: Semantics(
                        label: context.l10n.chatImageUnavailable,
                        child: Text(
                          context.l10n.chatImageUnavailable,
                          style: widget.textStyle,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.urls.length > 1)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _pageNotifier,
                    builder: (BuildContext context, int page, Widget? _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${page + 1}/${widget.urls.length}',
                          style: TextStyle(
                            color: widget.scheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

