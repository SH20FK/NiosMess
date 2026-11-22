import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_destination.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_item.dart';

export 'package:pulse_flutter/widgets/nav/app_nav_item.dart' show TabMorphIcon;

/// M3 Expressive navigation bar: 64 dp, a 56x32 indicator per destination, and
/// horizontal destinations (icon beside the label) from 600 dp.
///
/// It is drawn by hand because the SDK `NavigationBar` hard-codes a 64 dp
/// indicator and has no horizontal destinations.
class AppBottomNav extends ConsumerStatefulWidget {
  const AppBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.hapticsEnabled,
    this.onReselect,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Called when the active destination is tapped again. Returns whether the
  /// tap did anything; an idle tap gives no sound and no haptic.
  final bool Function(int index)? onReselect;
  final bool hapticsEnabled;

  @override
  ConsumerState<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends ConsumerState<AppBottomNav> {
  final AppNavTapController _taps = AppNavTapController();

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(adaptivePerformanceProvider.select((s) => s.tier));
    final bool animate = !context.reduceMotion;
    final Duration duration = animate
        ? (tier.isTierC ? M3Durations.short4 : M3Durations.medium2)
        : Duration.zero;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      key: const ValueKey('main-bottom-navigation'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.7,
          ),
        ),
      ),
      child: Padding(
        // The bar owns the system gesture inset below its destinations.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: SizedBox(
          height: AppNavMetrics.itemExtentFor(context),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final AppNavItemLayout layout =
                  constraints.maxWidth >= Breakpoints.compact
                  ? AppNavItemLayout.horizontal
                  : AppNavItemLayout.vertical;
              return Semantics(
                container: true,
                explicitChildNodes: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final AppNavDestination destination
                        in AppNavDestination.values)
                      Expanded(
                        child: AppNavItem(
                          key: ValueKey<String>('nav-item-${destination.route}'),
                          destination: destination,
                          selected: destination.index == widget.currentIndex,
                          animate: animate,
                          duration: duration,
                          layout: layout,
                          onTap: () => _taps.handle(
                            ref,
                            index: destination.index,
                            currentIndex: widget.currentIndex,
                            onTap: widget.onTap,
                            onReselect: widget.onReselect,
                            haptics: widget.hapticsEnabled,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
