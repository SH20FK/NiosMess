import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/features/account_deletion/data/account_deletion_repository.dart';
import 'package:pulse_flutter/features/account_deletion/domain/account_deletion_status.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

/// Deletion status of the signed-in account, read when the deletion screen
/// opens. Server refusals are thrown to the caller, which maps them with
/// [AccountDeletionFailure.of].
class AccountDeletionController extends AsyncNotifier<AccountDeletionStatus> {
  @override
  Future<AccountDeletionStatus> build() {
    // Another account must never inherit this one's answer.
    final int? account = ref.watch(
      authProvider.select((AuthState a) => a.session?.userId),
    );
    // Signed out, the screen is on its way out: asking now would only earn
    // an "Unauthorized" and a second logout.
    if (account == null) return Completer<AccountDeletionStatus>().future;
    return ref.watch(accountDeletionRepositoryProvider).status();
  }

  Future<void> requestCode() =>
      ref.read(accountDeletionRepositoryProvider).requestCode();

  /// After this returns the session is already dead on the server: the
  /// caller signs out locally.
  Future<AccountDeletionStatus> confirm(String code) async {
    final AccountDeletionStatus status = await ref
        .read(accountDeletionRepositoryProvider)
        .confirm(code);
    if (ref.mounted) state = AsyncData<AccountDeletionStatus>(status);
    return status;
  }

  Future<void> cancel() async {
    final AccountDeletionRepository repository = ref.read(
      accountDeletionRepositoryProvider,
    );
    await repository.cancel();
    if (!ref.mounted) return;
    final AsyncValue<AccountDeletionStatus> next = await AsyncValue.guard(
      repository.status,
    );
    if (!ref.mounted) return;
    state = next;
    // The profile carries the same flag for the hub card and the sign-in
    // warning.
    await ref.read(authProvider.notifier).refreshProfile();
  }
}

final accountDeletionControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AccountDeletionController,
      AccountDeletionStatus
    >(AccountDeletionController.new);
