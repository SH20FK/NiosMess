import 'package:flutter/foundation.dart';

/// Holds a deep link in memory until authentication and the router are ready.
class IncomingAppRoute extends ChangeNotifier {
  String? _pending;

  void enqueue(String route) {
    if (_pending == route) return;
    _pending = route;
    notifyListeners();
  }

  String? take({required bool hydrated}) {
    if (!hydrated) return null;
    final route = _pending;
    _pending = null;
    return route;
  }
}
