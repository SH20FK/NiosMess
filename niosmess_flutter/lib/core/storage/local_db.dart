import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}${Platform.pathSeparator}niosmess.db';
    return NativeDatabase(File(path));
  });
}

class LocalDb extends GeneratedDatabase {
  LocalDb() : super(_openConnection());

  static final LocalDb instance = LocalDb();

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS chats (
              owner TEXT NOT NULL,
              id TEXT NOT NULL,
              payload TEXT NOT NULL,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY (owner, id)
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS messages (
              owner TEXT NOT NULL,
              chat_id TEXT NOT NULL,
              id TEXT NOT NULL,
              payload TEXT NOT NULL,
              time INTEGER NOT NULL,
              PRIMARY KEY (owner, chat_id, id)
            )
          ''');
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_messages_chat_time ON messages(owner, chat_id, time)',
          );
          await customStatement('''
            CREATE TABLE IF NOT EXISTS profiles (
              username TEXT PRIMARY KEY,
              payload TEXT NOT NULL
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS settings (
              owner TEXT PRIMARY KEY,
              payload TEXT NOT NULL
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS sessions (
              owner TEXT PRIMARY KEY,
              payload TEXT NOT NULL
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS outbox (
              owner TEXT NOT NULL,
              id TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              PRIMARY KEY (owner, id)
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS avatars (
              username TEXT PRIMARY KEY,
              bytes BLOB NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      );
}
