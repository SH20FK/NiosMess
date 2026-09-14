import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';

/// Centralized Material 3 Expressive scaffold for settings screens.
/// Features a true collapsing [SliverAppBar.large] with tonal elevation,
/// clean responsive centering, and elimination of fake transparent app bars.
class SettingsShell extends ConsumerWidget {
  const SettingsShell({
    required this.title,
    required this.children,
    this.actions,
    this.onRefresh,
    this.isEmbedded = false,
    this.maxWidth = 860,
    this.leading,
    this.sliversBefore,
    this.sliversAfter,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final bool isEmbedded;
  final double maxWidth;
  final Widget? leading;
  final List<Widget>? sliversBefore;
  final List<Widget>? sliversAfter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 840;
        final double horizontalPadding = isEmbedded
            ? (isWide ? 28.0 : 16.0)
            : (isWide ? 28.0 : AppConstants.screenHorizontalPadding);

        final Widget contentSliver = SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isEmbedded ? 12.0 : 4.0,
            horizontalPadding,
            32.0,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => children[index],
              childCount: children.length,
            ),
          ),
        );

        final List<Widget> slivers = <Widget>[
          ...?sliversBefore,
          if (!isEmbedded)
            SliverAppBar.large(
              title: Text(
                title,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              centerTitle: false,
              pinned: true,
              backgroundColor: scheme.surface,
              surfaceTintColor: scheme.surfaceTint,
              scrolledUnderElevation: 2.5,
              actions: actions,
              leading: leading ??
                  (Navigator.canPop(context)
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.of(context).pop();
                            } else {
                              context.go('/main/profile');
                            }
                          },
                        )
                      : null),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    ...?actions,
                  ],
                ),
              ),
            ),
          contentSliver,
          ...?sliversAfter,
        ];

        final Widget rawScrollView = CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: slivers,
        );

        final Widget bodyContent = onRefresh != null
            ? RefreshIndicator(onRefresh: onRefresh!, child: rawScrollView)
            : rawScrollView;

        if (isEmbedded) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: bodyContent,
            ),
          );
        }

        return Scaffold(
          backgroundColor: scheme.surface,
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: bodyContent,
            ),
          ),
        );
      },
    );
  }
}
