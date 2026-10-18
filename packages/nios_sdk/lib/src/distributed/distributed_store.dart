import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import 'reed_solomon.dart';

String _hash(List<int> bytes) => sha256.convert(bytes).toString();

final class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest digest) {
    value = digest;
  }

  @override
  void close() {}
}

List<int> _unhex(String value) => List.generate(
  value.length ~/ 2,
  (i) => int.parse(value.substring(i * 2, i * 2 + 2), radix: 16),
);
String _randomId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

void _id(String value) {
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(value)) {
    throw const FormatException('Invalid distributed object ID');
  }
}

void _digest(String value) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const FormatException('Invalid SHA-256 digest');
  }
}

String _leaf(String id, int index, int stripe, List<int> bytes) => _hash([
  0,
  ...utf8.encode('NiosShard/1/$id/$index/$stripe\u0000'),
  ...bytes,
]);
String _parent(String a, String b) => _hash([1, ..._unhex(a), ..._unhex(b)]);
List<List<String>> _tree(List<String> leaves) {
  final levels = [List<String>.of(leaves)];
  while (levels.last.length > 1) {
    final previous = levels.last;
    levels.add([
      for (var i = 0; i < previous.length; i += 2)
        _parent(previous[i], previous[min(i + 1, previous.length - 1)]),
    ]);
  }
  return levels;
}

final class MerkleSibling {
  const MerkleSibling(this.hash, {required this.onLeft});
  final String hash;
  final bool onLeft;
}

final class ShardBlock {
  ShardBlock({
    required this.index,
    required this.stripe,
    required List<int> bytes,
    required List<MerkleSibling> proof,
  }) : bytes = Uint8List.fromList(bytes),
       proof = List.unmodifiable(proof);
  final int index;
  final int stripe;
  final Uint8List bytes;
  final List<MerkleSibling> proof;
}

/// Authenticated technical metadata. Encryption keys and plaintext names are absent.
final class DistributedManifest {
  DistributedManifest({
    required this.objectId,
    required this.ciphertextHash,
    required this.ciphertextLength,
    required this.blockSize,
    required List<String> roots,
  }) : roots = List.unmodifiable(roots) {
    _id(objectId);
    _digest(ciphertextHash);
    if (ciphertextLength < 0 ||
        blockSize < 1 ||
        blockSize > 256 * 1024 ||
        stripeCount > 4096 ||
        roots.length != 5) {
      throw const FormatException('Unsupported distributed object dimensions');
    }
    for (final root in roots) {
      _digest(root);
    }
  }
  static const version = 1;
  static const codec = 'rs-vandermonde-gf256-0x11d-3-5';
  final String objectId;
  final String ciphertextHash;
  final int ciphertextLength;
  final int blockSize;
  final List<String> roots;
  int get stripeCount =>
      max(1, (ciphertextLength + 3 * blockSize - 1) ~/ (3 * blockSize));
  int get shardLength => stripeCount * blockSize;
  Map<String, Object> toJson() => {
    'version': version,
    'codec': codec,
    'object_id': objectId,
    'ciphertext_hash': ciphertextHash,
    'ciphertext_length': ciphertextLength,
    'block_size': blockSize,
    'roots': roots,
  };
  String get hash => _hash(utf8.encode(jsonEncode(toJson())));
  factory DistributedManifest.fromJson(
    Map<String, dynamic> json, {
    required String expectedHash,
  }) {
    if (json['version'] != version || json['codec'] != codec) {
      throw const FormatException('Unsupported distributed storage version');
    }
    final result = DistributedManifest(
      objectId: json['object_id'] as String,
      ciphertextHash: json['ciphertext_hash'] as String,
      ciphertextLength: json['ciphertext_length'] as int,
      blockSize: json['block_size'] as int,
      roots: (json['roots'] as List).cast<String>(),
    );
    if (result.hash != expectedHash) {
      throw const FormatException('Untrusted distributed manifest');
    }
    return result;
  }
  bool verifies(ShardBlock block) {
    if (block.index < 0 ||
        block.index >= 5 ||
        block.stripe < 0 ||
        block.stripe >= stripeCount ||
        block.bytes.length != blockSize) {
      return false;
    }
    var width = stripeCount;
    var position = block.stripe;
    var value = _leaf(objectId, block.index, block.stripe, block.bytes);
    var level = 0;
    while (width > 1) {
      if (level >= block.proof.length) return false;
      final sibling = block.proof[level++];
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sibling.hash) ||
          sibling.onLeft != position.isOdd) {
        return false;
      }
      if (position.isEven && position + 1 == width && sibling.hash != value) {
        return false;
      }
      value = sibling.onLeft
          ? _parent(sibling.hash, value)
          : _parent(value, sibling.hash);
      position ~/= 2;
      width = (width + 1) ~/ 2;
    }
    return level == block.proof.length && value == roots[block.index];
  }
}

final class ShareReceipt {
  const ShareReceipt(
    this.nodeId,
    this.failureDomain,
    this.index,
    this.manifestHash,
  );
  final String nodeId;
  final String failureDomain;
  final int index;
  final String manifestHash;
}

abstract interface class ShardNode {
  String get id;
  String get failureDomain;
  Future<ShareReceipt> put(
    DistributedManifest manifest,
    int index,
    Stream<List<int>> bytes,
  );
  Future<ShardBlock> get(DistributedManifest manifest, int index, int stripe);
  Future<void> delete(String objectId);
}

/// Managed disk node. Caller can place nodes on independent hosts/volumes.
/// An ACK is returned only after data flush, metadata flush and directory publish.
final class DirectoryShardNode implements ShardNode {
  DirectoryShardNode({
    required this.id,
    required this.failureDomain,
    required this.directory,
  });
  @override
  final String id;
  @override
  final String failureDomain;
  final String directory;
  final _metadataCache = <String, Future<Map<String, dynamic>>>{};
  String _path(String objectId, int index) {
    _id(objectId);
    if (index < 0 || index > 4) throw RangeError.range(index, 0, 4);
    return p.join(directory, objectId, '$index');
  }

  File _deleted(String objectId) =>
      File(p.join(directory, '$objectId.deleted'));
  @override
  Future<ShareReceipt> put(
    DistributedManifest manifest,
    int index,
    Stream<List<int>> bytes,
  ) async {
    final destination = _path(manifest.objectId, index);
    if (await _deleted(manifest.objectId).exists()) {
      throw StateError('Object deleted');
    }
    final existing = Directory(destination);
    if (await existing.exists()) {
      final metadata = await _metadata(manifest, index);
      if (metadata['manifest_hash'] != manifest.hash) {
        throw StateError('Conflicting object ID');
      }
      for (var stripe = 0; stripe < manifest.stripeCount; stripe++) {
        await get(manifest, index, stripe);
      }
      // Drain to release HTTP/file producer resources, while enforcing the budget.
      var received = 0;
      await for (final chunk in bytes) {
        received += chunk.length;
        if (received > manifest.shardLength) {
          throw const FormatException('Oversized duplicate shard');
        }
      }
      if (received != manifest.shardLength) {
        throw const FormatException('Incomplete duplicate shard');
      }
      return ShareReceipt(id, failureDomain, index, manifest.hash);
    }
    await Directory(p.dirname(destination)).create(recursive: true);
    final stage = Directory('$destination.stage-${_randomId()}');
    await stage.create();
    final handle = await File(
      p.join(stage.path, 'data'),
    ).open(mode: FileMode.write);
    final leaves = <String>[];
    final pending = Uint8List(manifest.blockSize);
    var offset = 0;
    var total = 0;
    var published = false;
    try {
      await for (final chunk in bytes) {
        total += chunk.length;
        if (total > manifest.shardLength) {
          throw const FormatException('Oversized shard');
        }
        await handle.writeFrom(chunk);
        var source = 0;
        while (source < chunk.length) {
          final count = min(pending.length - offset, chunk.length - source);
          pending.setRange(offset, offset + count, chunk, source);
          source += count;
          offset += count;
          if (offset == pending.length) {
            leaves.add(_leaf(manifest.objectId, index, leaves.length, pending));
            offset = 0;
          }
        }
      }
      if (total != manifest.shardLength ||
          offset != 0 ||
          _tree(leaves).last.single != manifest.roots[index]) {
        throw const FormatException('Shard failed integrity validation');
      }
      await handle.flush();
      await handle.close();
      final metadata = {
        'manifest_hash': manifest.hash,
        'manifest': manifest.toJson(),
        'leaves': leaves,
      };
      await File(
        p.join(stage.path, 'metadata.json'),
      ).writeAsString(jsonEncode(metadata), flush: true);
      if (await _deleted(manifest.objectId).exists()) {
        throw StateError('Object deleted during upload');
      }
      try {
        await stage.rename(destination);
        published = true;
      } on FileSystemException {
        if (!await existing.exists()) rethrow;
        await _metadata(manifest, index);
      }
      return ShareReceipt(id, failureDomain, index, manifest.hash);
    } finally {
      try {
        await handle.close();
      } on FileSystemException {
        /* already closed */
      }
      if (!published && await stage.exists()) {
        await stage.delete(recursive: true);
      }
    }
  }

  Future<Map<String, dynamic>> _metadata(
    DistributedManifest manifest,
    int index,
  ) async {
    if (await _deleted(manifest.objectId).exists()) {
      throw StateError('Object deleted');
    }
    final key = '${manifest.hash}:$index';
    final cached = _metadataCache[key];
    if (cached != null) return cached;
    final loading = _loadMetadata(manifest, index);
    _metadataCache[key] = loading;
    if (_metadataCache.length > 16) {
      _metadataCache.remove(_metadataCache.keys.first);
    }
    try {
      return await loading;
    } catch (_) {
      _metadataCache.remove(key);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _loadMetadata(
    DistributedManifest manifest,
    int index,
  ) async {
    final file = File(p.join(_path(manifest.objectId, index), 'metadata.json'));
    if (await file.length() > 1024 * 1024) {
      throw const FormatException('Oversized shard metadata');
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (json['manifest_hash'] != manifest.hash) {
      throw const FormatException('Wrong shard manifest');
    }
    final leaves = (json['leaves'] as List).cast<String>();
    if (leaves.length != manifest.stripeCount) {
      throw const FormatException('Wrong stripe count');
    }
    for (final leaf in leaves) {
      _digest(leaf);
    }
    final tree = _tree(leaves);
    if (tree.last.single != manifest.roots[index]) {
      throw const FormatException('Corrupted integrity tree');
    }
    json['_tree'] = tree;
    return json;
  }

  @override
  Future<ShardBlock> get(
    DistributedManifest manifest,
    int index,
    int stripe,
  ) async {
    if (stripe < 0 || stripe >= manifest.stripeCount) {
      throw RangeError('Invalid stripe');
    }
    final metadata = await _metadata(manifest, index);
    final tree = metadata['_tree'] as List<List<String>>;
    var position = stripe;
    final proof = <MerkleSibling>[];
    for (final level in tree.take(tree.length - 1)) {
      proof.add(
        MerkleSibling(
          level[min(position ^ 1, level.length - 1)],
          onLeft: position.isOdd,
        ),
      );
      position ~/= 2;
    }
    final file = await File(
      p.join(_path(manifest.objectId, index), 'data'),
    ).open();
    try {
      await file.setPosition(stripe * manifest.blockSize);
      final block = ShardBlock(
        index: index,
        stripe: stripe,
        bytes: await file.read(manifest.blockSize),
        proof: proof,
      );
      if (!manifest.verifies(block)) {
        throw const FormatException('Corrupted shard block');
      }
      return block;
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> delete(String objectId) async {
    _id(objectId);
    _metadataCache.clear();
    await Directory(directory).create(recursive: true);
    await _deleted(objectId).writeAsString('deleted', flush: true);
    final object = Directory(p.join(directory, objectId));
    if (await object.exists()) await object.delete(recursive: true);
  }
}

final class DistributedObject {
  DistributedObject(this.manifest, List<ShareReceipt> receipts)
    : receipts = List.unmodifiable(receipts);
  final DistributedManifest manifest;
  final List<ShareReceipt> receipts;
}

/// Distribution operates only on ciphertext. The caller retains its AEAD key.
final class DistributedStore {
  DistributedStore({
    required List<ShardNode> nodes,
    required this.spoolDirectory,
  }) : nodes = List.unmodifiable(nodes) {
    if (nodes.map((n) => n.id).toSet().length != nodes.length ||
        nodes.map((n) => n.failureDomain).toSet().length < 5) {
      throw ArgumentError(
        'Five distinct nodes and failure domains are required',
      );
    }
  }
  final List<ShardNode> nodes;
  final String spoolDirectory;
  final _codec = ReedSolomon3of5();

  Future<DistributedObject> putCiphertext(
    String path, {
    String? objectId,
    int blockSize = 256 * 1024,
  }) async {
    final id = objectId ?? _randomId();
    _id(id);
    final file = File(path);
    final length = await file.length();
    if (blockSize < 1 || blockSize > 256 * 1024) {
      throw ArgumentError('Invalid block size');
    }
    blockSize = min(blockSize, max(1, (length + 2) ~/ 3));
    final stripes = max(1, (length + 3 * blockSize - 1) ~/ (3 * blockSize));
    if (stripes > 4096) {
      throw ArgumentError('Distributed v1 exceeds 4096 stripes');
    }
    final stage = Directory(p.join(spoolDirectory, '$id-${_randomId()}'));
    await stage.create(recursive: true);
    final outputs = <RandomAccessFile>[];
    final leaves = List.generate(5, (_) => <String>[]);
    final input = await file.open();
    final digest = _DigestSink();
    final hashing = sha256.startChunkedConversion(digest);
    var consumed = 0;
    try {
      for (var i = 0; i < 5; i++) {
        outputs.add(
          await File(p.join(stage.path, '$i')).open(mode: FileMode.write),
        );
      }
      for (var stripe = 0; stripe < stripes; stripe++) {
        final data = <Uint8List>[];
        for (var i = 0; i < 3; i++) {
          final bytes = Uint8List(blockSize);
          var read = 0;
          while (read < blockSize) {
            final count = await input.readInto(bytes, read);
            if (count == 0) break;
            hashing.add(Uint8List.sublistView(bytes, read, read + count));
            consumed += count;
            read += count;
          }
          data.add(bytes);
        }
        final encoded = _codec.encode(data);
        for (var i = 0; i < 5; i++) {
          await outputs[i].writeFrom(encoded[i]);
          leaves[i].add(_leaf(id, i, stripe, encoded[i]));
        }
      }
      for (final output in outputs) {
        await output.flush();
        await output.close();
      }
      outputs.clear();
      if (consumed != length || await input.readByte() != -1) {
        throw StateError('Ciphertext changed during encoding');
      }
      hashing.close();
      final contentHash = digest.value!.toString();
      final manifest = DistributedManifest(
        objectId: id,
        ciphertextHash: contentHash,
        ciphertextLength: length,
        blockSize: blockSize,
        roots: leaves.map((l) => _tree(l).last.single).toList(),
      );
      await File(
        p.join(stage.path, 'manifest.json'),
      ).writeAsString(jsonEncode(manifest.toJson()), flush: true);
      final domains = <String>{};
      final chosen = nodes
          .where((n) => domains.add(n.failureDomain))
          .take(5)
          .toList();
      final receipts = await Future.wait(
        List.generate(
          5,
          (i) => chosen[i].put(
            manifest,
            i,
            File(p.join(stage.path, '$i')).openRead(),
          ),
        ),
      );
      if (receipts.map((r) => r.failureDomain).toSet().length != 5 ||
          receipts.map((r) => r.index).toSet().length != 5 ||
          receipts.any((r) => r.manifestHash != manifest.hash)) {
        throw StateError(
          'Storage quorum did not confirm five independent shares',
        );
      }
      for (var i = 0; i < 5; i++) {
        final receipt = receipts[i];
        if (receipt.nodeId != chosen[i].id ||
            receipt.failureDomain != chosen[i].failureDomain ||
            receipt.index != i) {
          throw const FormatException(
            'Storage acknowledgement has another placement',
          );
        }
      }
      return DistributedObject(manifest, receipts);
    } finally {
      await input.close();
      for (final output in outputs) {
        await output.close();
      }
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  Future<Map<int, Uint8List>> _blocks(
    DistributedManifest manifest,
    int stripe,
    Map<int, ShardNode> hints,
    Set<String> missing,
    Set<String> unavailable,
  ) async {
    final verified = <int, Uint8List>{};
    for (var index = 0; index < 5 && verified.length < 3; index++) {
      final preferred = hints[index];
      final candidates = preferred == null
          ? nodes
          : [preferred, ...nodes.where((n) => n.id != preferred.id)];
      for (final node in candidates) {
        final location = jsonEncode([index, node.id]);
        if (unavailable.contains(node.id) || missing.contains(location)) {
          continue;
        }
        try {
          final block = await node.get(manifest, index, stripe);
          if (block.index != index ||
              block.stripe != stripe ||
              !manifest.verifies(block)) {
            continue;
          }
          verified[index] = block.bytes;
          hints[index] = node;
          break;
        } on FileSystemException {
          missing.add(location);
          continue;
        } on FormatException {
          continue;
        } on StateError {
          missing.add(location);
          continue;
        } on IOException {
          unavailable.add(node.id);
          continue;
        } on http.ClientException {
          unavailable.add(node.id);
          continue;
        } on TimeoutException {
          unavailable.add(node.id);
          continue;
        }
      }
    }
    if (verified.length < 3) {
      throw StateError('Fewer than three verified shard indices are available');
    }
    return verified;
  }

  Future<File> recoverCiphertext(
    DistributedManifest manifest,
    String destination,
  ) async {
    final target = File(destination);
    if (await target.exists()) {
      if (await target.length() == manifest.ciphertextLength &&
          (await sha256.bind(target.openRead()).first).toString() ==
              manifest.ciphertextHash) {
        return target;
      }
      throw StateError('Recovery destination already contains another object');
    }
    await target.parent.create(recursive: true);
    final stage = File('$destination.partial-${_randomId()}');
    final output = await stage.open(mode: FileMode.write);
    var remaining = manifest.ciphertextLength;
    final hints = <int, ShardNode>{};
    final missing = <String>{};
    final unavailable = <String>{};
    try {
      for (var stripe = 0; stripe < manifest.stripeCount; stripe++) {
        final data = _codec.reconstruct(
          await _blocks(manifest, stripe, hints, missing, unavailable),
        );
        for (final block in data) {
          final count = min(remaining, block.length);
          if (count > 0) await output.writeFrom(block, 0, count);
          remaining -= count;
        }
      }
      await output.flush();
      await output.close();
      if (remaining != 0 ||
          (await sha256.bind(stage.openRead()).first).toString() !=
              manifest.ciphertextHash) {
        throw const FormatException(
          'Recovered ciphertext failed integrity validation',
        );
      }
      await stage.rename(destination);
      return target;
    } finally {
      try {
        await output.close();
      } on FileSystemException {
        /* already closed */
      }
      if (await stage.exists()) await stage.delete();
    }
  }

  /// Repairs placement without an encryption key. The manifest remains unchanged.
  Future<ShareReceipt> repairShare(
    DistributedManifest manifest,
    int index,
    ShardNode replacement,
  ) async {
    if (index < 0 || index > 4) throw RangeError.range(index, 0, 4);
    await Directory(spoolDirectory).create(recursive: true);
    final stage = File(
      p.join(
        spoolDirectory,
        '${manifest.objectId}.$index.repair-${_randomId()}',
      ),
    );
    final output = await stage.open(mode: FileMode.write);
    final hints = <int, ShardNode>{};
    final missing = <String>{};
    final unavailable = <String>{};
    try {
      for (var stripe = 0; stripe < manifest.stripeCount; stripe++) {
        final data = _codec.reconstruct(
          await _blocks(manifest, stripe, hints, missing, unavailable),
        );
        await output.writeFrom(_codec.encode(data)[index]);
      }
      await output.flush();
      await output.close();
      final receipt = await replacement.put(manifest, index, stage.openRead());
      if (receipt.nodeId != replacement.id ||
          receipt.failureDomain != replacement.failureDomain ||
          receipt.index != index ||
          receipt.manifestHash != manifest.hash) {
        throw const FormatException(
          'Untrusted replacement storage acknowledgement',
        );
      }
      return receipt;
    } finally {
      try {
        await output.close();
      } on FileSystemException {
        /* already closed */
      }
      if (await stage.exists()) await stage.delete();
    }
  }

  Future<void> delete(DistributedManifest manifest) =>
      Future.wait(nodes.map((node) => node.delete(manifest.objectId)));
}
