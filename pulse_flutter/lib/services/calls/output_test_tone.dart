import 'dart:math' as math;
import 'dart:typed_data';

/// Short, quiet PCM test tone with tapered edges, generated entirely locally.
Uint8List outputTestTone() {
  const rate = 16000, count = 9600;
  final bytes = Uint8List(44 + count * 2);
  final b = ByteData.sublistView(bytes);
  void text(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  text(0, 'RIFF');
  b.setUint32(4, bytes.length - 8, Endian.little);
  text(8, 'WAVEfmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  text(36, 'data');
  b.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    final envelope = math.min(1.0, math.min(i / 320, (count - i) / 320));
    b.setInt16(
      44 + i * 2,
      (math.sin(2 * math.pi * 440 * i / rate) * 4000 * envelope).round(),
      Endian.little,
    );
  }
  return bytes;
}
