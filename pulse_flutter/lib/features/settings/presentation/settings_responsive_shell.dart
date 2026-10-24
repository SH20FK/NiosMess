import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/settings/settings_shell.dart';

ScrollPhysics settingsScrollPhysics(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
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
  }) : assert(
         child != null || (mobileBody != null && desktopBody != null),
         'Either child or both mobileBody and desktopBody must be provided',
       );

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
        final content = ScrollConfiguration(
          behavior: ScrollConfiguration.of(
            context,
          ).copyWith(physics: settingsScrollPhysics(platform)),
          child: child ?? (isDesktop ? desktopBody! : mobileBody!),
        );
        final body = isEmbedded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (SettingsHeadingScope.showHeading(context))
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 28 : 16,
                        28,
                        16,
                        16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ...?actions,
                        ],
                      ),
                    ),
                  Expanded(child: content),
                ],
              )
            : NestedScrollView(
                headerSliverBuilder: (context, innerScrolled) => [
                  SliverAppBar.large(
                    title: Text(title),
                    pinned: true,
                    actions: actions,
                    backgroundColor: theme.colorScheme.surface,
                  ),
                ],
                body: content,
              );
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: body,
            ),
          ),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}
