import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

enum ModalVariant {
  dialog,
  bottomSheet,
  sideSheet,
}

enum ModalTone {
  low,
  standard,
  high,
  highest,
  error,
}

/// A unified Material 3 Expressive surface container for modals, dialogs, sheets, and side panels.
/// Guarantees zero live blur passes, purely tonal elevation, and standardized radius scaling.
class M3ModalSurface extends StatelessWidget {
  const M3ModalSurface({
    required this.child,
    this.variant = ModalVariant.bottomSheet,
    this.tone = ModalTone.high,
    this.maxWidth,
    this.maxHeight,
    this.showDragHandle = false,
    this.isScrollable = false,
    this.destructive = false,
    this.padding,
    super.key,
  });

  final Widget child;
  final ModalVariant variant;
  final ModalTone tone;
  final double? maxWidth;
  final double? maxHeight;
  final bool showDragHandle;
  final bool isScrollable;
  final bool destructive;
  final EdgeInsetsGeometry? padding;

  Color _resolveBackgroundColor(ColorScheme scheme) {
    if (destructive || tone == ModalTone.error) {
      return scheme.errorContainer;
    }
    switch (tone) {
      case ModalTone.low:
        return scheme.surfaceContainerLow;
      case ModalTone.standard:
        return scheme.surfaceContainer;
      case ModalTone.high:
        return scheme.surfaceContainerHigh;
      case ModalTone.highest:
        return scheme.surfaceContainerHighest;
      case ModalTone.error:
        return scheme.errorContainer;
    }
  }

  BorderRadius _resolveBorderRadius() {
    switch (variant) {
      case ModalVariant.dialog:
        return AppRadii.xlRadius;
      case ModalVariant.bottomSheet:
        return const BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        );
      case ModalVariant.sideSheet:
        return const BorderRadius.horizontal(
          left: Radius.circular(AppRadii.xl),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color backgroundColor = _resolveBackgroundColor(scheme);
    final BorderRadius borderRadius = _resolveBorderRadius();
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showDragHandle && variant == ModalVariant.bottomSheet) ...<Widget>[
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (isScrollable)
          Flexible(child: content)
        else
          content,
      ],
    );

    // Apply safe area constraints depending on modal variant
    if (variant == ModalVariant.bottomSheet) {
      body = SafeArea(
        top: false,
        bottom: true,
        child: body,
      );
    } else if (variant == ModalVariant.sideSheet) {
      body = SafeArea(
        top: true,
        bottom: true,
        left: false,
        right: true,
        child: body,
      );
    }

    Widget surface = Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: destructive
              ? scheme.error.withValues(alpha: 0.28)
              : scheme.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: body,
    );

    if (maxWidth != null || maxHeight != null) {
      surface = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? double.infinity,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: surface,
      );
    }

    if (bottomInset > 0 && variant == ModalVariant.bottomSheet) {
      surface = Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: surface,
      );
    }

    return surface;
  }
}
