import 'dart:math';
import 'dart:typed_data';

import 'package:nios_sdk/distributed.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  final combinations = <List<int>>[
    for (var a = 0; a < 3; a++)
      for (var b = a + 1; b < 4; b++)
        for (var c = b + 1; c < 5; c++) [a, b, c],
  ];
  test('all ten arbitrary erasure patterns recover systematic data', () {
    final codec = ReedSolomon3of5();
    final random = Random(82);
    for (final length in [1, 3, 255, 4096]) {
      final input = List.generate(
        3,
        (_) => Uint8List.fromList(
          List.generate(length, (_) => random.nextInt(256)),
        ),
      );
      final shares = codec.encode(input);
      for (final indices in combinations) {
        final recovered = codec.reconstruct({
          for (final i in indices) i: shares[i],
        });
        expect(recovered, input, reason: '$length bytes, $indices');
      }
    }
    expect(
      () => codec.reconstruct({0: Uint8List(4), 1: Uint8List(4)}),
      throwsArgumentError,
    );
  });

  late Directory directory;
  late List<DirectoryShardNode> nodes;
  late DistributedStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nios-distributed-');
    nodes = List.generate(
      5,
      (i) => DirectoryShardNode(
        id: 'node-$i',
        failureDomain: 'site-$i',
        directory: p.join(directory.path, 'nodes', '$i'),
      ),
    );
    store = DistributedStore(
      nodes: nodes,
      spoolDirectory: p.join(directory.path, 'spool'),
    );
  });
  tearDown(() async {
    if (!p.basename(directory.path).startsWith('nios-distributed-')) {
      throw StateError('Wrong test directory');
    }
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'real on-disk objects recover with every three-node combination',
    () async {
      final input = File(p.join(directory.path, 'ciphertext'));
      final bytes = List.generate(34391, (i) => (i * 77) % 256);
      await input.writeAsBytes(bytes, flush: true);
      final stored = await store.putCiphertext(input.path, blockSize: 1024);
      expect(stored.receipts.map((r) => r.failureDomain).toSet(), hasLength(5));
      for (var index = 0; index < combinations.length; index++) {
        final subset = combinations[index].map((i) => nodes[i]).toList();
        // Recovery can use a subset of the configured five domains.
        final reader = DistributedStore(
          nodes: [
            ...subset,
            ...nodes
                .where((n) => !subset.contains(n))
                .map((n) => _OfflineNode(n)),
          ],
          spoolDirectory: p.join(directory.path, 'reader'),
        );
        final recovered = await reader.recoverCiphertext(
          stored.manifest,
          p.join(directory.path, 'recovered-$index'),
        );
        expect(
          await recovered.readAsBytes(),
          bytes,
          reason: '${combinations[index]}',
        );
      }
    },
  );

  test(
    'bad block is excluded; two failures remain recoverable; third fails',
    () async {
      final input = File(p.join(directory.path, 'ciphertext'));
      final bytes = List.generate(9000, (i) => i % 251);
      await input.writeAsBytes(bytes);
      final object = await store.putCiphertext(input.path, blockSize: 512);
      final corrupt = File(
        p.join(nodes[0].directory, object.manifest.objectId, '0', 'data'),
      );
      final handle = await corrupt.open(mode: FileMode.writeOnlyAppend);
      await handle.setPosition(0);
      await handle.writeByte(242);
      await handle.close();
      await nodes[1].delete(object.manifest.objectId);
      final recovered = await store.recoverCiphertext(
        object.manifest,
        p.join(directory.path, 'recovered'),
      );
      expect(await recovered.readAsBytes(), bytes);
      await nodes[2].delete(object.manifest.objectId);
      await expectLater(
        store.recoverCiphertext(
          object.manifest,
          p.join(directory.path, 'failed'),
        ),
        throwsStateError,
      );
      expect(await File(p.join(directory.path, 'failed')).exists(), isFalse);
    },
  );

  test('repair recreates identical share without a decryption key', () async {
    final input = File(p.join(directory.path, 'ciphertext'));
    final bytes = List.generate(19001, (i) => i % 233);
    await input.writeAsBytes(bytes);
    final object = await store.putCiphertext(input.path, blockSize: 2048);
    await nodes[0].delete(object.manifest.objectId);
    await nodes[1].delete(object.manifest.objectId);
    final spare = DirectoryShardNode(
      id: 'spare',
      failureDomain: 'other-site',
      directory: p.join(directory.path, 'spare'),
    );
    final receipt = await store.repairShare(object.manifest, 0, spare);
    expect(receipt.manifestHash, object.manifest.hash);
    final block = await spare.get(object.manifest, 0, 0);
    expect(object.manifest.verifies(block), isTrue);
    expect(
      await spare.get(object.manifest, 0, object.manifest.stripeCount - 1),
      isA<ShardBlock>(),
    );
  });

  test(
    'manifest tampering, wrong indices and correlated placement are rejected',
    () async {
      final input = File(p.join(directory.path, 'empty'));
      await input.writeAsBytes([]);
      final object = await store.putCiphertext(input.path);
      final json = object.manifest.toJson()..['ciphertext_length'] = 1;
      expect(
        () => DistributedManifest.fromJson(
          json,
          expectedHash: object.manifest.hash,
        ),
        throwsFormatException,
      );
      expect(
        () => DistributedStore(
          nodes: List.generate(
            5,
            (i) => DirectoryShardNode(
              id: '$i',
              failureDomain: 'same-machine',
              directory: directory.path,
            ),
          ),
          spoolDirectory: directory.path,
        ),
        throwsArgumentError,
      );
      final distinct = File(p.join(directory.path, 'distinct'));
      await distinct.writeAsBytes([1, 2, 3]);
      final other = await store.putCiphertext(distinct.path);
      final block = await nodes[0].get(other.manifest, 0, 0);
      expect(
        other.manifest.verifies(
          ShardBlock(
            index: 1,
            stripe: 0,
            bytes: block.bytes,
            proof: block.proof,
          ),
        ),
        isFalse,
      );
      final result = await store.recoverCiphertext(
        object.manifest,
        p.join(directory.path, 'empty-recovered'),
      );
      expect(await result.length(), 0);
    },
  );

  test(
    'deletion tombstones prevent an old upload from resurrecting an object',
    () async {
      final input = File(p.join(directory.path, 'ciphertext'));
      await input.writeAsBytes([1, 2, 3]);
      final object = await store.putCiphertext(input.path);
      await store.delete(object.manifest);
      await expectLater(
        nodes[0].put(object.manifest, 0, Stream.value([1])),
        throwsStateError,
      );
      await expectLater(
        store.recoverCiphertext(
          object.manifest,
          p.join(directory.path, 'resurrected'),
        ),
        throwsStateError,
      );
    },
  );
  test('a receipt must acknowledge its assigned node and share', () async {
    final input = await File(
      p.join(directory.path, 'ciphertext'),
    ).writeAsBytes([1, 2, 3]);
    final dishonest = DistributedStore(
      nodes: nodes.map(_WrongReceiptNode.new).toList(),
      spoolDirectory: p.join(directory.path, 'wrong-receipts'),
    );
    await expectLater(
      dishonest.putCiphertext(input.path, blockSize: 32),
      throwsFormatException,
    );
  });
}

class _WrongReceiptNode implements ShardNode {
  _WrongReceiptNode(this.inner);
  final ShardNode inner;
  @override
  String get id => inner.id;
  @override
  String get failureDomain => inner.failureDomain;
  @override
  Future<ShareReceipt> put(
    DistributedManifest manifest,
    int index,
    Stream<List<int>> bytes,
  ) async {
    await inner.put(manifest, index, bytes);
    // All indices/domains remain distinct, but belong to other placements.
    return ShareReceipt(
      'another-$id',
      failureDomain,
      (index + 1) % 5,
      manifest.hash,
    );
  }

  @override
  Future<ShardBlock> get(DistributedManifest manifest, int index, int stripe) =>
      inner.get(manifest, index, stripe);
  @override
  Future<void> delete(String objectId) => inner.delete(objectId);
}

final class _OfflineNode implements ShardNode {
  _OfflineNode(this.inner);
  final ShardNode inner;
  @override
  String get id => inner.id;
  @override
  String get failureDomain => inner.failureDomain;
  @override
  Future<ShardBlock> get(
    DistributedManifest manifest,
    int index,
    int stripe,
  ) async => throw FileSystemException('Node offline');
  @override
  Future<ShareReceipt> put(
    DistributedManifest manifest,
    int index,
    Stream<List<int>> bytes,
  ) => inner.put(manifest, index, bytes);
  @override
  Future<void> delete(String objectId) => inner.delete(objectId);
}
