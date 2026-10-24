import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:pulse_flutter/core/media/media_album.dart';
import 'package:pulse_flutter/services/calls/call_quality.dart';
import 'package:pulse_flutter/services/calls/output_test_tone.dart';

Uint8List pixel() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNw27HwPwAFhgKfaRamBAAAAABJRU5ErkJggg==',
);
void main() {
  test(
    'album round trips as a normal interoperable ZIP, without changing image bytes',
    () {
      final zip = MediaAlbum.encode([
        AlbumImage('one.png', pixel()),
        AlbumImage('two.png', pixel()),
      ]);
      final images = MediaAlbum.decode(zip);
      expect(images, hasLength(2));
      expect(images.first.bytes, pixel());
      final external = ZipDecoder().decodeBytes(zip, verify: true);
      expect(external.files.map((f) => f.name), [
        'nios_album.json',
        'photo_1.png',
        'photo_2.png',
      ]);
      expect(external.files.last.content, pixel());
    },
  );
  test(
    'album rejects corruption and compressed entries before parsing images',
    () {
      final zip = MediaAlbum.encode([
        AlbumImage('a.png', pixel()),
        AlbumImage('b.png', pixel()),
      ]);
      final corrupt = Uint8List.fromList(zip)..[60] ^= 1;
      expect(() => MediaAlbum.decode(corrupt), throwsFormatException);
      final compressed = Uint8List.fromList(zip)..[8] = 8;
      expect(() => MediaAlbum.decode(compressed), throwsFormatException);
      expect(
        () => MediaAlbum.decode(zip.sublist(0, 32)),
        throwsFormatException,
      );
    },
  );
  test('album rejects foreign files, missing items and too many photos', () {
    expect(
      () => MediaAlbum.encode([
        AlbumImage('x', Uint8List(1)),
        AlbumImage('y', pixel()),
      ]),
      throwsFormatException,
    );
    expect(
      () => MediaAlbum.encode([AlbumImage('a', pixel())]),
      throwsFormatException,
    );
    expect(
      () =>
          MediaAlbum.encode(List.generate(11, (_) => AlbumImage('a', pixel()))),
      throwsFormatException,
    );
    expect(MediaAlbum.isAlbum('NiosMess-Album.niosalbum.zip'), true);
    expect(MediaAlbum.isAlbum('ordinary.zip'), false);
  });
  test('loss is measured between samples, not across the whole call', () {
    final sampler = CallQualitySampler();
    List<Map<String, dynamic>> stats(int packets, int lost) => [
      {
        'id': 'audio',
        'type': 'inbound-rtp',
        'kind': 'audio',
        'packetsReceived': packets,
        'packetsLost': lost,
        'bytesReceived': packets * 100,
      },
    ];
    expect(sampler.sample(stats(10000, 1000)).level, CallQualityLevel.good);
    expect(
      sampler.sample(stats(10001, 1001)).level,
      CallQualityLevel.good,
    ); // Hysteresis.
    final poor = sampler.sample(stats(10002, 1002));
    expect(poor.reason, CallQualityReason.loss);
    expect(poor.lossPercent, 50);
    expect(sampler.sample(stats(10003, 1002)).level, CallQualityLevel.good);
    expect(
      sampler.sample(stats(1, 0)).lossPercent,
      0,
    ); // Replaced stream / reset counter.
  });
  test(
    'quality explains latency, bandwidth and encoding limits and has no invented idle score',
    () {
      expect(CallQualitySampler().sample([]).level, CallQualityLevel.unknown);
      final latency = CallQualitySampler().sample([
        {
          'type': 'candidate-pair',
          'selected': true,
          'state': 'succeeded',
          'currentRoundTripTime': .9,
        },
      ]);
      expect(latency.reason, CallQualityReason.latency);
      final cpu = CallQualitySampler().sample([
        {
          'type': 'outbound-rtp',
          'bytesSent': 30,
          'qualityLimitationReason': 'cpu',
        },
      ]);
      expect(cpu.reason, CallQualityReason.cpu);
      expect(cpu.level, CallQualityLevel.fair);
    },
  );
  test('test tone is a short bounded PCM WAV with quiet tapered ends', () {
    final tone = outputTestTone(),
        data = ByteData.sublistView(outputTestTone());
    expect(ascii.decode(tone.sublist(0, 4)), 'RIFF');
    expect(data.getUint32(24, Endian.little), 16000);
    expect(data.getInt16(44, Endian.little), 0);
    expect(tone.length, 19244);
  });
}
