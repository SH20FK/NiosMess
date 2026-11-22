import 'package:flutter/foundation.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/server_time.dart';

/// Server answer for `get_account_deletion_status` and
/// `confirm_account_deletion`.
@immutable
class AccountDeletionStatus {
  const AccountDeletionStatus({
    required this.isPending,
    required this.graceDays,
    this.scheduledAt,
  });

  factory AccountDeletionStatus.fromJson(Map<String, dynamic> json) =>
      AccountDeletionStatus(
        isPending: json['is_pending_deletion'] == true,
        graceDays: (json['grace_days'] as num).toInt(),
        scheduledAt: parseServerUtc(json['deletion_scheduled_at']),
      );

  final bool isPending;

  /// Days between confirmation and the final erase.
  final int graceDays;
  final DateTime? scheduledAt;
}

/// Why the server refused. It answers with English sentences only, so the
/// reason is recognized by its wording and shown in the app's own words.
enum AccountDeletionFailure {
  plusActive,
  invalidCode,
  alreadyScheduled,
  notScheduled,
  unknown;

  static AccountDeletionFailure of(Object error) {
    if (error is! ApiException) return AccountDeletionFailure.unknown;
    final String message = error.message.toLowerCase();
    if (message.contains('subscription')) {
      return AccountDeletionFailure.plusActive;
    }
    if (message.contains('invalid or expired code') ||
        message.contains('code is required')) {
      return AccountDeletionFailure.invalidCode;
    }
    if (message.contains('already scheduled')) {
      return AccountDeletionFailure.alreadyScheduled;
    }
    if (message.contains('no pending deletion')) {
      return AccountDeletionFailure.notScheduled;
    }
    return AccountDeletionFailure.unknown;
  }
}
