import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/app_surfaces.dart';

/// Wallpaper preferences stay stored, but no wallpaper is loaded or painted.
class ChatWallpaperBackground extends StatelessWidget {
  const ChatWallpaperBackground({this.chatId, super.key});

  final String? chatId;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppSurfaces.of(context));
}
