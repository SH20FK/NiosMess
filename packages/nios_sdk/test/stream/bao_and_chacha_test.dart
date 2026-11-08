import 'dart:typed_data';

import 'package:nios_sdk/stream.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('BaoTree Blake3-style streaming Merkle tree', () {
    test(
      'builds root hash and generates valid logarithmic proofs for all leaves',
      () {
        final leaves = List.generate(
          8,
          (i) =>
              Uint8List.fromList(List.generate(32, (j) => (i * 32 + j) % 256)),
        );

        final tree = BaoTree.build(leaves);
        expect(tree.leafCount, 8);
        expect(tree.rootHash.length, 32);

        for (var i = 0; i < leaves.length; i++) {
          final proof = tree.getProof(i);
          expect(proof.segmentIndex, i);
          // For 8 leaves, depth is 3: O(log2(8)) = 3 sibling hashes
          expect(proof.siblingHashes.length, 3);

          final isValid = BaoTree.verifyProof(
            expectedRoot: tree.rootHash,
            segmentHash: leaves[i],
            proof: proof,
          );
          expect(isValid, isTrue);

          // Verification must fail with altered data
          final alteredLeaf = Uint8List.fromList(leaves[i])..[0] ^= 0xFF;
          final isInvalid = BaoTree.verifyProof(
            expectedRoot: tree.rootHash,
            segmentHash: alteredLeaf,
            proof: proof,
          );
          expect(isInvalid, isFalse);
        }
      },
    );

    test('handles non-power-of-two leaf counts correctly', () {
      final leaves = List.generate(
        5,
        (i) => Uint8List.fromList(List.generate(32, (j) => i + j)),
      );
      final tree = BaoTree.build(leaves);
      expect(tree.leafCount, 5);

      for (var i = 0; i < 5; i++) {
        final proof = tree.getProof(i);
        expect(
          BaoTree.verifyProof(
            expectedRoot: tree.rootHash,
            segmentHash: leaves[i],
            proof: proof,
          ),
          isTrue,
        );
      }
    });
  });

  group('NiosStream ChaCha20-Poly1305 encryption', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nios_chacha_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      'prepares and round-trips ChaCha20-Poly1305 file with Bao tree root',
      () async {
        final inputFile = File('${tempDir.path}/input.bin');
        final originalData = Uint8List.fromList(
          List.generate(25000, (i) => (i * 17) % 256),
        );
        await inputFile.writeAsBytes(originalData);

        final prepared = await NiosStream.prepareFile(
          inputPath: inputFile.path,
          outputDirectory: '${tempDir.path}/out',
          segmentSize: 8192,
          algorithm: NiosStreamAlgorithms.chacha20Poly1305,
          enableBaoTree: true,
        );

        expect(
          prepared.manifest.algorithm,
          NiosStreamAlgorithms.chacha20Poly1305,
        );
        expect(prepared.manifest.baoRoot, isNotNull);
        expect(prepared.manifest.segmentCount, 4);

        final baoTree = prepared.manifest.toBaoTree();
        expect(baoTree.rootHashHex, prepared.manifest.baoRoot);

        // Verify download and decryption
        final downloadDir = '${tempDir.path}/download';
        final download = await NiosStreamDownload.open(
          directory: downloadDir,
          manifest: prepared.manifest,
          key: prepared.key,
          sources: [prepared.ciphertextSource],
        );

        final decrypted = await download.readRange(0, originalData.length);
        expect(decrypted, equals(originalData));
        await download.close();
      },
    );
  });
}
