import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class DRHeader {
  final String dh;
  final int pn;
  final int n;

  const DRHeader({required this.dh, required this.pn, required this.n});

  Map<String, dynamic> toJson() => {'dh': dh, 'pn': pn, 'n': n};

  factory DRHeader.fromJson(Map<String, dynamic> json) => DRHeader(
        dh: json['dh'] as String,
        pn: json['pn'] as int,
        n: json['n'] as int,
      );
}

class DRMetadata {
  final String type;
  final String content;
  final String? fileName;
  final String? fileData;

  const DRMetadata({
    required this.type,
    required this.content,
    this.fileName,
    this.fileData,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'t': type};
    if (type == 'file') {
      m['n'] = fileName;
      m['d'] = fileData;
    } else {
      m['c'] = content;
    }
    return m;
  }

  factory DRMetadata.fromJson(Map<String, dynamic> json) => DRMetadata(
        type: json['t'] as String,
        content: (json['c'] ?? json['n'] ?? '') as String,
        fileName: json['n'] as String?,
        fileData: json['d'] as String?,
      );
}

class DoubleRatchetSession {
  SecretKey ratKey;
  List<int>? dhsSeed;
  List<int> dhrKeyBytes;
  SecretKey? chnKsx;
  SecretKey? chnKrx;
  int numSnt;
  int numRcv;
  int prvNum;
  Map<String, SecretKey> skipKs;
  SecretKey keyVal;
  SecretKey? prvKey;
  String peerStaticEd;

  DoubleRatchetSession({
    required this.ratKey,
    this.dhsSeed,
    required this.dhrKeyBytes,
    this.chnKsx,
    this.chnKrx,
    this.numSnt = 0,
    this.numRcv = 0,
    this.prvNum = 0,
    Map<String, SecretKey>? skipKs,
    required this.keyVal,
    this.prvKey,
    required this.peerStaticEd,
  }) : skipKs = skipKs ?? {};

  DoubleRatchetSession copy() {
    return DoubleRatchetSession(
      ratKey: ratKey,
      dhsSeed: dhsSeed != null ? List<int>.from(dhsSeed!) : null,
      dhrKeyBytes: List<int>.from(dhrKeyBytes),
      chnKsx: chnKsx,
      chnKrx: chnKrx,
      numSnt: numSnt,
      numRcv: numRcv,
      prvNum: prvNum,
      skipKs: Map<String, SecretKey>.from(skipKs),
      keyVal: keyVal,
      prvKey: prvKey,
      peerStaticEd: peerStaticEd,
    );
  }

  Future<Map<String, dynamic>> toJson() async {
    return <String, dynamic>{
      'ratKey': base64Encode(await ratKey.extractBytes()),
      'dhsSeed': dhsSeed != null ? base64Encode(dhsSeed!) : null,
      'dhrKey': base64Encode(dhrKeyBytes),
      'chnKsx': chnKsx != null ? base64Encode(await chnKsx!.extractBytes()) : null,
      'chnKrx': chnKrx != null ? base64Encode(await chnKrx!.extractBytes()) : null,
      'numSnt': numSnt,
      'numRcv': numRcv,
      'prvNum': prvNum,
      'keyVal': base64Encode(await keyVal.extractBytes()),
      'prvKey': prvKey != null ? base64Encode(await prvKey!.extractBytes()) : null,
      'peerStaticEd': peerStaticEd,
    };
  }

  static Future<DoubleRatchetSession> fromJson(
    Map<String, dynamic> json,
  ) async {
    return DoubleRatchetSession(
      ratKey: SecretKey(base64Decode(json['ratKey'] as String)),
      dhsSeed: json['dhsSeed'] != null
          ? base64Decode(json['dhsSeed'] as String)
          : null,
      dhrKeyBytes: base64Decode(json['dhrKey'] as String),
      chnKsx: json['chnKsx'] != null
          ? SecretKey(base64Decode(json['chnKsx'] as String))
          : null,
      chnKrx: json['chnKrx'] != null
          ? SecretKey(base64Decode(json['chnKrx'] as String))
          : null,
      numSnt: json['numSnt'] as int? ?? 0,
      numRcv: json['numRcv'] as int? ?? 0,
      prvNum: json['prvNum'] as int? ?? 0,
      keyVal: SecretKey(base64Decode(json['keyVal'] as String)),
      prvKey: json['prvKey'] != null
          ? SecretKey(base64Decode(json['prvKey'] as String))
          : null,
      peerStaticEd: json['peerStaticEd'] as String? ?? '',
    );
  }
}

int _compareBytes(List<int> a, List<int> b) {
  final len = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}

class DoubleRatchetService {
  final X25519 _x25519 = X25519();

  Future<KeyPair> _restoreDhs(List<int> seed) {
    return _x25519.newKeyPairFromSeed(seed);
  }

  Future<KeyPair> _generateDhs() {
    return _x25519.newKeyPair();
  }

  Future<SecretKey> _hkdf(
    List<int> input,
    List<int> info, {
    List<int>? salt,
    int outputLength = 32,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: outputLength);
    return hkdf.deriveKey(
      secretKey: SecretKey(input),
      nonce: salt ?? <int>[],
      info: info,
    );
  }

  Future<({SecretKey newRoot, SecretKey newChain})> kdfrk(
    SecretKey ratKey,
    SecretKey dhOut,
  ) async {
    final salt = await ratKey.extractBytes();
    final output = await _hkdf(
      await dhOut.extractBytes(),
      utf8.encode('KDF_RK'),
      salt: salt,
      outputLength: 64,
    );
    final raw = await output.extractBytes();
    return (
      newRoot: SecretKey(raw.sublist(0, 32)),
      newChain: SecretKey(raw.sublist(32)),
    );
  }

  Future<({SecretKey newChain, SecretKey msgKey})> kdfck(
    SecretKey chainKey,
  ) async {
    final output = await _hkdf(
      await chainKey.extractBytes(),
      utf8.encode('KDF_CK'),
      outputLength: 64,
    );
    final raw = await output.extractBytes();
    return (
      newChain: SecretKey(raw.sublist(0, 32)),
      msgKey: SecretKey(raw.sublist(32)),
    );
  }

  Future<SecretKey> _computeVisualKey(
    SecretKey? chnKsx,
    SecretKey? chnKrx,
  ) async {
    final ck1 = chnKsx != null ? await chnKsx.extractBytes() : <int>[];
    final ck2 = chnKrx != null ? await chnKrx.extractBytes() : <int>[];
    List<int> minCk;
    List<int> maxCk;
    if (_compareBytes(ck1, ck2) <= 0) {
      minCk = ck1;
      maxCk = ck2;
    } else {
      minCk = ck2;
      maxCk = ck1;
    }
    return _hkdf(
      [...minCk, ...maxCk],
      utf8.encode('Visual'),
    );
  }

  Future<void> skipKs(DoubleRatchetSession session, int until) async {
    if (session.numRcv + 100 < until) {
      throw StateError('Too many skipped messages');
    }
    if (session.chnKrx != null) {
      while (session.numRcv < until) {
        final result = await kdfck(session.chnKrx!);
        session.chnKrx = result.newChain;
        session.skipKs['${base64Encode(session.dhrKeyBytes)}_${session.numRcv}'] =
            result.msgKey;
        session.numRcv++;
      }
    }
  }

  Future<void> dhratch(
    DoubleRatchetSession session,
    DRHeader header,
  ) async {
    session.prvNum = session.numSnt;
    session.numSnt = 0;
    session.numRcv = 0;
    session.dhrKeyBytes = base64Decode(header.dh);
    final dhrKey =
        SimplePublicKey(session.dhrKeyBytes, type: KeyPairType.x25519);

    if (session.dhsSeed == null) throw StateError('No DH private key');
    final dhsOld = await _restoreDhs(session.dhsSeed!);

    final dhOut1 = await _x25519.sharedSecretKey(
      keyPair: dhsOld,
      remotePublicKey: dhrKey,
    );
    var r = await kdfrk(session.ratKey, dhOut1);
    session.ratKey = r.newRoot;
    session.chnKrx = r.newChain;

    final newDhs = await _generateDhs();
    final newDhsData = await newDhs.extract() as SimpleKeyPairData;
    session.dhsSeed = List<int>.from(newDhsData.bytes);
    final dhOut2 = await _x25519.sharedSecretKey(
      keyPair: newDhs,
      remotePublicKey: dhrKey,
    );
    r = await kdfrk(session.ratKey, dhOut2);
    session.ratKey = r.newRoot;
    session.chnKsx = r.newChain;
  }

  Future<({String headerB64, List<int> ciphertext})> encrypt({
    required DoubleRatchetSession session,
    required String plaintext,
    required String messageType,
    String? fileName,
    String? fileData,
  }) async {
    if (session.chnKsx == null) {
      throw StateError('No sending chain key available');
    }
    if (session.dhsSeed == null) {
      throw StateError('No DH private key');
    }

    final ckResult = await kdfck(session.chnKsx!);
    session.chnKsx = ckResult.newChain;
    final msgKey = ckResult.msgKey;

    final dhs = await _restoreDhs(session.dhsSeed!);
    final dhsPub = await dhs.extractPublicKey() as SimplePublicKey;

    final header = DRHeader(
      dh: base64Encode(dhsPub.bytes),
      pn: session.prvNum,
      n: session.numSnt,
    );
    session.numSnt++;

    final metadata = DRMetadata(
      type: messageType,
      content: plaintext,
      fileName: fileName,
      fileData: fileData,
    );

    final headerJson = utf8.encode(jsonEncode(header.toJson()));
    final headerB64 = base64Encode(headerJson);
    final headerBytes = base64Decode(headerB64);

    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      utf8.encode(jsonEncode(metadata.toJson())),
      secretKey: msgKey,
      aad: headerBytes,
    );

    final ciphertext = <int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];

    session.keyVal = await _computeVisualKey(session.chnKsx, session.chnKrx);

    return (headerB64: headerB64, ciphertext: ciphertext);
  }

  Future<String?> decrypt({
    required DoubleRatchetSession session,
    required String headerB64,
    required List<int> ciphertext,
  }) async {
    final headerBytes = base64Decode(headerB64);
    final header = DRHeader.fromJson(
      jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>,
    );

    final mksKey = '${header.dh}_${header.n}';
    if (session.skipKs.containsKey(mksKey)) {
      final msgKey = session.skipKs.remove(mksKey)!;
      return _decryptWithKey(msgKey, headerBytes, ciphertext);
    }

    final tmpSession = session.copy();

    try {
      if (header.dh != base64Encode(tmpSession.dhrKeyBytes)) {
        await skipKs(tmpSession, header.pn);
        await dhratch(tmpSession, header);
      }

      await skipKs(tmpSession, header.n);

      if (tmpSession.chnKrx == null) return null;

      final ckResult = await kdfck(tmpSession.chnKrx!);
      tmpSession.chnKrx = ckResult.newChain;
      final msgKey = ckResult.msgKey;
      tmpSession.numRcv++;

      final plaintext = await _decryptWithKey(msgKey, headerBytes, ciphertext);
      if (plaintext == null) return null;

      session.ratKey = tmpSession.ratKey;
      session.dhsSeed = tmpSession.dhsSeed;
      session.dhrKeyBytes = tmpSession.dhrKeyBytes;
      session.chnKsx = tmpSession.chnKsx;
      session.chnKrx = tmpSession.chnKrx;
      session.numSnt = tmpSession.numSnt;
      session.numRcv = tmpSession.numRcv;
      session.prvNum = tmpSession.prvNum;
      session.skipKs = tmpSession.skipKs;

      session.prvKey = session.keyVal;
      session.keyVal =
          await _computeVisualKey(session.chnKsx, session.chnKrx);
      return plaintext;
    } catch (e) {
      debugPrint('[DoubleRatchet] Decrypt failed: $e');
      return null;
    }
  }

  Future<String?> _decryptWithKey(
    SecretKey msgKey,
    List<int> headerBytes,
    List<int> ciphertext,
  ) async {
    try {
      if (ciphertext.length < 28) return null;
      final iv = ciphertext.sublist(0, 12);
      final tag = ciphertext.sublist(ciphertext.length - 16);
      final ct = ciphertext.sublist(12, ciphertext.length - 16);

      final aesGcm = AesGcm.with256bits();
      final secretBox = SecretBox(ct, nonce: iv, mac: Mac(tag));
      final decrypted = await aesGcm.decrypt(
        secretBox,
        secretKey: msgKey,
        aad: headerBytes,
      );
      final metadata = DRMetadata.fromJson(
        jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>,
      );
      return metadata.type == 'file' ? metadata.fileName : metadata.content;
    } catch (e) {
      debugPrint('[DoubleRatchet] _decryptWithKey failed: $e');
      return null;
    }
  }

  Future<({String dhPubB64, List<int> seed})> generateEphemeralKey() async {
    final kp = await _x25519.newKeyPair();
    final pub = await kp.extractPublicKey();
    final data = await kp.extract();
    return (dhPubB64: base64Encode(pub.bytes), seed: List<int>.from(data.bytes));
  }

  /// Initiator: create session from static keys only.
  Future<DoubleRatchetSession> initiateSession({
    required List<int> ourStaticSeed,
    required SimplePublicKey theirStaticPublic,
    required String peerStaticEdB64,
  }) async {
    final ourStatic = await _x25519.newKeyPairFromSeed(ourStaticSeed);

    final dhOut = await _x25519.sharedSecretKey(
      keyPair: ourStatic,
      remotePublicKey: theirStaticPublic,
    );
    var ratKey = dhOut;
    var r = await kdfrk(ratKey, dhOut);
    ratKey = r.newRoot;
    final chnKrx = r.newChain;

    final dhs = await _generateDhs();
    final dhsData = await dhs.extract() as SimpleKeyPairData;

    final dhOut2 = await _x25519.sharedSecretKey(
      keyPair: dhs,
      remotePublicKey: theirStaticPublic,
    );
    r = await kdfrk(ratKey, dhOut2);
    ratKey = r.newRoot;
    final chnKsx = r.newChain;

    final keyVal = await _computeVisualKey(chnKsx, chnKrx);

    return DoubleRatchetSession(
      ratKey: ratKey,
      dhsSeed: List<int>.from(dhsData.bytes),
      dhrKeyBytes: List<int>.from(theirStaticPublic.bytes),
      chnKsx: chnKsx,
      chnKrx: chnKrx,
      keyVal: keyVal,
      peerStaticEd: peerStaticEdB64,
    );
  }

  /// Responder: create session from static keys + initiator's ephemeral.
  Future<DoubleRatchetSession> respondSession({
    required List<int> ourStaticSeed,
    required SimplePublicKey theirStaticPublic,
    required SimplePublicKey theirEphemeralPublic,
    required String peerStaticEdB64,
  }) async {
    final ourStatic = await _x25519.newKeyPairFromSeed(ourStaticSeed);

    final dhOut1 = await _x25519.sharedSecretKey(
      keyPair: ourStatic,
      remotePublicKey: theirStaticPublic,
    );
    var ratKey = dhOut1;
    var r = await kdfrk(ratKey, dhOut1);
    ratKey = r.newRoot;
    var chnKrx = r.newChain;

    final dhOut2 = await _x25519.sharedSecretKey(
      keyPair: ourStatic,
      remotePublicKey: theirEphemeralPublic,
    );
    r = await kdfrk(ratKey, dhOut2);
    ratKey = r.newRoot;
    chnKrx = r.newChain;

    final dhs = await _generateDhs();
    final dhsData = await dhs.extract() as SimpleKeyPairData;
    final dhOut3 = await _x25519.sharedSecretKey(
      keyPair: dhs,
      remotePublicKey: theirEphemeralPublic,
    );
    r = await kdfrk(ratKey, dhOut3);
    ratKey = r.newRoot;
    final chnKsx = r.newChain;

    final keyVal = await _computeVisualKey(chnKsx, chnKrx);

    return DoubleRatchetSession(
      ratKey: ratKey,
      dhsSeed: List<int>.from(dhsData.bytes),
      dhrKeyBytes: List<int>.from(theirEphemeralPublic.bytes),
      chnKsx: chnKsx,
      chnKrx: chnKrx,
      keyVal: keyVal,
      peerStaticEd: peerStaticEdB64,
    );
  }

  /// Initiator completing handshake after receiving RESP.
  Future<DoubleRatchetSession> completeHandshake({
    required DoubleRatchetSession pendingSession,
    required SimplePublicKey theirEphemeralPublic,
    required String peerStaticEdB64,
  }) async {
    if (pendingSession.dhsSeed == null) {
      throw StateError('No DH private key in pending session');
    }
    final dhs = await _restoreDhs(pendingSession.dhsSeed!);
    final dhOut = await _x25519.sharedSecretKey(
      keyPair: dhs,
      remotePublicKey: theirEphemeralPublic,
    );
    var ratKey = dhOut;
    final r = await kdfrk(ratKey, dhOut);
    ratKey = r.newRoot;
    final chnKsx = r.newChain;

    final keyVal = await _computeVisualKey(chnKsx, null);

    return DoubleRatchetSession(
      ratKey: ratKey,
      dhsSeed: pendingSession.dhsSeed,
      dhrKeyBytes: List<int>.from(theirEphemeralPublic.bytes),
      chnKsx: chnKsx,
      chnKrx: null,
      keyVal: keyVal,
      peerStaticEd: peerStaticEdB64,
    );
  }

  /// Generate 4 colored visual words (matches Python get_wrd).
  Future<List<({String word, String color})>> getVisualWords(
    SecretKey keyVal,
  ) async {
    final sha256 = Sha256();
    final hash = await sha256.hash(await keyVal.extractBytes());
    final hashBytes = hash.bytes;

    const words = [
      'acid', 'apex', 'band', 'bark', 'beta', 'bolt', 'born', 'calm', 'clay',
      'coal', 'dark', 'dawn', 'echo', 'edge', 'envy', 'fade', 'film', 'flow',
      'flux', 'glow', 'grid', 'hawk', 'haze', 'hint', 'icon', 'iron', 'jade',
      'jolt', 'kept', 'lava', 'leaf', 'limo', 'maze', 'mist', 'neon', 'node',
      'opal', 'open', 'path', 'pave', 'rift', 'rust', 'sand', 'silk', 'spark',
      'tide', 'toad', 'volt', 'wave', 'zinc',
    ];

    const colors = [
      'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white',
    ];

    final result = <({String word, String color})>[];
    for (var i = 0; i < 4; i++) {
      final wordIdx = hashBytes[i * 2] % 50;
      final colorIdx = hashBytes[i * 2 + 1] % 7;
      result.add((word: words[wordIdx], color: colors[colorIdx]));
    }
    return result;
  }

  Future<List<int>> hashKeyValBytes(SecretKey keyVal) async {
    final sha256 = Sha256();
    final hash = await sha256.hash(await keyVal.extractBytes());
    return hash.bytes;
  }
}
