import 'package:flutter/widgets.dart';

/// The anchored list knows its tail coordinate; estimated sliver extents do not.
class ChatHistoryScrollController extends ScrollController {
  Object? _owner;
  Future<void> Function(bool animate)? _latest;
  bool get hasLatestHandler => _latest != null;
  void bindLatest(Object owner, Future<void> Function(bool) handler) {
    _owner = owner;
    _latest = handler;
  }

  void unbindLatest(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _latest = null;
  }

  Future<void> moveToLoadedLatest(bool animate) async {
    await _latest?.call(animate);
  }
}
