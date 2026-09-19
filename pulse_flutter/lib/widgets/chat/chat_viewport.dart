import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pulse_flutter/widgets/chat/chat_message_edge_fade.dart';

/// Single RenderProxyBox to measure the dynamic height of the composer.
class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onSizeChange);

  void Function(Size size) onSizeChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final Size newSize = child?.size ?? Size.zero;
    if (_oldSize != newSize) {
      _oldSize = newSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSizeChange(newSize);
      });
    }
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({
    required this.onSizeChange,
    required super.child,
  });

  final void Function(Size size) onSizeChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onSizeChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onSizeChange = onSizeChange;
  }
}

/// Unified chat viewport architecture for NiosMess.
///
/// Single owner for:
/// - Wallpaper (fills viewport)
/// - Messages scroll view (with bottom padding = composerHeight)
/// - Top edge fade
/// - Dynamic bottom edge fade (anchored directly to top boundary of composer)
/// - Unified composer surface (background, subtle border, SafeArea)
/// - Scroll-to-bottom FAB (anchored to composer surface + 16dp)
/// - Security/system banners (pinned to top)
class ChatViewport extends StatefulWidget {
  const ChatViewport({
    super.key,
    required this.wallpaper,
    required this.messagesBuilder,
    required this.composer,
    this.topBanner,
    this.floatingActionButton,
    this.composerSurfaceColor,
    this.bottomFadeHeight = 64.0,
    this.topFadeHeight = 44.0,
  });

  /// Fullscreen wallpaper filling the viewport
  final Widget wallpaper;

  /// Builder for messages scrollable view. Receives effective composer height.
  final Widget Function(BuildContext context, double composerHeight)
      messagesBuilder;

  /// Unified composer surface (input, reply bar, attachments/dock)
  final Widget composer;

  /// System/security banners at top of viewport (offline, E2EE warnings)
  final Widget? topBanner;

  /// Floating action button (e.g. scroll to bottom)
  final Widget? floatingActionButton;

  /// Custom color for composer surface and bottom fade gradient
  final Color? composerSurfaceColor;

  /// Overhang height of dynamic bottom edge fade above composer (56..84 dp)
  final double bottomFadeHeight;

  /// Height of top edge fade
  final double topFadeHeight;

  @override
  State<ChatViewport> createState() => _ChatViewportState();
}

class _ChatViewportState extends State<ChatViewport> {
  double _composerHeight = 72.0;

  void _onComposerSizeChanged(Size size) {
    if (!mounted) return;
    if ((_composerHeight - size.height).abs() > 0.5) {
      setState(() {
        _composerHeight = size.height;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color composerSurface =
        widget.composerSurfaceColor ?? scheme.surfaceContainerLow;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 1. Wallpaper (full screen)
        Positioned.fill(
          child: widget.wallpaper,
        ),

        // 2. Messages scroll view (full viewport, bottom padding = composerHeight)
        Positioned.fill(
          child: widget.messagesBuilder(context, _composerHeight),
        ),

        // 3. Top edge fade (short, neat dissolution at top)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: widget.topFadeHeight,
          child: ChatMessageTopFade(
            height: widget.topFadeHeight,
            color: scheme.surface,
          ),
        ),

        // 4. Dynamic bottom edge fade (anchored to bottom 0, extending behind composer)
        ChatMessageBottomFade(
          bottom: 0.0,
          height: _composerHeight + widget.bottomFadeHeight,
          fadeOverhang: widget.bottomFadeHeight,
          color: composerSurface,
        ),

        // 5. Unified floating composer surface
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _MeasureSize(
            onSizeChange: _onComposerSizeChanged,
            child: RepaintBoundary(
              child: SafeArea(
                top: false,
                bottom: true,
                child: widget.composer,
              ),
            ),
          ),
        ),

        // 6. Scroll-to-bottom FAB (anchored to composer surface + 16dp)
        if (widget.floatingActionButton != null)
          Positioned(
            right: 16,
            bottom: _composerHeight + 16,
            child: widget.floatingActionButton!,
          ),

        // 7. Security / system banner (pinned to top)
        if (widget.topBanner != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: widget.topBanner!,
          ),
      ],
    );
  }
}
