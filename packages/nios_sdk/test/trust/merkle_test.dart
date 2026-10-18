import 'dart:convert';
import 'package:nios_sdk/trust.dart';
import 'package:test/test.dart';

void main() {
  test('all inclusion and consistency proof shapes through 70 leaves', () {
    final log = TransparencyMerkleLog();
    final leaves = List.generate(70, (i) => utf8.encode('entry-$i'));
    for (final leaf in leaves) {
      log.append(leaf);
    }
    for (var n = 1; n <= 70; n++) {
      for (var i = 0; i < n; i++) {
        final proof = log.inclusionProof(i, size: n);
        expect(
          verifyMerkleInclusion(
            leaf: leaves[i],
            index: i,
            size: n,
            proof: proof,
            root: log.root(n),
          ),
          isTrue,
          reason: 'inclusion $i/$n',
        );
        expect(
          verifyMerkleInclusion(
            leaf: utf8.encode('changed'),
            index: i,
            size: n,
            proof: proof,
            root: log.root(n),
          ),
          isFalse,
        );
      }
      for (var m = 0; m <= n; m++) {
        final proof = log.consistencyProof(m, size: n);
        expect(
          verifyMerkleConsistency(
            oldSize: m,
            newSize: n,
            oldRoot: log.root(m),
            newRoot: log.root(n),
            proof: proof,
          ),
          isTrue,
          reason: 'consistency $m/$n',
        );
        if (proof.isNotEmpty) {
          final changed = proof.map((e) => e.toList()).toList();
          changed[0][0] ^= 1;
          expect(
            verifyMerkleConsistency(
              oldSize: m,
              newSize: n,
              oldRoot: log.root(m),
              newRoot: log.root(n),
              proof: changed,
            ),
            isFalse,
          );
        }
      }
    }
  });

  test('domains, empty tree and malformed proofs fail closed', () {
    final log = TransparencyMerkleLog()
      ..append([1])
      ..append([2]);
    expect(
      sameDigest(
        merkleLeafHash([1, 2]),
        merkleNodeHash(merkleLeafHash([1]), merkleLeafHash([2])),
      ),
      isFalse,
    );
    expect(
      verifyMerkleInclusion(
        leaf: [1],
        index: 0,
        size: 2,
        proof: [],
        root: log.root(),
      ),
      isFalse,
    );
    expect(
      verifyMerkleInclusion(
        leaf: [1],
        index: 0,
        size: 2,
        proof: [
          [0],
        ],
        root: log.root(),
      ),
      isFalse,
    );
    expect(
      verifyMerkleConsistency(
        oldSize: 2,
        newSize: 1,
        oldRoot: log.root(),
        newRoot: log.root(1),
        proof: [],
      ),
      isFalse,
    );
    expect(
      verifyMerkleConsistency(
        oldSize: 1,
        newSize: 1,
        oldRoot: log.root(1),
        newRoot: log.root(),
        proof: [],
      ),
      isFalse,
    );
  });
}
