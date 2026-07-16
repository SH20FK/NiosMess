import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class E2eeKeyManager {
  E2eeKeyManager();

  final Ecdh _ecdh = Ecdh.p256();
  final AesGcm _aesGcm = AesGcm.with256bits();

  SimpleKeyPair? myKeyPair;
  Uint8List? myPubKeyRaw;
  SecretKey? mySenderKey;
  Uint8List? mySenderKeyRaw;

  final Map<int, SecretKey> sharedAesKeys = {};
  final Map<int, SecretKey> peerSenderKeys = {};
  final Map<int, Uint8List> peerPubKeysRaw = {};

  static const List<String> verificationEmojiList = [
    '🐶', '🐱', '🦁', '🐎', '🦄', '🐷', '🐘', '🐰',
    '🐼', '🐓', '🐧', '🐢', '🐟', '🐙', '🦋', '🌷',
    '🌳', '🌵', '🍄', '🌏', '🌙', '☁️', '🔥', '🍌',
    '🍎', '🍓', '🌽', '🍕', '🎂', '❤️', '😀', '🤖',
    '🎩', '👓', '🔧', '🎅', '👍', '☂️', '⌛', '⏰',
    '🎁', '💡', '📕', '✏️', '📎', '✂️', '🔒', '🔑',
    '🔨', '☎️', '🏁', '🚂', '🚲', '✈️', '🚀', '🏆',
    '⚽', '🎸', '🎺', '🔔', '⚓', '🎧', '📁', '📌'
  ];

  Future<void> initialize() async {
    myKeyPair = await _ecdh.newKeyPair();
    final myPubKey = await myKeyPair!.extractPublicKey() as EcPublicKey;
    myPubKeyRaw = Uint8List(65);
    myPubKeyRaw![0] = 0x04;
    myPubKeyRaw!.setRange(1, 33, myPubKey.x);
    myPubKeyRaw!.setRange(33, 65, myPubKey.y);

    mySenderKey = _aesGcm.newSecretKey();
    mySenderKeyRaw = Uint8List.fromList(await mySenderKey!.extractBytes());
  }

  Future<Uint8List> generateKeyExchange(int peerId, Uint8List peerPubKeyRaw) async {
    peerPubKeysRaw[peerId] = peerPubKeyRaw;

    final peerX = peerPubKeyRaw.sublist(1, 33);
    final peerY = peerPubKeyRaw.sublist(33, 65);
    final peerPublicKey = EcPublicKey(
      x: peerX,
      y: peerY,
      type: _ecdh.keyPairType,
    );

    final sharedAesKey = await _ecdh.sharedSecretKey(
      keyPair: myKeyPair!,
      remotePublicKey: peerPublicKey,
    );
    sharedAesKeys[peerId] = sharedAesKey;

    final iv = Uint8List(12);
    final random = Random.secure();
    for (int i = 0; i < 12; i++) {
      iv[i] = random.nextInt(256);
    }

    final secretBox = await _aesGcm.encrypt(
      mySenderKeyRaw!,
      secretKey: sharedAesKey,
      nonce: iv,
    );

    final encryptedKey = Uint8List(48);
    encryptedKey.setRange(0, 32, secretBox.cipherText);
    encryptedKey.setRange(32, 48, secretBox.mac.bytes);

    final result = Uint8List(60);
    result.setRange(0, 12, iv);
    result.setRange(12, 60, encryptedKey);
    return result;
  }

  Future<void> importKeyExchange(int senderId, Uint8List iv, Uint8List encryptedKey) async {
    final sharedKey = sharedAesKeys[senderId];
    if (sharedKey == null) return;

    final ciphertext = encryptedKey.sublist(0, 32);
    final tag = encryptedKey.sublist(32, 48);

    final secretBox = SecretBox(
      ciphertext,
      nonce: iv,
      mac: Mac(tag),
    );

    final decryptedKeyBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: sharedKey,
    );

    peerSenderKeys[senderId] = SecretKey(decryptedKeyBytes);
  }

  Future<List<String>> getVerificationEmojis(int localClientId) async {
    if (myPubKeyRaw == null) return const [];

    final List<MapEntry<int, Uint8List>> participants = [];
    participants.add(MapEntry(localClientId, myPubKeyRaw!));
    peerPubKeysRaw.forEach((peerId, pubKeyRaw) {
      participants.add(MapEntry(peerId, pubKeyRaw));
    });

    participants.sort((a, b) => a.key.compareTo(b.key));

    final buffer = Uint8List(participants.length * 69);
    int offset = 0;
    for (final p in participants) {
      final idBytes = Uint8List(4);
      ByteData.view(idBytes.buffer).setUint32(0, p.key);
      buffer.setRange(offset, offset + 4, idBytes);
      buffer.setRange(offset + 4, offset + 69, p.value);
      offset += 69;
    }

    final hashObj = await Sha256().hash(buffer);
    final hashBytes = hashObj.bytes;

    final List<String> emojis = [];
    for (int i = 0; i < 4; i++) {
      final byte = hashBytes[i];
      emojis.add(verificationEmojiList[byte % 64]);
    }

    return emojis;
  }
}
