import 'package:flutter/foundation.dart';

sealed class SettingsControl {
  const SettingsControl();
}

final class NavigationControl extends SettingsControl {
  const NavigationControl({this.value});
  final String? value;
}

final class ToggleControl extends SettingsControl {
  const ToggleControl({
    required this.value,
    required this.onChanged,
    this.pending = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool pending;
}

final class ValueControl extends SettingsControl {
  const ValueControl(this.value);
  final String value;
}

final class ActionControl extends SettingsControl {
  const ActionControl({this.destructive = false});
  final bool destructive;
}
