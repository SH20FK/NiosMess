import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Put around a settings section shown beside the list of sections. A screen
/// that belongs under the section (a privacy rule, the blocked list) then
/// opens in the same pane, and the list stays where it is.
class SettingsPaneScope extends InheritedWidget {
  const SettingsPaneScope({
    required this.onOpen,
    required this.onClose,
    required super.child,
    super.key,
  });

  /// Shows the screen of [route] in the pane. False when the pane has no
  /// such screen and the route should be pushed as usual.
  final bool Function(String route) onOpen;

  /// Returns from the opened screen to its section.
  final VoidCallback onClose;

  // Read from tap handlers only, so nothing subscribes to it.
  static SettingsPaneScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsPaneScope>();

  @override
  bool updateShouldNotify(SettingsPaneScope oldWidget) => false;
}

/// Opens a screen that sits under a settings section: in the pane when the
/// section is shown beside the list, as a pushed page otherwise. The returned
/// future completes when a pushed page is popped; in the pane the screen is
/// swapped without a route, so it completes right away.
Future<void> openSettingsPage(BuildContext context, String route) async {
  final SettingsPaneScope? pane = SettingsPaneScope.maybeOf(context);
  if (pane == null || !pane.onOpen(route)) await context.push(route);
}

/// Leaves a screen opened with [openSettingsPage] the way it came.
void closeSettingsPage(BuildContext context) {
  final SettingsPaneScope? pane = SettingsPaneScope.maybeOf(context);
  if (pane != null) {
    pane.onClose();
  } else {
    Navigator.of(context).maybePop();
  }
}
