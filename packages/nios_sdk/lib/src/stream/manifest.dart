import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;

/// Public metadata. The hash and encryption key must arrive over a trusted
/// channel. Neither an untrusted manifest nor its self-reported hash is a trust
/// anchor. Metadata intentionally contains no file name or encryption key.
final class NiosStreamManifest {
  static const int currentVersion = 1;
  static const int tagLength = 16;
  static const int maximumSegmentSize = 1024 * 1024;
  static const int maximumSegmentCount = 1024 * 1024;
  static const int maximumPlaintextLength = 1 << 40;

  final int version;
  final String objectId;
  final int plaintextLength;
  final int segmentSize;
  final Uint8List _noncePrefix;
  final List<String> segmentHashes;
  late final Uint8List _canonicalBytes = Uint8List.fromList(
    utf8.encode(jsonEncode(toJson())),
  );
  late final String hash = digest.sha256.convert(_canonicalBytes).toString();

  NiosStreamManifest({
    this.version = currentVersion,
    required this.objectId,
    required this.plaintextLength,
    required this.segmentSize,
    required List<int> noncePrefix,
    required List<String> segmentHashes,
  }) : _noncePrefix = Uint8List.fromList(noncePrefix),
       segmentHashes = List.unmodifiable(segmentHashes) {
    if (version != currentVersion ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(objectId) ||
        plaintextLength < 0 ||
        plaintextLength > maximumPlaintextLength ||
        segmentSize <= 0 ||
        segmentSize > maximumSegmentSize ||
        _noncePrefix.length != 8 ||
        noncePrefix.any((value) => value < 0 || value > 255) ||
        segmentCount > maximumSegmentCount ||
        this.segmentHashes.length != segmentCount ||
        this.segmentHashes.any(
          (value) => !RegExp(r'^[a-f0-9]{64}$').hasMatch(value),
        )) {
      throw const FormatException('Invalid NiosStream manifest');
    }
  }

  factory NiosStreamManifest.fromJson(
    Map<String, Object?> json, {
    required String expectedHash,
  }) {
    if (json.length != 7 ||
        json['version'] is! int ||
        json['objectId'] is! String ||
        json['plaintextLength'] is! int ||
        json['segmentSize'] is! int ||
        json['noncePrefix'] is! String ||
        json['segmentHashes'] is! List ||
        json['algorithm'] != 'A256GCM') {
      throw const FormatException('Invalid NiosStream manifest fields');
    }
    final rawHashes = json['segmentHashes']! as List;
    if (rawHashes.length > maximumSegmentCount ||
        rawHashes.any((value) => value is! String)) {
      throw const FormatException('Invalid segment hashes');
    }
    final manifest = NiosStreamManifest(
      version: json['version']! as int,
      objectId: json['objectId']! as String,
      plaintextLength: json['plaintextLength']! as int,
      segmentSize: json['segmentSize']! as int,
      noncePrefix: base64Decode(json['noncePrefix']! as String),
      segmentHashes: rawHashes.cast<String>(),
    );
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash) ||
        manifest.hash != expectedHash) {
      throw const FormatException('Untrusted NiosStream manifest');
    }
    return manifest;
  }

  int get segmentCount => (plaintextLength + segmentSize - 1) ~/ segmentSize;
  int get ciphertextLength => plaintextLength + segmentCount * tagLength;
  Uint8List get noncePrefix => Uint8List.fromList(_noncePrefix);

  Map<String, Object?> toJson() => {
    'version': version,
    'algorithm': 'A256GCM',
    'objectId': objectId,
    'plaintextLength': plaintextLength,
    'segmentSize': segmentSize,
    'noncePrefix': base64Encode(_noncePrefix),
    'segmentHashes': segmentHashes,
  };

  /// Fixed field order and JSON integer/string encodings are part of version 1.
  Uint8List get canonicalBytes => Uint8List.fromList(_canonicalBytes);

  int segmentPlaintextLength(int index) {
    RangeError.checkValidIndex(index, segmentHashes, 'index');
    final remaining = plaintextLength - index * segmentSize;
    return remaining < segmentSize ? remaining : segmentSize;
  }

  int segmentCiphertextLength(int index) =>
      segmentPlaintextLength(index) + tagLength;

  int segmentCiphertextOffset(int index) {
    RangeError.checkValidIndex(index, segmentHashes, 'index');
    return index * (segmentSize + tagLength);
  }

  Uint8List segmentNonce(int index) {
    RangeError.checkValidIndex(index, segmentHashes, 'index');
    final nonce = Uint8List(12)..setRange(0, 8, _noncePrefix);
    ByteData.sublistView(nonce).setUint32(8, index, Endian.big);
    return nonce;
  }

  /// Canonical AAD binds ciphertext to the object, protocol and exact position.
  Uint8List segmentAssociatedData(int index) => Uint8List.fromList(
    utf8.encode(
      jsonEncode([
        'NiosStream',
        version,
        'A256GCM',
        objectId,
        plaintextLength,
        segmentSize,
        index,
        segmentPlaintextLength(index),
      ]),
    ),
  );
}
