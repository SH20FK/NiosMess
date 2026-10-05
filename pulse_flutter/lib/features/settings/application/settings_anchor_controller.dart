import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class SettingsAnchorState {
  const SettingsAnchorState({
    this.targetRoute,
    this.highlightedAnchor,
  });

  final String? targetRoute;
  final String? highlightedAnchor;
}

class SettingsAnchorController extends Notifier<SettingsAnchorState> {
  Timer? _dismissTimer;

  @override
  SettingsAnchorState build() {
    ref.onDispose(() => _dismissTimer?.cancel());
    return const SettingsAnchorState();
  }

  void request({required String route, required String anchor}) {
    _dismissTimer?.cancel();
    state = SettingsAnchorState(targetRoute: route, highlightedAnchor: anchor);
    _dismissTimer = Timer(const Duration(milliseconds: 1000), () {
      state = const SettingsAnchorState();
    });
  }

  void clear() {
    _dismissTimer?.cancel();
    state = const SettingsAnchorState();
  }
}

final NotifierProvider<SettingsAnchorController, SettingsAnchorState>
    settingsAnchorControllerProvider =
        NotifierProvider<SettingsAnchorController, SettingsAnchorState>(
  SettingsAnchorController.new,
);
