import 'package:flutter/material.dart';
import 'package:pulse_flutter/features/wallpaper/presentation/wallpaper_studio_screen.dart';

class SettingsWallpaperScreen extends StatelessWidget {
  const SettingsWallpaperScreen({
    this.chatId,
    this.chatTitle,
    this.initialCode,
    this.isEmbedded = false,
    super.key,
  });

  final String? chatId;
  final String? chatTitle;
  final String? initialCode;
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    return WallpaperStudioScreen(
      chatId: chatId,
      chatTitle: chatTitle,
      initialCode: initialCode,
      isEmbedded: isEmbedded,
    );
  }
}
