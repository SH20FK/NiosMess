import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/illustration/illustration_asset.dart';
import 'package:pulse_flutter/core/illustration/illustration_motion_policy.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

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

    return _SubtleEntranceIllustration(
      width: targetWidth,
      height: targetHeight,
      child: graphic,
    );
  }
}

class _SubtleEntranceIllustration extends StatefulWidget {
  const _SubtleEntranceIllustration({
    required this.child,
    required this.width,
    required this.height,
  });

  final Widget child;
  final double width;
  final double height;

  @override
  State<_SubtleEntranceIllustration> createState() =>
      _SubtleEntranceIllustrationState();
}

class _SubtleEntranceIllustrationState
    extends State<_SubtleEntranceIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: M3SpringCurves.expressiveDecel,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
