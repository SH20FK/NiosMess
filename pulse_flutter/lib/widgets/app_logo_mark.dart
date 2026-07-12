import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';

class AppLogoMark extends StatelessWidget {
  const AppLogoMark({
    super.key,
    this.size = 88,
    this.backgroundColor,
    this.markColor,
  });

  final double size;
  final Color? backgroundColor;
  final Color? markColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return M3Container.c9SidedCookie(
      width: size,
      height: size,
      color: backgroundColor ?? scheme.primary,
      child: Center(
        child: SvgPicture.asset(
          'assets/svg/niosmess_n_mark.svg',
          width: size * 0.5,
          height: size * 0.5,
          colorFilter: ColorFilter.mode(
            markColor ?? scheme.onPrimary,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
