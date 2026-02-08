import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// MorphingAppBar - AppBar с изменяемой формой при скролле
/// Фича #4: Morphing AppBar
/// 
/// При скролле вниз: borderRadius уменьшается (20→0)
/// При скролле вверх: borderRadius возвращается
class MorphingAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double expandedHeight;
  final double collapsedHeight;
  final double maxBorderRadius;
  final double minBorderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? flexibleSpace;
  final bool centerTitle;
  final double elevation;
  final ScrollController? scrollController;

  const MorphingAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.expandedHeight = 120.0,
    this.collapsedHeight = 56.0,
    this.maxBorderRadius = 20.0,
    this.minBorderRadius = 0.0,
    this.backgroundColor,
    this.foregroundColor,
    this.flexibleSpace,
    this.centerTitle = false,
    this.elevation = 0,
    this.scrollController,
  });

  @override
  State<MorphingAppBar> createState() => _MorphingAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(expandedHeight);
}

class _MorphingAppBarState extends State<MorphingAppBar> {
  double _scrollOffset = 0.0;
  double _borderRadius = 20.0;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final offset = widget.scrollController?.offset ?? 0.0;
    final maxScroll = widget.expandedHeight - widget.collapsedHeight;
    
    // Нормализуем offset (0.0 - 1.0)
    final progress = (offset / maxScroll).clamp(0.0, 1.0);
    
    setState(() {
      _scrollOffset = offset;
      // Интерполяция borderRadius
      _borderRadius = widget.maxBorderRadius - 
          (widget.maxBorderRadius - widget.minBorderRadius) * progress;
      // Интерполяция прозрачности дополнительного контента
      _opacity = 1.0 - progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surface;
    final fgColor = widget.foregroundColor ?? theme.colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      height: widget.expandedHeight - _scrollOffset.clamp(0.0, widget.expandedHeight - widget.collapsedHeight),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_borderRadius),
          bottomRight: Radius.circular(_borderRadius),
        ),
        boxShadow: widget.elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: widget.elevation * 2,
                  offset: Offset(0, widget.elevation),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_borderRadius),
          bottomRight: Radius.circular(_borderRadius),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: widget.leading,
          actions: widget.actions,
          centerTitle: widget.centerTitle,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: theme.brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          flexibleSpace: widget.flexibleSpace != null
              ? Opacity(
                  opacity: _opacity,
                  child: widget.flexibleSpace,
                )
              : null,
          title: AnimatedOpacity(
            opacity: _opacity < 0.3 ? 1.0 : (_opacity > 0.7 ? 1.0 : 0.8),
            duration: const Duration(milliseconds: 150),
            child: Text(
              widget.title,
              style: TextStyle(
                color: fgColor,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SliverMorphingAppBar - версия для CustomScrollView
class SliverMorphingAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double expandedHeight;
  final double collapsedHeight;
  final double maxBorderRadius;
  final double minBorderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? flexibleSpace;
  final bool centerTitle;

  const SliverMorphingAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.expandedHeight = 120.0,
    this.collapsedHeight = 56.0,
    this.maxBorderRadius = 20.0,
    this.minBorderRadius = 0.0,
    this.backgroundColor,
    this.foregroundColor,
    this.flexibleSpace,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.surface;
    final fgColor = foregroundColor ?? theme.colorScheme.onSurface;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      collapsedHeight: collapsedHeight,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final progress = 1.0 - 
              ((constraints.maxHeight - collapsedHeight) / (expandedHeight - collapsedHeight))
                  .clamp(0.0, 1.0);
          
          final borderRadius = maxBorderRadius - (maxBorderRadius - minBorderRadius) * progress;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(borderRadius),
                bottomRight: Radius.circular(borderRadius),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(borderRadius),
                bottomRight: Radius.circular(borderRadius),
              ),
              child: FlexibleSpaceBar(
                title: Text(
                  title,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                centerTitle: centerTitle,
                background: flexibleSpace,
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 16,
                  bottom: 16,
                ),
              ),
            ),
          );
        },
      ),
      leading: leading,
      actions: actions,
    );
  }
}
