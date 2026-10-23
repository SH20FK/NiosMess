import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/app_surfaces.dart';

class PulseScaffoldBody extends StatelessWidget {
  const PulseScaffoldBody({
    required this.child,
    this.maxWidth = 1280,
    this.topSafe = false,
    this.bottomSafe = true,
    this.bottomPadding = 0,
    this.animatedBackdrop = true,
    this.expand = false,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final bool topSafe;
  final bool bottomSafe;
  final double bottomPadding;
  final bool animatedBackdrop;
  final bool expand;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurfaces.of(context),
      child: Stack(
        children: <Widget>[
          SafeArea(
            top: topSafe,
            bottom: bottomSafe,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (expand) {
                  return SizedBox.expand(child: child);
                }
                final double width = constraints.maxWidth < maxWidth
                    ? constraints.maxWidth
                    : maxWidth;
                final double height = constraints.maxHeight - bottomPadding;

                return Align(
                  alignment: alignment,
                  child: SizedBox(
                    width: width,
                    height: height > 0 ? height : 0,
                    child: child,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
