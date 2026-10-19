import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

abstract interface class BleTransport {
  Stream<Map<String, dynamic>> get events;
  Future<Map<String, dynamic>> start({bool requestPermission = false});
  Future<void> stop();
  Future<void> send(String peer, Uint8List bytes);
}

class NativeBleTransport implements BleTransport {
  final _lease = const Uuid().v4();
  static const _methods = MethodChannel('app.niosmess/bluetooth_mesh');
  static const _events = EventChannel('app.niosmess/bluetooth_mesh/events');
  @override
  Stream<Map<String, dynamic>> get events => _events
      .receiveBroadcastStream()
      .map((value) => Map<String, dynamic>.from(value as Map))
      .where((event) => event['lease'] == _lease);
  @override
  Future<Map<String, dynamic>> start({bool requestPermission = false}) async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('start', {
        'requestPermission': requestPermission,
        'lease': _lease,
      });
      return result ?? {'state': 'unavailable'};
    } on MissingPluginException {
      return {'state': 'unsupported'};
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stop', {'lease': _lease});
    } on MissingPluginException {
      /* Unsupported platform. */
    }
  }

  @override
  Future<void> send(String peer, Uint8List bytes) =>
      _methods.invokeMethod<void>('send', {
        'peer': peer,
        'data': bytes,
        'lease': _lease,
      });
}
