import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/server_time.dart';
import 'package:pulse_flutter/features/account_deletion/domain/account_deletion_status.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';

ApiException _refusal(String message) =>
    ApiException(statusCode: 400, message: message);

void main() {
  group('Account deletion', () {
    test('server time without an offset is read as UTC', () {
      expect(
        parseServerUtc('2026-12-23T10:00:00'),
        DateTime.utc(2026, 12, 23, 10),
      );
      final DateTime? withOffset = parseServerUtc('2026-12-23T10:00:00+00:00');
      expect(withOffset, DateTime.utc(2026, 12, 23, 10));
      expect(withOffset!.isUtc, isTrue);
      expect(parseServerUtc(null), isNull);
      expect(parseServerUtc('not a date'), isNull);
    });

    test('status is parsed from the server answer', () {
      final AccountDeletionStatus pending = AccountDeletionStatus.fromJson(
        <String, dynamic>{
          'is_pending_deletion': true,
          'deletion_requested_at': '2026-11-22T10:00:00',
          'deletion_scheduled_at': '2026-12-23T10:00:00',
          'grace_days': 31,
        },
      );
      expect(pending.isPending, isTrue);
      expect(pending.graceDays, 31);
      expect(pending.scheduledAt, DateTime.utc(2026, 12, 23, 10));

      final AccountDeletionStatus idle = AccountDeletionStatus.fromJson(
        <String, dynamic>{
          'is_pending_deletion': false,
          'deletion_requested_at': null,
          'deletion_scheduled_at': null,
          'grace_days': 31,
        },
      );
      expect(idle.isPending, isFalse);
      expect(idle.scheduledAt, isNull);
    });

    // The exact sentences the server sends today: profile_handler.py and
    // account_deletion_svc.py.
    test('server refusals are recognized by their wording', () {
      expect(
        AccountDeletionFailure.of(
          _refusal(
            'Cancel your Nios+ subscription before deleting the account',
          ),
        ),
        AccountDeletionFailure.plusActive,
      );
      expect(
        AccountDeletionFailure.of(_refusal('Invalid or expired code')),
        AccountDeletionFailure.invalidCode,
      );
      expect(
        AccountDeletionFailure.of(_refusal('code is required')),
        AccountDeletionFailure.invalidCode,
      );
      expect(
        AccountDeletionFailure.of(
          _refusal('Account deletion is already scheduled'),
        ),
        AccountDeletionFailure.alreadyScheduled,
      );
      expect(
        AccountDeletionFailure.of(_refusal('No pending deletion to cancel')),
        AccountDeletionFailure.notScheduled,
      );
      expect(
        AccountDeletionFailure.of(_refusal('Server response timed out')),
        AccountDeletionFailure.unknown,
      );
      expect(
        AccountDeletionFailure.of(StateError('anything')),
        AccountDeletionFailure.unknown,
      );
    });

    test('profile carries the flag and keeps it through the cache', () {
      final ApiProfile fresh = ApiProfile.fromJson(<String, dynamic>{
        'id': 1,
        'username': 'alex',
        'display_name': 'Alex',
        'is_pending_deletion': true,
        'deletion_scheduled_at': '2026-12-23T10:00:00',
      });
      expect(fresh.isPendingDeletion, isTrue);
      expect(fresh.deletionScheduledAt, DateTime.utc(2026, 12, 23, 10));

      final ApiProfile cached = ApiProfile.fromJson(fresh.toJson());
      expect(cached.isPendingDeletion, isTrue);
      expect(cached.deletionScheduledAt, DateTime.utc(2026, 12, 23, 10));
      expect(fresh.copyWith(bio: 'new').isPendingDeletion, isTrue);
    });

    test('an old server without the flag means no deletion', () {
      final ApiProfile profile = ApiProfile.fromJson(<String, dynamic>{
        'id': 1,
        'username': 'alex',
        'display_name': 'Alex',
      });
      expect(profile.isPendingDeletion, isFalse);
      expect(profile.deletionScheduledAt, isNull);
    });
  });
}
