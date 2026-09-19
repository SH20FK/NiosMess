
/// Exception thrown when an ongoing upload or network operation is cancelled.
class UploadCancelledException implements Exception {
  const UploadCancelledException([this.message = 'Upload cancelled by user']);

  final String message;

  @override
  String toString() => message;
}

/// Token used to propagate cancellation signals across asynchronous
/// operations (HTTP client abort, stream termination, chunked loop breaking).
class CancellationToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = <void Function()>[];

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Requests cancellation and triggers all attached listeners immediately.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    final List<void Function()> listenersCopy =
        List<void Function()>.from(_listeners);
    _listeners.clear();
    for (final void Function() listener in listenersCopy) {
      try {
        listener();
      } catch (_) {
        // Ignore listener errors during cancellation teardown.
      }
    }
  }

  /// Adds a listener to be called when cancellation occurs.
  /// If the token is already cancelled, the listener is called immediately.
  void addListener(void Function() listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  /// Removes a previously registered listener.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// Throws [UploadCancelledException] if cancellation has been requested.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw const UploadCancelledException();
    }
  }
}
