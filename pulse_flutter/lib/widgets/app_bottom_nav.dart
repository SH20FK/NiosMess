import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Animated squash-and-stretch pill indicator that travels horizontally
/// between navigation slots with M3 Expressive spatial spring physics.
class TravelingNavIndicator extends StatefulWidget {
  const TravelingNavIndicator({
    required this.index,
    required this.count,
    required this.color,
    required this.animate,
    this.stretch = 0.22,
    this.duration = const Duration(milliseconds: 220),
    this.pillHeight = 34.0,
    this.maxPillWidth = 72.0,
    super.key,
  });

  final int index;
  final int count;
  final Color color;
  final bool animate;
  final double stretch;
  final Duration duration;
  final double pillHeight;
  final double maxPillWidth;

  @override
  State<TravelingNavIndicator> createState() => _TravelingNavIndicatorState();
}

class _TravelingNavIndicatorState extends State<TravelingNavIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curveAnim;
  double _from = 0.0;
  double _fromStretch = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.index.toDouble();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1.0;
    _curveAnim = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.spatial,
    );
  }

  @override
  void didUpdateWidget(covariant TravelingNavIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (!widget.animate) {
      _from = widget.index.toDouble();
      _fromStretch = 0;
      _controller.value = 1;
      return;
    }
    if (oldWidget.index == widget.index) return;
    final raw = _controller.value;
    final oldTravel = ((oldWidget.index - _from).abs() / oldWidget.count).clamp(
      0.0,
      1.0,
    );
    _fromStretch =
        _fromStretch * (1 - raw) +
        oldWidget.stretch * 4 * raw * (1 - raw) * oldTravel;
    if (_controller.isAnimating) {
      final double currentT = _curveAnim.value;
      _from =
          ui.lerpDouble(_from, oldWidget.index.toDouble(), currentT) ??
          oldWidget.index.toDouble();
    } else {
      _from = oldWidget.index.toDouble();
    }
    if (widget.animate) {
      _controller.forward(from: 0.0);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _curveAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (widget.count <= 0 || constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        final double slot = constraints.maxWidth / widget.count;
        final double baseWidth = (slot * 0.62).clamp(48.0, widget.maxPillWidth);
        final double travel =
            ((widget.index.toDouble() - _from).abs() / widget.count).clamp(
              0.0,
              1.0,
            );

        double slotCenterX(double i) =>
            (Directionality.of(context) == TextDirection.rtl
                ? widget.count - i - 0.5
                : i + 0.5) *
            slot;

        return AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double t = _curveAnim.value;
            final raw = _controller.value;
            final deformation =
                _fromStretch * (1 - raw) +
                widget.stretch * 4 * raw * (1 - raw) * travel;
            final double pillW = baseWidth * (1 + deformation);
            final double pillH = widget.pillHeight * (1 - deformation * .5);
            final double fromX = slotCenterX(_from);
            final double toX = slotCenterX(widget.index.toDouble());
            final double currentCenterX = ui.lerpDouble(fromX, toX, t)!;
            final double left = currentCenterX - pillW / 2;
            final double top = (constraints.maxHeight - pillH) / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: left,
                  top: top,
                  width: pillW,
                  height: pillH,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: widget.color,
                      shape: const StadiumBorder(),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AppBottomNav extends ConsumerStatefulWidget {
  const AppBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.hapticsEnabled,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hapticsEnabled;

  @override
  ConsumerState<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends ConsumerState<AppBottomNav> {
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  void _handleTap(int index) {
    final DateTime now = DateTime.now();
    final feedback = now.difference(_lastTapTime).inMilliseconds >= 120;
    _lastTapTime = now;

    if (feedback && ref.read(uiSettingsProvider).soundEffects) {
      unawaited(ref.read(appSoundProvider).playUiTick());
    }
    if (feedback && widget.hapticsEnabled && index != widget.currentIndex) {
      HapticService.tap();
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final int totalUnread = ref.watch(totalUnreadCountProvider);
    final tier = ref.watch(adaptivePerformanceProvider.select((s) => s.tier));
    final bool animate =
        !tier.isTierC && !MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final duration = animate
        ? const Duration(milliseconds: 280)
        : Duration.zero;
    final items = <_NavItem>[
      _NavItem(
        context.l10n.tabChats,
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        badge: totalUnread,
      ),
      _NavItem(
        context.l10n.tabNiosgram,
        Icons.grid_view_outlined,
        Icons.grid_view_rounded,
      ),
      _NavItem(
        context.l10n.tabSettings,
        Icons.settings_outlined,
        Icons.settings_rounded,
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.7,
          ),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            height: 66,
            elevation: 0,
            backgroundColor: scheme.surfaceContainer,
            indicatorColor: scheme.primary.withValues(alpha: 0.16),
            indicatorShape: const StadiumBorder(),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
              (states) => TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        child: NavigationBar(
          key: const ValueKey('main-bottom-navigation'),
          height: 66,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          animationDuration: duration,
          maintainBottomViewPadding: true,
          selectedIndex: widget.currentIndex,
          onDestinationSelected: _handleTap,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: List<Widget>.generate(items.length, (index) {
            final item = items[index];
            final selected = index == widget.currentIndex;
            final icon = TabMorphIcon(
              outlineIcon: item.icon,
              filledIcon: item.selectedIcon,
              isSelected: selected,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              animate: animate,
              duration: duration,
              size: 20,
            );
            return NavigationDestination(
              label: item.label,
              icon: item.badge > 0
                  ? Badge(
                      backgroundColor: scheme.primary,
                      textColor: scheme.onPrimary,
                      label: Text(item.badge > 99 ? '99+' : '${item.badge}'),
                      child: icon,
                    )
                  : icon,
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon, {this.badge = 0});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badge;
}

class TabMorphIcon extends StatefulWidget {
  const TabMorphIcon({
    required this.outlineIcon,
    required this.filledIcon,
    required this.isSelected,
    required this.color,
    required this.animate,
    required this.duration,
    this.size = 24.0,
    super.key,
  });

  final IconData outlineIcon;
  final IconData filledIcon;
  final bool isSelected;
  final Color color;
  final bool animate;
  final Duration duration;
  final double size;

  @override
  State<TabMorphIcon> createState() => _TabMorphIconState();
}

class _TabMorphIconState extends State<TabMorphIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.expressiveDecel,
      reverseCurve: M3SpringCurves.expressiveAccel,
    );
  }

  @override
  void didUpdateWidget(covariant TabMorphIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (!widget.animate) {
      _controller.value = widget.isSelected ? 1 : 0;
      return;
    }
    if (oldWidget.isSelected != widget.isSelected) {
      if (widget.animate) {
        _controller.animateTo(
          widget.isSelected ? 1.0 : 0.0,
          duration: widget.duration,
          curve: Curves.linear,
        );
      } else {
        _controller.value = widget.isSelected ? 1.0 : 0.0;
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, _) {
        final double t = _animation.value;
        final pulse = math.sin(math.pi * _controller.value);
        final double scale = 1.0 + 0.16 * pulse;

        return Transform.translate(
          offset: Offset(0, -3.5 * pulse),
          child: Transform.scale(
            scale: scale,
            child: SizedBox.square(
              dimension: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Opacity(
                    opacity: (1.0 - t).clamp(0.0, 1.0),
                    child: Icon(
                      widget.outlineIcon,
                      size: widget.size,
                      color: widget.color,
                    ),
                  ),
                  Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Icon(
                      widget.filledIcon,
                      size: widget.size,
                      color: widget.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
