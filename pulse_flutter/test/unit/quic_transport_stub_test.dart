import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_flutter/services/calls/call_transport.dart';
import 'package:pulse_flutter/services/calls/quic_transport.dart';

void main() {
  test('QUIC stub never reports a disconnect on a failed connect', () async {
    final transport = QuicCallTransport();
    final events = <String>[];
    final sub = transport.onDisconnected.listen((_) => events.add('disconnected'));

    final result = await transport.connect(roomId: 'room', nickname: 'tester');

    expect(result, TransportConnectResult.failed);
    expect(transport.isConnected, isFalse);

    // Give the broadcast stream a chance to deliver any pending event.
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(
      events,
      isEmpty,
      reason: 'A transport that never connected must not emit onDisconnected: '
          'it made CallSession spawn a second transport and double the audio pipeline.',
    );

    await sub.cancel();
    await transport.disconnect();
  });
}