import 'dart:convert';
import 'dart:typed_data';

import 'package:nios_mls/nios_mls.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('Post-Quantum Hybrid OpenMLS (ML-KEM / X-Wing)', () {
    late Directory tempDir;
    final storageKey = Uint8List.fromList(List.generate(32, (i) => (i * 3) & 0xFF));

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nios_mls_pq_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('supports advertising post-quantum ciphersuites in capabilities', () {
      expect(
        NiosMlsClient.supportedCiphersuites,
        contains(NiosMlsClient.postQuantumHybridXWing),
      );
      expect(
        NiosMlsClient.supportedCiphersuites,
        contains(NiosMlsClient.postQuantumHybridMlKem768),
      );
    });

    test('Alice creates a Post-Quantum Hybrid group and generates ML-KEM KeyPackage', () async {
      final alice = await NiosMlsClient.open(
        path: '${tempDir.path}/alice',
        storageKey: storageKey,
        accountId: 'alice-acc',
        deviceId: 'alice-dev-1',
        ciphersuite: NiosMlsClient.postQuantumHybridXWing,
        authorizeDevice: (acc, dev, key) async => true,
      );

      expect(alice.ciphersuite, NiosMlsClient.postQuantumHybridXWing);

      // Create KeyPackage with Post-Quantum Hybrid ML-KEM-768 / X-Wing
      final keyPackageBytes = await alice.createKeyPackage(
        ciphersuite: NiosMlsClient.postQuantumHybridXWing,
      );
      expect(keyPackageBytes.isNotEmpty, isTrue);

      // Create Post-Quantum Hybrid group
      final groupId = Uint8List.fromList(utf8.encode('pq-group-1'));
      final createdGroupId = await alice.createGroup(
        groupId: groupId,
        ciphersuite: NiosMlsClient.postQuantumHybridXWing,
      );
      expect(createdGroupId, equals(groupId));

      expect(await alice.isActive(groupId), isTrue);
      expect(await alice.epoch(groupId), BigInt.zero);

      await alice.close();
    });
  });
}
