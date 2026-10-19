import 'package:shared_preferences/shared_preferences.dart';

class MeshAccessState {
  const MeshAccessState({
    required this.enabled,
    required this.foreground,
    required this.networkAvailable,
    required this.serverAvailable,
    required this.radioState,
  });
  final bool enabled, foreground, networkAvailable, serverAvailable;
  final String radioState;
}

/// Uses the existing socket health, not an additional network probe. Persisting
/// before the OS dialog also prevents a killed/restarted app repeating a refusal.
class MeshAutomaticAccess {
  MeshAutomaticAccess({
    required this.snapshot,
    required this.request,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  static const refusalKey =
      'niosmess.bluetooth_fallback.auto_access_refused.v1';
  final MeshAccessState Function() snapshot;
  final Future<String> Function() request;
  final DateTime Function() now;
  DateTime? _unavailableSince, _lastAttempt;
  Future<SharedPreferences>? _preferences;
  Future<void>? _checking;
  bool _disposed = false;

  Future<void> check() =>
      _checking ??= _check().whenComplete(() => _checking = null);
  bool _needed(MeshAccessState value) =>
      !_disposed &&
      value.enabled &&
      value.foreground &&
      value.radioState != 'active' &&
      value.radioState != 'unsupported' &&
      value.radioState != 'unsupported_peripheral' &&
      (!value.networkAvailable || !value.serverAvailable);
  bool _stillNeeded() => !_disposed && _needed(snapshot());

  Future<void> _check() async {
    if (_disposed) return;
    final value = snapshot();
    if (value.radioState == 'active') {
      final prefs = await (_preferences ??= SharedPreferences.getInstance());
      if (!_disposed && prefs.getBool(refusalKey) == true) {
        await prefs.setBool(refusalKey, false);
      }
    }
    if (!_needed(value)) {
      _unavailableSince = null;
      return;
    }
    _unavailableSince ??= now();
    // A normal handshake/reconnect must not immediately summon a permission UI.
    if (value.networkAvailable &&
        now().difference(_unavailableSince!) < const Duration(seconds: 8)) {
      return;
    }
    if (_lastAttempt != null &&
        now().difference(_lastAttempt!) < const Duration(minutes: 1)) {
      return;
    }
    final prefs = await (_preferences ??= SharedPreferences.getInstance());
    if (!_stillNeeded() || prefs.getBool(refusalKey) == true) return;
    _lastAttempt = now();
    if (!await prefs.setBool(refusalKey, true)) return;
    if (!_stillNeeded()) {
      await prefs.setBool(refusalKey, false);
      return;
    }
    try {
      final result = await request();
      if (!_disposed &&
          result != 'permission_required' &&
          result != 'bluetooth_off') {
        await prefs.setBool(refusalKey, false);
      }
    } catch (_) {
      await prefs.setBool(refusalKey, false);
      rethrow;
    }
  }

  void dispose() {
    _disposed = true;
  }
}
