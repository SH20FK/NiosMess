import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class AdaptivePoller {
  AdaptivePoller({
    required this.onRefresh,
    this.foregroundInterval = const Duration(seconds: 3),
    this.idleInterval = const Duration(seconds: 8),
    this.backgroundInterval = const Duration(seconds: 15),
  });

  final VoidCallback onRefresh;
  final Duration foregroundInterval;
  final Duration idleInterval;
  final Duration backgroundInterval;

  Timer? _timer;
  bool _paused = false;
  bool _disposed = false;
  AppLifecycleListener? _lifecycle;

  void start() {
    if (_disposed) return;
    _lifecycle = AppLifecycleListener(
      onStateChange: _onStateChange,
    );
    _schedule(foregroundInterval);
  }

  void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_disposed) return;
    _paused = false;
    onRefresh();
    _schedule(foregroundInterval);
  }

  void refreshNow() {
    if (_disposed || _paused) return;
    onRefresh();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
  }

  void _onStateChange(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _paused = false;
        onRefresh();
        _schedule(foregroundInterval);
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _paused = true;
        _timer?.cancel();
        _timer = null;
        _schedule(backgroundInterval);
      case AppLifecycleState.detached:
        _paused = true;
        _timer?.cancel();
        _timer = null;
    }
  }

  void _schedule(Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      if (_disposed || _paused) return;
      onRefresh();
    });
  }
}

class VisibilityPoller extends StatefulWidget {
  const VisibilityPoller({
    required this.poller,
    required this.child,
    super.key,
  });

  final AdaptivePoller poller;
  final Widget child;

  @override
  State<VisibilityPoller> createState() => _VisibilityPollerState();
}

class _VisibilityPollerState extends State<VisibilityPoller> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      widget.poller.resume();
    });
  }

  @override
  void dispose() {
    widget.poller.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
