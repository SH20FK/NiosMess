import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/double_ratchet_service.dart';

Future<List<int>> _seed(X25519 x) async {
  final pair = await x.newKeyPair();
  final data = await pair.extract() as SimpleKeyPairData;
  return List<int>.from(data.bytes);
}

void main() {
  final X25519 x25519 = X25519();
  final DoubleRatchetService dr = DoubleRatchetService();

  test('initiator <-> responder exchange stays in sync', () async {
    final List<int> aliceStaticSeed = await _seed(x25519);
    final List<int> bobStaticSeed = await _seed(x25519);

    final SimpleKeyPairData bobStaticPair =
        await x25519.newKeyPairFromSeed(bobStaticSeed) as SimpleKeyPairData;
    final SimplePublicKey bobStatic =
        bobStaticPair.publicKey as SimplePublicKey;

    // Alice initiates with a fresh ephemeral (her handshake DH key).
    final alicePending = await dr.initiateSession(
      ourStaticSeed: aliceStaticSeed,
      theirStaticPublic: bobStatic,
      peerStaticEdB64: 'peer-ed',
    );

    // Her HELO carries the pending session's ephemeral public key.
    final SimpleKeyPairData aliceEphemeral =
        await x25519.newKeyPairFromSeed(alicePending.dhsSeed!) as SimpleKeyPairData;

    // Bob responds using Alice's static + ephemeral.
    final SimpleKeyPairData aliceStaticPair =
        await x25519.newKeyPairFromSeed(aliceStaticSeed) as SimpleKeyPairData;
    final bobSession = await dr.respondSession(
      ourStaticSeed: bobStaticSeed,
      theirStaticPublic: aliceStaticPair.publicKey as SimplePublicKey,
      theirEphemeralPublic: aliceEphemeral.publicKey as SimplePublicKey,
      peerStaticEdB64: 'alice-ed',
    );

    // Alice keeps her pending session as-is (see E2eeService.completeHandshake).
    final aliceSession = alicePending;

    // Alice -> Bob: first message must decrypt with Bob's initial recv chain.
    final a1 = await dr.encrypt(
      session: aliceSession,
      plaintext: 'hello from alice',
      messageType: 'txt',
    );
    final a1Plain = await dr.decrypt(
      session: bobSession,
      headerB64: a1.headerB64,
      ciphertext: a1.ciphertext,
    );
    expect(a1Plain, 'hello from alice');

    // Bob -> Alice: first message triggers Alice's DH ratchet.
    final b1 = await dr.encrypt(
      session: bobSession,
      plaintext: 'hi alice',
      messageType: 'txt',
    );
    final b1Plain = await dr.decrypt(
      session: aliceSession,
      headerB64: b1.headerB64,
      ciphertext: b1.ciphertext,
    );
    expect(b1Plain, 'hi alice');

    // Continue the conversation both ways.
    for (int i = 0; i < 5; i++) {
      final out = await dr.encrypt(
        session: aliceSession,
        plaintext: 'alice msg $i',
        messageType: 'txt',
      );
      expect(
        await dr.decrypt(
          session: bobSession,
          headerB64: out.headerB64,
          ciphertext: out.ciphertext,
        ),
        'alice msg $i',
      );

      final back = await dr.encrypt(
        session: bobSession,
        plaintext: 'bob msg $i',
        messageType: 'txt',
      );
      expect(
        await dr.decrypt(
          session: aliceSession,
          headerB64: back.headerB64,
          ciphertext: back.ciphertext,
        ),
        'bob msg $i',
      );
    }
  });

  test('out-of-order messages are recovered via skipped keys', () async {
    final List<int> aliceStaticSeed = await _seed(x25519);
    final List<int> bobStaticSeed = await _seed(x25519);

    final SimpleKeyPairData bobStaticPair =
        await x25519.newKeyPairFromSeed(bobStaticSeed) as SimpleKeyPairData;
    final aliceSession = await dr.initiateSession(
      ourStaticSeed: aliceStaticSeed,
      theirStaticPublic: bobStaticPair.publicKey as SimplePublicKey,
      peerStaticEdB64: 'peer-ed',
    );
    final SimpleKeyPairData aliceEphemeral =
        await x25519.newKeyPairFromSeed(aliceSession.dhsSeed!) as SimpleKeyPairData;
    final SimpleKeyPairData aliceStaticPair =
        await x25519.newKeyPairFromSeed(aliceStaticSeed) as SimpleKeyPairData;
    final bobSession = await dr.respondSession(
      ourStaticSeed: bobStaticSeed,
      theirStaticPublic: aliceStaticPair.publicKey as SimplePublicKey,
      theirEphemeralPublic: aliceEphemeral.publicKey as SimplePublicKey,
      peerStaticEdB64: 'alice-ed',
    );

    final m1 = await dr.encrypt(session: aliceSession, plaintext: 'one', messageType: 'txt');
    final m2 = await dr.encrypt(session: aliceSession, plaintext: 'two', messageType: 'txt');
    final m3 = await dr.encrypt(session: aliceSession, plaintext: 'three', messageType: 'txt');

    // Deliver out of order.
    expect(await dr.decrypt(session: bobSession, headerB64: m3.headerB64, ciphertext: m3.ciphertext), 'three');
    expect(await dr.decrypt(session: bobSession, headerB64: m1.headerB64, ciphertext: m1.ciphertext), 'one');
    expect(await dr.decrypt(session: bobSession, headerB64: m2.headerB64, ciphertext: m2.ciphertext), 'two');
  });

  test('session serialization roundtrip keeps ratchet state', () async {
    final List<int> aliceStaticSeed = await _seed(x25519);
    final List<int> bobStaticSeed = await _seed(x25519);

    final SimpleKeyPairData bobStaticPair =
        await x25519.newKeyPairFromSeed(bobStaticSeed) as SimpleKeyPairData;
    final aliceSession = await dr.initiateSession(
      ourStaticSeed: aliceStaticSeed,
      theirStaticPublic: bobStaticPair.publicKey as SimplePublicKey,
      peerStaticEdB64: 'peer-ed',
    );
    final SimpleKeyPairData aliceEphemeral =
        await x25519.newKeyPairFromSeed(aliceSession.dhsSeed!) as SimpleKeyPairData;
    final SimpleKeyPairData aliceStaticPair =
        await x25519.newKeyPairFromSeed(aliceStaticSeed) as SimpleKeyPairData;
    final bobSession = await dr.respondSession(
      ourStaticSeed: bobStaticSeed,
      theirStaticPublic: aliceStaticPair.publicKey as SimplePublicKey,
      theirEphemeralPublic: aliceEphemeral.publicKey as SimplePublicKey,
      peerStaticEdB64: 'alice-ed',
    );

    // A couple of exchanges, then persist Bob's session and restore it.
    final a1 = await dr.encrypt(session: aliceSession, plaintext: 'pre-serialize', messageType: 'txt');
    expect(
      await dr.decrypt(session: bobSession, headerB64: a1.headerB64, ciphertext: a1.ciphertext),
      'pre-serialize',
    );

    final json = await bobSession.toJson();
    final restored = await DoubleRatchetSession.fromJson(
      Map<String, dynamic>.from(json),
    );

    final a2 = await dr.encrypt(session: aliceSession, plaintext: 'post-serialize', messageType: 'txt');
    expect(
      await dr.decrypt(session: restored, headerB64: a2.headerB64, ciphertext: a2.ciphertext),
      'post-serialize',
    );
  });

  test('visual words derive from the shared session key', () async {
    final List<int> aliceStaticSeed = await _seed(x25519);
    final List<int> bobStaticSeed = await _seed(x25519);

    final SimpleKeyPairData bobStaticPair =
        await x25519.newKeyPairFromSeed(bobStaticSeed) as SimpleKeyPairData;
    final aliceSession = await dr.initiateSession(
      ourStaticSeed: aliceStaticSeed,
      theirStaticPublic: bobStaticPair.publicKey as SimplePublicKey,
      peerStaticEdB64: 'peer-ed',
    );

    final words = await dr.getVisualWords(aliceSession.keyVal);
    expect(words.length, 4);
    // Same key -> same words (both sides see identical emoji words).
    final again = await dr.getVisualWords(aliceSession.keyVal);
    expect(again.map((w) => w.word), words.map((w) => w.word));
  });
}
