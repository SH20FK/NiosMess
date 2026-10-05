import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

ScrollPhysics settingsScrollPhysics(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    _ => const ClampingScrollPhysics(),
  };
}

class SettingsResponsiveShell extends StatelessWidget {
  const SettingsResponsiveShell({
    required this.title,
    this.mobileBody,
    this.desktopBody,
    this.child,
    this.actions,
    this.floatingActionButton,
    this.isEmbedded = false,
    super.key,
  }) : assert(child != null || (mobileBody != null && desktopBody != null),
            'Either child or both mobileBody and desktopBody must be provided');

  final String title;
  final Widget? mobileBody;
  final Widget? desktopBody;
  final Widget? child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TargetPlatform platform = theme.platform;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop = constraints.maxWidth >= Breakpoints.medium;

        final PreferredSizeWidget? appBar = isEmbedded
            ? null
            : AppBar(
                title: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                actions: actions,
              );

        return Scaffold(
          appBar: appBar,
          body: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              physics: settingsScrollPhysics(platform),
            ),
            child: child ?? (isDesktop ? desktopBody! : mobileBody!),
          ),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}
