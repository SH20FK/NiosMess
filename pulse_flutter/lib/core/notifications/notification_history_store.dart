import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'notification_event.dart';
import 'legacy_notification_archive.dart';

/// An account owns its key and box. Logout drains writes before erasing both.
class NotificationHistoryStore {
  NotificationHistoryStore(this.accountId);
  static final _accounts = <int, NotificationHistoryStore>{};
  static NotificationHistoryStore forAccount(int account) =>
      _accounts.putIfAbsent(account, () => NotificationHistoryStore(account));
  static Future<void> eraseAccount(int account) async {
    final store =
        _accounts.remove(account) ?? NotificationHistoryStore(account);
    await store.erase();
  }

  final int accountId;
  static Future<void>? _legacyArchive;
  static const _secure = FlutterSecureStorage();
  Future<Box<String>>? _opening;
  Future<void> _writes = Future.value();
  bool _closed = false;
  String get _name => 'notification_history_v2_$accountId';
  String get _key => 'notification_history_key_v2_$accountId';

  Future<Box<String>> _open() => _opening ??= () async {
    await HiveBootstrap.ensureInitialized();
    await (_legacyArchive ??= archiveUnassignedNotifications().catchError((
      Object error,
    ) {
      _legacyArchive = null;
      throw error;
    }));
    var encoded = await _secure.read(key: _key);
    if (encoded == null) {
      if (await Hive.boxExists(_name)) {
        // Never overwrite an encrypted box when a key is temporarily missing.
        throw StateError('NOTIFICATION_KEY_UNAVAILABLE');
      }
      encoded = base64Encode(Hive.generateSecureKey());
      await _secure.write(key: _key, value: encoded);
    }
    return Hive.isBoxOpen(_name)
        ? Hive.box<String>(_name)
        : await Hive.openBox<String>(
            _name,
            encryptionCipher: HiveAesCipher(base64Decode(encoded)),
          );
  }();

  Future<void> save(List<NotificationEvent> events) {
    if (_closed) return Future.value();
    final snapshot = events.map((e) => jsonEncode(e.toJson())).toList();
    final operation = _writes.then((_) async {
      final box = await _open();
      // A single Hive entry commits the bounded history atomically.
      await box.put('snapshot', jsonEncode(snapshot));
      await box.flush();
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<List<NotificationEvent>> restore() async {
    final box = await _open();
    final raw = box.get('snapshot');
    if (raw == null) return [];
    final values = jsonDecode(raw) as List;
    return values
        .map(
          (raw) => NotificationEvent.fromJson(
            jsonDecode(raw as String) as Map<String, dynamic>,
          ),
        )
        .where((event) => event.belongsTo(accountId))
        .take(100)
        .toList();
  }

  Future<String> readReplyDraft(int chatId) async {
    if (_closed) return '';
    return (await _open()).get('reply:$chatId') ?? '';
  }

  Future<void> saveReplyDraft(int chatId, String text) {
    if (_closed) return Future.value();
    final operation = _writes.then((_) async {
      final box = await _open();
      if (text.isEmpty) {
        await box.delete('reply:$chatId');
      } else {
        await box.put('reply:$chatId', text);
      }
      await box.flush();
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> erase() async {
    _closed = true;
    await _writes;
    if (_opening != null) await _opening;
    if (Hive.isBoxOpen(_name)) await Hive.box<String>(_name).close();
    await Hive.deleteBoxFromDisk(_name);
    await _secure.delete(key: _key);
  }
}
