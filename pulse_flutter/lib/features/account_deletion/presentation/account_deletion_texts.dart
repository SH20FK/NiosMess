import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

String accountDeletionDate(AppLocalizations l10n, DateTime date) =>
    DateFormat.yMMMMd(l10n.localeName).format(date.toLocal());

/// "The account will be deleted on 23 December 2026", or the dateless
/// fallback when the server did not say when.
String accountDeletionPendingTitle(
  AppLocalizations l10n,
  DateTime? scheduledAt,
) => scheduledAt == null
    ? l10n.accountDeletePendingNoDate
    : l10n.accountDeletePendingTitle(accountDeletionDate(l10n, scheduledAt));
