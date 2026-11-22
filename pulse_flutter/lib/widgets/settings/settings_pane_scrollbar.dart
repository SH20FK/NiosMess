import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';

/// A scrollbar for a settings pane in a desktop window or a browser, where a
/// mouse has no other cue that the pane scrolls. On a phone it adds nothing
/// and hands the builder no controller, so the list stays the primary scroll
/// view.
class SettingsPaneScrollbar extends ConsumerStatefulWidget {
  const SettingsPaneScrollbar({required this.builder, super.key});

  /// Builds the scroll view. A non-null controller must be given to it.
  final Widget Function(BuildContext context, ScrollController? controller)
  builder;

  @override
  ConsumerState<SettingsPaneScrollbar> createState() =>
      _SettingsPaneScrollbarState();
}

class _SettingsPaneScrollbarState extends ConsumerState<SettingsPaneScrollbar> {
  ScrollController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool pointer = ref.watch(
      clientCapabilitiesProvider.select(
        (c) => c.desktopFiles || c.browserWorkspace,
      ),
    );
    if (!pointer) return widget.builder(context, null);
    final ScrollController controller = _controller ??= ScrollController();
    return Scrollbar(
      controller: controller,
      // The app-wide scroll behaviour draws its own bar in a browser for any
      // list with a controller: without this there would be two.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget.builder(context, controller),
      ),
    );
  }
}
