import 'package:flutter/material.dart';

/// Identifies a particular attachment, even when several messages share a URL.
String chatMediaHeroTag(int chatId, int messageId) =>
    'chat-media:$chatId:$messageId';

class MediaHero extends StatelessWidget {
  const MediaHero({required this.tag, required this.child, super.key});

  final String? tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (tag == null || MediaQuery.disableAnimationsOf(context)) return child;
    return Hero(
      tag: tag!,
      transitionOnUserGestures: true,
      flightShuttleBuilder: (context, animation, direction, from, to) {
        // Keep the thumbnail visible while the full-resolution viewer loads.
        final hero =
            (direction == HeroFlightDirection.push ? from : to).widget as Hero;
        return Material(type: MaterialType.transparency, child: hero.child);
      },
      child: child,
    );
  }
}
