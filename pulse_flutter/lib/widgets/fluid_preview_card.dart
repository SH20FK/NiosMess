import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/nios_motion.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class FluidPreviewCard extends StatefulWidget {
  const FluidPreviewCard({
    required this.settings,
    required this.scheme,
    required this.textTheme,
    super.key,
  });

  final UiSettingsState settings;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  State<FluidPreviewCard> createState() => _FluidPreviewCardState();
}

class _FluidPreviewCardState extends State<FluidPreviewCard>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final ValueNotifier<double> _squishFactorNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<Offset> _parallaxNotifier = ValueNotifier<Offset>(Offset.zero);

  late final AnimationController _squishController;

  @override
  void initState() {
    super.initState();
    _squishController = AnimationController.unbounded(
      vsync: this,
      value: 0.0,
    );
    _pageController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) {
      return;
    }
    final double offset = _pageController.offset;
    final double viewport = _pageController.viewportFraction;
    if (viewport == 0) {
      return;
    }
    final double raw = offset / viewport;
    final double pageDiff = raw - _currentPage;
    _squishFactorNotifier.value = (pageDiff * 6).clamp(-12.0, 12.0);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _squishController.dispose();
    _squishFactorNotifier.dispose();
    _parallaxNotifier.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _squishController
        .animateWithSpring(
      spring: NiosMotion.snappy,
      target: 1.0,
    )
        .then((_) {
      if (mounted) {
        _squishFactorNotifier.value = 0.0;
        _squishController.value = 0.0;
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final Offset current = _parallaxNotifier.value;
    _parallaxNotifier.value = Offset(
      (d.delta.dx * 0.3 + current.dx).clamp(-12.0, 12.0),
      (d.delta.dy * 0.3 + current.dy).clamp(-8.0, 8.0),
    );
  }

  void _onPanEnd(DragEndDetails d) {
    _squishController
        .animateWithSpring(
      spring: NiosMotion.snappy,
      target: 1.0,
    )
        .then((_) {
      if (mounted) {
        _parallaxNotifier.value = Offset.zero;
        _squishController.value = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            _squishFactorNotifier,
            _parallaxNotifier,
            _squishController,
          ]),
          builder: (BuildContext context, _) {
            final double squishFactor = _squishFactorNotifier.value;
            final Offset parallax = _parallaxNotifier.value;
            final double squishOffset =
                squishFactor * (1.0 - _squishController.value * 0.5);

            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..setEntry(1, 0, squishOffset * 0.008)
                ..translateByDouble(
                  parallax.dx * (1.0 - _squishController.value * 0.5),
                  parallax.dy * (1.0 - _squishController.value * 0.5),
                  0,
                  1.0,
                ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      math.max(20.0 - squishOffset.abs() * 0.5, AppRadii.md),
                    ),
                    topRight: Radius.circular(
                      math.max(20.0 - squishOffset.abs() * 0.5, AppRadii.md),
                    ),
                    bottomLeft: Radius.circular(
                      math.max(20.0 + squishOffset.abs() * 0.3, AppRadii.md),
                    ),
                    bottomRight: Radius.circular(
                      math.max(20.0 + squishOffset.abs() * 0.3, AppRadii.md),
                    ),
                  ),
                ),
                child: _buildPreviewContent(context),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    return Material(
      color: widget.scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _buildPreviewBackground(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPreviewHeader(
                        icon: Icons.person_rounded,
                        title: 'SH20FK',
                      ),
                      const Spacer(),
                      _buildBubble(
                        text: context.l10n.appearanceIncomingPreview,
                        isMine: false,
                      ),
                      const SizedBox(height: 6),
                      _buildBubble(
                        text: context.l10n.appearanceAccentPreview,
                        isMine: true,
                      ),
                    ],
                  ),
                ),
                _buildPreviewBackground(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPreviewHeader(
                        icon: Icons.campaign_rounded,
                        title: 'NiosMess News',
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.scheme.surfaceContainerHigh.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.fluidPreviewM3Title,
                              style: widget.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: widget.scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.l10n.fluidPreviewM3Subtitle,
                              style: widget.textTheme.bodySmall?.copyWith(
                                color: widget.scheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPreviewBackground(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: widget.scheme.primaryContainer,
                        foregroundColor: widget.scheme.onPrimaryContainer,
                        child: const Text('S', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SH20FK',
                        style: widget.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: widget.scheme.onSurface,
                        ),
                      ),
                      Text(
                        '@sh20fk',
                        style: widget.textTheme.bodySmall?.copyWith(
                          color: widget.scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (int index) {
              final bool active = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 16 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? widget.scheme.primary
                      : widget.scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildPreviewBackground({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient(widget.scheme),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _buildPreviewHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(Icons.arrow_back_rounded, color: widget.scheme.onSurface, size: 18),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 11,
          backgroundColor: widget.scheme.primary.withValues(alpha: 0.18),
          child: Icon(icon, size: 12, color: widget.scheme.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: widget.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: widget.scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildBubble({required String text, required bool isMine}) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: isMine
              ? widget.scheme.primary
              : widget.scheme.surfaceContainerHighest.withValues(alpha: 0.85),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMine ? 12 : 3),
            bottomRight: Radius.circular(isMine ? 3 : 12),
          ),
        ),
        child: Text(
          text,
          style: widget.textTheme.bodySmall?.copyWith(
            color: isMine ? widget.scheme.onPrimary : widget.scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
