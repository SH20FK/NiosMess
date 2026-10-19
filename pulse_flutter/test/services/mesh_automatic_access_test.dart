import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_automatic_access.dart';

class _Environment {
  bool enabled = true, foreground = true, network = false, server = false;
  String radio = 'permission_required', result = 'permission_required';
  int requests = 0;
  DateTime time = DateTime.utc(2026, 10, 19);
  Completer<String>? pending;
  late final access = MeshAutomaticAccess(
    snapshot: () => MeshAccessState(
      enabled: enabled,
      foreground: foreground,
      networkAvailable: network,
      serverAvailable: server,
      radioState: radio,
    ),
    request: () async {
      requests++;
      return pending == null ? result : await pending!.future;
    },
    now: () => time,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('no network triggers one foreground OS request', () async {
    final env = _Environment();
    await env.access.check();
    await env.access.check();
    expect(env.requests, 1);
    env.access.dispose();
  });
  test(
    'server outage triggers after handshake grace even with Wi-Fi',
    () async {
      final env = _Environment()..network = true;
      await env.access.check();
      expect(env.requests, 0);
      env.time = env.time.add(const Duration(seconds: 8));
      await env.access.check();
      expect(env.requests, 1);
      env.access.dispose();
    },
  );
  test(
    'brief reconnect does not ask and a later outage gets a fresh grace',
    () async {
      final env = _Environment()..network = true;
      await env.access.check();
      env.time = env.time.add(const Duration(seconds: 6));
      env.server = true;
      await env.access.check();
      env.server = false;
      await env.access.check();
      env.time = env.time.add(const Duration(seconds: 6));
      await env.access.check();
      expect(env.requests, 0);
      env.access.dispose();
    },
  );
  test(
    'disabled setting and background suppress the UI until eligible',
    () async {
      final env = _Environment()..enabled = false;
      await env.access.check();
      env.enabled = true;
      env.foreground = false;
      await env.access.check();
      expect(env.requests, 0);
      env.foreground = true;
      await env.access.check();
      expect(env.requests, 1);
      env.access.dispose();
    },
  );
  test('refusal survives app/account restart, not just a reconnect', () async {
    final first = _Environment();
    await first.access.check();
    first.access.dispose();
    final second = _Environment();
    await second.access.check();
    expect(second.requests, 0);
    second.access.dispose();
  });
  test(
    'successful manual access clears refusal for a later revocation',
    () async {
      SharedPreferences.setMockInitialValues({
        MeshAutomaticAccess.refusalKey: true,
      });
      final env = _Environment()..radio = 'active';
      await env.access.check();
      env.radio = 'permission_required';
      await env.access.check();
      expect(env.requests, 1);
      env.access.dispose();
    },
  );
  test(
    'granted access is coalesced and can recover after a later outage',
    () async {
      final env = _Environment()..pending = Completer<String>();
      final one = env.access.check(), two = env.access.check();
      await Future<void>.delayed(Duration.zero);
      expect(env.requests, 1);
      env.pending!.complete('permission_granted');
      await Future.wait([one, two]);
      env.pending = null;
      env.result = 'permission_granted';
      await env.access.check();
      expect(env.requests, 1);
      env.time = env.time.add(const Duration(minutes: 2));
      await env.access.check();
      expect(env.requests, 2);
      env.access.dispose();
    },
  );
  test('unsupported hardware and disposed accounts never prompt', () async {
    final env = _Environment()..radio = 'unsupported';
    await env.access.check();
    env.radio = 'permission_required';
    env.access.dispose();
    await env.access.check();
    expect(env.requests, 0);
  });
  test('temporary adapter errors do not become a permanent refusal', () async {
    final env = _Environment()..result = 'unavailable';
    await env.access.check();
    env.time = env.time.add(const Duration(minutes: 2));
    await env.access.check();
    expect(env.requests, 2);
    env.access.dispose();
  });
}
