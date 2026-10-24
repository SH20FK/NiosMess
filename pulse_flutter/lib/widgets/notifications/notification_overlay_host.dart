import 'package:flutter/widgets.dart';

/// Global banners and call controls need an Overlay ancestor for focus/tooltips.
/// Keep the entry mounted across theme/router changes, but update its content.
class NotificationOverlayHost extends StatefulWidget {
  const NotificationOverlayHost({super.key, required this.child});
  final Widget child;
  @override
  State<NotificationOverlayHost> createState() =>
      _NotificationOverlayHostState();
}

class _NotificationOverlayHostState extends State<NotificationOverlayHost> {
  late final OverlayEntry _entry;
  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(builder: (_) => widget.child);
  }

  @override
  void didUpdateWidget(covariant NotificationOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
