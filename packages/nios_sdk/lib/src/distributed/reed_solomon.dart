import 'dart:typed_data';

/// Systematic Vandermonde Reed–Solomon (3 data + 2 parity), GF(256), 0x11d.
/// This is erasure coding, not encryption. Verify shards before decoding.
final class ReedSolomon3of5 {
  ReedSolomon3of5() {
    final vandermonde = List.generate(5, (r) => [1, r, _mul(r, r)]);
    final inverse = _invert(vandermonde.take(3).toList());
    _rows = List.generate(
      5,
      (r) => List.generate(3, (c) {
        var value = 0;
        for (var j = 0; j < 3; j++) {
          value ^= _mul(vandermonde[r][j], inverse[j][c]);
        }
        return value;
      }),
    );
  }

  late final List<List<int>> _rows;
  static final _exp = () {
    final table = List<int>.filled(512, 0);
    var value = 1;
    for (var i = 0; i < 255; i++) {
      table[i] = value;
      value <<= 1;
      if (value & 0x100 != 0) value ^= 0x11d;
    }
    for (var i = 255; i < table.length; i++) {
      table[i] = table[i - 255];
    }
    return table;
  }();
  static final _log = () {
    final table = List<int>.filled(256, 0);
    for (var i = 0; i < 255; i++) {
      table[_exp[i]] = i;
    }
    return table;
  }();

  static int _mul(int a, int b) =>
      a == 0 || b == 0 ? 0 : _exp[_log[a] + _log[b]];

  static List<List<int>> _invert(List<List<int>> matrix) {
    final augmented = List.generate(
      3,
      (r) => [...matrix[r], ...List.generate(3, (c) => r == c ? 1 : 0)],
    );
    for (var c = 0; c < 3; c++) {
      var pivot = c;
      while (pivot < 3 && augmented[pivot][c] == 0) {
        pivot++;
      }
      if (pivot == 3) throw const FormatException('Singular erasure matrix');
      final swap = augmented[c];
      augmented[c] = augmented[pivot];
      augmented[pivot] = swap;
      final inverse = _exp[255 - _log[augmented[c][c]]];
      for (var j = 0; j < 6; j++) {
        augmented[c][j] = _mul(augmented[c][j], inverse);
      }
      for (var r = 0; r < 3; r++) {
        if (r == c) continue;
        final factor = augmented[r][c];
        for (var j = 0; j < 6; j++) {
          augmented[r][j] ^= _mul(factor, augmented[c][j]);
        }
      }
    }
    return augmented.map((row) => row.sublist(3)).toList();
  }

  static Uint8List _combine(List<int> coefficients, List<Uint8List> input) {
    final output = Uint8List(input.first.length);
    for (var c = 0; c < 3; c++) {
      final coefficient = coefficients[c];
      if (coefficient == 0) continue;
      final table = List.generate(256, (n) => _mul(coefficient, n));
      final source = input[c];
      for (var p = 0; p < output.length; p++) {
        output[p] ^= table[source[p]];
      }
    }
    return output;
  }

  List<Uint8List> encode(List<Uint8List> data) {
    if (data.length != 3 ||
        data.first.isEmpty ||
        data.any((block) => block.length != data.first.length)) {
      throw ArgumentError('Three nonempty equal-sized blocks are required');
    }
    return [
      ...data.map(Uint8List.fromList),
      _combine(_rows[3], data),
      _combine(_rows[4], data),
    ];
  }

  List<Uint8List> reconstruct(Map<int, Uint8List> verifiedShards) {
    if (verifiedShards.length < 3 ||
        verifiedShards.length > 5 ||
        verifiedShards.keys.any((i) => i < 0 || i >= 5)) {
      throw ArgumentError(
        'At least three distinct verified shard indices are required',
      );
    }
    final indices = verifiedShards.keys.toList()..sort();
    final blocks = indices.take(3).map((i) => verifiedShards[i]!).toList();
    if (blocks.first.isEmpty ||
        blocks.any((b) => b.length != blocks.first.length)) {
      throw ArgumentError('Shard block lengths differ');
    }
    final inverse = _invert(indices.take(3).map((i) => _rows[i]).toList());
    return List.generate(3, (i) => _combine(inverse[i], blocks));
  }
}
