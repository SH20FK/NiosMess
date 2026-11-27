import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
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
    this.messagesGap = 8.0,
  });

  /// Fullscreen wallpaper filling the viewport
  final Widget wallpaper;

  /// Builder for messages scrollable view. `bottomInset` is the composer
  /// height plus [messagesGap]; the list listens to it instead of being
  /// rebuilt when the composer grows or shrinks.
  final Widget Function(
    BuildContext context,
    ValueListenable<double> bottomInset,
  )
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

  /// Gap between the newest message and the composer surface
  final double messagesGap;

  @override
  State<ChatViewport> createState() => _ChatViewportState();
}

class _ChatViewportState extends State<ChatViewport> {
  // The composer height lives in notifiers: opening the emoji panel or a reply
  // bar moves the inset, the fade and the FAB without rebuilding the messages.
  final ValueNotifier<double> _composerHeight = ValueNotifier<double>(72.0);
  late final ValueNotifier<double> _messagesInset = ValueNotifier<double>(
    _composerHeight.value + widget.messagesGap,
  );

  void _onComposerSizeChanged(Size size) {
    if (!mounted) return;
    if ((_composerHeight.value - size.height).abs() > 0.5) {
      _composerHeight.value = size.height;
      _messagesInset.value = size.height + widget.messagesGap;
    }
  }

  @override
  void didUpdateWidget(covariant ChatViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messagesGap != widget.messagesGap) {
      _messagesInset.value = _composerHeight.value + widget.messagesGap;
    }
  }

  @override
  void dispose() {
    _composerHeight.dispose();
    _messagesInset.dispose();
    super.dispose();
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
          child: widget.messagesBuilder(context, _messagesInset),
        ),

        // 3. Top edge fade (short, neat dissolution at top)
        // ChatMessageTopFade positions itself inside the Stack.
        ChatMessageTopFade(
          height: widget.topFadeHeight,
          color: scheme.surface,
        ),

        // 4. Dynamic bottom edge fade (anchored to bottom 0, extending behind composer)
        ValueListenableBuilder<double>(
          valueListenable: _composerHeight,
          builder: (BuildContext context, double height, _) =>
              ChatMessageBottomFade(
                bottom: 0.0,
                height: height + widget.bottomFadeHeight,
                fadeOverhang: widget.bottomFadeHeight,
                color: composerSurface,
              ),
        ),

        // 5. Unified floating composer surface. The composer subtree (chat
        // input area) carries its own RepaintBoundary, so none is layered
        // here.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _MeasureSize(
            onSizeChange: _onComposerSizeChanged,
            child: SafeArea(
              top: false,
              bottom: true,
              child: widget.composer,
            ),
          ),
        ),

        // 6. Scroll-to-bottom FAB (anchored to composer surface + 16dp)
        if (widget.floatingActionButton != null)
          ValueListenableBuilder<double>(
            valueListenable: _composerHeight,
            builder: (BuildContext context, double height, Widget? child) =>
                Positioned(right: 16, bottom: height + 16, child: child!),
            child: widget.floatingActionButton,
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
