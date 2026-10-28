import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/storage/niosgram_saved_store.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

final niosgramSavedProvider =
    AsyncNotifierProvider<NiosgramSavedNotifier, List<NgPost>>(
      NiosgramSavedNotifier.new,
    );

class NiosgramSavedNotifier extends AsyncNotifier<List<NgPost>> {
  int? _account;

  @override
  Future<List<NgPost>> build() async {
    final account = ref.watch(authProvider.select((s) => s.session?.userId));
    if (_account != null && _account != account) {
      // Never expose the previous account's snapshots during an async reload.
      state = const AsyncData(<NgPost>[]);
      state = const AsyncLoading();
    }
    _account = account;
    if (account == null) return <NgPost>[];
    return NiosgramSavedStore(account).read();
  }

  Future<void> toggle(NgPost post) async {
    final account = ref.read(authProvider).session?.userId;
    if (account == null || ref.read(authProvider.notifier).isLoggingOut) {
      throw StateError('SAVED_ACCOUNT_UNAVAILABLE');
    }
    final posts = await NiosgramSavedStore(account).toggle(post);
    if (!ref.mounted ||
        ref.read(authProvider).session?.userId != account ||
        ref.read(authProvider.notifier).isLoggingOut) {
      return;
    }
    state = AsyncData(posts);
  }
}
