import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/motion/m3_spring_switcher.dart';

/// The loading, error and loaded forms of a settings screen, cross-faded
/// instead of swapped in one frame. Takes the same three builders as
/// [AsyncValue.when] and shows the same form it would.
class SettingsAsyncSwitcher<T> extends StatelessWidget {
  const SettingsAsyncSwitcher({
    required this.value,
    required this.data,
    required this.loading,
    required this.error,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function() loading;
  final Widget Function(Object error, StackTrace stackTrace) error;

  @override
  Widget build(BuildContext context) {
    final (String form, Widget child) = value.when(
      data: (T loaded) => ('data', data(loaded)),
      loading: () => ('loading', loading()),
      error: (Object e, StackTrace s) => ('error', error(e, s)),
    );
    return M3SpringSwitcher(
      type: M3SwitcherType.fade,
      duration: M3Durations.medium1,
      reverseDuration: M3Durations.short3,
      // Forms differ in height: keep them pinned to the top, and keep the
      // one that is leaving out of reach of taps and Tab.
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          for (final Widget old in previous)
            ExcludeFocus(child: IgnorePointer(child: old)),
          ?current,
        ],
      ),
      child: KeyedSubtree(key: ValueKey<String>(form), child: child),
    );
  }
}
