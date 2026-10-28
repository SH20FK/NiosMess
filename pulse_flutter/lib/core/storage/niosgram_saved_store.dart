import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/models/api/post_model.dart';

/// Saved feed snapshots are local to an account and are not a server bookmark.
class NiosgramSavedStore {
  NiosgramSavedStore(this.accountId)
    : _generation = _generations[accountId] ?? 0;

  final int accountId;
  final int _generation;
  static const _storage = FlutterSecureStorage();
  static final _generations = <int, int>{};
  static final _tails = <int, Future<void>>{};
  String get _key => 'niosgram.saved.v1.$accountId';
  bool get _valid => _generation == (_generations[accountId] ?? 0);

  Future<T> _serial<T>(Future<T> Function() action) {
    final previous = _tails[accountId] ?? Future<void>.value();
    final operation = previous.then((_) async {
      if (!_valid) throw StateError('SAVED_ACCOUNT_CLOSED');
      final result = await action();
      if (!_valid) throw StateError('SAVED_ACCOUNT_CLOSED');
      return result;
    });
    _tails[accountId] = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<List<NgPost>> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return <NgPost>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('SAVED_POSTS_INVALID');
    return decoded.map((item) {
      if (item is! Map) throw const FormatException('SAVED_POST_INVALID');
      return NgPost.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  Future<List<NgPost>> read() => _serial(_read);

  Future<List<NgPost>> toggle(NgPost post) => _serial(() async {
    final posts = await _read();
    final index = posts.indexWhere((item) => item.id == post.id);
    if (index < 0) {
      // Save only the shareable snapshot, not private reaction/quiz state.
      posts.insert(0, NgPost.fromJson(post.toPublicCacheJson()));
    } else {
      posts.removeAt(index);
    }
    if (!_valid) throw StateError('SAVED_ACCOUNT_CLOSED');
    await _storage.write(
      key: _key,
      value: jsonEncode(posts.map((item) => item.toPublicCacheJson()).toList()),
    );
    return posts;
  });

  static Future<void> eraseAccount(int accountId) async {
    _generations[accountId] = (_generations[accountId] ?? 0) + 1;
    final previous = _tails[accountId] ?? Future<void>.value();
    final operation = previous.then(
      (_) => _storage.delete(key: 'niosgram.saved.v1.$accountId'),
    );
    _tails[accountId] = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    await operation;
  }
}
