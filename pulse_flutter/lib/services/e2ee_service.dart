import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/services/double_ratchet_service.dart';
import 'package:pulse_flutter/services/ed25519_identity_service.dart';

enum E2eeSessionStatus { none, connecting, secured, compromised }

class E2eeSessionInfo {
  final E2eeSessionStatus status;
  final bool isVerified;
  final List<({String word, String color})>? visualWords;
  final String? peerFingerprint;
  final String? ourFingerprint;

  const E2eeSessionInfo({
    this.status = E2eeSessionStatus.none,
    this.isVerified = false,
    this.visualWords,
    this.peerFingerprint,
    this.ourFingerprint,
  });
}

class E2eeService {
  E2eeService();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final X25519 _x25519 = X25519();
  final DoubleRatchetService _dr = DoubleRatchetService();
  final Ed25519IdentityService _ed = Ed25519IdentityService();

  static const String _privateKeyStorageKey = 'e2ee.private_key';
  static const String _publicKeyStorageKey = 'e2ee.public_key';
  static const String _sessionPrefix = 'e2ee.session.';

  static final Map<int, SecretKey> _sharedSecrets = {};
  static final Map<int, DoubleRatchetSession> _sessions = {};
  static final Map<int, E2eeSessionStatus> _sessionStatus = {};
  static final Map<int, String> _verifiedPeers = {};

  // ─── Legacy static key pair (unchanged) ───────────────────────

  Future<KeyPair> generateKeyPair() async {
    return _x25519.newKeyPair();
  }

  Future<String> getEdPublicKeyBase64() async {
    final pub = await _ed.getPublicKey();
    return base64Encode(pub.bytes);
  }

  Future<String> getPublicKeyBase64() async {
    String? existing = await _storage.read(key: _publicKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      try {
        base64Decode(existing);
        return existing;
      } catch (_) {}
    }
    final keyPair = await generateKeyPair();
    await saveKeyPair(keyPair);
    final publicKey = await keyPair.extractPublicKey() as SimplePublicKey;
    final b64 = base64Encode(publicKey.bytes);
    await _storage.write(key: _publicKeyStorageKey, value: b64);
    return b64;
  }

  Future<KeyPair?> loadKeyPair() async {
    final raw = await _storage.read(key: _privateKeyStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final bytes = base64Decode(raw);
      return _x25519.newKeyPairFromSeed(bytes);
    } catch (e) {
      debugPrint('[E2eeService] Failed to load key pair: $e');
      return null;
    }
  }

  Future<void> saveKeyPair(KeyPair keyPair) async {
    final keyPairData = await keyPair.extract() as SimpleKeyPairData;
    await _storage.write(
      key: _privateKeyStorageKey,
      value: base64Encode(keyPairData.bytes),
    );
    await _storage.write(
      key: _publicKeyStorageKey,
      value: base64Encode(keyPairData.publicKey.bytes),
    );
  }

  Future<void> deleteKeyPair() async {
    await _storage.delete(key: _privateKeyStorageKey);
    await _storage.delete(key: _publicKeyStorageKey);
    _sharedSecrets.clear();
    _sessions.clear();
    _sessionStatus.clear();
    _verifiedPeers.clear();
    await _ed.deleteKeyPair();
    await _clearAllSessions();
  }

  Future<bool> hasKeyPair() async {
    final raw = await _storage.read(key: _privateKeyStorageKey);
    return raw != null && raw.isNotEmpty;
  }

  // ─── Legacy shared secret (backward compat) ───────────────────

  Future<SecretKey> computeSharedSecret({
    required String theirPublicKeyBase64,
    KeyPair? ourKeyPair,
  }) async {
    final pair = ourKeyPair ?? await loadKeyPair();
    if (pair == null) {
      throw StateError('No E2EE key pair available on this device');
    }
    final theirBytes = base64Decode(theirPublicKeyBase64);
    final theirPublicKey = SimplePublicKey(theirBytes, type: KeyPairType.x25519);
    return _x25519.sharedSecretKey(
      keyPair: pair,
      remotePublicKey: theirPublicKey,
    );
  }

  Future<SecretKey> getOrComputeSharedSecret({
    required int chatId,
    required String theirPublicKeyBase64,
    KeyPair? ourKeyPair,
  }) async {
    if (_sharedSecrets.containsKey(chatId)) {
      return _sharedSecrets[chatId]!;
    }
    final secret = await computeSharedSecret(
      theirPublicKeyBase64: theirPublicKeyBase64,
      ourKeyPair: ourKeyPair,
    );
    _sharedSecrets[chatId] = secret;
    return secret;
  }

  // ─── Legacy encrypt/decrypt (unchanged) ──────────────────────

  Future<String> encryptE2EEMessage({
    required String plaintext,
    required int chatId,
    required String theirPublicKeyBase64,
    KeyPair? ourKeyPair,
  }) async {
    final sharedSecret = await getOrComputeSharedSecret(
      chatId: chatId,
      theirPublicKeyBase64: theirPublicKeyBase64,
      ourKeyPair: ourKeyPair,
    );

    final aesGcm = AesGcm.with256bits();
    final plaintextBytes = utf8.encode(plaintext);
    final secretBox = await aesGcm.encrypt(
      plaintextBytes,
      secretKey: sharedSecret,
    );

    final result = {
      'ciphertext': base64Encode(secretBox.cipherText),
      'iv': base64Encode(secretBox.nonce),
      'tag': base64Encode(secretBox.mac.bytes),
    };

    return base64Encode(utf8.encode(jsonEncode(result)));
  }

  Future<String> decryptE2EEMessage({
    required String e2eeContentBase64,
    required int chatId,
    required String theirPublicKeyBase64,
    KeyPair? ourKeyPair,
  }) async {
    final raw = base64Decode(e2eeContentBase64);
    final jsonStr = utf8.decode(raw);
    final structure = jsonDecode(jsonStr) as Map<String, dynamic>;

    if (structure.containsKey('v') && structure['v'] == 2) {
      return _decryptDR(chatId, structure);
    }

    final sharedSecret = await getOrComputeSharedSecret(
      chatId: chatId,
      theirPublicKeyBase64: theirPublicKeyBase64,
      ourKeyPair: ourKeyPair,
    );

    final ciphertext = base64Decode(structure['ciphertext'] as String);
    final iv = base64Decode(structure['iv'] as String);
    final tag = base64Decode(structure['tag'] as String);

    final aesGcm = AesGcm.with256bits();
    final secretBox = SecretBox(ciphertext, nonce: iv, mac: Mac(tag));
    final decrypted = await aesGcm.decrypt(secretBox, secretKey: sharedSecret);

    return utf8.decode(decrypted);
  }

  // ─── DR encrypt/decrypt (new format) ─────────────────────────

  Future<String> encryptE2EEMessageDR({
    required String plaintext,
    required int chatId,
  }) async {
    final session = _sessions[chatId];
    if (session == null) {
      throw StateError('No DR session for chat $chatId');
    }

    final result = await _dr.encrypt(
      session: session,
      plaintext: plaintext,
      messageType: 'txt',
    );

    final payload = {
      'v': 2,
      'h': jsonDecode(utf8.decode(base64Decode(result.headerB64))),
      'c': base64Encode(result.ciphertext),
    };

    await _saveSession(chatId, session);
    return base64Encode(utf8.encode(jsonEncode(payload)));
  }

  Future<String> _decryptDR(int chatId, Map<String, dynamic> structure) async {
    final session = _sessions[chatId];
    if (session == null) {
      throw StateError('No DR session for chat $chatId');
    }

    final headerB64 = base64Encode(utf8.encode(jsonEncode(structure['h'])));
    final ciphertext = base64Decode(structure['c'] as String);

    final plaintext = await _dr.decrypt(
      session: session,
      headerB64: headerB64,
      ciphertext: ciphertext,
    );

    if (plaintext == null) {
      throw StateError('DR decrypt failed for chat $chatId');
    }

    await _saveSession(chatId, session);
    return plaintext;
  }

  // ─── Session management ───────────────────────────────────────

  Future<DoubleRatchetSession?> getOrCreateSession({
    required int chatId,
    required String theirPublicKeyBase64,
    bool isInitiator = false,
  }) async {
    if (_sessions.containsKey(chatId)) {
      return _sessions[chatId];
    }

    final loaded = await _loadSession(chatId);
    if (loaded != null) {
      _sessions[chatId] = loaded;
      _sessionStatus[chatId] = E2eeSessionStatus.secured;
      return loaded;
    }

    return null;
  }

  Future<void> initiateHandshake({
    required int chatId,
    required String theirPublicKeyBase64,
    required String theirEdPublicKeyBase64,
  }) async {
    final ourKeyPair = await loadKeyPair();
    if (ourKeyPair == null) throw StateError('No E2EE key pair');

    final ourStaticData = await ourKeyPair.extract() as SimpleKeyPairData;
    final theirStatic = SimplePublicKey(
      base64Decode(theirPublicKeyBase64),
      type: KeyPairType.x25519,
    );

    final session = await _dr.initiateSession(
      ourStaticSeed: List<int>.from(ourStaticData.bytes),
      theirStaticPublic: theirStatic,
      peerStaticEdB64: theirEdPublicKeyBase64,
    );

    _sessions[chatId] = session;
    _sessionStatus[chatId] = E2eeSessionStatus.connecting;
  }

  Future<void> completeHandshake({
    required int chatId,
    required String theirEphemeralPublicKeyBase64,
    required String theirEdPublicKeyBase64,
  }) async {
    final pending = _sessions[chatId];
    if (pending == null) throw StateError('No pending session for chat $chatId');

    final theirEphemeral = SimplePublicKey(
      base64Decode(theirEphemeralPublicKeyBase64),
      type: KeyPairType.x25519,
    );

    final session = await _dr.completeHandshake(
      pendingSession: pending,
      theirEphemeralPublic: theirEphemeral,
      peerStaticEdB64: theirEdPublicKeyBase64,
    );

    _sessions[chatId] = session;
    _sessionStatus[chatId] = E2eeSessionStatus.secured;
    await _saveSession(chatId, session);
  }

  Future<({String dhPubB64, String edPubB64, List<int> signature})>
      createHandshakeMessage(int chatId) async {
    final session = _sessions[chatId];
    if (session?.dhsSeed == null) {
      throw StateError('No DH key for handshake');
    }
    final dhs = await _x25519.newKeyPairFromSeed(session!.dhsSeed!);
    final dhsPub = await dhs.extractPublicKey();
    final dhPubB64 = base64Encode(dhsPub.bytes);

    final edPub = await _ed.getPublicKey();
    final edPubB64 = base64Encode(edPub.bytes);

    final signature = await _ed.sign(dhsPub.bytes);

    return (dhPubB64: dhPubB64, edPubB64: edPubB64, signature: signature);
  }

  Future<bool> verifyHandshakeMessage({
    required int chatId,
    required String dhPubB64,
    required String edPubB64,
    required List<int> signature,
  }) async {
    final dhPubBytes = base64Decode(dhPubB64);
    final edPubBytes = base64Decode(edPubB64);

    return _ed.verify(
      message: dhPubBytes,
      signature: signature,
      publicKeyBytes: edPubBytes,
    );
  }

  Future<void> handleHeloMessage({
    required int chatId,
    required String dhPubB64,
    required String edPubB64,
    required List<int> signature,
    required String theirPublicKeyBase64,
    required String theirEdPublicKeyBase64,
  }) async {
    final valid = await verifyHandshakeMessage(
      chatId: chatId,
      dhPubB64: dhPubB64,
      edPubB64: edPubB64,
      signature: signature,
    );
    if (!valid) {
      _sessionStatus[chatId] = E2eeSessionStatus.compromised;
      return;
    }

    if (_verifiedPeers.containsKey(chatId)) {
      if (_verifiedPeers[chatId] != theirEdPublicKeyBase64) {
        debugPrint('[E2eeService] MITM DETECTED: peer Ed25519 key changed for chat $chatId');
        _sessionStatus[chatId] = E2eeSessionStatus.compromised;
        return;
      }
    }

    final ourKeyPair = await loadKeyPair();
    if (ourKeyPair == null) throw StateError('No E2EE key pair');
    final ourStaticData = await ourKeyPair.extract() as SimpleKeyPairData;

    final theirStatic = SimplePublicKey(
      base64Decode(theirPublicKeyBase64),
      type: KeyPairType.x25519,
    );
    final theirEphemeral = SimplePublicKey(
      base64Decode(dhPubB64),
      type: KeyPairType.x25519,
    );

    final session = await _dr.respondSession(
      ourStaticSeed: List<int>.from(ourStaticData.bytes),
      theirStaticPublic: theirStatic,
      theirEphemeralPublic: theirEphemeral,
      peerStaticEdB64: theirEdPublicKeyBase64,
    );

    _sessions[chatId] = session;
    _sessionStatus[chatId] = E2eeSessionStatus.secured;
    await _saveSession(chatId, session);
  }

  // ─── Visual words / MITM protection ──────────────────────────

  Future<List<({String word, String color})>> getVisualWords(int chatId) async {
    final session = _sessions[chatId];
    if (session == null) return [];
    return _dr.getVisualWords(session.keyVal);
  }

  Future<String> computeCheckHash(int chatId) async {
    final session = _sessions[chatId];
    if (session == null) return '';
    final keyVal = session.prvKey ?? session.keyVal;
    final hash = await _dr.hashKeyValBytes(keyVal);
    return base64Encode(hash.sublist(0, 4));
  }

  Future<bool> verifyCheckHash(int chatId, String peerHashB64) async {
    final session = _sessions[chatId];
    if (session == null) return false;
    final keyVal = session.prvKey ?? session.keyVal;
    final hash = await _dr.hashKeyValBytes(keyVal);
    final ourHashB64 = base64Encode(hash.sublist(0, 4));
    return ourHashB64 == peerHashB64;
  }

  Future<void> verifyPeer(int chatId) async {
    final session = _sessions[chatId];
    if (session == null) return;
    _verifiedPeers[chatId] = session.peerStaticEd;
    await _saveVerifiedPeers();
  }

  bool isPeerVerified(int chatId) {
    return _verifiedPeers.containsKey(chatId);
  }

  Future<E2eeSessionInfo> getSessionInfo(int chatId) async {
    final status = _sessionStatus[chatId] ?? E2eeSessionStatus.none;
    final isVerified = _verifiedPeers.containsKey(chatId);
    List<({String word, String color})>? words;
    String? peerFp;
    String? ourFp;

    if (status == E2eeSessionStatus.secured) {
      words = await getVisualWords(chatId);
      final session = _sessions[chatId];
      if (session != null) {
        final peerBytes = base64Decode(session.peerStaticEd);
        peerFp = _ed.formatFingerprint(peerBytes);
      }
      final ourPub = await _ed.getPublicKey();
      ourFp = _ed.formatFingerprint(ourPub.bytes);
    }

    return E2eeSessionInfo(
      status: status,
      isVerified: isVerified,
      visualWords: words,
      peerFingerprint: peerFp,
      ourFingerprint: ourFp,
    );
  }

  E2eeSessionStatus getSessionStatus(int chatId) {
    return _sessionStatus[chatId] ?? E2eeSessionStatus.none;
  }

  // ─── Persistence ──────────────────────────────────────────────

  Future<void> _saveSession(int chatId, DoubleRatchetSession session) async {
    try {
      final json = await session.toJson();
      await _storage.write(
        key: '$_sessionPrefix$chatId',
        value: jsonEncode(json),
      );
    } catch (e) {
      debugPrint('[E2eeService] Failed to save session: $e');
    }
  }

  Future<DoubleRatchetSession?> _loadSession(int chatId) async {
    try {
      final raw = await _storage.read(key: '$_sessionPrefix$chatId');
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DoubleRatchetSession.fromJson(json);
    } catch (e) {
      debugPrint('[E2eeService] Failed to load session: $e');
      return null;
    }
  }

  Future<void> _clearAllSessions() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_sessionPrefix)) {
        await _storage.delete(key: key);
      }
    }
  }

  Future<void> _saveVerifiedPeers() async {
    final data = <String, String>{};
    for (final entry in _verifiedPeers.entries) {
      data[entry.key.toString()] = entry.value;
    }
    await _storage.write(
      key: 'e2ee.verified_peers',
      value: jsonEncode(data),
    );
  }

  Future<void> loadVerifiedPeers() async {
    try {
      final raw = await _storage.read(key: 'e2ee.verified_peers');
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in data.entries) {
        _verifiedPeers[int.parse(entry.key)] = entry.value as String;
      }
    } catch (e) {
      debugPrint('[E2eeService] Failed to load verified peers: $e');
    }
  }

  // ─── Call key derivation (unchanged) ─────────────────────────

  Future<SecretKey> deriveCallKey(int callId) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final info = utf8.encode('nios-call-key-$callId');
    final keyPair = await loadKeyPair();
    if (keyPair == null) {
      return AesGcm.with256bits().newSecretKey();
    }
    final publicKey = await keyPair.extractPublicKey() as SimplePublicKey;
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(publicKey.bytes),
      nonce: info,
      info: info,
    );
    return derived;
  }
}

final Provider<E2eeService> e2eeServiceProvider =
    Provider<E2eeService>((Ref ref) => E2eeService());
