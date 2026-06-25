import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
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

  double _squishFactor = 0;
  double _parallaxDx = 0;
  double _parallaxDy = 0;

  late final AnimationController _squishController;

  @override
  void initState() {
    super.initState();
    _squishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pageController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final double offset = _pageController.offset;
    final double viewport = _pageController.viewportFraction;
    if (viewport == 0) return;
    final double raw = offset / viewport;
    final double pageDiff = raw - _currentPage;
    setState(() => _squishFactor = (pageDiff * 6).clamp(-12, 12));
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _squishController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    _squishController.forward(from: 0).then((_) {
      if (mounted) setState(() => _squishFactor = 0);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _parallaxDx = (d.delta.dx * 0.3 + _parallaxDx).clamp(-12, 12);
      _parallaxDy = (d.delta.dy * 0.3 + _parallaxDy).clamp(-8, 8);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    _squishController.forward(from: 0).then((_) {
      if (mounted) setState(() {
        _parallaxDx = 0;
        _parallaxDy = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final double squishOffset = _squishFactor + _squishController.value * _squishFactor * -0.3;

    return GestureDetector(
      onPanUpdate: kIsWeb ? _onPanUpdate : null,
      onPanEnd: kIsWeb ? _onPanEnd : null,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _squishController,
          builder: (context, _) {
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..setEntry(1, 0, squishOffset * 0.008)
                ..translate(
                  _parallaxDx * (1 - _squishController.value * 0.5),
                  _parallaxDy * (1 - _squishController.value * 0.5),
                ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      math.max(20 - squishOffset.abs() * 0.5, 12),
                    ),
                    topRight: Radius.circular(
                      math.max(20 - squishOffset.abs() * 0.5, 12),
                    ),
                    bottomLeft: Radius.circular(
                      math.max(20 + squishOffset.abs() * 0.3, 12),
                    ),
                    bottomRight: Radius.circular(
                      math.max(20 + squishOffset.abs() * 0.3, 12),
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
