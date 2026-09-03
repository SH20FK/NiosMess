import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Cryptographic PKCE (Proof Key for Code Exchange) S256 generator and URL-safe encoder.
///
/// Implements RFC 7636 S256 code challenge generation and unpadded Base64URL formatting
/// for OAuth 2.0 with Nios ID.
class PkceHelper {
  const PkceHelper._();

  /// Converts arbitrary bytes to unpadded Base64URL string (RFC 7636 §3).
  ///
  /// Replaces `+` with `-`, `/` with `_`, and strips all trailing `=` padding characters.
  static String base64UrlUnpadded(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Generates cryptographically secure random bytes from CSPRNG.
  static Uint8List _randomBytes(int length) {
    final Random random = Random.secure();
    final Uint8List bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Generates a PKCE code verifier of [byteLength] random bytes (default: 64 bytes = 512 bits).
  ///
  /// The resulting Base64URL string has high entropy (typically ~86 characters)
  /// without padding characters.
  static String generateCodeVerifier([int byteLength = 64]) {
    return base64UrlUnpadded(_randomBytes(byteLength));
  }

  /// Computes the S256 code challenge from the given [verifier].
  ///
  /// Calculates SHA-256 digest of ASCII bytes of the verifier string and encodes
  /// the digest as unpadded Base64URL (RFC 7636 §4.2).
  static String generateCodeChallenge(String verifier) {
    final List<int> bytes = utf8.encode(verifier);
    final Digest digest = sha256.convert(bytes);
    return base64UrlUnpadded(digest.bytes);
  }

  /// Generates a cryptographically secure random state parameter (default: 24 bytes = 192 bits).
  static String generateState([int byteLength = 24]) {
    return base64UrlUnpadded(_randomBytes(byteLength));
  }

  /// Generates a cryptographically secure random nonce parameter (default: 24 bytes = 192 bits).
  static String generateNonce([int byteLength = 24]) {
    return base64UrlUnpadded(_randomBytes(byteLength));
  }
}
