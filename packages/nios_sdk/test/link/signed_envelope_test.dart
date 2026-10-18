import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:nios_sdk/link.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  test(
    'another group-key holder cannot impersonate a device or its ACK',
    () async {
      final signatures = Ed25519();
      final keyA = await signatures.newKeyPair();
      final keyB = await signatures.newKeyPair();
      final keyC = await signatures.newKeyPair();
      final publicKeys = {
        'a': await keyA.extractPublicKey(),
        'b': await keyB.extractPublicKey(),
        'c': await keyC.extractPublicKey(),
      };
      final sharedGroupKey = SecretKey(List.filled(32, 91));
      AesGcmEnvelopeCipher aes(String device) => AesGcmEnvelopeCipher(
        deviceId: device,
        keyForPeer: (_) async => sharedGroupKey,
      );
      SignedEnvelopeCipher signed(String device, SimpleKeyPair pair) =>
          SignedEnvelopeCipher(
            deviceId: device,
            inner: aes(device),
            signingKeyPair: pair,
            signingKeyForPeer: (device) async =>
                publicKeys[device] ?? (throw StateError('Unknown device')),
          );
      final directory = await Directory.systemTemp.createTemp('nios_signed_');
      DurableSession? a;
      DurableSession? b;
      try {
        a = await DurableSession.open(
          directory: directory.path,
          accountId: 'signed',
          journalKey: List.filled(32, 19),
          deviceId: 'a',
          cipher: signed('a', keyA),
          transports: [],
          autoStart: false,
        );
        b = await DurableSession.open(
          directory: directory.path,
          accountId: 'signed',
          journalKey: List.filled(32, 19),
          deviceId: 'b',
          cipher: signed('b', keyB),
          transports: [],
          autoStart: false,
          reducer: (state, _) => {'count': (state['count'] as int? ?? 0) + 1},
        );
        final first = await a.enqueue(
          peerId: 'b',
          sessionId: 'group',
          payload: {'number': 1},
        );
        final ack = await b.receive(first.envelope);
        await a.acceptAcknowledgement(ack);
        expect(a.operation(first.operationId)!.applied, isTrue);

        final waiting = await a.enqueue(
          peerId: 'b',
          sessionId: 'group',
          payload: {'number': 2},
        );
        // C knows the same AES group secret and can construct a valid AEAD body
        // claiming to be B, but it does not possess B's pinned signing identity.
        final forgedUnsigned = await aes('b').seal(
          EnvelopeContext(
            senderId: 'b',
            recipientId: 'a',
            sessionId: 'group',
            operationId: waiting.operationId,
            sequence: waiting.context.sequence,
            kind: 'ack',
          ),
          utf8.encode(
            jsonEncode({
              'digest': waiting.envelope.digest,
              'fact': DeliveryFact.recipientApplied.name,
            }),
          ),
        );
        await expectLater(
          a.acceptAcknowledgement(forgedUnsigned),
          throwsStateError,
        );
        final wrongSignature = await signatures.sign(
          forgedUnsigned.signatureInput,
          keyPair: keyC,
        );
        final forgedSigned = EncryptedEnvelope(
          context: forgedUnsigned.context,
          nonce: forgedUnsigned.nonce,
          ciphertext: forgedUnsigned.ciphertext,
          mac: forgedUnsigned.mac,
          signature: wrongSignature.bytes,
        );
        await expectLater(
          a.acceptAcknowledgement(forgedSigned),
          throwsStateError,
        );
        expect(a.operation(waiting.operationId)!.facts, {
          DeliveryFact.localDurable,
        });

        final altered = first.envelope.toJson()
          ..['nonce'] = base64Encode(List.filled(12, 0));
        await expectLater(
          signed('b', keyB).open(EncryptedEnvelope.fromJson(altered)),
          throwsStateError,
        );
        expect(b.applicationState(peerId: 'a', sessionId: 'group')['count'], 1);
      } finally {
        await a?.close();
        await b?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
