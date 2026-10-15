import 'package:crypto/crypto.dart';
import 'package:universal_io/io.dart';

class UpdateIntegrity {
  static const errorCode = 'UPDATE_INTEGRITY_MISMATCH';

  static Future<bool> verify(File file, {int? size, String? sha}) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length <= 0 || (size != null && size > 0 && length != size)) {
      return false;
    }
    if (sha == null) {
      return true; // Compatibility with previously published releases.
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == sha;
  }
}
