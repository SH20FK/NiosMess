import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_surfaces.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';

/// Stored wallpaper settings are retained while decorative backgrounds are off.
class WallpaperPreviewPane extends StatelessWidget {
  const WallpaperPreviewPane({
    required this.config,
    this.height,
    this.borderRadius,
    this.showSampleMessages = true,
    super.key,
  });

  final ChatWallpaperConfig config;
  final double? height;
  final BorderRadius? borderRadius;
  final bool showSampleMessages;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppSurfaces.of(context),
        borderRadius: borderRadius ?? BorderRadius.circular(24),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.backgroundsPaused,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
