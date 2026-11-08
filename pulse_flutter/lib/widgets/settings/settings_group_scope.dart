import 'package:flutter/material.dart';

/// The surface and shape shared by a row in a connected settings group.
class SettingsGroupScope extends InheritedWidget {
  const SettingsGroupScope({
    required this.borderRadius,
    required this.color,
    required super.child,
    super.key,
  });

  final BorderRadius borderRadius;
  final Color color;

  static SettingsGroupScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsGroupScope>();

  @override
  bool updateShouldNotify(SettingsGroupScope oldWidget) =>
      borderRadius != oldWidget.borderRadius || color != oldWidget.color;
}
