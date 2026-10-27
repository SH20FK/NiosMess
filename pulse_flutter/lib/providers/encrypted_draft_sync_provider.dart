import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/services/encrypted_draft_sync.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

final encryptedDraftSyncProvider = Provider<EncryptedDraftSync?>((ref) {
  final storage = ref.watch(draftStorageProvider);
  final ordinary = ref.watch(ordinaryE2eeProvider);
  if (storage.accountId == null ||
      ordinary == null ||
      storage.accountId != ordinary.userId) {
    return null;
  }
  final sync = EncryptedDraftSync(
    userId: ordinary.userId,
    storage: storage,
    crypto: ordinary,
  )..start();
  ref.onDispose(() => unawaited(sync.close()));
  return sync;
});

final encryptedDraftConflictsProvider = StreamProvider<Set<int>>((ref) async* {
  final sync = ref.watch(encryptedDraftSyncProvider);
  if (sync == null) {
    yield const <int>{};
    return;
  }
  yield Set<int>.of(sync.conflicts);
  await for (final _ in sync.conflictChanges) {
    yield Set<int>.of(sync.conflicts);
  }
});
