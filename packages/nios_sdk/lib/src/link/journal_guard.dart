import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:universal_io/io.dart';

/// Hive's crash recovery may truncate a file opened with the wrong key. Check a
/// domain-bound key commitment before opening it so a key error cannot erase it.
Future<File> verifyJournalKey({
  required String directory,
  required String name,
  required List<int> key,
}) async {
  final file = File('$directory${Platform.pathSeparator}$name.keycheck');
  // The key commitment is created before Hive can acquire its data-file lock.
  // Serialize that creation across processes too, otherwise simultaneous first
  // opens with different keys could leave a commitment for the losing writer.
  final guard = await File('${file.path}.lock').open(mode: FileMode.append);
  try {
    await guard.lock(FileLock.exclusive);
    try {
      return await _verifyLockedJournalKey(file, name, directory, key);
    } finally {
      await guard.unlock();
    }
  } finally {
    await guard.close();
  }
}

Future<File> _verifyLockedJournalKey(
  File file,
  String name,
  String directory,
  List<int> key,
) async {
  final expected = Hmac(
    sha256,
    key,
  ).convert(utf8.encode('nios-link-journal-key-v1:$name')).bytes;
  if (await file.exists()) {
    final actual = await file.readAsBytes();
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ (i < actual.length ? actual[i] : 0);
    }
    if (difference != 0) {
      throw StateError('Journal key does not match; data was preserved');
    }
  } else {
    if (await File('$directory${Platform.pathSeparator}$name.hive').exists()) {
      throw StateError('Journal key commitment is missing; data was preserved');
    }
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(expected, flush: true);
    await temporary.rename(file.path);
  }
  return file;
}
