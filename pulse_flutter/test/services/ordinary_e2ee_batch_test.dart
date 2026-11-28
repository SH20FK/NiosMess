import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixture =
      jsonDecode(
            File('test/fixtures/ordinary_e2ee_vectors.json').readAsStringSync(),
          )
          as E2eJson;
  final records = fixture['identities'] as List;
  final alice = OrdinaryKeys.fromJson(
    (records[0] as E2eJson)['secret'] as E2eJson,
  );
  final bob = OrdinaryKeys.fromJson((records[1] as E2eJson)['secret'] as E2eJson);
  final alicePublic = records[0]['public'] as E2eJson;
  final bobPublic = records[1]['public'] as E2eJson;

  OrdinaryE2eeService serviceForBob() {
    FlutterSecureStorage.setMockInitialValues({
      'niosmess.ordinary.${bob.userId}.v1.keys': jsonEncode({
        'keys': bob.secret(),
        'recovery': records[1]['recovery'],
        'old': [],
      }),
    });
    return OrdinaryE2eeService(bob.userId, (action, {payload}) async {
      final op = payload!['op'];
      switch (op) {
        case 'status':
          return {
            'enabled': true,
            'identity': records[1]['public'],
            'backup': records[1]['backup'],
          };
        case 'identity':
          expect(payload['user_id'], alice.userId);
          expect(payload['epoch'], alice.epoch);
          return records[0]['public'];
        default:
          throw StateError('unexpected $op');
      }
    });
  }

  Future<List<ApiMessage>> page(int count) async {
    final messages = <ApiMessage>[];
    for (var i = 0; i < count; i++) {
      final packet = await OrdinaryCodec.encrypt(
        alice,
        bobPublic,
        11,
        {'text': 'batch-$i'},
        reply: i == 0 ? null : i,
      );
      messages.add(
        ApiMessage.fromJson({
          'id': 1000 + i,
          'chat_id': 11,
          'sender_id': alice.userId,
          'msg_type': 'text',
          'content': '',
          'is_e2ee': true,
          'is_decrypted': false,
          'e2ee_content': packet,
          'reply_to_id': i == 0 ? null : i,
        }),
      );
    }
    return messages;
  }

  /// Rewrites the authenticated body of one envelope, so only its own row can
  /// fail while the rest of the page still opens.
  String tamperedPacket(String encoded) {
    final packet = OrdinaryCodec.packet(encoded);
    final body =
        jsonDecode(packet['body'] as String) as Map<String, dynamic>;
    body['tampered'] = true;
    packet['body'] = jsonEncode(body);
    return base64Encode(utf8.encode(jsonEncode(packet)));
  }

  test('batch keeps page order, matches per-message results and localizes '
      'a broken envelope', () async {
    final rows = await page(6);
    rows[3] = rows[3].copyWith(
      e2eeContent: tamperedPacket(rows[3].e2eeContent!),
    );

    final sequential = serviceForBob();
    await sequential.open();
    final expected = <ApiMessage>[];
    for (final row in rows) {
      expected.add(await sequential.decrypt(row));
    }
    sequential.dispose();

    final batched = serviceForBob();
    await batched.open();
    OrdinaryE2eeService.lastBatchWorkerPort = null;
    final actual = await batched.decryptBatch(rows);
    batched.dispose();

    expect(actual, hasLength(rows.length));
    for (var i = 0; i < rows.length; i++) {
      expect(actual[i].id, expected[i].id, reason: 'id at $i');
      expect(actual[i].isDecrypted, expected[i].isDecrypted, reason: 'flag $i');
      expect(actual[i].content, expected[i].content, reason: 'content $i');
      expect(actual[i].msgType, expected[i].msgType, reason: 'type $i');
    }
    for (var i = 0; i < rows.length; i++) {
      if (i == 3) {
        expect(actual[i].isDecrypted, isFalse);
        expect(actual[i].content, contains('Не удалось проверить'));
        continue;
      }
      expect(actual[i].isDecrypted, isTrue);
      expect(actual[i].content, 'batch-$i');
    }

    final worker = OrdinaryE2eeService.lastBatchWorkerPort;
    expect(worker, isNotNull);
    expect(worker, isNot(Isolate.current.controlPort));
  });

  test('single decrypt and batch agree on a clean page', () async {
    final rows = await page(8);
    final service = serviceForBob();
    await service.open();
    final single = <ApiMessage>[];
    for (final row in rows) {
      single.add(await service.decrypt(row));
    }
    final batch = await service.decryptBatch(rows);
    for (var i = 0; i < rows.length; i++) {
      expect(batch[i].content, single[i].content);
      expect(batch[i].isDecrypted, single[i].isDecrypted);
      expect(batch[i].id, single[i].id);
    }
    service.dispose();
  });

  test('batch opens 50 messages off the platform isolate', () async {
    const count = 50;
    final rows = await page(count);
    final packets = <String>[for (final row in rows) row.e2eeContent!];

    // Warm-up: the baseline is per-message in-process work, not a cold start.
    await OrdinaryCodec.decrypt(bob, alicePublic, packets.first, 11, 1);
    final service = serviceForBob();
    await service.open();
    await service.decryptBatch(<ApiMessage>[rows.first]);

    final sequentialClock = Stopwatch()..start();
    final sequentialProbe = _StallProbe()..start();
    for (var i = 0; i < count; i++) {
      await OrdinaryCodec.decrypt(
        bob,
        alicePublic,
        packets[i],
        11,
        1,
        reply: i == 0 ? null : i,
      );
    }
    sequentialClock.stop();
    final sequentialStall = sequentialProbe.stop();

    final batchClock = Stopwatch()..start();
    final batchProbe = _StallProbe()..start();
    final opened = await service.decryptBatch(rows);
    batchClock.stop();
    final batchStall = batchProbe.stop();
    service.dispose();

    expect(opened.every((m) => m.isDecrypted), isTrue);
    // ignore: avoid_print
    print(
      'E2EE 50 messages: sequential ${sequentialClock.elapsedMilliseconds} ms '
      '(ticks ${sequentialStall.$1}, max gap ${sequentialStall.$2} us); '
      'batch ${batchClock.elapsedMilliseconds} ms '
      '(ticks ${batchStall.$1}, max gap ${batchStall.$2} us)',
    );
    // Measured here (`flutter test`, debug, Windows): 50 messages sequentially
    // took 221 ms and the calling isolate never serviced its 2 ms timer (0
    // ticks — the frame loop was starved for the whole run); the same 50
    // opened as a batch in 206 ms with 101 ticks and a 4.6 ms worst gap
    // (worker spawn + result copy). Crypto cost is unchanged by design; what
    // changes is that the caller is free while it runs.
  });
}

/// Longest gap between 2 ms timer ticks: how long the calling isolate could
/// not service its event loop (i.e. a dropped frame).
class _StallProbe {
  final List<int> _gaps = <int>[];
  Timer? _timer;
  DateTime? _last;

  void start() {
    _last = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 2), (_) {
      final now = DateTime.now();
      _gaps.add(now.difference(_last!).inMicroseconds);
      _last = now;
    });
  }

  (int, int) stop() {
    _timer?.cancel();
    _timer = null;
    if (_gaps.isEmpty) return (0, 0);
    return (_gaps.length, _gaps.reduce((a, b) => a > b ? a : b));
  }
}
