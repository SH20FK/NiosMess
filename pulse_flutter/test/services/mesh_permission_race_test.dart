import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/ble_transport.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class _WaitingKeys extends OrdinaryE2eeService {
  _WaitingKeys() : super(1, (action, {payload}) async => <String, dynamic>{});
  final pending = Completer<void>();
  @override
  Future<void> open() => pending.future;
}

class _PermissionRadio implements BleTransport, BleAccessTransport {
  int prompts = 0;
  final answer = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> requestAccess() {
    prompts++;
    return answer.future;
  }

  @override
  Stream<Map<String, dynamic>> get events => const Stream.empty();
  @override
  Future<Map<String, dynamic>> start({bool requestPermission = false}) async =>
      {'state': 'active'};
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(String peer, Uint8List bytes) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BluetoothMeshService mesh(_WaitingKeys keys, _PermissionRadio radio) =>
      BluetoothMeshService(
        userId: 1,
        scope: () => 'fixture',
        ordinary: keys,
        transport: radio,
        chat: (_) => null,
        cloudSubmit: (_) => throw StateError('Not expected'),
        enabled: () => true,
        online: () => false,
      );
  test(
    'OS access is not queued behind unavailable network/key preparation',
    () async {
      final keys = _WaitingKeys(), radio = _PermissionRadio();
      final service = mesh(keys, radio);
      addTearDown(service.dispose);
      addTearDown(keys.dispose);
      unawaited(service.start());
      final first = service.start(requestPermission: true);
      final second = service.start(requestPermission: true);
      expect(radio.prompts, 1);
      radio.answer.complete({'state': 'permission_required'});
      await Future.wait([first, second]).timeout(const Duration(seconds: 1));
      expect(service.state, 'permission_required');
      expect(keys.pending.isCompleted, isFalse);
    },
  );
  test(
    'native granted/started access does not report a ready ciphertext router',
    () async {
      final keys = _WaitingKeys(), radio = _PermissionRadio();
      final service = mesh(keys, radio);
      addTearDown(service.dispose);
      addTearDown(keys.dispose);
      final request = service.requestAccess();
      radio.answer.complete({'state': 'active'});
      expect(await request, 'permission_granted');
      expect(service.active, isFalse);
    },
  );
}
