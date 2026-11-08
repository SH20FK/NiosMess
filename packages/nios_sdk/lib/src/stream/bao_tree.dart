import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;

/// A node in a Blake3/Bao-style verified streaming tree.
///
/// In Bao/Blake3 trees, leaf nodes are the hashes of individual data segments,
/// and parent nodes are the cryptographic hash of their concatenated children:
/// `parent = Hash(0x01 || leftChild || rightChild)`.
/// Leaf hashing uses domain separation `Hash(0x00 || chunk)`.
final class BaoNode {
  final Uint8List hash;
  final BaoNode? left;
  final BaoNode? right;
  final int startSegment;
  final int endSegment; // exclusive

  const BaoNode({
    required this.hash,
    required this.startSegment,
    required this.endSegment,
    this.left,
    this.right,
  });

  bool get isLeaf => left == null && right == null;
}

/// A compact logarithmic authentication path for a single segment.
/// Allows verifying an individual 1 MiB segment against the Bao root hash
/// using only O(log N) hashes instead of downloading all N segment hashes.
final class BaoProof {
  final int segmentIndex;
  final List<Uint8List> siblingHashes;
  final List<bool> isSiblingLeft; // true if sibling is on the left

  const BaoProof({
    required this.segmentIndex,
    required this.siblingHashes,
    required this.isSiblingLeft,
  });

  Map<String, dynamic> toJson() => {
    'index': segmentIndex,
    'siblings': siblingHashes.map(base64Encode).toList(),
    'lefts': isSiblingLeft,
  };

  factory BaoProof.fromJson(Map<String, dynamic> json) => BaoProof(
    segmentIndex: json['index'] as int,
    siblingHashes: (json['siblings'] as List)
        .map((s) => Uint8List.fromList(base64Decode(s as String)))
        .toList(),
    isSiblingLeft: List<bool>.from(json['lefts'] as List),
  );
}

/// Hierarchical Blake3/Bao verified streaming Merkle tree.
///
/// Provides O(log N) range proofs and instant stream verification for
/// large encrypted files, avoiding linear manifest downloads.
final class BaoTree {
  static const int domainLeaf = 0x00;
  static const int domainParent = 0x01;

  final BaoNode root;
  final int leafCount;

  const BaoTree._({required this.root, required this.leafCount});

  Uint8List get rootHash => root.hash;
  String get rootHashHex =>
      root.hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Build a Bao tree from precomputed segment hashes (each 32 bytes).
  static BaoTree build(List<Uint8List> segmentHashes) {
    if (segmentHashes.isEmpty) {
      final emptyHash = Uint8List.fromList(
        digest.sha256.convert([domainLeaf]).bytes,
      );
      return BaoTree._(
        root: BaoNode(hash: emptyHash, startSegment: 0, endSegment: 0),
        leafCount: 0,
      );
    }

    var currentLevel = <BaoNode>[];
    for (var i = 0; i < segmentHashes.length; i++) {
      final leafHash = _hashLeaf(segmentHashes[i]);
      currentLevel.add(
        BaoNode(hash: leafHash, startSegment: i, endSegment: i + 1),
      );
    }

    while (currentLevel.length > 1) {
      final nextLevel = <BaoNode>[];
      for (var i = 0; i < currentLevel.length; i += 2) {
        if (i + 1 < currentLevel.length) {
          final left = currentLevel[i];
          final right = currentLevel[i + 1];
          final parentHash = _hashParent(left.hash, right.hash);
          nextLevel.add(
            BaoNode(
              hash: parentHash,
              startSegment: left.startSegment,
              endSegment: right.endSegment,
              left: left,
              right: right,
            ),
          );
        } else {
          // Promote odd node to next level
          nextLevel.add(currentLevel[i]);
        }
      }
      currentLevel = nextLevel;
    }

    return BaoTree._(root: currentLevel.first, leafCount: segmentHashes.length);
  }

  /// Generate logarithmic proof for a specific segment index.
  BaoProof getProof(int segmentIndex) {
    if (segmentIndex < 0 || segmentIndex >= leafCount) {
      throw RangeError.index(segmentIndex, this, 'segmentIndex');
    }

    final siblingHashes = <Uint8List>[];
    final isSiblingLeft = <bool>[];

    void traverse(BaoNode node) {
      if (node.isLeaf) return;

      final left = node.left;
      final right = node.right;

      if (left != null && right != null) {
        if (segmentIndex < left.endSegment) {
          // Target is in the left branch, right is sibling
          siblingHashes.add(right.hash);
          isSiblingLeft.add(false);
          traverse(left);
        } else {
          // Target is in the right branch, left is sibling
          siblingHashes.add(left.hash);
          isSiblingLeft.add(true);
          traverse(right);
        }
      } else if (left != null) {
        traverse(left);
      }
    }

    traverse(root);
    // Reverse so proof evaluates bottom-up from leaf to root
    return BaoProof(
      segmentIndex: segmentIndex,
      siblingHashes: siblingHashes.reversed.toList(),
      isSiblingLeft: isSiblingLeft.reversed.toList(),
    );
  }

  /// Verify a segment hash against an expected Bao root hash using a BaoProof.
  static bool verifyProof({
    required Uint8List expectedRoot,
    required Uint8List segmentHash,
    required BaoProof proof,
  }) {
    var current = _hashLeaf(segmentHash);

    for (var i = 0; i < proof.siblingHashes.length; i++) {
      final sibling = proof.siblingHashes[i];
      final isLeft = proof.isSiblingLeft[i];
      if (isLeft) {
        current = _hashParent(sibling, current);
      } else {
        current = _hashParent(current, sibling);
      }
    }

    return _constantTimeEquals(current, expectedRoot);
  }

  static Uint8List _hashLeaf(Uint8List segmentHash) {
    final bytes = Uint8List(1 + segmentHash.length);
    bytes[0] = domainLeaf;
    bytes.setRange(1, bytes.length, segmentHash);
    return Uint8List.fromList(digest.sha256.convert(bytes).bytes);
  }

  static Uint8List _hashParent(Uint8List left, Uint8List right) {
    final bytes = Uint8List(1 + left.length + right.length);
    bytes[0] = domainParent;
    bytes.setRange(1, 1 + left.length, left);
    bytes.setRange(1 + left.length, bytes.length, right);
    return Uint8List.fromList(digest.sha256.convert(bytes).bytes);
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
