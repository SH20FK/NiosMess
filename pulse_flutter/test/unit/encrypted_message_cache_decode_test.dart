import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

const int _count = 2000;

Map<String, dynamic> _messageJson(int i) {
  return <String, dynamic>{
    'id': i + 1,
    'chat_id': 71219,
    'sender_id': (i % 7) + 1,
    'sender_username': 'user${i % 7}',
    'sender_display_name': 'User ${i % 7}',
    'sender_badges': <dynamic>[
      <String, dynamic>{'id': 1, 'name': 'plus', 'icon': 'star', 'color': 'primary'},
    ],
    'content': 'cached message $i',
    'msg_type': i % 11 == 0 ? 'sticker' : 'text',
    'reply_to_id': i % 5 == 0 ? i : null,
    'media_url': i % 13 == 0 ? 'https://cdn.example/$i.png' : null,
    'reactions': <String, dynamic>{'❤️': i % 3, 'thumbs_up': i % 2},
    'comments_count': i % 4,
    'sent_at': DateTime.utc(2026, 10, 15)
        .add(Duration(seconds: i))
        .toIso8601String(),
    'edited_at': i % 9 == 0
        ? DateTime.utc(2026, 10, 16).toIso8601String()
        : null,
    'is_read': i.isEven,
    'is_e2ee': true,
    'is_decrypted': true,
    'e2ee_file_key': i % 17 == 0 ? 'a2V5JQ==' : null,
    'system_event_type': i % 101 == 0 ? 'call' : null,
    'system_event': i % 101 == 0
        ? <String, dynamic>{'status': 'missed', 'is_video': false}
        : null,
  };
}

Future<String> _encryptLikeCache(
  List<Map<String, dynamic>> json,
  SecretKey key,
) async {
  final SecretBox box = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode(json)),
    secretKey: key,
  );
  return base64Encode(<int>[...box.nonce, ...box.cipherText, ...box.mac.bytes]);
}

/// Runs [action] while a 2ms heartbeat timer ticks. Returns how many times the
/// UI event loop was serviced, the longest gap and the wall duration. A fully
/// blocking implementation yields 0 ticks because Dart timers cannot fire while
/// one turn occupies the isolate.
Future<({int ticks, int maxGapMs, int wallMs})> _probe(
  FutureOr<void> Function() action,
) async {
  int ticks = 0;
  int last = 0;
  int maxGap = 0;
  final Stopwatch sw = Stopwatch()..start();
  final Timer timer = Timer.periodic(const Duration(milliseconds: 2), (_) {
    ticks++;
    final int now = sw.elapsedMilliseconds;
    if (now - last > maxGap) maxGap = now - last;
    last = now;
  });
  // Let the timer register before the measured turn starts.
  await Future<void>.delayed(Duration.zero);
  final int before = ticks;
  try {
    await action();
  } finally {
    timer.cancel();
  }
  return (ticks: ticks - before, maxGapMs: maxGap, wallMs: sw.elapsedMilliseconds);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptedMessageCache decode off the UI thread', () {
    test('2000 cached messages arrive as built models, in order', () async {
      final List<Map<String, dynamic>> json = <Map<String, dynamic>>[
        for (int i = 0; i < _count; i++) _messageJson(i),
      ];
      final SecretKey key = await AesGcm.with256bits().newSecretKey();
      final List<int> keyBytes = await key.extractBytes();
      final String encoded = await _encryptLikeCache(json, key);

      // Previous behaviour: the whole decode ran on the UI isolate. The
      // heartbeat timer proves it starved the event loop.
      late List<ApiMessage> syncDecoded;
      final Stopwatch syncWatch = Stopwatch();
      final ({int ticks, int maxGapMs, int wallMs}) syncProbe = await _probe(() {
        syncWatch.start();
        syncDecoded = json.map(ApiMessage.fromJson).toList();
        syncWatch.stop();
      });
      expect(syncDecoded.length, _count);

      late List<ApiMessage>? decoded;
      final ({int ticks, int maxGapMs, int wallMs}) bgProbe =
          await _probe(() async {
        decoded = await EncryptedMessageCache.debugDecodeMessagesInBackground(
          encoded,
          keyBytes,
        );
      });

      expect(decoded, isNotNull);
      expect(decoded!.length, _count);
      expect(decoded!.first.id, 1);
      expect(decoded!.last.id, _count);

      // Same order and same field values as the sync path.
      for (int i = 0; i < _count; i++) {
        expect(decoded![i].toJson(), syncDecoded[i].toJson());
      }

      // The old sync decode never let the event loop run; the isolated one does.
      expect(
        syncProbe.ticks,
        0,
        reason: 'sync decode should block the UI turn entirely',
      );
      expect(
        bgProbe.ticks,
        greaterThan(0),
        reason: 'cache decode must leave the UI event loop running',
      );
      expect(
        bgProbe.maxGapMs,
        lessThan(50),
        reason: 'cache decode left a ${bgProbe.maxGapMs}ms hole in the UI loop',
      );

      // ignore: avoid_print
      print(
        'D4 cache decode $_count: sync UI block '
        '${syncWatch.elapsedMilliseconds}ms (loop ticks ${syncProbe.ticks}) -> '
        'background max UI gap ${bgProbe.maxGapMs}ms '
        '(wall ${bgProbe.wallMs}ms, loop ticks ${bgProbe.ticks}, no UI fromJson)',
      );
    });

    test('corrupt payload still reports null so callers keep old fallback', () async {
      final SecretKey key = await AesGcm.with256bits().newSecretKey();
      final List<int> keyBytes = await key.extractBytes();
      final List<ApiMessage>? decoded = await EncryptedMessageCache
          .debugDecodeMessagesInBackground('AAAA', keyBytes);
      expect(decoded, isNull);
    });
  });
}
