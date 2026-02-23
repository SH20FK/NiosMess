import 'package:flutter/material.dart';

/// Responsive breakpoints for different screen sizes
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double wideDesktop = 1600;
}

/// Utility class for responsive design
class ResponsiveUtils {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.mobile &&
        width < ResponsiveBreakpoints.desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktop;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.wideDesktop;

  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < ResponsiveBreakpoints.mobile) return ScreenType.mobile;
    if (width < ResponsiveBreakpoints.desktop) return ScreenType.tablet;
    if (width < ResponsiveBreakpoints.wideDesktop) return ScreenType.desktop;
    return ScreenType.wideDesktop;
  }

  static double getSidebarWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < ResponsiveBreakpoints.desktop) return 0;
    if (width < ResponsiveBreakpoints.wideDesktop) return 320;
    return 400;
  }

  static double getChatListWidth(BuildContext context) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.mobile:
        return double.infinity;
      case ScreenType.tablet:
        return 280;
      case ScreenType.desktop:
        return 320;
      case ScreenType.wideDesktop:
        return 360;
    }
  }
}

enum ScreenType { mobile, tablet, desktop, wideDesktop }

/// Responsive layout builder
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;
  final Widget? wideDesktop;

  const ResponsiveLayoutBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
    this.wideDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth == 0 || constraints.maxHeight == 0) {
          return const SizedBox.shrink();
        }
        if (constraints.maxWidth >= ResponsiveBreakpoints.wideDesktop &&
            wideDesktop != null) {
          return wideDesktop!;
        }
        if (constraints.maxWidth >= ResponsiveBreakpoints.desktop) {
          return desktop;
        }
        if (constraints.maxWidth >= ResponsiveBreakpoints.mobile &&
            tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}

/// Adaptive container that changes based on screen size
class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? mobilePadding;
  final EdgeInsets? desktopPadding;
  final double? maxWidth;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.mobilePadding,
    this.desktopPadding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? double.infinity,
        ),
        child: Padding(
          padding: isDesktop
              ? (desktopPadding ?? const EdgeInsets.all(24))
              : (mobilePadding ?? const EdgeInsets.all(16)),
          child: child,
        ),
      ),
    );
  }
}
