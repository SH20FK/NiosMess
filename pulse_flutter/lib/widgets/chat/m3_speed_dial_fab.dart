import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

/// Material 3 Expressive Speed Dial FloatingActionButton.
///
/// Features:
/// - Squircle shape (20dp radius) with tonal primary container styling.
/// - Scroll-aware show/hide animation using [M3SpringCurves.spatial].
/// - Tap expands into an expressive speed dial with rotating close icon and
///   staggered spring pop-up pills for "New Group" and "New Channel".
/// - Touch outside / scrim dismisses the speed dial.
/// - System back navigation dismisses overlay cleanly.
class M3SpeedDialFab extends StatefulWidget {
  const M3SpeedDialFab({
    required this.onSelectGroup,
    required this.onSelectChannel,
    this.visible = true,
    this.heroTag = 'compose_chat_fab',
    super.key,
  });

  final VoidCallback onSelectGroup;
  final VoidCallback onSelectChannel;
  final bool visible;
  final Object? heroTag;

  @override
  State<M3SpeedDialFab> createState() => _M3SpeedDialFabState();
}

class _M3SpeedDialFabState extends State<M3SpeedDialFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _rotationAnimation;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.bouncy,
      reverseCurve: M3SpringCurves.snappy,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: M3SpringCurves.bouncy,
        reverseCurve: M3SpringCurves.snappy,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant M3SpeedDialFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible && _isOpen) {
      _close();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticService.tap();
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    if (_isOpen) return;
    _isOpen = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _controller.forward();
    if (mounted) setState(() {});
  }

  void _close() {
    if (!_isOpen) return;
    _isOpen = false;
    _controller.reverse().then((_) {
      _removeOverlay();
    });
    if (mounted) setState(() {});
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (BuildContext overlayContext) {
        final ColorScheme scheme = Theme.of(overlayContext).colorScheme;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) {
              HapticService.tap();
              _close();
            }
          },
          child: Stack(
            children: <Widget>[
              // Scrim / Backdrop
              Positioned.fill(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticService.tap();
                      _close();
                    },
                    child: Container(
                      color: scheme.scrim.withValues(alpha: 0.36),
                    ),
                  ),
                ),
              ),

              // Satellite Items & Active FAB linked to base position
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.bottomRight,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    final double progress = _expandAnimation.value;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        // Action 2: New Channel
                        _buildActionItem(
                          context: context,
                          label: context.l10n.groupNewChannel,
                          icon: Icons.campaign_rounded,
                          iconColor: scheme.onTertiaryContainer,
                          containerColor: scheme.tertiaryContainer,
                          delayProgress: (progress - 0.2).clamp(0.0, 0.8) / 0.8,
                          onTap: () {
                            HapticService.tap();
                            _close();
                            widget.onSelectChannel();
                          },
                        ),
                        const SizedBox(height: 12),

                        // Action 1: New Group
                        _buildActionItem(
                          context: context,
                          label: context.l10n.groupNewGroup,
                          icon: Icons.groups_rounded,
                          iconColor: scheme.onPrimaryContainer,
                          containerColor: scheme.primaryContainer,
                          delayProgress: progress.clamp(0.0, 1.0),
                          onTap: () {
                            HapticService.tap();
                            _close();
                            widget.onSelectGroup();
                          },
                        ),
                        const SizedBox(height: 14),

                        // Overlay active FAB copy sitting above scrim
                        _buildFabButton(
                          scheme: scheme,
                          isExpanded: true,
                          onTap: () {
                            HapticService.tap();
                            _close();
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color containerColor,
    required double delayProgress,
    required VoidCallback onTap,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Transform.scale(
      scale: math.max(0.0, delayProgress),
      alignment: Alignment.centerRight,
      child: Opacity(
        opacity: delayProgress.clamp(0.0, 1.0),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Text label pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.20),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Squircle icon button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.15),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFabButton({
    required ColorScheme scheme,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: isExpanded ? 'Закрыть меню создания' : context.l10n.commonCreate,
      child: Material(
        color: scheme.primaryContainer,
        elevation: isExpanded ? 6 : 3,
        shadowColor: scheme.shadow.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.20),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (BuildContext context, Widget? child) {
                final double t = _rotationAnimation.value;
                final bool showClose = t > 0.25;

                return Transform.rotate(
                  angle: t * math.pi,
                  child: Icon(
                    showClose ? Icons.close_rounded : Icons.edit_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 26,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: AnimatedScale(
        scale: widget.visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: M3SpringCurves.spatial,
        child: AnimatedOpacity(
          opacity: widget.visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: _isOpen
              ? const SizedBox(width: 56, height: 56)
              : _buildFabButton(
                  scheme: scheme,
                  isExpanded: false,
                  onTap: _toggle,
                ),
        ),
      ),
    );
  }
}
