import 'package:crypto/crypto.dart';
import 'package:universal_io/io.dart';

class UpdateIntegrity {
  static const errorCode = 'UPDATE_INTEGRITY_MISMATCH';

  /// An artifact must carry a sha256 from the release manifest before it may
  /// be installed; size-only checks are a download convenience, not trust.
  static bool hasAuthenticatedDigest(String? sha) =>
      sha != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(sha);

  static Future<bool> verifyForInstall(
    File file, {
    int? size,
    String? sha,
  }) async {
    if (!hasAuthenticatedDigest(sha)) return false;
    return verify(file, size: size, sha: sha);
  }

  static Future<bool> verify(File file, {int? size, String? sha}) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length <= 0 || (size != null && size > 0 && length != size)) {
      return false;
    }
    if (sha == null) {
      // Compatibility with previously published releases. Install paths must
      // use [verifyForInstall], which refuses digest-less manifests.
      return true;
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == sha;
  }
}
