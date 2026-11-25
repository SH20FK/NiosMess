import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_destination.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_item.dart';

/// M3 Expressive collapsed navigation rail: 96 dp wide, labelled destinations
/// with the same indicator, unread badge, sound and haptics as the bottom bar.
///
/// The shell shows it instead of the bar from 840 dp on every platform.
class AppNavRail extends ConsumerStatefulWidget {
  const AppNavRail({
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
  ConsumerState<AppNavRail> createState() => _AppNavRailState();
}

class _AppNavRailState extends ConsumerState<AppNavRail> {
  final AppNavTapController _taps = AppNavTapController();

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(adaptivePerformanceProvider.select((s) => s.tier));
    final bool animate = !context.reduceMotion;
    final Duration duration = animate
        ? (tier.isTierC ? M3Durations.short4 : M3Durations.medium2)
        : Duration.zero;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double itemExtent = AppNavMetrics.itemExtentFor(context);

    return DecoratedBox(
      key: const ValueKey('main-navigation-rail'),
      decoration: BoxDecoration(color: scheme.surfaceContainer),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: AppNavMetrics.railWidth,
          // Full height of the shell row: the row centres its children, and
          // the rail would otherwise shrink to its destinations.
          height: double.infinity,
          // A very low window scrolls the rail instead of overflowing it.
          child: SingleChildScrollView(
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 20),
                  Tooltip(
                    message: 'NiosMess',
                    child: ExcludeSemantics(
                      child: SizedBox.square(
                        dimension: 48,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: scheme.primaryContainer,
                            shape: AppRadii.superellipse(16),
                          ),
                          child: Icon(
                            Icons.forum_rounded,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final AppNavDestination destination
                      in AppNavDestination.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: SizedBox(
                        height: itemExtent,
                        child: AppNavItem(
                          key: ValueKey<String>(
                            'nav-item-${destination.route}',
                          ),
                          destination: destination,
                          selected: destination.index == widget.currentIndex,
                          animate: animate,
                          duration: duration,
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
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
