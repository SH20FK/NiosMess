import 'package:pulse_flutter/widgets/app_refresh_indicator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/motion/m3_morphing_icon.dart';
import 'package:pulse_flutter/widgets/settings/pressable_surface.dart';
import 'package:pulse_flutter/widgets/settings/settings_pane_scrollbar.dart';

/// Compact web pages already receive a title from their persistent app bar.
class SettingsHeadingScope extends InheritedWidget {
  const SettingsHeadingScope({
    required this.showEmbeddedHeading,
    required super.child,
    super.key,
  });
  final bool showEmbeddedHeading;
  static bool showHeading(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SettingsHeadingScope>()
          ?.showEmbeddedHeading ??
      true;
  @override
  bool updateShouldNotify(SettingsHeadingScope oldWidget) =>
      showEmbeddedHeading != oldWidget.showEmbeddedHeading;
}

/// Centralized Material 3 Expressive scaffold for settings screens.
///
/// The page is tonal: the content sits on [ColorScheme.surfaceContainerLowest]
/// while every group of rows is a lighter [ColorScheme.surfaceContainerLow]
/// card, so depth comes from the surface ladder and never from a shadow. The
/// heading is a large expressive title over a collapsing [SliverAppBar.large],
/// the back control is an M3E tonal circle that morphs its glyph, and an optional
/// [hero] block opens the page above the first section.
class SettingsShell extends ConsumerWidget {
  const SettingsShell({
    required this.title,
    required this.children,
    this.actions,
    this.onRefresh,
    this.isEmbedded = false,
    this.maxWidth = 860,
    this.leading,
    this.hero,
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

  /// Horizontal gutter shared by the hub and every sub-screen, so a screen
  /// that places its own slivers (blocked users) cannot drift from the shell.
  static double gutterFor(BoxConstraints constraints) =>
      constraints.maxWidth >= 840 ? 28.0 : AppSpacing.lg;

  /// Large opening block above the first section, such as a live preview.
  /// It takes the same gutters as the rows and scrolls with them.
  final Widget? hero;

  final List<Widget>? sliversBefore;
  final List<Widget>? sliversAfter;

  /// Size of the [SliverAppBar.large] heading. One step above the baseline
  /// `headlineMedium`, so the page announces itself before it is scrolled.
  static const double headingSize = 32.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool keyboard = ref.watch(
      clientCapabilitiesProvider.select(
        (c) => c.desktopFiles || c.browserWorkspace,
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // One gutter for the hub and every section under it.
        final double horizontalPadding = SettingsShell.gutterFor(constraints);
        // What the system still covers here: the gesture bar below, a cutout
        // at the side in landscape. The app bar handles the top itself.
        final EdgeInsets safe = MediaQuery.paddingOf(context);
        final TextStyle headingStyle =
            (textTheme.headlineLarge ?? const TextStyle()).copyWith(
              fontSize: headingSize,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: scheme.onSurface,
            );

        final Widget contentSliver = SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding + safe.left,
            isEmbedded ? AppSpacing.md : AppSpacing.sm,
            horizontalPadding + safe.right,
            AppSpacing.xxl + safe.bottom,
          ),
          // Settings are short forms. Mount their anchors together so search
          // can reveal a control below the viewport on its first frame.
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (hero != null) ...<Widget>[
                  hero!,
                  const SizedBox(height: AppSpacing.xs),
                ],
                ...children,
              ],
            ),
          ),
        );

        final List<Widget> slivers = <Widget>[
          ...?sliversBefore,
          if (!isEmbedded && title.isNotEmpty)
            SliverAppBar.large(
              expandedHeight:
                  148 + (MediaQuery.textScalerOf(context).scale(headingSize) -
                          headingSize) *
                      2,
              toolbarHeight: (MediaQuery.textScalerOf(context).scale(20) + 28)
                  .clamp(64, 112),
              title: Text(title, style: headingStyle),
              centerTitle: false,
              pinned: true,
              // The bar and the page are one surface: the tonal step is done
              // by the sections, not by the app bar.
              backgroundColor: scheme.surfaceContainerLowest,
              scrolledUnderElevation: 0,
              actions: actions,
              leading:
                  leading ??
                  (Navigator.canPop(context)
                      ? SettingsBackButton(
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
          else if (isEmbedded &&
              title.isNotEmpty &&
              SettingsHeadingScope.showHeading(context))
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding + safe.left,
                  AppSpacing.lg,
                  horizontalPadding + safe.right,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: headingStyle)),
                    ...?actions,
                  ],
                ),
              ),
            ),
          contentSliver,
          ...?sliversAfter,
        ];

        // The thumb sits at the edge of the pane, not of the centred column.
        final Widget body = SettingsPaneScrollbar(
          builder: (BuildContext context, ScrollController? controller) {
            final Widget scrolling = CustomScrollView(
              controller: controller,
              physics: kIsWeb
                  ? const ClampingScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
              slivers: slivers,
            );
            return Align(
              // A pushed page has the window to itself, so its column is
              // centred. An embedded one stands beside the list of sections:
              // it stays next to that list, and a wide window keeps its
              // emptiness on the right instead of pushing the column into
              // the middle of the pane.
              alignment: isEmbedded
                  ? Alignment.topLeft
                  : Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: onRefresh != null
                    ? AppRefreshIndicator(
                        onRefresh: onRefresh!,
                        child: scrolling,
                      )
                    : scrolling,
              ),
            );
          },
        );

        if (isEmbedded) return body;
        final Widget page = Scaffold(
          // One tonal step below the row cards, so groups read as panels on
          // a page rather than as blocks glued to the window.
          backgroundColor: scheme.surfaceContainerLowest,
          body: body,
        );
        if (!keyboard) return page;
        // A pushed settings page closes on Escape where there is a keyboard.
        // The focus node gives the key somewhere to land before anything on
        // the page has been focused.
        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.maybePop(context),
          },
          child: Focus(autofocus: true, child: page),
        );
      },
    );
  }
}

/// The back control of a settings page: a tonal circle holding an M3E
/// morphing arrow. The glyph follows the reading direction, so it morphs into
/// the forward arrow under RTL instead of pointing the wrong way. The tap
/// target is the whole 48 dp button, and the arrow compresses under a
/// finger through [PressableSurface].
class SettingsBackButton extends StatelessWidget {
  const SettingsBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final String tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Center(
      child: SizedBox.square(
        // 40 dp visual circle inside a 48 dp hit target so the touch area
        // still meets the M3 minimum.
        dimension: 48,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Center(
            child: SizedBox.square(
              dimension: 40,
              child: Tooltip(
                message: tooltip,
                child: Semantics(
                  button: true,
                  label: tooltip,
                  child: PressableSurface(
                    // The page change is its own feedback; a UI tick here would
                    // double up on the route transition.
                    playFeedback: false,
                    onTap: onPressed,
                    borderRadius: AppRadii.of(context).fullRadius,
                    color: scheme.surfaceContainerHigh,
                    child: Center(
                      child: M3MorphingIcon(
                        icon: rtl
                            ? Icons.arrow_forward_rounded
                            : Icons.arrow_back_rounded,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
