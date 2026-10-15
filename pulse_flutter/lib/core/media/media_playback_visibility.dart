import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Native playback follows the viewport, route and app, not just Dart tickers.
class MediaPlaybackVisibility extends StatefulWidget {
  const MediaPlaybackVisibility({
    required this.onChanged,
    required this.child,
    super.key,
  });
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  State<MediaPlaybackVisibility> createState() =>
      _MediaPlaybackVisibilityState();
}

class _MediaPlaybackVisibilityState extends State<MediaPlaybackVisibility>
    with WidgetsBindingObserver {
  ScrollNotificationObserverState? _scrollObserver;
  bool _currentRoute = true;
  bool _tickerEnabled = true;
  bool _foreground = true;
  bool _visible = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _currentRoute = ModalRoute.isCurrentOf(context) ?? true;
    final observer = ScrollNotificationObserver.maybeOf(context);
    if (_scrollObserver != observer) {
      _scrollObserver?.removeListener(_onScroll);
      _scrollObserver = observer;
      observer?.addListener(_onScroll);
    }
    _scheduleCheck();
  }

  void _onScroll(ScrollNotification _) => _scheduleCheck();

  void _scheduleCheck() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      var visible = _foreground && _tickerEnabled && _currentRoute;
      if (visible && box is RenderBox && box.attached && box.hasSize) {
        final bounds = box.localToGlobal(Offset.zero) & box.size;
        var viewportBounds = Offset.zero & MediaQuery.sizeOf(context);
        // Inner carousels can intersect their own viewport while the containing
        // chat is clipped. Account for every viewport and the window bounds.
        RenderObject? ancestor = box.parent;
        while (ancestor != null) {
          if (ancestor is RenderOffstage && ancestor.offstage) {
            visible = false;
            break;
          }
          if (ancestor is RenderAbstractViewport && ancestor is RenderBox) {
            final viewportBox = ancestor as RenderBox;
            if (viewportBox.hasSize) {
              viewportBounds = viewportBounds.intersect(
                viewportBox.localToGlobal(Offset.zero) & viewportBox.size,
              );
            }
          }
          ancestor = ancestor.parent;
        }
        final intersection = bounds.intersect(viewportBounds);
        visible = visible && intersection.width > 1 && intersection.height > 1;
      } else {
        visible = false;
      }
      if (_visible != visible) {
        _visible = visible;
        widget.onChanged(visible);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MediaPlaybackVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _visible) {
      _visible = false;
      widget.onChanged(false);
    }
    _scheduleCheck();
  }

  @override
  void dispose() {
    _scrollObserver?.removeListener(_onScroll);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
