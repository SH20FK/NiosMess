import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/illustration/illustration_asset.dart';
import 'package:pulse_flutter/core/illustration/illustration_motion_policy.dart';
import 'package:pulse_flutter/widgets/motion/m3_entrance.dart';

class AppIllustration extends StatelessWidget {
  const AppIllustration({
    required this.asset,
    this.width,
    this.height,
    this.color,
    this.motionPolicy = AppIllustrationMotionPolicy.once,
    super.key,
  });

  final IllustrationAsset asset;
  final double? width;
  final double? height;
  final Color? color;
  final AppIllustrationMotionPolicy motionPolicy;

  @override
  Widget build(BuildContext context) {
    final double targetWidth = width ?? asset.width;
    final double targetHeight = height ?? asset.height;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color tint = color ?? scheme.primary;

    final Widget graphic = SvgPicture.asset(
      asset.assetPath,
      width: targetWidth,
      height: targetHeight,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      placeholderBuilder: (BuildContext _) => SizedBox(
        width: targetWidth,
        height: targetHeight,
        child: Center(
          child: Icon(
            asset.fallbackIcon,
            size: targetWidth * 0.45,
            color: tint.withValues(alpha: 0.6),
          ),
        ),
      ),
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) => SizedBox(
        width: targetWidth,
        height: targetHeight,
        child: Center(
          child: Icon(
            asset.fallbackIcon,
            size: targetWidth * 0.45,
            color: tint.withValues(alpha: 0.6),
          ),
        ),
      ),
    );

    if (!motionPolicy.shouldAnimate(context)) {
      return SizedBox(
        width: targetWidth,
        height: targetHeight,
        child: Center(child: graphic),
      );
    }

    return SizedBox(
      width: targetWidth,
      height: targetHeight,
      child: M3Entrance(
        scaleFrom: 0.94,
        child: Center(child: graphic),
      ),
    );
  }
}
