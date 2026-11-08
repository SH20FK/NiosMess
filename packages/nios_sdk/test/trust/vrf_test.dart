import 'dart:typed_data';

import 'package:nios_sdk/trust.dart';
import 'package:test/test.dart';

void main() {
  group('NiosVrf Verifiable Random Function for Blinded Key Transparency', () {
    test('evaluates deterministic output hash and valid proof for account identifier', () async {
      final keyPair = await VrfKeyPair.generate();

      final proof1 = await NiosVrf.evaluate(
        keyPair: keyPair,
        input: 'alice@nios.mesh',
      );
      final proof2 = await NiosVrf.evaluate(
        keyPair: keyPair,
        input: 'alice@nios.mesh',
      );

      // Determinism: Same input and key produces exact same output hash
      expect(proof1.outputHash, equals(proof2.outputHash));
      expect(proof1.outputHash.length, 32);
      expect(proof1.proofBytes.length, 64);

      // Verify honestly generated proof
      final isValid = await NiosVrf.verify(
        publicKey: keyPair.publicKey,
        input: 'alice@nios.mesh',
        proof: proof1,
      );
      expect(isValid, isTrue);

      // Verification fails if input does not match
      final isWrongInputValid = await NiosVrf.verify(
        publicKey: keyPair.publicKey,
        input: 'bob@nios.mesh',
        proof: proof1,
      );
      expect(isWrongInputValid, isFalse);

      // Verification fails if outputHash is tampered with
      final tamperedHash = Uint8List.fromList(proof1.outputHash)..[0] ^= 0xFF;
      final tamperedProof = VrfProof(
        outputHash: tamperedHash,
        proofBytes: proof1.proofBytes,
      );
      final isTamperedValid = await NiosVrf.verify(
        publicKey: keyPair.publicKey,
        input: 'alice@nios.mesh',
        proof: tamperedProof,
      );
      expect(isTamperedValid, isFalse);

      // Verification fails with wrong public key
      final otherKeyPair = await VrfKeyPair.generate();
      final isWrongKeyValid = await NiosVrf.verify(
        publicKey: otherKeyPair.publicKey,
        input: 'alice@nios.mesh',
        proof: proof1,
      );
      expect(isWrongKeyValid, isFalse);
    });

    test('different account inputs yield distinct pseudorandom blind hashes', () async {
      final keyPair = await VrfKeyPair.generate();

      final pAlice = await NiosVrf.evaluate(
        keyPair: keyPair,
        input: 'user_alice',
      );
      final pBob = await NiosVrf.evaluate(
        keyPair: keyPair,
        input: 'user_bob',
      );

      expect(pAlice.outputHash, isNot(equals(pBob.outputHash)));
    });
  });
}
