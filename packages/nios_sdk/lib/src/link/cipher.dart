import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'models.dart';

/// Implementations must not mutate protocol state before the caller persists
/// the resulting envelope. Stateful ratchets require an external atomic adapter.
abstract interface class EnvelopeCipher {
  Future<EncryptedEnvelope> seal(EnvelopeContext context, List<int> plaintext);
  Future<Uint8List> open(EncryptedEnvelope envelope);
}

typedef PeerKeyResolver = Future<SecretKey> Function(String peerDeviceId);

/// A pairwise-key adapter, not a ratchet or an identity exchange protocol.
/// Keys must be independently provisioned through a trusted device channel.
class AesGcmEnvelopeCipher implements EnvelopeCipher {
  AesGcmEnvelopeCipher({required this.deviceId, required this.keyForPeer});

  final String deviceId;
  final PeerKeyResolver keyForPeer;
  final AesGcm _algorithm = AesGcm.with256bits();

  String _peer(EnvelopeContext context) {
    if (context.senderId == deviceId) return context.recipientId;
    if (context.recipientId == deviceId) return context.senderId;
    throw StateError('Envelope does not belong to this device');
  }

  @override
  Future<EncryptedEnvelope> seal(
    EnvelopeContext context,
    List<int> plaintext,
  ) async {
    if (context.senderId != deviceId) {
      throw StateError('Invalid envelope sender');
    }
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: await keyForPeer(_peer(context)),
      nonce: _algorithm.newNonce(),
      aad: context.associatedData,
    );
    return EncryptedEnvelope(
      context: context,
      nonce: box.nonce,
      ciphertext: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  @override
  Future<Uint8List> open(EncryptedEnvelope envelope) async =>
      Uint8List.fromList(
        await _algorithm.decrypt(
          SecretBox(
            envelope.ciphertext,
            nonce: envelope.nonce,
            mac: Mac(envelope.mac),
          ),
          secretKey: await keyForPeer(_peer(envelope.context)),
          aad: envelope.context.associatedData,
        ),
      );
}

typedef PeerSigningKeyResolver =
    Future<SimplePublicKey> Function(String peerDeviceId);

/// Device authentication when an encryption secret is shared by a whole group.
/// The signature covers the exact ciphertext and context, so another group
/// member cannot impersonate a sender or re-encrypt its bytes to forge ACKs.
/// Pinning/rotation of verification keys belongs to the trusted device catalog.
class SignedEnvelopeCipher implements EnvelopeCipher {
  SignedEnvelopeCipher({
    required this.deviceId,
    required this.inner,
    required this.signingKeyPair,
    required this.signingKeyForPeer,
  });

  final String deviceId;
  final EnvelopeCipher inner;
  final SimpleKeyPair signingKeyPair;
  final PeerSigningKeyResolver signingKeyForPeer;
  final Ed25519 _signatures = Ed25519();

  @override
  Future<EncryptedEnvelope> seal(
    EnvelopeContext context,
    List<int> plaintext,
  ) async {
    if (context.senderId != deviceId) {
      throw StateError('Invalid signing device');
    }
    final envelope = await inner.seal(context, plaintext);
    if (envelope.signature != null) {
      throw StateError('Envelope is already signed');
    }
    final signature = await _signatures.sign(
      envelope.signatureInput,
      keyPair: signingKeyPair,
    );
    return EncryptedEnvelope(
      context: envelope.context,
      nonce: envelope.nonce,
      ciphertext: envelope.ciphertext,
      mac: envelope.mac,
      signature: signature.bytes,
    );
  }

  @override
  Future<Uint8List> open(EncryptedEnvelope envelope) async {
    final signature = envelope.signature;
    if (signature == null) throw StateError('Device signature is required');
    if (envelope.context.recipientId != deviceId &&
        envelope.context.senderId != deviceId) {
      throw StateError('Envelope does not belong to signing device');
    }
    final valid = await _signatures.verify(
      envelope.signatureInput,
      signature: Signature(
        signature,
        publicKey: await signingKeyForPeer(envelope.context.senderId),
      ),
    );
    if (!valid) {
      throw StateError('Device signature does not match pinned identity');
    }
    return inner.open(envelope);
  }
}
