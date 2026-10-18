import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 6962 Merkle tree hash domains: leaves start with 0, branches with 1.
Uint8List merkleLeafHash(List<int> leaf) =>
    Uint8List.fromList(sha256.convert([0, ...leaf]).bytes);

Uint8List merkleNodeHash(List<int> left, List<int> right) {
  if (left.length != 32 || right.length != 32) {
    throw ArgumentError('Merkle nodes must be SHA-256 digests');
  }
  return Uint8List.fromList(sha256.convert([1, ...left, ...right]).bytes);
}

bool sameDigest(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var mismatch = 0;
  for (var i = 0; i < a.length; i++) {
    mismatch |= a[i] ^ b[i];
  }
  return mismatch == 0;
}

/// A small reference log/proof producer, useful in servers and deterministic
/// integration tests. A production log can replace storage without changing
/// the proof format. Clients never need to download this complete tree.
final class TransparencyMerkleLog {
  final List<Uint8List> _leaves = [];
  int get length => _leaves.length;

  int append(List<int> encodedEntry) {
    if (encodedEntry.isEmpty || encodedEntry.length > 65536) {
      throw ArgumentError('A log entry must contain 1..65536 bytes');
    }
    _leaves.add(merkleLeafHash(encodedEntry));
    return _leaves.length - 1;
  }

  Uint8List root([int? size]) {
    final n = size ?? length;
    _checkSize(n);
    return _root(0, n);
  }

  List<Uint8List> inclusionProof(int leafIndex, {int? size}) {
    final n = size ?? length;
    _checkSize(n);
    if (leafIndex < 0 || leafIndex >= n) {
      throw RangeError('Leaf is outside the requested tree');
    }
    return _inclusion(leafIndex, 0, n);
  }

  List<Uint8List> consistencyProof(int oldSize, {int? size}) {
    final n = size ?? length;
    _checkSize(n);
    if (oldSize < 0 || oldSize > n) throw RangeError('Invalid old size');
    if (oldSize == 0 || oldSize == n) return [];
    return _subproof(oldSize, 0, n, true);
  }

  void _checkSize(int n) {
    if (n < 0 || n > length) throw RangeError('Invalid tree size');
  }

  Uint8List _root(int offset, int n) {
    if (n == 0) return Uint8List.fromList(sha256.convert([]).bytes);
    if (n == 1) return Uint8List.fromList(_leaves[offset]);
    final k = _split(n);
    return merkleNodeHash(_root(offset, k), _root(offset + k, n - k));
  }

  List<Uint8List> _inclusion(int index, int offset, int n) {
    if (n == 1) return [];
    final k = _split(n);
    if (index < k) {
      return [..._inclusion(index, offset, k), _root(offset + k, n - k)];
    }
    return [..._inclusion(index - k, offset + k, n - k), _root(offset, k)];
  }

  List<Uint8List> _subproof(int m, int offset, int n, bool complete) {
    if (m == n) return complete ? [] : [_root(offset, n)];
    final k = _split(n);
    if (m <= k) {
      return [..._subproof(m, offset, k, complete), _root(offset + k, n - k)];
    }
    return [..._subproof(m - k, offset + k, n - k, false), _root(offset, k)];
  }
}

int _split(int n) {
  var k = 1;
  while ((k << 1) < n) {
    k <<= 1;
  }
  return k;
}

bool verifyMerkleInclusion({
  required List<int> leaf,
  required int index,
  required int size,
  required List<List<int>> proof,
  required List<int> root,
}) {
  if (size < 1 ||
      size > 9007199254740991 ||
      index < 0 ||
      index >= size ||
      root.length != 32 ||
      proof.length > 64 ||
      proof.any((node) => node.length != 32)) {
    return false;
  }
  var fn = index;
  var sn = size - 1;
  var hash = merkleLeafHash(leaf);
  for (final node in proof) {
    if (sn == 0) return false;
    if ((fn & 1) == 1 || fn == sn) {
      hash = merkleNodeHash(node, hash);
      while (fn != 0 && (fn & 1) == 0) {
        fn >>= 1;
        sn >>= 1;
      }
    } else {
      hash = merkleNodeHash(hash, node);
    }
    fn >>= 1;
    sn >>= 1;
  }
  return sn == 0 && sameDigest(hash, root);
}

bool verifyMerkleConsistency({
  required int oldSize,
  required int newSize,
  required List<int> oldRoot,
  required List<int> newRoot,
  required List<List<int>> proof,
}) {
  if (oldSize < 0 ||
      newSize < oldSize ||
      newSize > 9007199254740991 ||
      oldRoot.length != 32 ||
      newRoot.length != 32 ||
      proof.length > 64 ||
      proof.any((node) => node.length != 32)) {
    return false;
  }
  if (oldSize == 0) {
    return proof.isEmpty &&
        sameDigest(oldRoot, sha256.convert([]).bytes) &&
        (newSize != 0 || sameDigest(oldRoot, newRoot));
  }
  if (oldSize == newSize) return proof.isEmpty && sameDigest(oldRoot, newRoot);
  var fn = oldSize - 1;
  var sn = newSize - 1;
  while ((fn & 1) == 1) {
    fn >>= 1;
    sn >>= 1;
  }
  var offset = 0;
  List<int> first;
  if (fn == 0) {
    first = oldRoot;
  } else {
    if (proof.isEmpty) return false;
    first = proof[offset++];
  }
  var fr = Uint8List.fromList(first);
  var sr = Uint8List.fromList(first);
  for (; offset < proof.length; offset++) {
    if (sn == 0) return false;
    final node = proof[offset];
    if ((fn & 1) == 1 || fn == sn) {
      fr = merkleNodeHash(node, fr);
      sr = merkleNodeHash(node, sr);
      while (fn != 0 && (fn & 1) == 0) {
        fn >>= 1;
        sn >>= 1;
      }
    } else {
      sr = merkleNodeHash(sr, node);
    }
    fn >>= 1;
    sn >>= 1;
  }
  return sn == 0 && sameDigest(fr, oldRoot) && sameDigest(sr, newRoot);
}
