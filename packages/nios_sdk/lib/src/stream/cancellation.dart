/// Cooperative cancellation. Tokens can be shared by a transfer and its source.
final class StreamCancellation {
  bool _cancelled = false;
  final Set<void Function()> _listeners = {};

  bool get isCancelled => _cancelled;

  void throwIfCancelled() {
    if (_cancelled) throw const StreamCancelledException();
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  /// Returns a function that unregisters this listener.
  void Function() onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }
}

final class StreamCancelledException implements Exception {
  const StreamCancelledException();

  @override
  String toString() => 'StreamCancelledException';
}
