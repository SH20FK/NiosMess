import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/storage/niosgram_draft_store.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

final niosgramDraftStoreProvider = Provider<NiosgramDraftStore?>((ref) {
  final account = ref.watch(authProvider.select((s) => s.session?.userId));
  return account == null ? null : NiosgramDraftStore(account);
});
