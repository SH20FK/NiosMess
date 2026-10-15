/// One account-level fallback poll. WebSocket pushes and reconnects bypass this
/// schedule; durable outgoing work remains eligible while the UI is paused.
class SecretPollSchedule {
  int _idleStep = 0;

  void reset() => _idleStep = 0;

  Duration? next({
    required bool connected,
    required bool background,
    required bool pending,
    required bool hasChats,
  }) {
    if (!connected || !hasChats || (background && !pending)) return null;
    if (pending) {
      reset();
      return const Duration(seconds: 5);
    }
    const seconds = [5, 10, 20, 40, 60];
    final delay = Duration(seconds: seconds[_idleStep]);
    if (_idleStep < seconds.length - 1) _idleStep++;
    return delay;
  }
}
