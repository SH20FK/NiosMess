import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/features/account_deletion/domain/account_deletion_status.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class AccountDeletionRepository {
  const AccountDeletionRepository(this._ref);
  final Ref _ref;

  // Never retried: a repeated request would email a second code or confirm
  // twice.
  Future<dynamic> _send(
    String action, [
    Map<String, dynamic> payload = const <String, dynamic>{},
  ]) => _ref
      .read(webSocketClientProvider)
      .request(action, payload: payload, maxRetries: 0);

  Future<AccountDeletionStatus> status() async =>
      AccountDeletionStatus.fromJson(
        asStringMap(await _send('get_account_deletion_status')),
      );

  /// Emails a one-time code. Nothing is scheduled until [confirm].
  Future<void> requestCode() => _send('request_account_deletion');

  /// Schedules the deletion and ends every session, this one included.
  Future<AccountDeletionStatus> confirm(String code) async =>
      AccountDeletionStatus.fromJson(
        asStringMap(
          await _send('confirm_account_deletion', <String, dynamic>{
            'code': code,
          }),
        ),
      );

  Future<void> cancel() => _send('cancel_account_deletion');
}

final Provider<AccountDeletionRepository> accountDeletionRepositoryProvider =
    Provider<AccountDeletionRepository>(
      (Ref ref) => AccountDeletionRepository(ref),
    );
