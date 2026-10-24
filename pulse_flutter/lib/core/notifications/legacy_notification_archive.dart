import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Old notifications never recorded an account. Assigning them to whoever signs
/// in next would leak another user's history. Preserve them in an encrypted,
/// unassigned archive; never expose them through an authenticated account's UI.
Future<void> archiveUnassignedNotifications() async {
  const oldName = 'app_notifications_v1';
  const archiveName = 'notification_unassigned_archive_v2';
  const keyName = 'notification_unassigned_archive_key_v2';
  if (!await Hive.boxExists(oldName)) return;
  final old = Hive.isBoxOpen(oldName)
      ? Hive.box<String>(oldName)
      : await Hive.openBox<String>(oldName);
  if (old.isEmpty) return;
  const secure = FlutterSecureStorage();
  var key = await secure.read(key: keyName);
  if (key == null) {
    if (await Hive.boxExists(archiveName)) {
      throw StateError('NOTIFICATION_ARCHIVE_KEY_UNAVAILABLE');
    }
    key = base64Encode(Hive.generateSecureKey());
    await secure.write(key: keyName, value: key);
  }
  final archive = Hive.isBoxOpen(archiveName)
      ? Hive.box<String>(archiveName)
      : await Hive.openBox<String>(
          archiveName,
          encryptionCipher: HiveAesCipher(base64Decode(key)),
        );
  final snapshot = Map<String, String>.fromEntries(
    old.keys.map((key) => MapEntry(key.toString(), old.get(key)!)),
  );
  await archive.putAll(snapshot);
  await archive.flush();
  for (final entry in snapshot.entries) {
    if (archive.get(entry.key) != entry.value) {
      throw StateError('NOTIFICATION_ARCHIVE_VERIFY_FAILED');
    }
  }
  // Verify the full copy first; a crash during erasure can safely resume.
  await old.deleteAll(snapshot.keys);
  await old.flush();
}
